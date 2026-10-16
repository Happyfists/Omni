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
    enemy_target = 'bt',    -- 'bt' or 't'
};
local s = settings.load(defaults, 'omni_ms');
settings.register('omni_ms', 'omni_ms_update', function (n) if (n ~= nil) then s = n; end end);
local function save() pcall(function () settings.save('omni_ms'); end); end

local followme = false;   -- what we last told Multisend
local queue = {};         -- { at = clock, cmd = '...' }
local last_sent = nil;
local free_cmd = { '' };

local GOLD  = { 0.79, 0.69, 0.42, 1.0 };
local GREEN = { 0.45, 0.85, 0.45, 1.0 };
local DIM   = { 0.66, 0.68, 0.76, 1.0 };

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
        return my_name() or '<me>', true;
    end
    local ent = GetEntity(index);
    if (ent ~= nil and ent.SpawnFlags ~= nil and bit.band(ent.SpawnFlags, 0x0001) == 0x0001 and ent.Name ~= nil) then
        return ent.Name, false;        -- another player: by name
    end
    return (s.enemy_target == 't') and '<t>' or '<bt>', false;
end

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
    local cmd = nil;

    if (category == 0x03 and s.simcast) then
        local sp = res:GetSpellById(param);
        local name = sp and sp.Name and sp.Name[1];
        if (name ~= nil and name ~= '') then
            local tgt, is_me = target_for(index);
            -- A spell that only works on the caster (Stoneskin, Blink...) goes on the alt itself.
            local self_only = sp.Targets ~= nil and sp.Targets == 1;
            if (self_only) then tgt = '<me>'; end
            cmd = string.format('/ma "%s" %s', name, tgt);
        end
    elseif (category == 0x07 and s.copy_ws) then
        local r = res:GetAbilityById(param);
        local name = r and r.Name and r.Name[1];
        if (name ~= nil and name ~= '') then
            cmd = string.format('/ws "%s" %s', name, (s.enemy_target == 't') and '<t>' or '<bt>');
        end
    elseif (category == 0x09 and s.copy_ja) then
        local name = ability_name(param);
        if (name ~= nil and name ~= '') then
            local tgt, is_me = target_for(index);
            if (is_me) then tgt = '<me>'; end
            cmd = string.format('/ja "%s" %s', name, tgt);
        end
    end

    if (cmd ~= nil) then
        queue[#queue + 1] = { at = os.clock() + (tonumber(s.delay) or 0), cmd = to_alts(cmd) };
    end
end

ashita.events.register('packet_out', 'omni_ms_packet_out', function (e)
    if (e.id == 0x01A and (s.simcast or s.copy_ws or s.copy_ja)) then
        pcall(on_action_out, e.data);
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
    label('Copy my');
    check('Spells##ms_sc', 'simcast', 'Every spell you cast, your other character casts too.');
    imgui.SameLine(0, 20);
    check('Weapon skills##ms_ws', 'copy_ws');
    imgui.SameLine(0, 20);
    check('Job abilities##ms_ja', 'copy_ja');

    label('Enemy target');
    local et = { (s.enemy_target == 't') and 1 or 0 };
    imgui.PushItemWidth(240);
    if (imgui.Combo('##ms_et', et, 'Battle target (<bt>)\0Their own target (<t>)\0')) then
        s.enemy_target = (et[1] == 1) and 't' or 'bt';
        save();
    end
    imgui.PopItemWidth();

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
    note('Enemies: their battle target. You or a party member: that person by name. Self-only spells: themselves.');
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
