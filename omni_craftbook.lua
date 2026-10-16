--[[
    omni_craftbook.lua - Craftbook inside omni (Character > Crafts > Craftbook).

    From Happys' craftbook addon (github.com/Happyfists/Craftbook), adjusted for omni:
    no window of its own, omni's colours instead of themes, names cut to fit the real
    font, and its own settings (omni_craftbook). It only scans your bags while it is
    on screen.

    Scans your inventory and every mog house / carried bag, then shows which synthesis
    recipes you can make, which ingredients you have, where each one is stored and what
    is still missing. Recipe data: LandSandBoat server database (craft_recipes.lua).
]]

local imgui    = require('imgui');
local settings = require('settings');

local cb = {};
----------------------------------------------------------------------------------------------------
-- Constants
----------------------------------------------------------------------------------------------------

-- Storage containers, in the order they are displayed. 'carried' bags are with you outside the mog house.
local BAGS = {
    { id = 0,  name = 'Inventory',   carried = true  },
    { id = 5,  name = 'Mog Satchel', carried = true  },
    { id = 6,  name = 'Mog Sack',    carried = true  },
    { id = 7,  name = 'Mog Case',    carried = true  },
    { id = 1,  name = 'Mog Safe',    carried = false },
    { id = 9,  name = 'Mog Safe 2',  carried = false },
    { id = 2,  name = 'Storage',     carried = false },
    { id = 4,  name = 'Mog Locker',  carried = false },
    { id = 8,  name = 'Wardrobe',    carried = true  },
    { id = 10, name = 'Wardrobe 2',  carried = true  },
    { id = 11, name = 'Wardrobe 3',  carried = true  },
    { id = 12, name = 'Wardrobe 4',  carried = true  },
    { id = 13, name = 'Wardrobe 5',  carried = true  },
    { id = 14, name = 'Wardrobe 6',  carried = true  },
    { id = 15, name = 'Wardrobe 7',  carried = true  },
    { id = 16, name = 'Wardrobe 8',  carried = true  },
};

local CRAFTS = { 'Woodworking', 'Smithing', 'Goldsmithing', 'Clothcraft', 'Leathercraft', 'Bonecraft', 'Alchemy', 'Cooking' };
local CRAFT_SHORT = { 'Wood', 'Smith', 'Gold', 'Cloth', 'Leather', 'Bone', 'Alch', 'Cook' };

local ERAS = {
    { key = 'BASE',    name = 'Original game' },
    { key = 'ROTZ',    name = 'Rise of the Zilart' },
    { key = 'COP',     name = 'Chains of Promathia' },
    { key = 'TOAU',    name = 'Treasures of Aht Urhgan' },
    { key = 'WOTG',    name = 'Wings of the Goddess' },
    { key = 'ABYSSEA', name = 'Abyssea' },
    { key = 'SOA',     name = 'Seekers of Adoulin' },
    { key = 'ROV',     name = 'Rhapsodies of Vana\'diel' },
    { key = 'TVR',     name = 'The Voracious Resurgence' },
};

local SHOW_MODES = {
    'Ready now',
    'Have everything',
    'Missing 1',
    'Missing up to 2',
    'All recipes',
};

-- Level bands for the level filter: 0-10, 11-20, ... 111-120.
local LEVELS = {};
for i = 1, 12 do
    LEVELS[i] = string.format('Lv %d-%d', (i == 1) and 0 or ((i - 1) * 10 + 1), i * 10);
end

-- omni colours.
local COLOR = {
    ready   = { 0.45, 0.88, 0.45, 1.0 },
    fetch   = { 1.00, 0.80, 0.30, 1.0 },
    missing = { 1.00, 0.45, 0.45, 1.0 },
    dim     = { 0.62, 0.64, 0.74, 1.0 },
    head    = { 0.90, 0.78, 0.40, 1.0 },
    text    = { 0.92, 0.92, 0.95, 1.0 },
};

local default_settings = T{
    show_mode    = 2,
    craft        = 0,
    level        = 0,
    desynth      = false,
    hide_no_ki   = true,
    skill_limit  = false,
    skill_margin = 10,
    mats_only    = true,
    queue        = '',   -- saved craft queue: 'recipeId:count,recipeId:count'
    open_crafts  = T{ c1 = false, c2 = false, c3 = false, c4 = false, c5 = false, c6 = false, c7 = false, c8 = false },
    bags = T{
        b0 = true, b1 = true, b2 = true, b4 = true, b5 = true, b6 = true, b7 = true, b8 = true, b9 = true,
        b10 = true, b11 = true, b12 = true, b13 = true, b14 = true, b15 = true, b16 = true,
    },
    eras = T{
        BASE = true, ROTZ = true, COP = true, TOAU = true, WOTG = true,
        ABYSSEA = false, SOA = false, ROV = false, TVR = false,
    },
};

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------

local cfg = default_settings;

local recipes   = {};   -- all recipes
local uses      = {};   -- item id -> list of recipes that use it as an ingredient
local makes     = {};   -- item id -> list of recipes that produce it
local have      = {};   -- item id -> { total = n, bags = { [bagId] = n } }
local owned     = {};   -- sorted list of owned item ids
local skills    = {};   -- craft index -> your skill level (nil if unknown)
local names     = {};   -- item name cache
local recipes_by_id = {}; -- recipe id -> recipe

local state = {
    open          = { true },
    search        = { '' },
    item_search   = { '' },
    filtered      = {},
    items         = {},
    tab           = 1,     -- 1 recipes, 2 queue, 3 items, 4 settings
    queue         = {},    -- { r = recipe, n = number of synths }
    add_qty       = 1,
    extra_h       = {},    -- measured height of the expanded row per list
    sel_idx       = nil,
    rows          = {},    -- what the recipe list shows: craft headers and recipes
    rows_dirty    = true,
    item_idx      = nil,
    selected      = nil,   -- selected recipe (Recipes tab)
    selected_item = nil,   -- selected item id (Items tab)
    item_recipe   = nil,   -- recipe picked inside the Items tab
    dirty         = true,
    items_dirty   = true,
    last_scan     = -100,
    last_filter   = nil,
    last_ifilter  = nil,
    search_ready  = false,
    logged_in     = false,
};

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

local function save() pcall(function () settings.save('omni_craftbook'); end); end

local function flag(name)
    local v = _G[name];
    if type(v) == 'number' then return v; end
    return 0;
end

local function item_name(id)
    local n = names[id];
    if n ~= nil then return n; end
    local ok, res = pcall(function ()
        return AshitaCore:GetResourceManager():GetItemById(id);
    end);
    if ok and res ~= nil and res.Name ~= nil and res.Name[1] ~= nil and #res.Name[1] > 0 then
        n = res.Name[1];
    else
        n = string.format('Item #%d', id);
    end
    names[id] = n;
    return n;
end

local function keyitem_name(id)
    local ok, s = pcall(function ()
        return AshitaCore:GetResourceManager():GetString('keyitems.names', id);
    end);
    if ok and type(s) == 'string' and #s > 0 then return s; end
    return string.format('Key item #%d', id);
end

local function has_keyitem(id)
    local ok, r = pcall(function ()
        return AshitaCore:GetMemoryManager():GetPlayer():HasKeyItem(id);
    end);
    if ok then return r == true; end
    return nil; -- unknown
end

local function bag_enabled(id)
    return cfg.bags['b' .. id] ~= false;
end

local function split_numbers(s)
    local t = {};
    for n in s:gmatch('%d+') do t[#t + 1] = tonumber(n); end
    return t;
end

----------------------------------------------------------------------------------------------------
-- Recipe loading
----------------------------------------------------------------------------------------------------

local function load_recipes()
    local raw = require('craft_recipes');
    for line in raw:gmatch('[^\r\n]+') do
        local id, des, ki, sk, cry, ings, res, qty, name, tag =
            line:match('^(%d+)|(%d)|(%d+)|([%d,]+)|(%d+)|([%d,]*)|([%d,]+)|([%d,]+)|(.-)|(%u*)$');
        if id ~= nil then
            local r = {
                id      = tonumber(id),
                desynth = des == '1',
                ki      = tonumber(ki),
                skills  = split_numbers(sk),
                crystal = tonumber(cry),
                results = split_numbers(res),
                qty     = split_numbers(qty),
                name    = name,
                lname   = name:lower(),
                era     = (tag == '' and 'BASE') or tag,
                need    = {},
                craft   = 1,
                level   = 0,
                status  = 3,
            };

            -- Main craft is the one with the highest requirement.
            for i = 1, 8 do
                local lv = r.skills[i] or 0;
                if lv > r.level then r.level = lv; r.craft = i; end
            end

            -- Collapse duplicate ingredients into { id, count } pairs. Crystals are not counted as ingredients.
            local counts, order = {}, {};
            local function add(item)
                if item == nil or item == 0 then return; end
                if counts[item] == nil then counts[item] = 0; order[#order + 1] = item; end
                counts[item] = counts[item] + 1;
            end
            for _, item in ipairs(split_numbers(ings)) do add(item); end
            for _, item in ipairs(order) do
                r.need[#r.need + 1] = { id = item, count = counts[item] };
                uses[item] = uses[item] or {};
                table.insert(uses[item], r);
            end

            if not r.desynth then
                local seen = {};
                for _, item in ipairs(r.results) do
                    if item ~= 0 and not seen[item] then
                        seen[item] = true;
                        makes[item] = makes[item] or {};
                        table.insert(makes[item], r);
                    end
                end
            end

            recipes[#recipes + 1] = r;
            recipes_by_id[r.id] = r;
        end
    end
end

-- Builds the text each recipe is searched by (its name plus its ingredient names).
local function build_search_index()
    for _, r in ipairs(recipes) do
        local parts = { r.lname };
        for _, n in ipairs(r.need) do parts[#parts + 1] = item_name(n.id):lower(); end
        r.search = table.concat(parts, '\n');
    end
    state.search_ready = true;
end

----------------------------------------------------------------------------------------------------
-- Scanning and evaluation
----------------------------------------------------------------------------------------------------

local function scan_bags()
    local ok, inv = pcall(function () return AshitaCore:GetMemoryManager():GetInventory(); end);
    if not ok or inv == nil then return false; end

    local found, list = {}, {};
    local any = false;
    for _, bag in ipairs(BAGS) do
        if bag_enabled(bag.id) then
            for slot = 0, 80 do
                local item = inv:GetContainerItem(bag.id, slot);
                if item ~= nil and item.Id ~= nil and item.Id ~= 0 and item.Id ~= 65535 and (item.Count or 0) > 0 then
                    local h = found[item.Id];
                    if h == nil then
                        h = { total = 0, bags = {} };
                        found[item.Id] = h;
                        list[#list + 1] = item.Id;
                    end
                    h.total = h.total + item.Count;
                    h.bags[bag.id] = (h.bags[bag.id] or 0) + item.Count;
                    any = true;
                end
            end
        end
    end

    have, owned = found, list;
    state.logged_in = any;
    return true;
end

local function read_skills()
    for i = 1, 8 do
        local ok, v = pcall(function ()
            return AshitaCore:GetMemoryManager():GetPlayer():GetCraftSkill(i):GetSkill();
        end);
        if ok and type(v) == 'number' then skills[i] = v; else skills[i] = nil; end
    end
end

local function evaluate(r)
    local kinds, fetch = 0, 0;
    local times = math.huge;
    for _, n in ipairs(r.need) do
        local h = have[n.id];
        local total = (h and h.total) or 0;
        local inbag = (h and h.bags[0]) or 0;
        if total < n.count then
            kinds = kinds + 1;
        elseif inbag < n.count then
            fetch = fetch + 1;
        end
        times = math.min(times, math.floor(total / n.count));
    end
    r.missing = kinds;
    r.times   = (times == math.huge) and 0 or times;
    r.status  = (kinds > 0 and 3) or (fetch > 0 and 2) or 1;

    if r.ki ~= 0 then
        local k = has_keyitem(r.ki);
        r.ki_missing = (k == false);
    else
        r.ki_missing = false;
    end

    local gap = nil;
    for i = 1, 8 do
        local req = r.skills[i] or 0;
        if req > 0 and skills[i] ~= nil then
            local g = req - skills[i];
            if gap == nil or g > gap then gap = g; end
        end
    end
    r.gap = gap; -- nil when your skill could not be read
end

local function refresh()
    if not scan_bags() then return; end
    read_skills();
    for _, r in ipairs(recipes) do evaluate(r); end
    state.dirty = true;
    state.items_dirty = true;
end

----------------------------------------------------------------------------------------------------
-- Filtering
----------------------------------------------------------------------------------------------------

local function passes(r, text)
    if not cfg.eras[r.era] then return false; end
    if r.desynth and not cfg.desynth then return false; end

    -- Typing in the search box looks through every recipe, whatever the dropdowns say,
    -- so you can look up something you cannot make yet and see what it needs.
    if text ~= '' then
        return r.search:find(text, 1, true) ~= nil;
    end

    if cfg.craft ~= 0 and (r.skills[cfg.craft] or 0) == 0 then return false; end
    if cfg.level ~= 0 then
        -- With a craft picked, use that craft's requirement; otherwise the recipe's main level.
        local lv = (cfg.craft ~= 0 and r.skills[cfg.craft]) or r.level;
        local lo = (cfg.level == 1) and 0 or ((cfg.level - 1) * 10 + 1);
        if lv < lo or lv > cfg.level * 10 then return false; end
    end

    local mode = cfg.show_mode;
    if mode == 1 and r.status ~= 1 then return false; end
    if mode == 2 and r.status > 2 then return false; end
    if mode == 3 and r.missing > 1 then return false; end
    if mode == 4 and r.missing > 2 then return false; end
    -- In the "missing" views, skip recipes you own nothing for.
    if (mode == 3 or mode == 4) and r.missing >= #r.need then return false; end

    if cfg.hide_no_ki and mode ~= 5 and r.ki_missing then return false; end
    if cfg.skill_limit and r.gap ~= nil and r.gap > cfg.skill_margin then return false; end
    return true;
end

local function rebuild_filtered()
    local text = (state.search[1] or ''):lower();
    if text ~= '' and not state.search_ready then build_search_index(); end
    if not state.search_ready then
        -- Cheap fallback until the full index is needed.
        for _, r in ipairs(recipes) do r.search = r.search or r.lname; end
    end

    local out = {};
    for _, r in ipairs(recipes) do
        if passes(r, text) then out[#out + 1] = r; end
    end
    -- When searching, recipes whose own name matches come before ones that only use the item.
    if text ~= '' then
        for _, r in ipairs(out) do
            r.rank = (r.lname == text and 0) or (r.lname:find(text, 1, true) and 1) or 2;
        end
    else
        for _, r in ipairs(out) do r.rank = 0; end
    end
    table.sort(out, function (a, b)
        if a.rank ~= b.rank then return a.rank < b.rank; end
        if a.status ~= b.status then return a.status < b.status; end
        if a.missing ~= b.missing then return a.missing < b.missing; end
        if a.craft ~= b.craft then return a.craft < b.craft; end
        if a.level ~= b.level then return a.level < b.level; end
        if a.lname ~= b.lname then return a.lname < b.lname; end
        return a.id < b.id;
    end);
    state.filtered = out;
    state.dirty = false;
end

local function rebuild_items()
    local text = (state.item_search[1] or ''):lower();
    local out = {};
    for _, id in ipairs(owned) do
        local used = uses[id];
        if (not cfg.mats_only) or used ~= nil then
            local name = item_name(id);
            if text == '' or name:lower():find(text, 1, true) then
                out[#out + 1] = { id = id, name = name, lname = name:lower(), total = have[id].total, uses = (used and #used) or 0 };
            end
        end
    end
    table.sort(out, function (a, b)
        if a.lname ~= b.lname then return a.lname < b.lname; end
        return a.id < b.id;
    end);
    state.items = out;
    state.items_dirty = false;
end

----------------------------------------------------------------------------------------------------
-- Themes
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------------------

local function status_color(r)
    if r.status == 1 then return COLOR.ready; end
    if r.status == 2 then return COLOR.fetch; end
    return COLOR.missing;
end

local function where_text(id)
    local h = have[id];
    if h == nil then return 'none'; end
    local parts = {};
    for _, bag in ipairs(BAGS) do
        local n = h.bags[bag.id];
        if n ~= nil then parts[#parts + 1] = string.format('%s x%d', bag.name, n); end
    end
    return table.concat(parts, ', ');
end

local function checkbox(label, value)
    local t = { value == true };
    imgui.Checkbox(label, t);
    return t[1] == true, (t[1] == true) ~= (value == true);
end

local function combo(label, current, options, first)
    local changed = false;
    local preview = options[current] or first or '';
    if imgui.BeginCombo(label, preview) then
        if first ~= nil then
            if imgui.Selectable(first, current == 0) then current = 0; changed = true; end
        end
        for i, name in ipairs(options) do
            if imgui.Selectable(name, current == i) then current = i; changed = true; end
        end
        imgui.EndCombo();
    end
    return current, changed;
end


-- Draws a long list where one row (sel) can be expanded with extra lines under it.
-- Only the rows on screen are drawn, so thousands of recipes stay cheap.
local function expanding_list(key, count, sel, draw_row, draw_extra)
    if count == 0 then return; end
    local ok, h, scroll, height, base = pcall(function ()
        return imgui.GetTextLineHeightWithSpacing(), imgui.GetScrollY(), imgui.GetWindowHeight(), imgui.GetCursorPosY();
    end);
    if not ok or type(h) ~= 'number' or type(scroll) ~= 'number' or type(height) ~= 'number' or type(base) ~= 'number' or h <= 0 then
        -- Could not measure: draw a capped list without clipping.
        for i = 1, math.min(count, 300) do
            draw_row(i);
            if i == sel then draw_extra(i); end
        end
        return;
    end

    local extra = (sel ~= nil and state.extra_h[key]) or 0;
    local first;
    if sel == nil or scroll < sel * h then
        first = math.floor(scroll / h);
    elseif scroll < sel * h + extra then
        first = sel;
    else
        first = math.floor((scroll - extra) / h);
    end
    first = math.max(1, math.min(count, first));
    local last = math.min(count, first + math.ceil(height / h) + 2);

    imgui.SetCursorPosY(base + (first - 1) * h + ((sel ~= nil and first > sel) and extra or 0));
    for i = first, last do
        draw_row(i);
        if i == sel then
            local y0 = imgui.GetCursorPosY();
            draw_extra(i);
            local y1 = imgui.GetCursorPosY();
            if type(y0) == 'number' and type(y1) == 'number' then
                extra = math.max(0, y1 - y0);
                state.extra_h[key] = extra;
            end
        end
    end
    imgui.SetCursorPosY(base + count * h + ((sel ~= nil) and extra or 0));
    imgui.Dummy({ 1, 0 });
end


local function line_height()
    local ok, h = pcall(imgui.GetTextLineHeightWithSpacing);
    if ok and type(h) == 'number' and h > 0 then return h; end
    return 17;
end

-- Bigger text for titles and counts; ignored if this imgui build cannot scale fonts.
local function font_scale(s)
    pcall(imgui.SetWindowFontScale, s);
end

-- Cut a name to fit a width in pixels (the game font is wider than it looks), ending in "..".
local function short_name(name, width)
    name = tostring(name or '');
    if width <= 0 then return ''; end
    if imgui.CalcTextSize(name) <= width then return name; end
    local n = #name;
    while n > 1 and imgui.CalcTextSize(name:sub(1, n) .. '..') > width do n = n - 1; end
    return name:sub(1, n) .. '..';
end

local function status_tail(r)
    if r.status == 3 then return string.format('need %d', r.missing); end
    return string.format('x%d', r.times);
end

-- The best recipe that makes an item, for "you can craft it" hints.
local function best_maker(id)
    local best = nil;
    for _, s in ipairs(makes[id] or {}) do
        if cfg.eras[s.era] and (best == nil or s.status < best.status) then best = s; end
    end
    return best;
end

----------------------------------------------------------------------------------------------------
-- Craft queue (from Craftbook 3.2)
----------------------------------------------------------------------------------------------------

local function save_queue()
    local parts = {};
    for _, q in ipairs(state.queue) do parts[#parts + 1] = string.format('%d:%d', q.r.id, q.n); end
    cfg.queue = table.concat(parts, ',');
    save();
end

local function load_queue()
    state.queue = {};
    for id, n in tostring(cfg.queue or ''):gmatch('(%d+):(%d+)') do
        local r = recipes_by_id[tonumber(id)];
        n = tonumber(n);
        if r ~= nil and n > 0 then state.queue[#state.queue + 1] = { r = r, n = n }; end
    end
end

local function queue_find(r)
    for i, q in ipairs(state.queue) do
        if q.r == r then return i; end
    end
    return nil;
end

local function queue_add(r, n)
    local i = queue_find(r);
    if i ~= nil then
        state.queue[i].n = math.min(999, state.queue[i].n + n);
    else
        state.queue[#state.queue + 1] = { r = r, n = n };
    end
    save_queue();
end

local function queue_set(i, n)
    if state.queue[i] == nil then return; end
    if n <= 0 then
        table.remove(state.queue, i);
    else
        state.queue[i].n = math.min(999, n);
    end
    save_queue();
end

-- Adds up every ingredient for every queued synth and compares it with what you own.
local function queue_totals()
    local need, order, crystals, corder = {}, {}, {}, {};
    local synths = 0;
    for _, q in ipairs(state.queue) do
        synths = synths + q.n;
        for _, n in ipairs(q.r.need) do
            if need[n.id] == nil then need[n.id] = 0; order[#order + 1] = n.id; end
            need[n.id] = need[n.id] + n.count * q.n;
        end
        if q.r.crystal ~= 0 then
            if crystals[q.r.crystal] == nil then crystals[q.r.crystal] = 0; corder[#corder + 1] = q.r.crystal; end
            crystals[q.r.crystal] = crystals[q.r.crystal] + q.n;
        end
    end

    local rows, short_kinds, fetch_kinds = {}, 0, 0;
    for _, id in ipairs(order) do
        local h = have[id];
        local total = (h and h.total) or 0;
        local inbag = (h and h.bags[0]) or 0;
        local st = (total < need[id] and 3) or (inbag < need[id] and 2) or 1;
        if st == 3 then short_kinds = short_kinds + 1; end
        if st == 2 then fetch_kinds = fetch_kinds + 1; end
        rows[#rows + 1] = { id = id, name = item_name(id), need = need[id], total = total, inbag = inbag, status = st };
    end
    table.sort(rows, function (a, b)
        if a.status ~= b.status then return a.status > b.status; end
        return a.name < b.name;
    end);

    local clist = {};
    for _, id in ipairs(corder) do clist[#clist + 1] = string.format('%d %s', crystals[id], item_name(id)); end
    return rows, clist, synths, short_kinds, fetch_kinds;
end

----------------------------------------------------------------------------------------------------
-- Left pane: recipe list
----------------------------------------------------------------------------------------------------

-- One list row: status dot, name, level, how many you can make.
local function draw_recipe_row(r, selected, w, id_prefix, show_craft)
    local c = status_color(r);
    imgui.PushStyleColor(flag('ImGuiCol_Text'), c);
    imgui.Bullet();
    imgui.PopStyleColor(1);
    imgui.SameLine();
    local tailW = imgui.CalcTextSize('need 99') + 6;
    local midW = imgui.CalcTextSize(show_craft and 'Leather 110' or 'Lv 110') + 10;
    local nameW = w - tailW - midW - 40;
    local name = short_name((r.desynth and 'Desynth ' or '') .. r.name, nameW);
    local clicked = imgui.Selectable(string.format('%s##%s%d', name, id_prefix, r.id), selected);
    imgui.SameLine(w - tailW - midW);
    if show_craft then
        imgui.TextColored(COLOR.dim, string.format('%s %d', CRAFT_SHORT[r.craft], r.level));
    else
        imgui.TextColored(COLOR.dim, string.format('Lv %d', r.level));
    end
    imgui.SameLine(w - tailW);
    imgui.TextColored(c, status_tail(r));
    return clicked;
end

-- Builds the rows of the recipe list. With "All crafts" picked and nothing typed in the
-- search box, recipes are grouped under a header per craft that opens and closes.
local function build_rows()
    local rows = {};
    local searching = (state.search[1] or '') ~= '';
    if cfg.craft ~= 0 or searching then
        for _, r in ipairs(state.filtered) do rows[#rows + 1] = { r = r }; end
    else
        local groups = {};
        for i = 1, #CRAFTS do groups[i] = {}; end
        for _, r in ipairs(state.filtered) do table.insert(groups[r.craft], r); end
        for i = 1, #CRAFTS do
            local g = groups[i];
            if #g > 0 then
                local ready = 0;
                for _, r in ipairs(g) do
                    if r.status == 1 then ready = ready + 1; end
                end
                local open = cfg.open_crafts['c' .. i] == true;
                rows[#rows + 1] = { header = true, craft = i, count = #g, ready = ready, open = open };
                if open then
                    for _, r in ipairs(g) do rows[#rows + 1] = { r = r }; end
                end
            end
        end
    end
    state.rows = rows;
    state.rows_dirty = false;
end

-- A craft section header: click to open or close it.
local function draw_craft_header(row, w)
    imgui.PushStyleColor(flag('ImGuiCol_Text'), COLOR.head);
    local clicked = imgui.Selectable(string.format('%s %s##craft%d', row.open and '[-]' or '[+]', CRAFTS[row.craft], row.craft), false);
    imgui.PopStyleColor(1);
    local tailW = imgui.CalcTextSize('99 ready') + 6;
    local cnt = tostring(row.count);
    imgui.SameLine(w - tailW - imgui.CalcTextSize(cnt) - 14);
    imgui.TextColored(COLOR.dim, cnt);
    imgui.SameLine(w - tailW);
    imgui.TextColored(row.ready > 0 and COLOR.ready or COLOR.dim, string.format('%d ready', row.ready));
    return clicked;
end

local function draw_recipe_list(w)
    local changed, c;

    -- Look up anything you want to craft.
    imgui.PushItemWidth(w - 24);
    imgui.InputText('##find', state.search, 64);
    imgui.PopItemWidth();
    if (state.search[1] or '') == '' then
        imgui.SameLine(18);
        imgui.TextColored(COLOR.dim, 'Find a recipe...');
    end

    imgui.PushItemWidth(w - 24);
    cfg.show_mode, c = combo('##show', cfg.show_mode, SHOW_MODES); changed = c;
    imgui.PopItemWidth();
    imgui.PushItemWidth(math.floor((w - 24 - 8) * 0.55));
    cfg.craft, c = combo('##craft', cfg.craft, CRAFTS, 'All crafts'); changed = changed or c;
    imgui.PopItemWidth();
    imgui.SameLine();
    imgui.PushItemWidth(math.floor((w - 24 - 8) * 0.45));
    cfg.level, c = combo('##level', cfg.level, LEVELS, 'All levels'); changed = changed or c;
    imgui.PopItemWidth();

    if changed then save(); state.dirty = true; end
    if state.search[1] ~= state.last_filter then
        state.last_filter = state.search[1];
        state.dirty = true;
        state.autoselect = true;
    end
    if state.dirty then
        rebuild_filtered();
        -- After typing, open the recipe straight away when there is an exact or single match.
        if state.autoselect then
            state.autoselect = false;
            local first = state.filtered[1];
            if (state.search[1] or '') ~= '' and first ~= nil and (#state.filtered == 1 or first.rank == 0) then
                state.selected = first;
            end
        end
        state.rows_dirty = true;
    end
    if state.rows_dirty then build_rows(); end

    imgui.Separator();

    imgui.BeginChild('##recipe_list', { 0, -24 }, false);
    local list = state.rows;
    local cw = math.floor(imgui.GetContentRegionAvail()) - 4;
    if #list == 0 then
        if not state.logged_in then
            imgui.TextColored(COLOR.dim, 'No items found yet.');
            imgui.TextColored(COLOR.dim, 'Log in to a character.');
        elseif (state.search[1] or '') ~= '' then
            imgui.TextColored(COLOR.dim, 'No recipe with that name.');
        else
            imgui.TextColored(COLOR.dim, 'Nothing matches these filters.');
        end
    end
    local show_craft = (cfg.craft == 0 and (state.search[1] or '') ~= '');
    expanding_list('recipes', #list, nil, function (i)
        local row = list[i];
        if row.header then
            if draw_craft_header(row, cw) then
                local key = 'c' .. row.craft;
                cfg.open_crafts[key] = not (cfg.open_crafts[key] == true);
                save();
                state.rows_dirty = true; -- rebuilt next frame, not while drawing
            end
            return;
        end
        if draw_recipe_row(row.r, state.selected == row.r, cw, 'r', show_craft) then
            state.selected = row.r;
        end
    end, function () end);
    imgui.EndChild();

    imgui.TextColored(COLOR.dim, string.format((state.search[1] or '') ~= '' and '%d found' or '%d recipes', #state.filtered));
end

----------------------------------------------------------------------------------------------------
-- Right pane: recipe detail
----------------------------------------------------------------------------------------------------

-- What to do before you can synth: items to move, items to get, key items, skill.
local function todo_lines(r)
    local out = {};
    for _, n in ipairs(r.need) do
        local h = have[n.id];
        local total = (h and h.total) or 0;
        local inbag = (h and h.bags[0]) or 0;
        local name = item_name(n.id);
        if total < n.count then
            local text = string.format('Get %d more %s', n.count - total, name);
            local best = best_maker(n.id);
            if best ~= nil then
                text = text .. string.format(' (craftable: %s %d)', CRAFT_SHORT[best.craft], best.level);
            end
            out[#out + 1] = { COLOR.missing, text };
        elseif inbag < n.count then
            local short = n.count - inbag;
            for _, bag in ipairs(BAGS) do
                local cnt = (bag.id ~= 0) and h.bags[bag.id] or nil;
                if cnt ~= nil and short > 0 then
                    local take = math.min(short, cnt);
                    out[#out + 1] = { COLOR.fetch, string.format('Move %d %s from %s', take, name, bag.name) };
                    short = short - take;
                end
            end
        end
    end
    if r.ki ~= 0 and r.ki_missing then
        out[#out + 1] = { COLOR.missing, 'Get the key item: ' .. keyitem_name(r.ki) };
    end
    for i = 1, 8 do
        local req, mine = r.skills[i] or 0, skills[i];
        if req > 0 and mine ~= nil and mine < req then
            out[#out + 1] = { (mine + 10 >= req) and COLOR.fetch or COLOR.missing,
                string.format('Your %s is %d, this recipe is %d', CRAFTS[i], mine, req) };
        end
    end
    if #out == 0 then
        out[1] = { COLOR.ready, 'Everything is in your Inventory - ready to synth.' };
    end
    return out;
end

-- One ingredient tile: name and have / need on top, where it is underneath.
local function tile_lines(n)
    local h = have[n.id];
    local total = (h and h.total) or 0;
    local inbag = (h and h.bags[0]) or 0;
    local c = (total < n.count and COLOR.missing) or (inbag < n.count and COLOR.fetch) or COLOR.ready;
    local lines = {};
    if total == 0 then
        local best = best_maker(n.id);
        lines[1] = { COLOR.dim, 'you have none' };
        if best ~= nil then
            lines[2] = { COLOR.dim, string.format('craftable: %s %d', CRAFT_SHORT[best.craft], best.level) };
        end
    else
        for _, bag in ipairs(BAGS) do
            local cnt = h.bags[bag.id];
            if cnt ~= nil then
                lines[#lines + 1] = { (bag.id == 0) and COLOR.dim or c, string.format('%s x%d', bag.name, cnt) };
            end
        end
        if inbag == 0 then lines[#lines + 1] = { COLOR.dim, 'none in Inventory' }; end
    end
    return c, total, lines;
end

local function draw_close_button(dw) end   -- omni: no window to close

local function draw_recipe_detail(r, dw)
    local c = status_color(r);
    local lh = line_height();

    -- Title and subtitle on the left, the "can make" badge on the right.
    local big = (r.status == 3) and string.format('-%d', r.missing) or string.format('x%d', r.times);
    local small = (r.status == 3) and 'missing' or 'can make';
    local badgeW = math.floor(math.max(imgui.CalcTextSize(small), imgui.CalcTextSize(big) * 1.35) + 24);
    local badgeH = math.floor(lh * 2.35 + 12);
    local textW = dw - badgeW - 24;
    local x0, y0 = imgui.GetCursorPosX(), imgui.GetCursorPosY();

    imgui.BeginGroup();
    font_scale(1.45);
    imgui.TextColored(COLOR.head, short_name((r.desynth and 'Desynth ' or '') .. r.name, textW / 1.45));
    font_scale(1.0);
    local sub = {};
    for i = 1, 8 do
        local req = r.skills[i] or 0;
        if req > 0 then
            sub[#sub + 1] = (skills[i] ~= nil) and string.format('%s %d (you %d)', CRAFTS[i], req, skills[i]) or string.format('%s %d', CRAFTS[i], req);
        end
    end
    if r.crystal ~= 0 then sub[#sub + 1] = item_name(r.crystal); end
    imgui.PushTextWrapPos(x0 + textW);
    imgui.TextColored(COLOR.dim, table.concat(sub, '  -  '));
    imgui.PopTextWrapPos();
    imgui.EndGroup();
    local yText = imgui.GetCursorPosY();

    imgui.SetCursorPos({ x0 + dw - badgeW - 8, y0 });
    imgui.PushStyleColor(flag('ImGuiCol_Border'), c);
    imgui.PushStyleColor(flag('ImGuiCol_ChildBg'), { c[1], c[2], c[3], 0.08 });
    imgui.BeginChild('##badge', { badgeW, badgeH }, true, bit.bor(flag('ImGuiWindowFlags_NoScrollbar'), flag('ImGuiWindowFlags_NoScrollWithMouse')));
    local bw = imgui.GetContentRegionAvail();
    font_scale(1.35);
    imgui.SetCursorPosX(math.max(0, (badgeW - imgui.CalcTextSize(big)) / 2));
    imgui.TextColored(c, big);
    font_scale(1.0);
    imgui.SetCursorPosX(math.max(0, (badgeW - imgui.CalcTextSize(small)) / 2));
    imgui.TextColored(COLOR.dim, small);
    imgui.EndChild();
    imgui.PopStyleColor(2);

    imgui.SetCursorPos({ x0, math.max(yText, y0 + badgeH) + 4 });

    -- Add this recipe to the craft queue.
    if imgui.SmallButton('-##addqm') then state.add_qty = math.max(1, state.add_qty - 1); end
    imgui.SameLine();
    imgui.Text(tostring(state.add_qty));
    imgui.SameLine();
    if imgui.SmallButton('+##addqp') then state.add_qty = math.min(999, state.add_qty + 1); end
    imgui.SameLine();
    if imgui.SmallButton(string.format('Add %d to queue##addq', state.add_qty)) then
        queue_add(r, state.add_qty);
        state.add_qty = 1;
    end
    local qi = queue_find(r);
    if qi ~= nil then
        imgui.SameLine();
        imgui.TextColored(COLOR.head, string.format('In queue: %d', state.queue[qi].n));
    end

    -- Ingredients, two tiles per row.
    imgui.TextColored(COLOR.head, 'INGREDIENTS');
    local tw = math.floor((dw - 24 - 8) / 2);
    local tiles = {};
    for i, n in ipairs(r.need) do
        local tc, total, lines = tile_lines(n);
        tiles[i] = { n = n, c = tc, total = total, lines = lines };
    end
    for i, t in ipairs(tiles) do
        local partner = (i % 2 == 1) and tiles[i + 1] or tiles[i - 1];
        local rows_needed = math.max(#t.lines, partner and #partner.lines or 0, 1) + 1;
        local th = rows_needed * lh + 18;
        if i % 2 == 0 then imgui.SameLine(); end
        imgui.PushStyleColor(flag('ImGuiCol_Border'), t.c);
        imgui.BeginChild('##tile' .. i, { tw, th }, true, bit.bor(flag('ImGuiWindowFlags_NoScrollbar'), flag('ImGuiWindowFlags_NoScrollWithMouse')));
        local hn = string.format('%d / %d', t.total, t.n.count);
        local hw = imgui.CalcTextSize(hn);
        imgui.TextColored(t.c, short_name(item_name(t.n.id), tw - hw - 30));
        imgui.SameLine(tw - hw - 12);
        imgui.TextColored(t.c, hn);
        for _, l in ipairs(t.lines) do imgui.TextColored(l[1], l[2]); end
        imgui.EndChild();
        imgui.PopStyleColor(1);
    end

    -- What still needs doing.
    imgui.TextColored(COLOR.head, 'TO DO');
    for _, l in ipairs(todo_lines(r)) do
        imgui.PushStyleColor(flag('ImGuiCol_Text'), l[1]);
        imgui.TextWrapped(l[2]);
        imgui.PopStyleColor(1);
    end

    -- Results
    imgui.Separator();
    local q = r.qty;
    local parts = { string.format('Makes: %s x%d', item_name(r.results[1] or 0), q[1] or 1) };
    for i = 2, 4 do
        local id = r.results[i] or 0;
        if id ~= 0 and (id ~= r.results[1] or (q[i] or 1) ~= (q[1] or 1)) then
            parts[#parts + 1] = string.format('HQ%d %s x%d', i - 1, item_name(id), q[i] or 1);
        end
    end
    imgui.PushStyleColor(flag('ImGuiCol_Text'), COLOR.dim);
    imgui.TextWrapped(table.concat(parts, '   '));
    imgui.PopStyleColor(1);
end

----------------------------------------------------------------------------------------------------
-- Items tab
----------------------------------------------------------------------------------------------------


local function draw_item_list(w)
    local c;
    imgui.PushItemWidth(w - 24);
    imgui.InputText('##itemfind', state.item_search, 64);
    imgui.PopItemWidth();
    if (state.item_search[1] or '') == '' then
        imgui.SameLine(18);
        imgui.TextColored(COLOR.dim, 'Find an item...');
    end
    cfg.mats_only, c = checkbox('Only crafting materials', cfg.mats_only);
    if c then save(); state.items_dirty = true; end

    if state.item_search[1] ~= state.last_ifilter then
        state.last_ifilter = state.item_search[1];
        state.items_dirty = true;
    end
    if state.items_dirty then rebuild_items(); end

    imgui.Separator();
    imgui.BeginChild('##item_list', { 0, -24 }, false);
    local list = state.items;
    local cw = math.floor(imgui.GetContentRegionAvail()) - 4;
    if #list == 0 then imgui.TextColored(COLOR.dim, 'No items to show.'); end
    expanding_list('items', #list, nil, function (i)
        local it = list[i];
        local n = string.format('x%d', it.total);
        local nw = imgui.CalcTextSize(n);
        if imgui.Selectable(string.format('%s##i%d', short_name(it.name, cw - nw - 30), it.id), state.selected_item == it.id) then
            state.selected_item = it.id;
        end
        imgui.SameLine(cw - nw - 8);
        imgui.Text(n);
    end, function () end);
    imgui.EndChild();
    imgui.TextColored(COLOR.dim, string.format('%d items', #state.items));
end

local function draw_item_detail(dw)
    local id = state.selected_item;
    if id == nil then
        imgui.TextColored(COLOR.dim, 'Pick an item on the left.');
        draw_close_button(dw);
        imgui.TextColored(COLOR.dim, 'You will see where it is and which recipes use it.');
        return;
    end

    font_scale(1.45);
    imgui.TextColored(COLOR.head, short_name(item_name(id), (dw - 20) / 1.45));
    font_scale(1.0);
    draw_close_button(dw);

    imgui.TextColored(COLOR.head, 'WHERE IT IS');
    imgui.PushStyleColor(flag('ImGuiCol_Text'), COLOR.dim);
    imgui.TextWrapped(where_text(id));
    imgui.PopStyleColor(1);

    local used = {};
    for _, r in ipairs(uses[id] or {}) do
        if cfg.eras[r.era] and (cfg.desynth or not r.desynth) then used[#used + 1] = r; end
    end
    table.sort(used, function (a, b)
        if a.status ~= b.status then return a.status < b.status; end
        if a.missing ~= b.missing then return a.missing < b.missing; end
        if a.level ~= b.level then return a.level < b.level; end
        return a.id < b.id;
    end);

    imgui.TextColored(COLOR.head, string.format('USED IN %d RECIPES', #used));
    imgui.TextColored(COLOR.dim, 'Click one to open it.');
    imgui.BeginChild('##item_recipes', { 0, 0 }, false);
    local cw = math.floor(imgui.GetContentRegionAvail()) - 4;
    local jump = nil;
    expanding_list('item_recipes', #used, nil, function (i)
        if draw_recipe_row(used[i], false, cw, 'u', true) then jump = used[i]; end
    end, function () end);
    imgui.EndChild();

    -- Clicking a recipe opens it on the Recipes tab.
    if jump ~= nil then
        state.tab = 1;
        state.search[1] = jump.name;
        state.selected = jump;
        state.dirty = true;
    end
end

----------------------------------------------------------------------------------------------------
-- Queue tab
----------------------------------------------------------------------------------------------------

local function draw_queue_list(w)
    if #state.queue == 0 then
        imgui.TextColored(COLOR.dim, 'Your queue is empty.');
        imgui.TextColored(COLOR.dim, 'Open a recipe and press');
        imgui.TextColored(COLOR.dim, '"Add to queue".');
        return;
    end

    imgui.BeginChild('##cb_queue_list', { 0, -48 }, false);
    local right = w - 24;
    local controls_w = imgui.CalcTextSize('-') + imgui.CalcTextSize('x999') + imgui.CalcTextSize('+') + imgui.CalcTextSize('x') + 70;
    local change, jump = nil, nil;
    for i, q in ipairs(state.queue) do
        local r = q.r;
        imgui.PushStyleColor(flag('ImGuiCol_Text'), status_color(r));
        imgui.Bullet();
        imgui.PopStyleColor(1);
        imgui.SameLine();
        local name_w = right - controls_w - 30;
        if imgui.Selectable(string.format('%s##q%d', short_name(r.name, name_w), r.id), false, 0, { name_w, 0 }) then jump = r; end
        imgui.SameLine(right - controls_w);
        if imgui.SmallButton('-##qm' .. r.id) then change = { i, q.n - 1 }; end
        imgui.SameLine();
        imgui.Text(string.format('x%d', q.n));
        imgui.SameLine();
        if imgui.SmallButton('+##qp' .. r.id) then change = { i, q.n + 1 }; end
        imgui.SameLine();
        if imgui.SmallButton('x##qx' .. r.id) then change = { i, 0 }; end
    end
    imgui.EndChild();

    if change ~= nil then queue_set(change[1], change[2]); end
    if jump ~= nil then
        state.tab = 1;
        state.search[1] = jump.name;
        state.selected = jump;
        state.dirty = true;
    end

    imgui.Separator();
    local synths = 0;
    for _, q in ipairs(state.queue) do synths = synths + q.n; end
    imgui.TextColored(COLOR.dim, string.format('%d recipes, %d synths', #state.queue, synths));
    if imgui.SmallButton('Clear queue##qclear') then
        state.queue = {};
        save_queue();
    end
end

local function draw_queue_detail(dw)
    font_scale(1.45);
    imgui.TextColored(COLOR.head, 'Shopping list');
    font_scale(1.0);

    if #state.queue == 0 then
        imgui.TextColored(COLOR.dim, 'Add recipes to your queue and this shows');
        imgui.TextColored(COLOR.dim, 'everything you need for all of them together.');
        return;
    end

    local rows, crystals, synths, short_kinds, fetch_kinds = queue_totals();
    if short_kinds > 0 then
        imgui.TextColored(COLOR.missing, string.format('Short of %d ingredient(s) for %d synth(s).', short_kinds, synths));
    elseif fetch_kinds > 0 then
        imgui.TextColored(COLOR.fetch, string.format('You own everything for %d synth(s), some is in other bags.', synths));
    else
        imgui.TextColored(COLOR.ready, string.format('Everything for %d synth(s) is in your Inventory.', synths));
    end

    -- Columns
    local need_x = math.floor(dw * 0.42);
    local have_x = need_x + imgui.CalcTextSize('Need') + 24;
    local where_x = have_x + imgui.CalcTextSize('Have') + 24;
    imgui.TextColored(COLOR.head, 'ITEM');
    imgui.SameLine(need_x); imgui.TextColored(COLOR.head, 'NEED');
    imgui.SameLine(have_x); imgui.TextColored(COLOR.head, 'HAVE');
    imgui.SameLine(where_x); imgui.TextColored(COLOR.head, 'WHERE');

    for _, row in ipairs(rows) do
        local c = (row.status == 3 and COLOR.missing) or (row.status == 2 and COLOR.fetch) or COLOR.ready;
        imgui.TextColored(c, short_name(row.name, need_x - 20));
        imgui.SameLine(need_x); imgui.Text(tostring(row.need));
        imgui.SameLine(have_x); imgui.TextColored(c, tostring(row.total));
        imgui.SameLine(where_x);
        if row.status == 3 then
            imgui.TextColored(COLOR.missing, string.format('short %d', row.need - row.total));
        else
            imgui.TextColored(COLOR.dim, short_name(where_text(row.id), dw - where_x - 16));
        end
    end
    if #crystals > 0 then
        imgui.PushStyleColor(flag('ImGuiCol_Text'), COLOR.dim);
        imgui.TextWrapped('Crystals (not counted): ' .. table.concat(crystals, ', '));
        imgui.PopStyleColor(1);
    end

    -- What to do for the whole queue.
    imgui.Separator();
    imgui.TextColored(COLOR.head, 'TO DO');
    local any = false;
    for _, row in ipairs(rows) do
        if row.status == 3 then
            any = true;
            local text = string.format('Get %d more %s', row.need - row.total, row.name);
            local best = best_maker(row.id);
            if best ~= nil then text = text .. string.format(' (craftable: %s %d)', CRAFT_SHORT[best.craft], best.level); end
            imgui.PushStyleColor(flag('ImGuiCol_Text'), COLOR.missing);
            imgui.TextWrapped(text);
            imgui.PopStyleColor(1);
        end
        -- Move what you do own into the Inventory.
        local want = math.min(row.need, row.total) - row.inbag;
        if want > 0 then
            local h = have[row.id];
            for _, bag in ipairs(BAGS) do
                local cnt = (bag.id ~= 0) and h.bags[bag.id] or nil;
                if cnt ~= nil and want > 0 then
                    local take = math.min(want, cnt);
                    any = true;
                    imgui.PushStyleColor(flag('ImGuiCol_Text'), COLOR.fetch);
                    imgui.TextWrapped(string.format('Move %d %s from %s', take, row.name, bag.name));
                    imgui.PopStyleColor(1);
                    want = want - take;
                end
            end
        end
    end
    if not any then
        imgui.TextColored(COLOR.ready, 'Everything is in your Inventory - start synthing!');
    end
end

----------------------------------------------------------------------------------------------------
-- Settings tab
----------------------------------------------------------------------------------------------------

local function draw_settings(dw)
    local changed, c = false, false;

    imgui.TextColored(COLOR.head, 'RECIPES');
    cfg.desynth, c = checkbox('Show desynthesis recipes', cfg.desynth); changed = changed or c;
    cfg.hide_no_ki, c = checkbox('Hide recipes needing a key item I lack', cfg.hide_no_ki); changed = changed or c;
    cfg.skill_limit, c = checkbox('Hide recipes too far above my skill', cfg.skill_limit); changed = changed or c;
    if cfg.skill_limit then
        local t = { cfg.skill_margin };
        imgui.PushItemWidth(120);
        imgui.SliderInt('levels above my skill allowed', t, 0, 30);
        imgui.PopItemWidth();
        if t[1] ~= cfg.skill_margin then cfg.skill_margin = t[1]; changed = true; end
    end

    imgui.Separator();
    imgui.TextColored(COLOR.head, 'EXPANSIONS TO INCLUDE');
    for i, era in ipairs(ERAS) do
        cfg.eras[era.key], c = checkbox(era.name, cfg.eras[era.key]); changed = changed or c;
        if i % 2 == 1 and i ~= #ERAS then imgui.SameLine(math.floor(dw / 2)); end
    end

    imgui.Separator();
    imgui.TextColored(COLOR.head, 'BAGS TO SEARCH');
    local rescan = false;
    for i, bag in ipairs(BAGS) do
        local key = 'b' .. bag.id;
        cfg.bags[key], c = checkbox(bag.name, cfg.bags[key] ~= false);
        if c then changed = true; rescan = true; end
        if i % 3 ~= 0 and i ~= #BAGS then imgui.SameLine(math.floor((i % 3) * dw / 3) + 8); end
    end

    if changed then
        save();
        state.dirty = true;
        state.items_dirty = true;
    end
    if rescan then refresh(); end
end

----------------------------------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------------------------------
local function apply_settings(s)
    if s ~= nil then cfg = s; end
    -- Fill in anything missing from older settings files.
    cfg.bags = cfg.bags or T{};
    cfg.eras = cfg.eras or T{};
    cfg.open_crafts = cfg.open_crafts or T{};
    for k, v in pairs(default_settings.eras) do
        if cfg.eras[k] == nil then cfg.eras[k] = v; end
    end
    if type(cfg.show_mode) ~= 'number' or cfg.show_mode < 1 or cfg.show_mode > #SHOW_MODES then cfg.show_mode = 2; end
    if type(cfg.craft) ~= 'number' or cfg.craft < 0 or cfg.craft > 8 then cfg.craft = 0; end
    if type(cfg.level) ~= 'number' or cfg.level < 0 or cfg.level > #LEVELS then cfg.level = 0; end
    if type(cfg.skill_margin) ~= 'number' then cfg.skill_margin = 10; end
    if type(cfg.queue) ~= 'string' then cfg.queue = ''; end
    if #recipes > 0 then load_queue(); end
    state.dirty = true;
    state.items_dirty = true;
    state.last_scan = -100;
end

----------------------------------------------------------------------------------------------------
-- omni: drawn inside Character > Crafts
----------------------------------------------------------------------------------------------------
local loaded = false;
local function ensure_loaded()
    if loaded then return; end
    loaded = true;
    apply_settings(settings.load(default_settings, 'omni_craftbook'));
    settings.register('omni_craftbook', 'omni_craftbook_update', function (s) apply_settings(s); end);
    load_recipes();
    load_queue();
end

local TABS = { 'Recipes', 'Queue', 'Items', 'Settings' };

local function draw_header(w)
    for i, name in ipairs(TABS) do
        if i > 1 then imgui.SameLine(0, 4); end
        local on = (state.tab == i);
        imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
        imgui.PushStyleColor(ImGuiCol_Text, on and { 1, 0.96, 0.85, 1 } or COLOR.dim);
        local label = name;
        if i == 2 and #state.queue > 0 then label = string.format('Queue %d', #state.queue); end
        if imgui.Button(label .. '###cbtab' .. i, { math.floor((w - 24 - 12) / 4), 0 }) then state.tab = i; end
        imgui.PopStyleColor(2);
    end
    imgui.Dummy({ 1, 2 });
end

cb.height = 540;

-- Draws the whole Craftbook at the cursor, `height` pixels tall, filling the width.
cb.render = function (height)
    ensure_loaded();
    height = height or cb.height;

    local now = os.clock();
    if now - state.last_scan >= 2 then
        state.last_scan = now;
        refresh();
    end

    local avail = math.floor(imgui.GetContentRegionAvail());
    local leftW = math.max(300, math.floor(avail * 0.40));

    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.07, 0.08, 0.13, 0.70 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.90, 0.78, 0.40, 0.22 });
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, 6);
    imgui.PushStyleColor(ImGuiCol_Header, { 0.90, 0.78, 0.40, 0.20 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.90, 0.78, 0.40, 0.12 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.90, 0.78, 0.40, 0.28 });

    -- Left: tabs, filters and the list.
    imgui.BeginChild('##cb_left', { leftW, height }, true);
    local lw = math.floor(imgui.GetContentRegionAvail()) + 16;
    draw_header(lw);
    if state.tab == 2 then
        draw_queue_list(lw);
    elseif state.tab == 3 then
        draw_item_list(lw);
    elseif state.tab == 4 then
        imgui.TextColored(COLOR.dim, 'Settings are on the right.');
    else
        draw_recipe_list(lw);
    end
    imgui.EndChild();

    imgui.SameLine(0, 10);

    -- Right: details for whatever is picked on the left.
    imgui.BeginChild('##cb_right', { 0, height }, true);
    local dw = math.floor(imgui.GetContentRegionAvail()) + 8;
    if state.tab == 2 then
        draw_queue_detail(dw);
    elseif state.tab == 3 then
        draw_item_detail(dw);
    elseif state.tab == 4 then
        draw_settings(dw);
    elseif state.selected ~= nil then
        draw_recipe_detail(state.selected, dw);
    else
        imgui.TextColored(COLOR.dim, 'Pick a recipe on the left,');
        imgui.TextColored(COLOR.dim, 'or type what you want to make in the search box.');
        imgui.TextColored(COLOR.dim, 'Open a craft with [+] to see its recipes.');
        imgui.Dummy({ 1, 8 });
        imgui.TextColored(COLOR.ready, 'Green');
        imgui.SameLine(0, 6); imgui.TextColored(COLOR.dim, 'everything is in your Inventory - ready to synth');
        imgui.TextColored(COLOR.fetch, 'Yellow');
        imgui.SameLine(0, 6); imgui.TextColored(COLOR.dim, 'you own it all, some is in another bag');
        imgui.TextColored(COLOR.missing, 'Red');
        imgui.SameLine(0, 6); imgui.TextColored(COLOR.dim, 'something is missing ("need 2" = two short)');
    end
    imgui.EndChild();

    imgui.PopStyleColor(3);
    imgui.PopStyleVar(1);
    imgui.PopStyleColor(2);
end

return cb;
