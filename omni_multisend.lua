--[[
    omni_multisend.lua - the Multisend tab.

    Uses Ashita's Multisend plugin (/ms) to drive your other characters on this PC:
      * Follow Me   - your other characters walk after you (/ms followme on|off).
      * Sim-cast    - whatever spell you cast, your alt casts too (and optionally your
                      weapon skills and job abilities). Enemies are cast on with <bt>,
                      yourself and other players by name, self-only spells on <me>.
      * Quick buttons - assist, attack, stop attacking, follow, and a free command box.
]]

local imgui = require('imgui');
local settings = require('settings');

local ms = {};
ms.height = 300;

local defaults = T{
    simcast = false,        -- copy spells
    copy_ws = false,        -- copy weapon skills
    copy_ja = false,        -- copy job abilities
    delay = 0,              -- seconds to wait before the alt copies you
    enemy_target = 'assist', -- 'assist' (/assist you, then <t>), 'bt' or 't'
    assist_set = false,     -- moved old settings over to 'assist' once
    copy_all = false,       -- copy everything: spells, WS, JA, engage/disengage, ranged, items
    all_delay = 0.3,        -- seconds behind you when copying everything
};
local s = settings.load(defaults, 'omni_ms');
settings.register('omni_ms', 'omni_ms_update', function (n) if (n ~= nil) then s = n; end end);
local function save() pcall(function () settings.save('omni_ms'); end); end
-- <bt> only works once your party has claimed the mob, and the copy goes out before your spell lands,
-- so opening nukes found nothing. Assist is the new default; switch it on once for old settings.
if (not s.assist_set) then s.enemy_target = 'assist'; s.assist_set = true; save(); end

local followme = false;   -- what we last told Multisend
local queue = {};         -- { at = clock, cmd = '...' }
local last_sent = nil;
local free_cmd = { '' };

local GOLD  = { 0.79, 0.69, 0.42, 1.0 };
local GREEN = { 0.50, 0.88, 0.50, 1.0 };
local DIM   = { 0.62, 0.66, 0.80, 1.0 };

local function run(cmd) pcall(function () AshitaCore:GetChatManager():QueueCommand(1, cmd); end); end

-- CatsEyeXI allows one other character, so everything goes to "the others".
local function to_alts(cmd)
    return '/ms sendothers ' .. cmd;
end

local function my_name()
    local n = nil;
    pcall(function () n = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
    return n;
end

----------------------------------------------------------------------------------------------------
-- Sim-cast: watch the action packets you send (0x01A).
----------------------------------------------------------------------------------------------------
local function u16(d, o) return (d:byte(o + 1) or 0) + (d:byte(o + 2) or 0) * 256; end

-- What the alt should aim at, as a command target.
local function target_for(index)
    local my_index = nil;
    pcall(function () my_index = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0); end);
    if (index == 0 or index == my_index) then
        -- Copy everything mirrors you: what you do to yourself, they do to themselves.
        if (s.copy_all) then return '<me>', true; end
        return my_name() or '<me>', true;
    end
    local ent = GetEntity(index);
    if (ent ~= nil and ent.SpawnFlags ~= nil and bit.band(ent.SpawnFlags, 0x0001) == 0x0001 and ent.Name ~= nil) then
        return ent.Name, false;        -- another player: by name
    end
    return (s.enemy_target == 'bt') and '<bt>' or '<t>', false, true;
end

-- Send to the alt; on an enemy in Assist mode, /assist you first and cast a moment later.
local ASSIST_GAP = 0.8;
local assisted = { index = nil, at = -100 };   -- the mob they last /assisted you onto
local function wait()
    if (s.copy_all) then return tonumber(s.all_delay) or 0.3; end
    return tonumber(s.delay) or 0;
end
-- index: the enemy's target index, so a second spell on the same mob skips the /assist.
local function send(cmd, enemy, index)
    local at = os.clock() + wait();
    if (enemy and s.enemy_target == 'assist') then
        local me = my_name();
        local same = (index ~= nil and index ~= 0 and assisted.index == index and os.clock() - assisted.at < 300);
        if (me ~= nil and me ~= '' and not same) then
            queue[#queue + 1] = { at = at, cmd = to_alts('/assist ' .. me) };
            at = at + ASSIST_GAP;
            assisted.index, assisted.at = index, os.clock();
        elseif (same) then
            assisted.at = os.clock();
        end
    end
    queue[#queue + 1] = { at = at, cmd = to_alts(cmd) };
end
local function on(key) return s.copy_all or s[key]; end

local function ability_name(id)
    local res = AshitaCore:GetResourceManager();
    local r = res:GetAbilityById(id + 512);
    if (r == nil or r.Name == nil or r.Name[1] == nil or r.Name[1] == '') then r = res:GetAbilityById(id); end
    return r and r.Name and r.Name[1] or nil;
end

local function on_action_out(data)
    if (#data < 14) then return; end
    local index = u16(data, 0x08);
    local category = u16(data, 0x0A);
    local param = u16(data, 0x0C);
    local res = AshitaCore:GetResourceManager();
    local cmd, enemy = nil, false;

    if (category == 0x03 and on('simcast')) then
        local sp = res:GetSpellById(param);
        local name = sp and sp.Name and sp.Name[1];
        if (name ~= nil and name ~= '') then
            local tgt, is_me, is_enemy = target_for(index);
            -- A spell that only works on the caster (Stoneskin, Blink...) goes on the alt itself.
            local self_only = sp.Targets ~= nil and sp.Targets == 1;
            if (self_only) then tgt = '<me>'; is_enemy = false; end
            enemy = is_enemy == true;
            cmd = string.format('/ma "%s" %s', name, tgt);
        end
    elseif (category == 0x07 and on('copy_ws')) then
        local r = res:GetAbilityById(param);
        local name = r and r.Name and r.Name[1];
        if (name ~= nil and name ~= '') then
            cmd = string.format('/ws "%s" %s', name, (s.enemy_target == 'bt') and '<bt>' or '<t>');
            enemy = true;
        end
    elseif (category == 0x09 and on('copy_ja')) then
        local name = ability_name(param);
        if (name ~= nil and name ~= '') then
            local tgt, is_me, is_enemy = target_for(index);
            if (is_me) then tgt = '<me>'; end
            enemy = is_enemy == true;
            cmd = string.format('/ja "%s" %s', name, tgt);
        end
    elseif (s.copy_all and category == 0x02) then
        cmd, enemy = '/attack <t>', true;              -- engage
    elseif (s.copy_all and category == 0x04) then
        cmd = '/attack off';                           -- disengage
        assisted.index = nil;
    elseif (s.copy_all and category == 0x10) then
        cmd, enemy = '/ra <t>', true;                  -- ranged attack
    end

    if (cmd ~= nil) then send(cmd, enemy, index); end
end

-- Using an item (0x037): the same item, on the same kind of target.
local function on_item_out(data)
    if (#data < 0x11) then return; end
    local index = u16(data, 0x0C);
    local slot = data:byte(0x0E + 1) or 0;
    local bag = data:byte(0x10 + 1) or 0;
    local inv = AshitaCore:GetMemoryManager():GetInventory();
    local it = inv:GetContainerItem(bag, slot);
    if (it == nil or it.Id == nil or it.Id == 0 or it.Id == 65535) then return; end
    local r = AshitaCore:GetResourceManager():GetItemById(it.Id);
    local name = r and r.Name and r.Name[1];
    if (name == nil or name == '') then return; end
    local tgt, is_me, is_enemy = target_for(index);
    if (is_me) then tgt = '<me>'; end
    send(string.format('/item "%s" %s', name, tgt), is_enemy == true, index);
end

-- /heal (0x0E8, byte 0x04: 1 = start resting, 2 = stop, anything else = toggle). Sent as
-- an explicit on/off so the two characters can't end up out of step.
local function on_heal_out(data)
    local mode = data:byte(0x04 + 1) or 0;
    local on_now;
    if (mode == 1) then on_now = true;
    elseif (mode == 2) then on_now = false;
    else
        local resting = false;
        pcall(function ()
            local idx = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
            local ent = GetEntity(idx);
            resting = (ent ~= nil and ent.Status == 33);
        end);
        on_now = not resting;
    end
    send(on_now and '/heal on' or '/heal off', false, nil);
end

ashita.events.register('packet_out', 'omni_ms_packet_out', function (e)
    if (e.id == 0x01A and (s.copy_all or s.simcast or s.copy_ws or s.copy_ja)) then
        pcall(on_action_out, e.data);
    elseif (e.id == 0x037 and s.copy_all) then
        pcall(on_item_out, e.data);
    elseif (e.id == 0x0E8 and s.copy_all) then
        pcall(on_heal_out, e.data);
    end
end);

ashita.events.register('d3d_present', 'omni_ms_tick', function ()
    if (#queue > 0 and os.clock() >= queue[1].at) then
        local q = table.remove(queue, 1);
        run(q.cmd);
        last_sent = q.cmd;
    end
end);

----------------------------------------------------------------------------------------------------
-- The tab
----------------------------------------------------------------------------------------------------
local function check(label, key, tip)
    local v = { s[key] == true };
    if (imgui.Checkbox(label, v)) then s[key] = v[1]; save(); end
    if (tip and imgui.IsItemHovered()) then imgui.SetTooltip(tip); end
end

-- Layout: every row is a label in a fixed left column, then its controls.
local LABEL_W = 120;

local function section(title, first)
    if (not first) then imgui.Dummy({ 1, 6 }); end
    imgui.TextColored(GOLD, title);
    imgui.PushStyleColor(ImGuiCol_Separator, { 0.79, 0.69, 0.42, 0.35 });
    imgui.Separator();
    imgui.PopStyleColor(1);
    imgui.Dummy({ 1, 2 });
end

local function label(text)
    local y = imgui.GetCursorPosY();
    imgui.SetCursorPosY(y + 3);
    imgui.Text(text);
    imgui.SameLine(LABEL_W);
    imgui.SetCursorPosY(y);
end

local function note(text)
    imgui.SetCursorPosX(LABEL_W);
    imgui.PushTextWrapPos(imgui.GetWindowWidth() - 16);
    imgui.TextColored(DIM, text);
    imgui.PopTextWrapPos();
end

ms.render = function ()
    local me = my_name() or 'you';
    local fullW = imgui.GetWindowWidth() - LABEL_W - 20;

    section('Follow Me', true);
    label('Follow Me');
    if (followme) then
        imgui.PushStyleColor(ImGuiCol_Button, { 0.20, 0.55, 0.22, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.26, 0.64, 0.28, 1.0 });
    else
        imgui.PushStyleColor(ImGuiCol_Button, { 0.45, 0.16, 0.16, 1.0 });
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.55, 0.20, 0.20, 1.0 });
    end
    if (imgui.Button(followme and 'ON##ms_fm' or 'OFF##ms_fm', { 80, 0 })) then
        followme = not followme;
        run('/ms followme ' .. (followme and 'on' or 'off'));
    end
    imgui.PopStyleColor(2);
    imgui.SameLine(0, 10);
    imgui.SetCursorPosY(imgui.GetCursorPosY() + 3);
    imgui.TextColored(DIM, 'Your other character walks where ' .. me .. ' walks.');
    note('Uses the Multisend plugin. If nothing happens, type /load multisend in both games.');

    -- Sim-cast.
    section('Sim-cast');
    label('Copy everything');
    check('##ms_all', 'copy_all', 'Spells, weapon skills, job abilities, engage / disengage, ranged attacks, items and /heal:\n'
        .. 'your other character does whatever you do, a moment after you.');
    imgui.SameLine(0, 10);
    if (s.copy_all) then
        local ad = { tonumber(s.all_delay) or 0.3 };
        imgui.PushItemWidth(60);
        if (imgui.InputFloat('##ms_alld', ad, 0, 0, '%.1f')) then
            s.all_delay = math.max(0, math.min(5, ad[1]));
            save();
        end
        imgui.PopItemWidth();
        imgui.SameLine(0, 6);
        imgui.TextColored(GREEN, 'seconds after you - everything you do, they do');
    else
        imgui.TextColored(DIM, 'Off - only the ticks below are copied');
    end

    label('Copy my');
    check('Spells##ms_sc', 'simcast', 'Every spell you cast, your other character casts too.');
    imgui.SameLine(0, 20);
    check('Weapon skills##ms_ws', 'copy_ws');
    imgui.SameLine(0, 20);
    check('Job abilities##ms_ja', 'copy_ja');

    label('Enemy target');
    local MODES = { 'assist', 'bt', 't' };
    local et = { (s.enemy_target == 'bt') and 1 or (s.enemy_target == 't') and 2 or 0 };
    imgui.PushItemWidth(240);
    if (imgui.Combo('##ms_et', et, 'Assist me, then <t>\0Battle target (<bt>)\0Their own target (<t>)\0')) then
        s.enemy_target = MODES[et[1] + 1];
        save();
    end
    imgui.PopItemWidth();
    if (imgui.IsItemHovered()) then
        imgui.SetTooltip('Assist me: they /assist you, then cast on <t> a second later - works on a fresh mob.\n'
            .. 'Battle target: only finds a mob your party has already claimed.');
    end

    label('Wait');
    local d = { tonumber(s.delay) or 0 };
    imgui.PushItemWidth(60);
    if (imgui.InputFloat('##ms_delay', d, 0, 0, '%.1f')) then
        s.delay = math.max(0, math.min(10, d[1]));
        save();
    end
    imgui.PopItemWidth();
    imgui.SameLine(0, 8);
    imgui.SetCursorPosY(imgui.GetCursorPosY() + 3);
    imgui.TextColored(DIM, 'seconds before they copy you');
    note((s.enemy_target == 'assist') and 'Enemies: they /assist you, then cast on <t> 1 s later. You or a party member: that person by name. Self-only spells: themselves.' or 'Enemies: their ' .. ((s.enemy_target == 'bt') and 'battle target' or 'own target') .. '. You or a party member: that person by name. Self-only spells: themselves.');
    if (last_sent ~= nil) then
        imgui.SetCursorPosX(LABEL_W);
        imgui.TextColored(GREEN, 'Last sent: ' .. last_sent);
    end

    -- Quick buttons, two rows of equal width.
    section('Quick commands');
    label('Do');
    local bw = math.floor((fullW - 12) / 4);
    if (imgui.Button('Assist me##ms_as', { bw, 0 })) then run(to_alts('/assist ' .. me)); end
    imgui.SameLine(0, 4);
    if (imgui.Button('Attack##ms_at', { bw, 0 })) then run(to_alts('/attack <bt>')); end
    imgui.SameLine(0, 4);
    if (imgui.Button('Stop attacking##ms_off', { bw, 0 })) then run(to_alts('/attack off')); end
    imgui.SameLine(0, 4);
    if (imgui.Button('Follow me##ms_fol', { bw, 0 })) then run(to_alts('/follow ' .. me)); end

    label('Command');
    imgui.PushItemWidth(fullW - 80);
    local enter = imgui.InputText('##ms_free', free_cmd, 120, ImGuiInputTextFlags_EnterReturnsTrue);
    imgui.PopItemWidth();
    imgui.SameLine(0, 6);
    if ((imgui.Button('Send##ms_send', { 70, 0 }) or enter) and free_cmd[1] ~= '') then
        local c = free_cmd[1];
        if (c:sub(1, 1) ~= '/') then c = '/' .. c; end
        run(to_alts(c));
        last_sent = to_alts(c);
    end
    note('Any command, e.g. /ma "Haste" ' .. me .. ' - your other characters do it.');

    ms.height = imgui.GetCursorPosY() + 8;
end

-- For omni's main bar: Follow Me on / off from anywhere.
ms.following = function () return followme; end
ms.toggle_follow = function ()
    followme = not followme;
    run('/ms followme ' .. (followme and 'on' or 'off'));
end

return ms;
