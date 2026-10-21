--[[
    omni_dynamis.lua - Dynamis on omni's bar: time left and the five time-extension key items.

    In any Dynamis zone the bar shows "Dynamis", the time left, and five dots - Crimson, Azure,
    Amber, Alabaster and Obsidian granules of time - filled in once that time-extension NM is
    killed and its granules drop. Each one adds time (classic Dynamis 10/10/10/15/15 min,
    Dreamland 10/10/10/10/20 min).

    The time comes from the game itself where it can: the "... minutes remaining in Dynamis"
    message on entering and the "will be expelled from Dynamis in ..." warnings. Until the first
    message it counts down from 60 minutes. Granules are read from your key items, the Dynamis
    status packet and the "Obtained key item" message.

    Based on the Dynamis tracker in the points addon by Shinzaku (POINTS_LICENSE).
]]

local imgui = require('imgui');

local dyn = {};

-- Zone id -> extra seconds each granule gives (points addon's tables).
local ORIG  = { 600, 600, 600, 900, 900 };       -- San d'Oria, Bastok, Windurst, Jeuno, Beaucedine, Xarcabard
local DREAM = { 600, 600, 600, 600, 1200 };      -- Valkurm, Buburimu, Qufim, Tavnazia
local ZONES = {
    [185] = ORIG, [186] = ORIG, [187] = ORIG, [188] = ORIG, [134] = ORIG, [135] = ORIG,
    [39] = DREAM, [40] = DREAM, [41] = DREAM, [42] = DREAM,
};
local ZONE_NAME = {
    [185] = "San d'Oria", [186] = 'Bastok', [187] = 'Windurst', [188] = 'Jeuno', [134] = 'Beaucedine', [135] = 'Xarcabard',
    [39] = 'Valkurm', [40] = 'Buburimu', [41] = 'Qufim', [42] = 'Tavnazia',
};

dyn.GRANULES = {
    { name = 'Crimson granules of time',   short = 'Crimson',   col = { 0.90, 0.25, 0.25, 1.0 } },
    { name = 'Azure granules of time',     short = 'Azure',     col = { 0.30, 0.55, 1.00, 1.0 } },
    { name = 'Amber granules of time',     short = 'Amber',     col = { 1.00, 0.72, 0.20, 1.0 } },
    { name = 'Alabaster granules of time', short = 'Alabaster', col = { 0.95, 0.95, 0.92, 1.0 } },
    { name = 'Obsidian granules of time',  short = 'Obsidian',  col = { 0.55, 0.45, 0.75, 1.0 } },
};

local st = {
    zone = -1,
    inside = false,
    ends = nil,            -- os.time() when you are expelled
    told = false,          -- the game has told us the time at least once
    keys = { false, false, false, false, false },
};

local function zone_now()
    local z = 0;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    return tonumber(z) or 0;
end

-- Granules you hold right now (key items).
local ki_ids = nil;
local function held_now()
    local out = {};
    pcall(function ()
        local res = AshitaCore:GetResourceManager();
        local player = AshitaCore:GetMemoryManager():GetPlayer();
        if ki_ids == nil then
            ki_ids = {};
            for i, g in ipairs(dyn.GRANULES) do
                -- Same lookup as the points addon: key item id from its name.
                local ok, id = pcall(function () return res:GetString('keyitems.names', g.name:lower(), 2); end);
                if ok and type(id) == 'number' and id > 0 then ki_ids[i] = id; end
            end
        end
        for i in ipairs(dyn.GRANULES) do
            if ki_ids[i] ~= nil then out[i] = player:HasKeyItem(ki_ids[i]); end
        end
    end);
    return out;
end

-- Mark granules as got; a new one adds its time (unless the game tells us the time anyway).
local function set_keys(list, add_time)
    local ext = ZONES[st.zone];
    for i, v in pairs(list) do
        if v ~= nil then
            if v and not st.keys[i] and add_time and ext and st.ends then
                st.ends = st.ends + ext[i];
            end
            st.keys[i] = v and true or false;
        end
    end
end

local function check_zone()
    local z = zone_now();
    if z == st.zone then return; end
    st.zone = z;
    st.inside = ZONES[z] ~= nil;
    st.told = false;
    st.keys = { false, false, false, false, false };
    if st.inside then
        st.ends = os.time() + 3600;          -- until the game says otherwise
        set_keys(held_now(), false);
    else
        st.ends = nil;
    end
end

local last = 0;
ashita.events.register('d3d_present', 'omni_dynamis_tick', function ()
    if os.clock() - last < 1 then return; end
    last = os.clock();
    pcall(check_zone);
    if st.inside then
        -- Granules are never taken away during a run, so the key-item check only ever adds them.
        pcall(function ()
            local got = {};
            for i, v in pairs(held_now()) do if v then got[i] = true; end end
            set_keys(got, true);
        end);
    end
end);

-- The game's own messages.
ashita.events.register('text_in', 'omni_dynamis_text', function (e)
    if not st.inside or e.injected then return; end
    pcall(function ()
        local m = (e.message or ''):gsub('[\30\31].', ''):gsub('\127.', '');
        -- "You have 60 minutes (Earth time) remaining in Dynamis."
        local mins = m:match('(%d+) minutes? %b() ?remaining in Dynamis') or m:match('(%d+) minutes? .-remaining in Dynamis');
        if mins then st.ends = os.time() + tonumber(mins) * 60; st.told = true; return; end
        -- "... will be expelled from Dynamis in 5 minutes." / "... in 30 seconds."
        local n, unit = m:match('expelled from Dynamis in (%d+) (%a+)');
        if n then
            n = tonumber(n);
            st.ends = os.time() + ((unit:sub(1, 6) == 'second') and n or n * 60);
            st.told = true;
            return;
        end
        -- "Obtained key item: Crimson granules of time."
        for i, g in ipairs(dyn.GRANULES) do
            if m:find('Obtained key item', 1, true) and m:lower():find(g.name:lower(), 1, true) then
                local list = {}; list[i] = true;
                set_keys(list, true);
                return;
            end
        end
    end);
end);

-- Dynamis status packet (0x055 type 3): which granules the server says you have.
ashita.events.register('packet_in', 'omni_dynamis_packet', function (e)
    if e.id ~= 0x055 or not st.inside then return; end
    pcall(function ()
        local kind = struct.unpack('B', e.data, 0x85);
        if kind ~= 3 then return; end
        local bits = struct.unpack('B', e.data, 0x06);
        set_keys({ bit.band(bits, 2) > 0, bit.band(bits, 4) > 0, bit.band(bits, 8) > 0, bit.band(bits, 16) > 0, bit.band(bits, 32) > 0 }, true);
    end);
end);

dyn.inside = function () pcall(check_zone); return st.inside; end
dyn.seconds_left = function () if st.ends == nil then return nil; end return math.max(0, st.ends - os.time()); end

-- The bar: "Dynamis  Time 47:12  ● ● ○ ○ ○"
dyn.draw_bar = function (c)
    imgui.TextColored({ 0.80, 0.55, 1.00, 1.0 }, 'Dynamis');
    if imgui.IsItemHovered() then imgui.SetTooltip('Dynamis - ' .. (ZONE_NAME[st.zone] or '?')); end
    imgui.SameLine(0, 12);
    imgui.TextColored(c.label, 'Time');
    imgui.SameLine(0, 5);
    local secs = dyn.seconds_left() or 0;
    local tcol = (secs <= 300) and { 1.0, 0.40, 0.40, 1.0 } or ((secs <= 900) and { 1.0, 0.80, 0.30, 1.0 } or { 0.50, 0.92, 0.50, 1.0 });
    local h, m, s = math.floor(secs / 3600), math.floor(secs / 60) % 60, secs % 60;
    imgui.TextColored(tcol, (h > 0) and string.format('%d:%02d:%02d', h, m, s) or string.format('%d:%02d', m, s));
    if imgui.IsItemHovered() then
        imgui.SetTooltip(st.told and 'Time left before you are expelled (from the game\'s own message).\nYellow at 15 minutes, red at 5.'
            or 'Counting down from 60 minutes until the game says the exact time.\nYellow at 15 minutes, red at 5.');
    end
    -- The five granules: filled = got (that time-extension NM is done), hollow = still to get.
    imgui.SameLine(0, 14);
    local x, y = imgui.GetCursorScreenPos();
    local _, th = imgui.CalcTextSize('Ag');
    local r = math.floor((th or 14) / 2) - 1;
    local dl = imgui.GetWindowDrawList();
    local ext = ZONES[st.zone] or ORIG;
    local got = 0;
    for i, g in ipairs(dyn.GRANULES) do
        local cx, cy = x + r + (i - 1) * (r * 2 + 6), y + (th or 14) / 2;
        if st.keys[i] then
            dl:AddCircleFilled({ cx, cy }, r, imgui.GetColorU32(g.col), 16);
            got = got + 1;
        else
            dl:AddCircle({ cx, cy }, r, imgui.GetColorU32({ g.col[1], g.col[2], g.col[3], 0.55 }), 16, 1.5);
        end
    end
    local w = 5 * (r * 2 + 6);
    imgui.InvisibleButton('##omni_dyna_keys', { w, th or 14 });
    if imgui.IsItemHovered() then
        local lines = { ('Time extensions: %d / 5'):format(got) };
        for i, g in ipairs(dyn.GRANULES) do
            lines[#lines + 1] = ('  %s %s  (+%d min)'):format(st.keys[i] and '[got]' or '[   ]', g.short, math.floor(ext[i] / 60));
        end
        imgui.SetTooltip(table.concat(lines, '\n'));
    end
end

return dyn;
