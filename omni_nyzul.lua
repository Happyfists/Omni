--[[
    omni_nyzul.lua - Nyzul Isle on omni's bar: floor, the floor's objective and the time left.

    On Nyzul Isle (zone 77) the bar shows
        Nyzul Isle   Floor 23   Eliminate all enemies   Time 27:41
    Boss floors (every 20th) are marked, and hovering the objective gives a short tip for it.

    The floor comes from "Transfer complete. Welcome to Floor N", the objective from the
    "Objective: ..." line, and the time from the game's "You have N minutes to complete..." /
    "Time remaining: N minutes" lines. Until the game says, the time counts down from 30 minutes.

    Based on the Nyzul Isle part of the points addon by Shinzaku (POINTS_LICENSE).
]]

local imgui = require('imgui');

local nyz = {};

local ZONE = 77;   -- Nyzul Isle

local st = {
    zone = -1,
    inside = false,
    floor = 0,
    objective = nil,
    ends = nil,        -- os.time() when the time runs out
    told = false,      -- the game has said the time at least once
};

-- Short tips for each kind of objective (matched on the objective's words).
local TIPS = {
    { 'enemy leader',      'Kill the floor\'s leader (a named NM). The other enemies don\'t need killing.' },
    { 'specified enemy',   'Kill the one named enemy. Everything else is optional.' },
    { 'specified enemies', 'Kill every enemy of the named kind. Others are optional.' },
    { 'all enemies',       'Kill every enemy on the floor, then use the Rune of Transfer.' },
    { 'lamp',              'Examine each lamp and do what it says: some need a party member on each lamp at the same time,\n'
                        .. 'some must be lit in the right order, some need a certification code.' },
    { 'free floor',        'No objective: find the Rune of Transfer and go up.' },
};

local function tip_for(obj)
    if obj == nil then return nil; end
    local o = obj:lower();
    -- longest key first so "specified enemies" wins over "specified enemy"
    local best, blen = nil, 0;
    for _, t in ipairs(TIPS) do
        if o:find(t[1], 1, true) and #t[1] > blen then best, blen = t[2], #t[1]; end
    end
    return best;
end

local function zone_now()
    local z = 0;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    return tonumber(z) or 0;
end

local function check_zone()
    local z = zone_now();
    if z == st.zone then return; end
    st.zone = z;
    local was = st.inside;
    st.inside = (z == ZONE);
    if st.inside and not was then
        st.floor = 0;
        st.objective = nil;
        st.told = false;
        st.ends = os.time() + 30 * 60;   -- until the game says otherwise
    elseif not st.inside then
        st.ends = nil;
    end
end

local last = 0;
ashita.events.register('d3d_present', 'omni_nyzul_tick', function ()
    if os.clock() - last < 1 then return; end
    last = os.clock();
    pcall(check_zone);
end);

local function set_time(n, unit)
    n = tonumber(n);
    if n == nil then return; end
    st.ends = os.time() + ((unit:sub(1, 6) == 'second') and n or n * 60);
    st.told = true;
end

ashita.events.register('text_in', 'omni_nyzul_text', function (e)
    if not st.inside or e.injected then return; end
    pcall(function ()
        local m = (e.message or ''):gsub('[\30\31].', ''):gsub('\127.', ''):gsub('[\r\n]', ' ');
        local f = m:match('Welcome to Floor (%d+)');
        if f then
            st.floor = tonumber(f) or st.floor;
            st.objective = nil;          -- a new floor's objective follows
            return;
        end
        local obj = m:match('Objective: (.-)%s*$');
        if obj and obj ~= '' then
            st.objective = obj:gsub('[%.!]+$', '');
            return;
        end
        local n, unit = m:match('You have (%d+) (%a+).-to complete');
        if n then set_time(n, unit); return; end
        n, unit = m:match('Time remaining: (%d+) (%a+)');
        if n then set_time(n, unit); return; end
    end);
end);

nyz.inside = function () pcall(check_zone); return st.inside; end
nyz.seconds_left = function () if st.ends == nil then return nil; end return math.max(0, st.ends - os.time()); end

-- The bar: "Nyzul Isle  Floor 23  Eliminate all enemies  Time 27:41"
nyz.draw_bar = function (c)
    local y = imgui.GetCursorPosY();
    local function same(gap) imgui.SameLine(0, gap); imgui.SetCursorPosY(y); end

    imgui.TextColored({ 0.45, 0.80, 0.95, 1.0 }, 'Nyzul Isle');

    same(16);
    imgui.TextColored(c.label, 'Floor');
    same(6);
    local boss = st.floor > 0 and st.floor % 20 == 0;
    imgui.TextColored(boss and { 1.0, 0.45, 0.45, 1.0 } or c.text, (st.floor > 0) and tostring(st.floor) or '-');
    if boss then
        same(6);
        imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'Boss');
    end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(boss and 'Boss floor (every 20th floor).' or 'Floor you are on. Every 20th floor is a boss floor.');
    end

    same(16);
    local obj = st.objective or 'Objective: -';
    if #obj > 42 then obj = obj:sub(1, 40) .. '..'; end
    imgui.TextColored(st.objective and { 1.0, 0.84, 0.45, 1.0 } or c.dim, obj);
    if imgui.IsItemHovered() then
        local tip = tip_for(st.objective);
        imgui.SetTooltip((st.objective or 'The objective shows when the floor starts.') .. (tip and ('\n\n' .. tip) or ''));
    end

    same(16);
    imgui.TextColored(c.label, 'Time');
    same(6);
    local secs = nyz.seconds_left() or 0;
    local tcol = (secs <= 60) and { 1.0, 0.40, 0.40, 1.0 } or ((secs <= 300) and { 1.0, 0.80, 0.30, 1.0 } or { 0.50, 0.92, 0.50, 1.0 });
    imgui.TextColored(tcol, string.format('%d:%02d', math.floor(secs / 60), secs % 60));
    if imgui.IsItemHovered() then
        imgui.SetTooltip(st.told and 'Time left (from the game\'s own message).\nYellow at 5 minutes, red at 1.'
            or 'Counting down from 30 minutes until the game says the exact time.\nYellow at 5 minutes, red at 1.');
    end
end

return nyz;
