--[[
    omni_jachat.lua - JA Chat (Options > JA Chat): your own line in party chat for each job ability.

    Every job ability you know (main job and support job) is listed with a box. Type a line in a
    box and, whenever you use that ability, the line goes to /p. Leave a box empty for nothing.
    Start a line with / to use another chat instead (/s, /l, /em ...). <t> and the other game
    tags work as normal.

    Saved to config\addons\omni\jachat.txt (one "Ability<TAB>line" per line), so lines for
    other jobs are kept when you change job.
    /jachat on | off
]]

local imgui = require('imgui');

local jachat = {};

local st = { on = true, lines = {} };   -- lines[lowercase ability name] = { name = 'Steal', text = '...' }

local function base() return string.format('%s\\config\\addons\\', AshitaCore:GetInstallPath()); end
local function path() return base() .. 'omni\\jachat.txt'; end

local function save()
    pcall(function ()
        local f = io.open(path(), 'w');
        if f == nil then return; end
        f:write('on\t', st.on and '1' or '0', '\n');
        local keys = {};
        for k, v in pairs(st.lines) do if v.text ~= '' then keys[#keys + 1] = k; end end
        table.sort(keys);
        for _, k in ipairs(keys) do
            local v = st.lines[k];
            f:write(v.name, '\t', (v.text:gsub('[\r\n\t]', ' ')), '\n');
        end
        f:close();
    end);
end

local function load()
    pcall(function ()
        local f = io.open(path(), 'r');
        if f == nil then return; end
        for line in f:lines() do
            local a, b = line:match('^([^\t]+)\t(.*)$');
            if a == 'on' then st.on = (b == '1');
            elseif a and b then st.lines[a:lower()] = { name = a, text = b }; end
        end
        f:close();
    end);
end
load();

-- The job abilities you know right now (main + support job), from the game's own list.
local known, known_combo, known_at = {}, '', -100;
local function job_combo()
    local ok, v = pcall(function ()
        local p = AshitaCore:GetMemoryManager():GetPlayer();
        return string.format('%d/%d/%d/%d', p:GetMainJob(), p:GetMainJobLevel(), p:GetSubJob(), p:GetSubJobLevel());
    end);
    return ok and v or '';
end
local function refresh_known(force)
    local combo = job_combo();
    if not force and combo == known_combo and os.clock() - known_at < 10 then return; end
    known_combo, known_at = combo, os.clock();
    local list, seen = {}, {};
    pcall(function ()
        local res = AshitaCore:GetResourceManager();
        local pl = AshitaCore:GetMemoryManager():GetPlayer();
        for rid = 512, 1535 do
            if pl:HasAbility(rid) then
                local a = res:GetAbilityById(rid);
                local n = a and a.Name and a.Name[1];
                if n and n ~= '' and n ~= '.' and not seen[n:lower()] then
                    seen[n:lower()] = true;
                    list[#list + 1] = n;
                end
            end
        end
    end);
    table.sort(list, function (x, y) return x:lower() < y:lower(); end);
    known = list;
end

-- Say the line for an ability (by name).
local last_key, last_t = '', 0;
local function say(name)
    if not st.on or name == nil then return; end
    local v = st.lines[name:lower()];
    if v == nil or v.text == nil or v.text:match('^%s*$') then return; end
    local now = os.clock();
    if name == last_key and now - last_t < 1 then return; end   -- the same use seen twice
    last_key, last_t = name, now;
    local text = v.text;
    local cmd = text:sub(1, 1) == '/' and text or ('/p ' .. text);
    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, cmd); end);
end

-- Your job abilities as they happen (action packet: 6 = job ability, 14 = steps/flourishes, 15 = runes/wards).
local zoning = false;
ashita.events.register('packet_in', 'omni_jachat_in', function (e)
    if e.id == 0x00B then zoning = true; return; end
    if e.id == 0x00A then zoning = false; return; end
    if e.id ~= 0x028 or zoning or not st.on then return; end
    pcall(function ()
        local actor = struct.unpack('I', e.data, 0x05 + 1);
        if actor ~= AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0) then return; end
        local category = ashita.bits.unpack_be(e.data_raw, 82, 4);
        if category ~= 6 and category ~= 14 and category ~= 15 then return; end
        local id = ashita.bits.unpack_be(e.data_raw, 86, 10);
        local res = AshitaCore:GetResourceManager();
        local a = res:GetAbilityById(id + 512);
        local n = a and a.Name and a.Name[1];
        say(n);
    end);
end);

ashita.events.register('command', 'omni_jachat_cmd', function (e)
    local args = e.command:args();
    if #args == 0 or args[1]:lower() ~= '/jachat' then return; end
    e.blocked = true;
    local sub = (args[2] or ''):lower();
    if sub == 'on' then st.on = true; save();
    elseif sub == 'off' then st.on = false; save(); end
    print(string.format('[omni] JA Chat is %s.', st.on and 'on' or 'off'));
end);

-- ============================================================================ page
local GOLD, DIM = { 0.90, 0.78, 0.40, 1.0 }, { 0.62, 0.66, 0.80, 1.0 };
local bufs = {};          -- bufs[lowercase name] = { text }
local dirty_at = nil;     -- save shortly after typing stops

local function row(name)
    local k = name:lower();
    local v = st.lines[k];
    local b = bufs[k];
    if b == nil then b = { v and v.text or '' }; bufs[k] = b; end
    imgui.AlignTextToFramePadding();
    imgui.TextColored((b[1] ~= '') and GOLD or DIM, name);
    imgui.SameLine(170);
    imgui.PushItemWidth(-1);
    if imgui.InputText('##jachat_' .. k, b, 120) then
        st.lines[k] = { name = name, text = b[1] };
        dirty_at = os.clock();
    end
    imgui.PopItemWidth();
end

jachat.render = function ()
    refresh_known(false);
    local on = { st.on };
    if imgui.Checkbox('Say my line in party when I use a job ability##jachat_on', on) then st.on = on[1]; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('/jachat on | off'); end
    imgui.SameLine(0, 20);
    if imgui.SmallButton('Refresh list##jachat_ref') then refresh_known(true); end
    imgui.TextColored(DIM, 'Empty box = nothing said. Lines go to /p - start with / for another chat (/s, /l, /em). <t> works.');
    imgui.Separator();
    imgui.BeginChild('##jachat_list', { 0, 420 }, false);

    if #known == 0 then
        imgui.TextColored(DIM, 'No job abilities found yet - log in, or press Refresh list.');
    end
    local shown = {};
    for _, n in ipairs(known) do
        shown[n:lower()] = true;
        row(n);
    end

    -- Lines saved for abilities you don't have on this job (kept for when you switch back).
    local others = {};
    for k, v in pairs(st.lines) do
        if not shown[k] and v.text ~= '' then others[#others + 1] = v.name; end
    end
    if #others > 0 then
        table.sort(others);
        imgui.Spacing();
        if imgui.CollapsingHeader(string.format('Lines for other jobs (%d)##jachat_other', #others)) then
            for _, n in ipairs(others) do row(n); end
        end
    end
    imgui.EndChild();

    if dirty_at and os.clock() - dirty_at > 1 then dirty_at = nil; save(); end
end

return jachat;
