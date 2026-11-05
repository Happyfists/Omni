--[[
    omni_mobinfo.lua - a small strip under omni's target bar with what mobdb knows about the monster:

        Lv 63-65  WAR  NM   Aggro: Sound Blood   Links   Weak: Fire Light   Resists: Water   Immune: Sleep Bind   Respawn 5:30

    The facts come from the mobdb addon's database (Thorny's mobdb, its data\<zone>.lua files), read
    straight from its folder - so mobdb has to be in your addons folder (it does not need to be loaded).
    Turn it on or off in Options > Bars.
]]

local imgui = require('imgui');

local mi = {};

-- mobdb's database: one file per zone, { Names = { [name] = {...} }, Indices = { [index] = {...} } }.
local cache = { zone = -1, names = {}, indices = {}, found = false, dir = nil };

local function data_dir()
    if cache.dir ~= nil then return cache.dir; end
    local base = AshitaCore:GetInstallPath();
    if base:sub(-1) ~= '\\' and base:sub(-1) ~= '/' then base = base .. '\\'; end
    for _, d in ipairs({ 'addons\\ashita\\mobdb\\data\\', 'addons\\mobdb\\data\\' }) do
        local f = io.open(base .. d .. '1.lua', 'r');
        if f then f:close(); cache.dir = base .. d; return cache.dir; end
    end
    cache.dir = false;
    return false;
end

local function load_zone(zone)
    if zone == cache.zone then return; end
    cache.zone, cache.names, cache.indices, cache.found = zone, {}, {}, false;
    local dir = data_dir();
    if not dir or zone == nil or zone == 0 then return; end
    local fn = loadfile(('%s%d.lua'):format(dir, zone));
    if fn == nil then return; end
    local ok, t = pcall(fn);
    if ok and type(t) == 'table' then
        cache.names = t.Names or {};
        cache.indices = t.Indices or {};
        cache.found = true;
    end
end

mi.available = function () return data_dir() ~= false; end

-- What mobdb knows about the monster with this target index (nil if it is not a monster or unknown).
mi.lookup = function (index, name)
    local z = 0;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    load_zone(z);
    return cache.indices[index] or cache.names[name or ''];
end

local IMMUNE = {
    { 0x01, 'Sleep' }, { 0x02, 'Gravity' }, { 0x04, 'Bind' }, { 0x08, 'Stun' }, { 0x10, 'Silence' },
    { 0x20, 'Paralyze' }, { 0x40, 'Blind' }, { 0x80, 'Slow' }, { 0x100, 'Poison' }, { 0x200, 'Elegy' },
    { 0x400, 'Requiem' }, { 0x800, 'Lullaby' }, { 0x1000, 'Dark Sleep' }, { 0x2000, 'Petrify' },
};
local ELEM = { 'Fire', 'Ice', 'Wind', 'Earth', 'Lightning', 'Water', 'Light', 'Dark' };
local PHYS = { 'Slashing', 'Piercing', 'H2H', 'Impact' };
local ELEM_COL = {
    Fire = { 1.00, 0.45, 0.35, 1 }, Ice = { 0.55, 0.85, 1.00, 1 }, Wind = { 0.45, 0.95, 0.55, 1 },
    Earth = { 0.85, 0.70, 0.40, 1 }, Lightning = { 0.85, 0.55, 1.00, 1 }, Water = { 0.40, 0.60, 1.00, 1 },
    Light = { 1.00, 1.00, 0.85, 1 }, Dark = { 0.65, 0.55, 0.80, 1 },
};

-- The strip. x, y: top-left on screen; w: width. c: omni's colours. Returns its height.
mi.HEIGHT = 20;
mi.open = { true };
-- top: extra room above the text (so it lines up with the training strip beside it, whose top part
-- holds the buff times). id / index: the monster's server id and target index, shown on the right.
mi.draw = function (x, y, w, r, c, bg, border, top, id, index)
    top = top or 0;
    local job = '';
    if r.Job and r.Job > 0 then
        pcall(function () job = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', r.Job) or ''; end);
    end
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ w, mi.HEIGHT + top }, ImGuiCond_Always);
    -- Same frame as the bars above (the crystal / themed looks draw their own border).
    local orn = mi.look ~= nil and mi.look.crystal();
    imgui.PushStyleColor(ImGuiCol_WindowBg, orn and { 0, 0, 0, 0 } or bg);
    imgui.PushStyleColor(ImGuiCol_Border, orn and { 0, 0, 0, 0 } or border);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 10, 2 });
    if orn then imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 0); end
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 0, 0 });
    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoScrollbar);
    if imgui.Begin('OmniMobInfo', mi.open, flags) then
        if orn then
            local wx, wy = imgui.GetWindowPos();
            pcall(mi.look.frame, imgui.GetWindowDrawList(), wx + 1, wy + 1, wx + w - 1, wy + mi.HEIGHT + top - 1);
        end
        imgui.SetWindowFontScale(0.85);
        if top > 0 then imgui.SetCursorPosY(imgui.GetCursorPosY() + top); end
        local line_y = imgui.GetCursorPosY();
        -- [3.87] The ID always shows: it is worked out first and its room kept free at the right end.
        -- Anything else that doesn't fit is left off the strip and listed in the hover tooltip.
        -- [3.65] the entity's ServerId can be empty under VanaCore: read it from memory, or work it out
        -- (a monster's id is 0x01000000 + zone * 4096 + its target index)
        if (id == nil or id == 0) and index ~= nil then
            pcall(function () id = AshitaCore:GetMemoryManager():GetEntity():GetServerId(index); end);
            if id == nil or id == 0 then
                pcall(function ()
                    local z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
                    id = 0x01000000 + z * 4096 + index;
                end);
            end
        end
        local id_txt, id_w = nil, 0;
        if id ~= nil and id ~= 0 then
            id_txt = ('ID %03X (%d)'):format(bit.band(id, 0xFFF), id);   -- e.g. ID 02D (16793645), as the wikis show it
            id_w = tonumber(imgui.CalcTextSize(id_txt)) or 0;
        end
        local limit = w - 10 - (id_txt and (id_w + 12) or 0);
        local pos = imgui.GetCursorPosX();
        local dim, text = c.dim, c.text;
        local first, cut = true, false;
        local hidden = {};
        local function put(text, col, gap)
            if cut then hidden[#hidden + 1] = text; return; end
            local tw = tonumber(imgui.CalcTextSize(text)) or 0;
            local need = (first and 0 or (gap or 10)) + tw;
            if pos + need > limit then
                cut = true;
                hidden[#hidden + 1] = text;
                return;
            end
            if not first then imgui.SameLine(0, gap or 10); end
            first = false;
            pos = pos + need;
            imgui.TextColored(col, text);
        end
        -- A label with its words (Weak: Fire Light) goes on whole or not at all.
        local function group(label, words)
            if not cut then
                local tw = tonumber(imgui.CalcTextSize(label .. ' ' .. table.concat(words, ' '))) or 0;
                if pos + (first and 0 or 10) + tw > limit then cut = true; end
            end
            put(label, dim);
            for _, k in ipairs(words) do put(k, ELEM_COL[k] or text, 4); end
        end
        -- Level, job, NM
        local lv = (r.MinLevel == r.MaxLevel) and ('Lv ' .. tostring(r.MinLevel)) or ('Lv %d-%d'):format(r.MinLevel or 0, r.MaxLevel or 0);
        put(lv, text);
        if job ~= '' then put(job, dim, 6); end
        if r.Notorious then put('NM', { 1.0, 0.84, 0.30, 1 }, 6); end
        -- Aggro and how it detects you
        if r.Aggro then
            local how = {};
            for _, k in ipairs({ 'Sight', 'Sound', 'Scent', 'Magic', 'JA', 'Blood' }) do
                if r[k] then how[#how + 1] = (k == 'Blood') and 'Low HP' or k; end
            end
            if r.TrueSight then how[#how + 1] = 'True Sight'; end
            put('Aggro' .. (#how > 0 and (': ' .. table.concat(how, ' ')) or ''), { 1.0, 0.45, 0.45, 1 });
        else
            put('Passive', { 0.55, 0.92, 0.55, 1 });
        end
        if r.Link then put('Links', { 1.0, 0.75, 0.35, 1 }); end
        -- Weaknesses / resistances (mobdb's damage taken: above 1 = weak, 0.5 or less = resists)
        local m = r.Modifiers or {};
        local weak, res = {}, {};
        -- Elements: compared with this monster's own average, so one that takes double from
        -- everything doesn't list all eight.
        local sum, n = 0, 0;
        for _, k in ipairs(ELEM) do if m[k] then sum = sum + m[k]; n = n + 1; end end
        local avg = (n > 0) and (sum / n) or 1;
        for _, k in ipairs(ELEM) do
            local v = m[k];
            if v and v > avg * 1.08 and v > 1.0 then weak[#weak + 1] = k;
            elseif v and v < avg * 0.80 and v < 1.0 then res[#res + 1] = k; end
        end
        -- Physical: all four the same -> one word; otherwise each one.
        local p1, same = m.Slashing, true;
        for _, k in ipairs(PHYS) do if m[k] ~= p1 then same = false; end end
        if same and p1 then
            if p1 > 1.05 then weak[#weak + 1] = 'Physical'; elseif p1 <= 0.55 then res[#res + 1] = 'Physical'; end
        else
            for _, k in ipairs(PHYS) do
                local v = m[k];
                if v and v > 1.05 then weak[#weak + 1] = k; elseif v and v <= 0.55 then res[#res + 1] = k; end
            end
        end
        if #weak > 0 then group('Weak:', weak); end
        if #res > 0 then group('Resists:', res); end
        -- Immunities
        if r.Immunities and r.Immunities > 0 then
            local im = {};
            for _, f in ipairs(IMMUNE) do if bit.band(r.Immunities, f[1]) ~= 0 then im[#im + 1] = f[2]; end end
            put('Immune: ' .. table.concat(im, ' '), { 0.85, 0.65, 1.0, 1 });
        end
        -- Respawn
        if r.Respawn and r.Respawn > 0 then
            put(('Respawn %d:%02d'):format(math.floor(r.Respawn / 60), r.Respawn % 60), dim);
        end
        -- The monster's ID, always at the right end (its room was kept free above).
        if id_txt then
            if not first then imgui.SameLine(0, 0); end
            imgui.SetCursorPos({ math.max(w - 10 - id_w, pos + 12), line_y });
            imgui.TextColored(dim, id_txt);
        end
        -- Hover: drops and spells counts
        if imgui.IsWindowHovered() then
            local lines = { r.Name or '' };
            if #hidden > 0 then lines[#lines + 1] = 'Not shown (no room): ' .. table.concat(hidden, ' '); end
            local dn = {};
            pcall(function ()
                local res2 = AshitaCore:GetResourceManager();
                for _, id in ipairs(r.Drops or {}) do
                    local it = res2:GetItemById(id);
                    if it and it.Name and it.Name[1] then dn[#dn + 1] = it.Name[1]; end
                end
            end);
            lines[#lines + 1] = 'Drops: ' .. (#dn > 0 and table.concat(dn, ', ') or 'none listed');
            if r.Spells and #r.Spells > 0 then lines[#lines + 1] = ('Casts %d spells'):format(#r.Spells); end
            if id ~= nil and id ~= 0 then
                lines[#lines + 1] = ('ID %d  (0x%X)   index %d  (0x%X)'):format(id, id, index or 0, index or 0);
            end
            lines[#lines + 1] = '(from the mobdb database)';
            imgui.SetTooltip(table.concat(lines, '\n'));
        end
    end
    imgui.End();
    imgui.PopStyleVar(orn and 3 or 2);
    imgui.PopStyleColor(2);
    return mi.HEIGHT + top;
end

return mi;
