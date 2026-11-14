--[[
    omni_jachat.lua - JA Chat (Options > JA Chat): your own line in party chat for each job ability.

    Every job ability you know (main job and support job) is listed with a box. Type a line in a
    box and, whenever you use that ability, the line goes to /p. Leave a box empty for nothing.
    Several lines for one ability: split them with " | " - one is picked at random each time
    (never the same one twice in a row).
    Start a line with / to use another chat instead (/s, /l, /em ...). <t> and the other game
    tags work as normal.

    Lines are sent as a chat packet (not typed), so they never cancel a macro that is still
    running; <t> and <me> are filled in here. Other channels: start a line with /s, /sh, /l, /l2
    or /y; /em and other commands are typed instead.
    Saved to config\addons\omni\jachat.txt (one "Ability<TAB>line" per line; an ability can have
    many), so lines for other jobs are kept when you change job. The file is re-read when it
    changes, so every character picks up new lines without a reload.
    /jachat on | off | last (the last ability it saw) | reload | typed | packet
]]

local imgui = require('imgui');

local jachat = {};

local st = { on = true, mode = 'packet', lines = {} };   -- mode: 'packet' or 'typed'   -- lines[lowercase ability name] = { name = 'Steal', texts = { '...', '...' } }
local SEP = ' | ';                        -- in the box, several lines are split with " | "; one is picked at random
local last_file = nil;                    -- the file as last read or written (to spot outside changes)
math.randomseed(os.time());

local function base() return string.format('%s\\config\\addons\\', AshitaCore:GetInstallPath()); end
local function path() return base() .. 'omni\\jachat.txt'; end

local function serialize()
    local out = { 'on\t' .. (st.on and '1' or '0'), 'mode\t' .. st.mode };
    local keys = {};
    for k, v in pairs(st.lines) do if #v.texts > 0 then keys[#keys + 1] = k; end end
    table.sort(keys);
    for _, k in ipairs(keys) do
        local v = st.lines[k];
        for _, line in ipairs(v.texts) do
            out[#out + 1] = v.name .. '\t' .. (line:gsub('[\r\n\t]', ' '));
        end
    end
    return table.concat(out, '\n') .. '\n';
end

local function save()
    pcall(function ()
        local text = serialize();
        local f = io.open(path(), 'w');
        if f == nil then return; end
        f:write(text);
        f:close();
        last_file = text;
    end);
end

local function parse(text)
    local on, mode, lines = true, 'packet', {};
    for raw in (text .. '\n'):gmatch('([^\n]*)\n') do
        local line = raw:gsub('\r$', '');
        local a, b = line:match('^([^\t]+)\t(.*)$');
        if a == 'on' then on = (b == '1');
        elseif a == 'mode' then mode = (b == 'typed') and 'typed' or 'packet';
        elseif a and b and not b:match('^%s*$') then
            local k = a:lower();
            lines[k] = lines[k] or { name = a, texts = {} };
            -- old single-box files may hold "a | b | c" on one line
            for raw_piece in (b .. SEP):gmatch('(.-)' .. SEP:gsub('%p', '%%%0')) do
                local piece = raw_piece:match('^%s*(.-)%s*$');
                if piece ~= '' then table.insert(lines[k].texts, piece); end
            end
        end
    end
    return on, mode, lines;
end

local function read_file()
    local ok, text = pcall(function ()
        local f = io.open(path(), 'r');
        if f == nil then return nil; end
        local s = f:read('*a');
        f:close();
        return s;
    end);
    return ok and text or nil;
end

local bufs = {};          -- the page's text boxes (reset when the file changes)
local function load()
    local text = read_file();
    if text == nil then return; end
    last_file = text;
    st.on, st.mode, st.lines = parse(text);
    bufs = {};
end
load();

-- Re-read the file when it changes outside this window (another character, or a new set of lines).
local last_check = 0;
local dirty_at = nil;     -- save shortly after typing stops
local function watch()
    if os.clock() - last_check < 3 or dirty_at ~= nil then return; end
    last_check = os.clock();
    local text = read_file();
    if text ~= nil and text ~= last_file then load(); end
end

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
-- Sending: straight to the server as a chat packet (0x0B5), like the game does with a typed line.
-- Typing into the chat line instead would cancel a macro that is still running (e.g. the
-- "/wait 1" before Trick Attack in a Sneak Attack + Trick Attack macro). The game fills in
-- <t> and <me> itself only for typed lines, so they are filled in here.
local CHANNELS = { p = 4, party = 4, s = 0, say = 0, sh = 1, shout = 1, l = 5, linkshell = 5,
    l2 = 27, linkshell2 = 27, y = 26, yell = 26 };

local function name_of_target()
    local ok, n = pcall(function ()
        local tm = AshitaCore:GetMemoryManager():GetTarget();
        local idx = tm:GetTargetIndex(tm:GetIsSubTargetActive());
        if idx == nil or idx == 0 then return nil; end
        return AshitaCore:GetMemoryManager():GetEntity():GetName(idx);
    end);
    return ok and n or nil;
end

local function my_name()
    local ok, n = pcall(function () return AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
    return ok and n or nil;
end

local function chat_packet(mode, text)
    local bytes = { 0xB5, 0x00, 0x00, 0x00, mode, 0x00 };
    for i = 1, math.min(#text, 150) do bytes[#bytes + 1] = text:byte(i); end
    bytes[#bytes + 1] = 0x00;
    while #bytes % 4 ~= 0 do bytes[#bytes + 1] = 0x00; end
    bytes[2] = (#bytes / 4) * 2;   -- packet size, in 4-byte words, shifted up one bit
    return bytes;
end

local function send_line(text)
    -- Which chat: /p by default, or the one the line starts with (/s, /l, /sh ...).
    local mode, body = 4, text;
    local pre, rest = text:match('^/(%S+)%s+(.*)$');
    if pre ~= nil then
        mode = CHANNELS[pre:lower()];
        body = rest;
    end
    -- Fill in <t> / <me>; anything else the game must fill in, so type those (rare) lines.
    local tname, me = name_of_target(), my_name();
    body = body:gsub('<[tT]>', tname or 'it'):gsub('<[mM][eE]>', me or 'me');
    if mode == nil or body:find('<%a+>') then
        local cmd = text:sub(1, 1) == '/' and text or ('/p ' .. text);
        pcall(function () AshitaCore:GetChatManager():QueueCommand(1, cmd); end);
        return;
    end
    local ok = pcall(function () AshitaCore:GetPacketManager():AddOutgoingPacket(0xB5, chat_packet(mode, body)); end);
    if ok then
        -- A sent packet isn't shown back to you by the game, so show it here the way the game would.
        local LOG = { [0] = 1, [1] = 2, [4] = 5, [5] = 6, [26] = 11, [27] = 213 };
        pcall(function ()
            AshitaCore:GetChatManager():AddChatMessage(LOG[mode] or 5, false, string.format('(%s) %s', me or '?', body));
        end);
    else
        pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. body); end);
    end
end

-- "typed" mode: lines are typed, but held until 3 seconds after your last action, so a macro
-- with /wait lines is finished first. Only the newest waiting line is said.
local pending, last_action = nil, 0;
local function typed_tick()
    if pending ~= nil and os.clock() - last_action >= 3 then
        local text = pending;
        pending = nil;
        local cmd = text:sub(1, 1) == '/' and text or ('/p ' .. text);
        pcall(function () AshitaCore:GetChatManager():QueueCommand(1, cmd); end);
    end
end
ashita.events.register('d3d_present', 'omni_jachat_tick', typed_tick);

local last_key, last_t = '', 0;
local last_pick = {};     -- last line used per ability, so it doesn't repeat straight away
local last_seen = nil;    -- for /jachat last
local last_how = nil;
local function say(name, how)
    if name == nil then return; end
    last_seen = name;
    last_how = how or '?';
    watch();
    if not st.on then return; end
    local v = st.lines[name:lower()];
    if v == nil or #v.texts == 0 then return; end
    local now = os.clock();
    if name == last_key and now - last_t < 4 then return; end   -- the same use seen twice (sent + done)
    last_key, last_t = name, now;
    local i = 1;
    if #v.texts > 1 then
        repeat i = math.random(#v.texts); until i ~= last_pick[name:lower()];
    end
    last_pick[name:lower()] = i;
    if st.mode == 'typed' then
        pending = v.texts[i];
    else
        send_line(v.texts[i]);
    end
end

-- Your job abilities as they happen (action packet: 6 = job ability, 14 = steps/flourishes, 15 = runes/wards).
local function ability_name(id)
    local ok, n = pcall(function ()
        local a = AshitaCore:GetResourceManager():GetAbilityById(id + 512);
        return a and a.Name and a.Name[1];
    end);
    return ok and n or nil;
end
local zoning = false;
ashita.events.register('packet_in', 'omni_jachat_in', function (e)
    if e.id == 0x00B then zoning = true; return; end
    if e.id == 0x00A then zoning = false; return; end
    if e.id ~= 0x028 or zoning or not st.on then return; end
    pcall(function ()
        local actor = struct.unpack('I', e.data, 0x05 + 1);
        if actor ~= AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0) then return; end
        local category = ashita.bits.unpack_be(e.data_raw, 82, 4);
        last_action = os.clock();
        if category ~= 6 and category ~= 14 and category ~= 15 then return; end
        local id = ashita.bits.unpack_be(e.data_raw, 86, 10);
        say(ability_name(id), string.format('done, category %d id %d', category, id));
    end);
end);

-- Your job abilities as you use them: the action packet you send (0x01A, category 9 = job ability,
-- param = ability id). This catches every ability the moment it's used, whatever the server's
-- answer looks like (some, like Steal and Mug, may not come back in the usual form).
ashita.events.register('packet_out', 'omni_jachat_out', function (e)
    if e.id ~= 0x01A or zoning or not st.on then return; end
    pcall(function ()
        local cat = struct.unpack('H', e.data, 0x0A + 1);
        if cat ~= 9 then return; end
        local id = struct.unpack('H', e.data, 0x0C + 1);
        last_action = os.clock();
        say(ability_name(id), 'sent, id ' .. tostring(id));
    end);
end);

ashita.events.register('command', 'omni_jachat_cmd', function (e)
    local args = e.command:args();
    if #args == 0 or args[1]:lower() ~= '/jachat' then return; end
    e.blocked = true;
    local sub = (args[2] or ''):lower();
    if sub == 'on' then st.on = true; save();
    elseif sub == 'off' then st.on = false; save();
    elseif sub == 'last' then
        local v = last_seen and st.lines[last_seen:lower()];
        print(string.format('[omni] JA Chat: last ability seen: %s (%s) - %d line%s.', tostring(last_seen or 'none yet'),
            tostring(last_how or '-'), v and #v.texts or 0, (v and #v.texts == 1) and '' or 's'));
        return;
    elseif sub == 'reload' then load(); print('[omni] JA Chat: lines re-read.'); return;
    elseif sub == 'typed' or sub == 'packet' then
        st.mode = sub; save();
        print(sub == 'typed' and '[omni] JA Chat: lines are typed, 3 seconds after your last action (so macros finish first).'
            or '[omni] JA Chat: lines are sent straight away as a chat packet (macros are never cut off).');
        return;
    end
    print(string.format('[omni] JA Chat is %s.', st.on and 'on' or 'off'));
end);

-- ============================================================================ page
local GOLD, DIM = { 0.90, 0.78, 0.40, 1.0 }, { 0.62, 0.66, 0.80, 1.0 };

local function row(name)
    local k = name:lower();
    local v = st.lines[k];
    local b = bufs[k];
    if b == nil then b = { v and table.concat(v.texts, SEP) or '' }; bufs[k] = b; end
    imgui.AlignTextToFramePadding();
    local n = v and #v.texts or 0;
    imgui.TextColored((n > 0) and GOLD or DIM, n > 1 and string.format('%s (%d)', name, n) or name);
    imgui.SameLine(170);
    imgui.PushItemWidth(-1);
    if imgui.InputText('##jachat_' .. k, b, 1000) then
        local texts = {};
        for raw_piece in (b[1] .. SEP):gmatch('(.-)' .. SEP:gsub('%p', '%%%0')) do
            local piece = raw_piece:match('^%s*(.-)%s*$');
            if piece ~= '' then texts[#texts + 1] = piece; end
        end
        st.lines[k] = { name = name, texts = texts };
        dirty_at = os.clock();
    end
    imgui.PopItemWidth();
    if imgui.IsItemHovered() and n > 1 then
        imgui.SetTooltip(table.concat(v.texts, '\n'));
    end
end

jachat.render = function ()
    refresh_known(false);
    watch();
    local on = { st.on };
    if imgui.Checkbox('Say my line in party when I use a job ability##jachat_on', on) then st.on = on[1]; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('/jachat on | off'); end
    imgui.SameLine(0, 20);
    if imgui.SmallButton('Refresh list##jachat_ref') then refresh_known(true); end
    imgui.TextColored(DIM, 'Empty box = nothing said. Several lines? Split them with  |  and one is picked at random.');
    imgui.TextColored(DIM, 'Lines go to /p - start a line with / for another chat (/s, /l, /em). <t> works.');
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
        if not shown[k] and #v.texts > 0 then others[#others + 1] = v.name; end
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
