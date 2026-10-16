--[[
    omni_ventures.lua - the "Ventures" tab.

    EXP areas   : read from the server's venture packet (0x1A3), the same way the
                  'ventures' addon by Commandobill, Seekey and Phatty does. Shows both
                  pools, the zone boss, where it spawns and how full its bar is.
                  Click a row to see which monsters count there.
    HELM        : today's Harvesting / Excavation / Logging / Mining zones.
    Fishing     : today's fish and how many to catch, by skill band.

    HELM and Fishing are not in the packet; they come from the server's own web page
    data (catseyexi.com/api/ventures), fetched when the tab is opened and after each
    daily reset. The game pauses for a moment while that is fetched.
]]

local imgui = require('imgui');
local settings = require('settings');

local ventures = {};
ventures.height = 300;      -- how tall the tab's contents came out last frame

local API_URL = 'https://catseyexi.com/api/ventures';
local RETRY_SECONDS = 600;   -- at most one fetch (and its short pause) every 10 minutes
local FETCH_TIMEOUT = 6;

local BANDS = { '10-19', '20-29', '30-39', '40-49', '50-59', '60-69' };
local POOLS = { 'A', 'B' };
local HELM = {
    { key = 'harvesting', label = 'Harvesting' },
    { key = 'excavation', label = 'Excavation' },
    { key = 'logging',    label = 'Logging' },
    { key = 'mining',     label = 'Mining' },
};

local GREEN = { 0.40, 0.90, 0.40, 1.0 };
local GOLD  = { 0.79, 0.69, 0.42, 1.0 };
local BLUE  = { 0.45, 0.70, 1.00, 1.0 };

----------------------------------------------------------------------------------------------------
-- Data files
----------------------------------------------------------------------------------------------------
local function load_data(name)
    local ok, data = pcall(require, 'plugins/data/' .. name);
    return (ok and type(data) == 'table') and data or {};
end

local ZONES = load_data('venture_zones');
local VNMS  = load_data('venture_vnms');
local MOBS  = load_data('venture_mobs');

-- "East Ronfaure [S]", "East Ronfaure (S)" and "East Ronfaure S" all become "eastronfaures".
local function norm(name)
    name = tostring(name or ''):lower():gsub('%[s%]', 's'):gsub('%(s%)', 's');
    return (name:gsub('[^%w]', ''));
end

local VNM_BY_ZONE = {};
for zone, list in pairs(VNMS) do
    VNM_BY_ZONE[norm(zone)] = list;
end

local function vnm_for(area, band)
    for _, vnm in ipairs(VNM_BY_ZONE[norm(area)] or {}) do
        if (vnm.level_range == band) then
            return vnm;
        end
    end
    return nil;
end

----------------------------------------------------------------------------------------------------
-- Saved choices
----------------------------------------------------------------------------------------------------
local saved = settings.load(T{ mode = 'ACE' }, 'omni_ventures');
settings.register('omni_ventures', 'omni_ventures_update', function (s)
    if (s ~= nil) then
        saved = s;
    end
end);

----------------------------------------------------------------------------------------------------
-- EXP areas from the packet
----------------------------------------------------------------------------------------------------
local exp_rows = nil;       -- list of { pool, band, ace, cw, progress }
local hvnm = nil;           -- { area, progress }
local open_row = nil;       -- key of the row whose monster list is showing
local packet_at = nil;      -- os.time() the last venture update arrived

local function parse_packet(data)
    local rows = {};
    for p = 0, 1 do
        for tier = 0, 5 do
            local off = 0x08 + (p * 0x24) + (tier * 6) + 1;
            local ace = struct.unpack('H', data, off);
            local cw = struct.unpack('H', data, off + 2);
            rows[#rows + 1] = {
                pool = POOLS[p + 1],
                band = BANDS[tier + 1],
                ace = ZONES[ace] or string.format('Zone %d', ace),
                cw = ZONES[cw] or string.format('Zone %d', cw),
                progress = struct.unpack('B', data, off + 4),
            };
        end
    end
    exp_rows = rows;

    local zone = struct.unpack('H', data, 0x51);
    hvnm = { area = ZONES[zone] or string.format('Zone %d', zone), progress = struct.unpack('B', data, 0x53) / 2 };
end

-- Asking the server for an update: the same as typing !ventures, sent as the chat
-- packet the 'ventures' addon used to send. The server answers with packet 0x1A3.
local ASK_EVERY = 60;       -- seconds, while the Ventures tab is on screen
local asked_at = -1000;
local asked_wall = nil;     -- os.time() of the last ask
local ask_method = 'packet';
local ASK_PACKET = { 0xB5, 0x08, 0x81, 0x01, 0x00, 0x00,
    0x21, 0x76, 0x65, 0x6E, 0x74, 0x75, 0x72, 0x65, 0x73, 0x00 };   -- "!ventures"

-- True while a cutscene or NPC menu is running (code by Thorny); asking then could disturb it.
local event_ptr = nil;
local function in_event()
    if (event_ptr == nil) then
        event_ptr = ashita.memory.find('FFXiMain.dll', 0, 'A0????????84C0741AA1????????85C0741166A1????????663B05????????0F94C0C3', 0, 0) or 0;
    end
    if (event_ptr == 0) then
        return false;
    end
    local p = ashita.memory.read_uint32(event_ptr + 1);
    return p ~= 0 and ashita.memory.read_uint8(p) == 1;
end

ventures.asked_clock = -1000;

local function ask_if_due()
    if (os.clock() - asked_at < ASK_EVERY) then
        return;
    end
    local ok, busy = pcall(function ()
        local party = AshitaCore:GetMemoryManager():GetParty();
        return party == nil or (party:GetMemberZone(0) or 0) == 0 or in_event();
    end);
    if (not ok or busy) then
        return;     -- zoning, or in a cutscene / menu
    end
    -- If the last raw-packet ask got no answer, type the command instead (as you would).
    if (ask_method == 'packet' and asked_wall ~= nil and (packet_at == nil or packet_at < asked_wall)) then
        ask_method = 'command';
    end
    asked_at = os.clock();
    ventures.asked_clock = asked_at;
    asked_wall = os.time();
    if (ask_method == 'packet') then
        pcall(function () AshitaCore:GetPacketManager():AddOutgoingPacket(0xB5, ASK_PACKET); end);
    else
        pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '!ventures'); end);
    end
end

----------------------------------------------------------------------------------------------------
-- The server's own text answer to !ventures ("Pool A: (10-19) Maze of Shakhrami @4%, ...").
-- It is caught here, shown at the bottom of the tab, and kept out of chat when omni asked.
----------------------------------------------------------------------------------------------------
local report = nil;         -- { pools = { A = {...}, B = {...} }, hvnm = {...}, at = os.time() }
local capture = nil;        -- text being collected while the answer arrives
local capture_until = 0;

-- Chat text with the game's colour codes removed; the star (Shift-JIS 81 9A) becomes '*'.
local function clean(text)
    local out, i = {}, 1;
    while (i <= #text) do
        local b = text:byte(i);
        if (b == 0x1E or b == 0x1F or b == 0x7F) then
            i = i + 2;
        elseif (b == 0x81 and text:byte(i + 1) == 0x9A) then
            out[#out + 1] = '*';
            i = i + 2;
        elseif (b >= 0x80) then
            i = i + 2;      -- other double-byte characters are dropped
        elseif (b < 0x20) then
            i = i + 1;
        else
            out[#out + 1] = string.char(b);
            i = i + 1;
        end
    end
    return table.concat(out);
end

local function parse_pool(text)
    local rows = {};
    -- Each entry starts with its level band, e.g. "(40-49) Rolanberry Fields [S] * @34%".
    local starts = {};
    for pos, band in text:gmatch('()%((%d+%-%d+)%)') do
        starts[#starts + 1] = { pos = pos, band = band };
    end
    for i, st in ipairs(starts) do
        local stop = starts[i + 1] and (starts[i + 1].pos - 1) or #text;
        local body = text:sub(st.pos + #st.band + 2, stop):gsub(',%s*$', '');
        local pct = body:match('@([%d%.]+)%%');
        local area = body:gsub('@[%d%.]+%%', ''):gsub(',', '');
        local star = area:find('%*') ~= nil;
        area = area:gsub('%*', ''):gsub('^%s+', ''):gsub('%s+$', '');
        rows[#rows + 1] = { band = st.band, area = area, star = star, progress = tonumber(pct) or 0 };
    end
    return rows;
end

local function finish_capture()
    if (capture == nil) then
        return;
    end
    local text = table.concat(capture, ' ');
    capture = nil;
    local a = text:match('Pool A:(.-)Pool B:') or text:match('Pool A:(.*)') or '';
    local b = text:match('Pool B:(.-)HVNM:') or text:match('Pool B:(.*)') or '';
    local new = { pools = { A = parse_pool(a), B = parse_pool(b) }, at = os.time() };
    local name, boss, pct = text:match('HVNM:%s*(.-)%s*%((.-)%)%s*@([%d%.]+)%%');
    if (name ~= nil) then
        new.hvnm = { area = name, boss = boss, progress = tonumber(pct) or 0 };
    end
    if (#new.pools.A + #new.pools.B > 0) then
        report = new;
    end
end

-- Called for every incoming chat line (text_in). Returns true if the line should be hidden.
ventures.on_text = function (e)
    local text = clean(e.message or '');
    local now = os.clock();
    if (capture ~= nil and now > capture_until) then
        finish_capture();
    end
    local is_start = text:find('Pool A:', 1, true) ~= nil;
    local is_part = capture ~= nil and (text:find('Pool B:', 1, true) or text:find('HVNM:', 1, true)
        or text:match('^%s*%(%d+%-%d+%)') or text:match('^%s*$'));
    if (not is_start and not is_part) then
        return false;
    end
    if (is_start) then
        capture = {};
    end
    capture[#capture + 1] = text;
    capture_until = now + 2;
    if (text:find('HVNM:', 1, true)) then
        finish_capture();
    end
    -- Hide it from chat only when omni asked a moment ago; your own !ventures shows as normal.
    return (now - ventures.asked_clock) < 10;
end

-- The server only sends this when you zone (and now and then after that), so the last
-- one is saved and shown again after a reload, with its age on screen.
ventures.on_packet = function (data)
    parse_packet(data);
    packet_at = os.time();
    saved.packet = (data:gsub('.', function (c) return string.format('%02X', c:byte()); end));
    saved.packet_at = packet_at;
    pcall(function () settings.save('omni_ventures'); end);
end

if (type(saved.packet) == 'string' and #saved.packet >= 0x54 * 2) then
    local ok = pcall(parse_packet, (saved.packet:gsub('%x%x', function (h) return string.char(tonumber(h, 16)); end)));
    if (ok) then
        packet_at = tonumber(saved.packet_at);
    else
        exp_rows, hvnm = nil, nil;
    end
end

----------------------------------------------------------------------------------------------------
-- HELM / fishing from the server's web data
----------------------------------------------------------------------------------------------------
local api = nil;            -- decoded reply
local api_error = nil;
local tried_at = -1000;     -- os.time() of the last attempt
local reset_at = nil;       -- os.time() of the next daily reset
local fetch_in = 0;          -- frames until the fetch runs, so "Loading" is on screen first

local function iso_seconds(text)
    local y, mo, d, h, mi, s = tostring(text or ''):match('(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)');
    if (y == nil) then
        return nil;
    end
    return os.time({ year = tonumber(y), month = tonumber(mo), day = tonumber(d), hour = tonumber(h), min = tonumber(mi), sec = tonumber(s) });
end

local function fetch()
    tried_at = os.time();
    local ok, result = pcall(function ()
        local https = require('socket.ssl.https');
        local json = require('json');
        local previous = https.TIMEOUT;
        https.TIMEOUT = FETCH_TIMEOUT;
        local body, code = https.request(API_URL);
        https.TIMEOUT = previous;
        if (body == nil or tonumber(code) ~= 200) then
            error('the server page did not answer (' .. tostring(code) .. ')');
        end
        local decoded = json.decode(body);
        if (type(decoded) ~= 'table' or type(decoded.ventures) ~= 'table') then
            error('the server page sent something unexpected');
        end
        return decoded;
    end);
    if (not ok) then
        api_error = tostring(result):gsub('^.-:%d+: ', '');
        return;
    end
    api, api_error = result, nil;

    -- Work out the reset time on this PC's clock from the gap the server reports.
    -- nextReset is UTC; os.time() reads a date table as local time, so add this PC's offset.
    local next_s = iso_seconds(api.ventures.nextReset);
    local offset = os.time() - os.time(os.date('!*t'));
    reset_at = (next_s ~= nil) and (next_s + offset) or nil;
end

local function fetch_if_due()
    if (fetch_in > 0) then
        fetch_in = fetch_in - 1;
        if (fetch_in == 0) then
            fetch();
        end
        return;
    end
    local stale = (api == nil) or (reset_at ~= nil and os.time() > reset_at + 60);
    if (stale and os.time() - tried_at > RETRY_SECONDS) then
        fetch_in = 3;
    end
end

-- The web data keys its lists "1", "2", ... ; accept numbers as well.
local function entry(list, index)
    if (type(list) ~= 'table') then
        return nil;
    end
    return list[tostring(index)] or list[index];
end

-- Monsters for an area: the server's own list when it has one, otherwise the wiki's.
local function mobs_for(area, band)
    local key = norm(area);
    if (api ~= nil and type(api.ventures.exp) == 'table') then
        for _, e in pairs(api.ventures.exp) do
            if (type(e) == 'table' and norm(e.area) == key and type(e.mobs) == 'table' and #e.mobs > 0) then
                local names, mana = {}, {};
                for _, mob in ipairs(e.mobs) do
                    names[#names + 1] = string.format('%s (%s)', tostring(mob.name):gsub('_', ' '), tostring(mob.level));
                end
                for _, mob in ipairs(type(e.mana) == 'table' and e.mana or {}) do
                    local lv = (type(mob.level) == 'table') and table.concat(mob.level, '-') or tostring(mob.level or '');
                    mana[#mana + 1] = string.format('%s (%s)', tostring(mob.name):gsub('_', ' '), lv);
                end
                return table.concat(names, ', '), table.concat(mana, ', ');
            end
        end
    end
    return (MOBS[band] or {})[key], nil;
end

----------------------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------------------
local function pill(dl, x1, y1, x2, y2, fraction, color)
    local h = y2 - y1;
    fraction = math.max(0, math.min(1, fraction));
    dl:AddRectFilled({ x1 - 1, y1 - 1 }, { x2 + 1, y2 + 1 }, imgui.GetColorU32({ 0, 0, 0, 1 }), h / 2 + 1);
    dl:AddRectFilled({ x1, y1 }, { x2, y2 }, imgui.GetColorU32({ 0.10, 0.12, 0.20, 1 }), h / 2);
    if (fraction > 0) then
        local fx = x1 + math.max((x2 - x1) * fraction, h);
        dl:AddRectFilled({ x1, y1 }, { fx, y2 }, imgui.GetColorU32(color), h / 2);
        dl:AddRectFilled({ x1 + 2, y1 + 1 }, { fx - 2, y1 + h * 0.45 }, imgui.GetColorU32({ 1, 1, 1, 0.22 }), h / 2);
    end
end

local function wrapped(color, text)
    imgui.PushTextWrapPos(0);
    imgui.TextColored(color, (tostring(text):gsub('%%', '%%%%')));
    imgui.PopTextWrapPos();
end

local ROW = 22;
local boss_x = 268;      -- where the boss column starts; set from the widest area name
local drops_x = 440;     -- where the drops column starts; set from the widest boss text

-- How many of each crest you have, across your inventory and every Mog House bag.
-- Counted by item name, so no item numbers are needed.
local crest_counts = {};
local crests_at = -100;
local function scan_crests()
    if (os.clock() - crests_at < 5) then
        return;
    end
    crests_at = os.clock();
    local counts = {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();
        for bag = 0, 16 do
            local max = inv:GetContainerCountMax(bag) or 0;
            for slot = 1, max do
                local item = inv:GetContainerItem(bag, slot);
                if (item ~= nil and item.Id ~= nil and item.Id ~= 0 and item.Id ~= 65535) then
                    local r = res:GetItemById(item.Id);
                    local name = r and r.Name and r.Name[1];
                    if (name ~= nil) then
                        counts[name:lower()] = (counts[name:lower()] or 0) + (item.Count or 1);
                    end
                end
            end
        end
    end);
    crest_counts = counts;
end

-- What the zone boss drops, e.g. "15 Feet, Ocean Crest (3)" (from the ventures addon's data);
-- the number is how many of that crest you already have.
local function drops_text(vnm)
    if (vnm == nil) then
        return '';
    end
    local bits = {};
    if (vnm.equipment ~= nil and vnm.equipment ~= '') then bits[#bits + 1] = vnm.equipment; end
    if (vnm.crest ~= nil and vnm.crest ~= '' and vnm.crest ~= '?') then
        bits[#bits + 1] = string.format('%s (%d)', vnm.crest, crest_counts[vnm.crest:lower()] or 0);
    end
    return table.concat(bits, ', ');
end

-- Just where the boss spawns, e.g. "(J-7)"; its name is in the click-open details.
local function boss_text(vnm)
    if (vnm == nil or vnm.position == nil or vnm.position == '') then
        return '';
    end
    return string.format('(%s)', vnm.position);
end

-- One EXP line: "A 10-19   Pashhow Marshlands   Sludge Walker (F-8)   [=====   ] 27%"
local function draw_exp_row(ui, key, tag, area, band, progress)
    local dl = imgui.GetWindowDrawList();
    local ww = imgui.GetWindowWidth();
    local y = imgui.GetCursorPosY();
    local vnm = vnm_for(area, band);

    if (imgui.Selectable('##venture_' .. key, open_row == key, 0, { 0, ROW - 2 })) then
        open_row = (open_row ~= key) and key or nil;
    end

    imgui.SetCursorPos({ 6, y + 2 });
    imgui.TextColored(GOLD, tag);
    imgui.SetCursorPos({ 78, y + 2 });
    imgui.TextColored(ui.color('white'), area);
    if (vnm ~= nil) then
        imgui.SetCursorPos({ boss_x, y + 2 });
        imgui.TextColored(ui.color('dimmed'), boss_text(vnm));

        -- Drops, cut short with "..." if they would run into the bar (hover for the full list).
        local drops = drops_text(vnm);
        if (band == 'HVNM' and drops ~= '') then
            -- HVNM drops are Rare/Ex: each one green if you own it (any bag), red if not.
            local x = drops_x;
            local limit = ww - 160;
            local first = true;
            for name in tostring(vnm.equipment or ''):gmatch('[^,]+') do
                name = name:gsub('^%s+', ''):gsub('%s+$', '');
                local text = (first and '' or ', ') .. name;
                local w = imgui.CalcTextSize(text);
                if (x + w > limit) then
                    break;
                end
                local have = (crest_counts[name:lower()] or 0) > 0;
                imgui.SetCursorPos({ x, y + 2 });
                imgui.TextColored(have and GREEN or { 1.0, 0.40, 0.40, 1.0 }, text);
                if (imgui.IsItemHovered()) then
                    imgui.BeginTooltip();
                    imgui.TextColored(have and GREEN or { 1.0, 0.40, 0.40, 1.0 }, name .. (have and ' - you have this' or ' - you do not have this'));
                    imgui.EndTooltip();
                end
                x = x + w;
                first = false;
            end
        elseif (drops ~= '') then
            local room = (ww - 160) - drops_x;
            local shown = drops;
            if (imgui.CalcTextSize(shown) > room) then
                while (#shown > 1 and imgui.CalcTextSize(shown .. '...') > room) do
                    shown = shown:sub(1, -2);
                end
                shown = shown .. '...';
            end
            if (room > 30) then
                imgui.SetCursorPos({ drops_x, y + 2 });
                imgui.TextColored(BLUE, shown);
                if (imgui.IsItemHovered()) then
                    imgui.BeginTooltip();
                    imgui.TextColored(GOLD, 'Drops');
                    imgui.TextColored(ui.color('white'), drops);
                    imgui.EndTooltip();
                end
            end
        end
    end

    local wx, wy = imgui.GetWindowPos();
    local sy = wy + y - imgui.GetScrollY();
    local color = (progress >= 90) and GREEN or GOLD;
    pill(dl, wx + ww - 150, sy + 5, wx + ww - 52, sy + 15, progress / 100, color);
    local pct = (progress == math.floor(progress)) and string.format('%d%%%%', progress) or string.format('%.1f%%%%', progress);
    imgui.SetCursorPos({ ww - 44, y + 2 });
    imgui.TextColored((progress >= 90) and GREEN or ui.color('white'), pct);

    imgui.SetCursorPos({ 0, y + ROW });

    if (open_row == key) then
        imgui.Indent(20);
        local mobs, mana = mobs_for(area, band);
        if (band == 'HVNM') then
            -- nothing to hunt for the HVNM bar; it fills as zone bosses die
        elseif (mobs ~= nil and mobs ~= '') then
            wrapped(ui.color('white'), 'Monsters: ' .. mobs);
        else
            wrapped(ui.color('dimmed'), 'Monsters: no list for this area yet.');
        end
        if (mana ~= nil and mana ~= '') then
            wrapped(BLUE, 'Manaburn: ' .. mana);
        end
        if (vnm ~= nil) then
            local bits = {};
            if (vnm.notes ~= nil and vnm.notes ~= '') then bits[#bits + 1] = 'Boss spot: ' .. vnm.notes; end
            if (vnm.name ~= nil and vnm.name ~= '') then bits[#bits + 1] = 'Boss: ' .. vnm.name; end
            if (drops_text(vnm) ~= '') then bits[#bits + 1] = 'Drops: ' .. drops_text(vnm); end
            if (vnm.element ~= nil and vnm.element ~= '') then bits[#bits + 1] = vnm.element; end
            if (#bits > 0) then
                wrapped(ui.color('dimmed'), table.concat(bits, '   -   '));
            end
        end
        imgui.Unindent(20);
        imgui.Spacing();
    end
end

local function draw_exp(ui)
    -- ACE / CW switch.
    imgui.SetCursorPosX(6);
    imgui.TextColored(ui.color('dimmed'), 'Server mode:');
    for _, mode in ipairs({ 'ACE', 'CW' }) do
        imgui.SameLine(0, 8);
        if (saved.mode == mode) then
            imgui.TextColored(GOLD, '[' .. mode .. ']');
        elseif (imgui.SmallButton(mode .. '##venture_mode')) then
            saved.mode = mode;
            pcall(function () settings.save('omni_ventures'); end);
        end
    end
    imgui.SameLine(0, 16);
    imgui.TextColored(ui.color('dimmed'), 'Click an area to see which monsters count.');
    if (packet_at ~= nil) then
        local ago = os.time() - packet_at;
        imgui.SameLine(0, 16);
        imgui.TextColored(ui.color('dimmed'), (ago < 60) and 'Updated just now' or string.format('Updated %dm ago', math.floor(ago / 60)));
    end

    scan_crests();

    -- Gather the lines to show: both pools from the game, or the web page's list until then.
    local list = {};
    if (exp_rows ~= nil) then
        for _, row in ipairs(exp_rows) do
            list[#list + 1] = { key = row.pool .. row.band, tag = row.pool .. ' ' .. row.band,
                area = (saved.mode == 'CW') and row.cw or row.ace, band = row.band, progress = row.progress };
        end
        if (hvnm ~= nil) then
            list[#list + 1] = { key = 'HVNM', tag = 'HVNM', area = hvnm.area, band = 'HVNM', progress = hvnm.progress };
        end
    elseif (api ~= nil and type(api.ventures.exp) == 'table') then
        for tier = 1, 6 do
            local e = entry(api.ventures.exp, tier);
            if (type(e) == 'table') then
                local band = tostring(e.level or ''):gsub('[%(%)]', '');
                list[#list + 1] = { key = 'web' .. tier, tag = tostring(e.pool or ''):upper() .. ' ' .. band,
                    area = tostring(e.area), band = band, progress = tonumber(e.bossProgress) or 0 };
            end
        end
    end

    -- Closest to done first; level order breaks ties.
    table.sort(list, function (a, b)
        if (a.progress ~= b.progress) then
            return a.progress > b.progress;
        end
        return a.tag < b.tag;
    end);

    -- Column positions from the widest area name and boss text.
    local widest_area, widest_boss = 0, 0;
    for _, row in ipairs(list) do
        widest_area = math.max(widest_area, imgui.CalcTextSize(row.area));
        widest_boss = math.max(widest_boss, imgui.CalcTextSize(boss_text(vnm_for(row.area, row.band))));
    end
    boss_x = 78 + widest_area + 18;
    drops_x = boss_x + widest_boss + 18;

    for _, row in ipairs(list) do
        draw_exp_row(ui, row.key, row.tag, row.area, row.band, row.progress);
    end

    if (exp_rows ~= nil) then
        return;
    end
    local shown = #list > 0;
    imgui.SetCursorPosX(6);
    wrapped(ui.color('dimmed'), shown
        and 'Showing the server web page\'s list. Both pools appear here as soon as the server answers.'
        or 'Asking the server for the venture areas...');
end

local function draw_helm(ui)
    local v = api.ventures;
    local ww = imgui.GetWindowWidth();
    local lx = 6 + imgui.CalcTextSize('Excavation') + 14;   -- first column after the widest label
    local col = (ww - lx) / 3;

    -- Heading row: tier names and what each pays.
    local y = imgui.GetCursorPosY();
    for tier = 1, 3 do
        local e = entry(v.harvesting, tier) or entry(v.mining, tier) or {};
        imgui.SetCursorPos({ lx + (tier - 1) * col, y });
        local exp = tonumber(e.exp);
        imgui.TextColored(ui.color('dimmed'), string.format('%s%s', tostring(e.tierName or ('Tier ' .. tier)), exp and string.format('  (%d EXP)', exp) or ''));
    end
    imgui.SetCursorPos({ 0, y + 18 });

    for _, kind in ipairs(HELM) do
        y = imgui.GetCursorPosY();
        imgui.SetCursorPos({ 6, y });
        imgui.TextColored(GOLD, kind.label);
        for tier = 1, 3 do
            local e = entry(v[kind.key], tier);
            imgui.SetCursorPos({ lx + (tier - 1) * col, y });
            if (type(e) ~= 'table') then
                imgui.TextColored(ui.color('dimmed'), '-');
            else
                imgui.TextColored((e.active == false) and ui.color('dimmed') or ui.color('white'), tostring(e.area or '-'));
                if (imgui.IsItemHovered() and type(e.items) == 'table' and #e.items > 0) then
                    imgui.BeginTooltip();
                    imgui.TextColored(GOLD, string.format('%s - %s', kind.label, tostring(e.area)));
                    imgui.Separator();
                    for _, item in ipairs(e.items) do
                        local pts = tonumber(item.points) or 0;
                        imgui.TextColored(ui.color('white'), string.format('%s  -  %d point%s', tostring(item.name), pts, pts == 1 and '' or 's'));
                    end
                    imgui.EndTooltip();
                end
            end
        end
        imgui.SetCursorPos({ 0, y + 19 });
    end
    imgui.SetCursorPosX(6);
    imgui.TextColored(ui.color('dimmed'), 'Hover over a zone to see which items count and their points.');
end

local function draw_fishing(ui, host)
    local ww = imgui.GetWindowWidth();
    local half = ww / 2;
    local y0 = imgui.GetCursorPosY();
    local label_w = 0;
    for tier = 1, 6 do
        local e = entry(api.ventures.fishing, tier);
        if (type(e) == 'table') then
            label_w = math.max(label_w, imgui.CalcTextSize('Skill ' .. tostring(e.name or ''):gsub('[%(%)]', '')));
        end
    end
    for tier = 1, 6 do
        local e = entry(api.ventures.fishing, tier);
        local x = (tier > 3) and half or 0;
        local y = y0 + ((tier - 1) % 3) * 24;
        if (type(e) == 'table' and type(e.fish) == 'table') then
            imgui.SetCursorPos({ x + 6, y + 2 });
            imgui.TextColored(GOLD, 'Skill ' .. tostring(e.name or ''):gsub('[%(%)]', ''));
            imgui.SetCursorPos({ x + 6 + label_w + 8, y });
            if (not host.renderIcon(tonumber(e.fish.id) or 0, 20)) then
                imgui.Dummy({ 20, 20 });
            end
            imgui.SetCursorPos({ x + 6 + label_w + 34, y + 2 });
            imgui.TextColored((e.active == false) and ui.color('dimmed') or ui.color('white'),
                string.format('%s  x%d', tostring(e.fish.name), tonumber(e.fish.qty) or 0));
        end
    end
    imgui.SetCursorPos({ 0, y0 + 3 * 24 });
end

-- The server's !ventures answer: Pool A and Pool B side by side, then the HVNM.
local function draw_report(ui)
    if (report == nil) then
        imgui.SetCursorPosX(6);
        imgui.TextColored(ui.color('dimmed'), 'Waiting for the server\'s !ventures answer...');
        return;
    end
    local ww = imgui.GetWindowWidth();
    local half = ww / 2;
    local y0 = imgui.GetCursorPosY();
    local rows = 0;
    for p, pool in ipairs({ 'A', 'B' }) do
        local x = (p == 1) and 6 or (half + 6);
        imgui.SetCursorPos({ x, y0 });
        imgui.TextColored(GOLD, 'Pool ' .. pool);
        for i, row in ipairs(report.pools[pool] or {}) do
            local y = y0 + i * 19;
            imgui.SetCursorPos({ x, y });
            imgui.TextColored(ui.color('dimmed'), row.band);
            imgui.SetCursorPos({ x + 52, y });
            imgui.TextColored(ui.color('white'), row.area);
            if (row.star) then
                imgui.SameLine(0, 6);
                imgui.TextColored(GOLD, '*');
                if (imgui.IsItemHovered()) then
                    imgui.BeginTooltip();
                    imgui.TextColored(ui.color('white'), 'Marked with a star by the server.');
                    imgui.EndTooltip();
                end
            end
            local pct = (row.progress == math.floor(row.progress)) and string.format('%d%%%%', row.progress) or string.format('%.1f%%%%', row.progress);
            imgui.SetCursorPos({ x + half - 60, y });
            imgui.TextColored((row.progress >= 90) and GREEN or ui.color('white'), pct);
            rows = math.max(rows, i);
        end
    end
    imgui.SetCursorPos({ 6, y0 + (rows + 1) * 19 + 2 });
    if (report.hvnm ~= nil) then
        imgui.TextColored(GOLD, 'HVNM');
        imgui.SameLine(0, 10);
        imgui.TextColored(ui.color('white'), string.format('%s  (%s)', report.hvnm.area, report.hvnm.boss));
        imgui.SameLine(0, 10);
        local p = report.hvnm.progress;
        imgui.TextColored((p >= 90) and GREEN or ui.color('white'),
            (p == math.floor(p)) and string.format('%d%%%%', p) or string.format('%.1f%%%%', p));
    end
    imgui.SetCursorPosX(6);
    imgui.TextColored(ui.color('dimmed'), 'As of ' .. os.date('%H:%M', report.at));
end

local function reset_text()
    if (reset_at == nil) then
        return '';
    end
    local left = reset_at - os.time();
    if (left <= 0) then
        return 'Daily reset has passed - refreshing soon.';
    end
    return string.format('Daily reset in %dh %02dm.', math.floor(left / 3600), math.floor((left % 3600) / 60));
end

-- host is the trove host module (gives the item icons and the shared look).
ventures.render = function (host)
    local ui = host.ui;
    local pushed = ui.pushWindowStyle();

    if (ui.sectionHeader('EXP Areas', nil, 'ventures:exp')) then
        draw_exp(ui);
    end
    imgui.Spacing();

    local helm_open = ui.sectionHeader('HELM', nil, 'ventures:helm');
    if (helm_open) then
        if (api ~= nil) then
            draw_helm(ui);
        end
    end
    imgui.Spacing();

    local fish_open = ui.sectionHeader('Fishing', nil, 'ventures:fishing');
    if (fish_open and api ~= nil) then
        draw_fishing(ui, host);
    end
    imgui.Spacing();

    if (ui.sectionHeader('Server Report (!ventures)', nil, 'ventures:report')) then
        draw_report(ui);
    end
    imgui.Spacing();

    -- Status line and refresh.
    imgui.SetCursorPosX(6);
    if (fetch_in > 0 or (api == nil and api_error == nil)) then
        imgui.TextColored(ui.color('dimmed'), 'Loading HELM and fishing from the server page...');
    elseif (api == nil) then
        wrapped(ui.color('yellow'), 'HELM and fishing could not be loaded: ' .. tostring(api_error or 'not tried yet') .. '.');
    else
        imgui.TextColored(ui.color('dimmed'), reset_text());
    end
    imgui.SameLine(0, 12);
    if (imgui.SmallButton('Refresh##ventures')) then
        fetch_in = 3;
    end
    imgui.Spacing();

    ventures.height = imgui.GetCursorPosY() + 6;
    ui.popWindowStyle(pushed);

    -- Fetch after drawing, so the "Loading" line is on screen while the game pauses.
    ask_if_due();
    fetch_if_due();
end

return ventures;
