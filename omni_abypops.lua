--[[
    omni_abypops.lua - NM Pops page of omni's Abyssea tab.

    Every NM in the nine Abyssea zones with what pops it, whether you have it (items in
    any bag, key items) and where each piece comes from, following the chain up from the
    first pop. Opens on the zone you are in.

    NM / pop / drop data: "Abyssea Tracker - CatsEyeXI Edition" by IntegReady
    (abydata/abyssea_data.lua, abydata/catseye_drops.lua), used with thanks.
]]

local imgui = require('imgui');
local bit = require('bit');

local pops = {};

local data = require('abydata.abyssea_data');
local okd, drops = pcall(require, 'abydata.catseye_drops');
if not okd or type(drops) ~= 'table' then drops = { zones = {} }; end

-- Game zone id -> index in data.zones (by short name).
local ZONE_IDS = { [132] = 'La Theine', [15] = 'Konschtat', [45] = 'Tahrongi', [215] = 'Attohwa', [216] = 'Misareaux',
    [217] = 'Vunkerl', [218] = 'Altepa', [253] = 'Uleguerand', [254] = 'Grauberg' };

local CONTAINERS = {
    { 0, 'Inventory' }, { 1, 'Safe' }, { 2, 'Storage' }, { 4, 'Locker' }, { 5, 'Satchel' }, { 6, 'Sack' },
    { 7, 'Case' }, { 8, 'Wardrobe' }, { 9, 'Safe 2' }, { 10, 'Wardrobe 2' }, { 11, 'Wardrobe 3' },
    { 12, 'Wardrobe 4' }, { 13, 'Wardrobe 5' }, { 14, 'Wardrobe 6' }, { 15, 'Wardrobe 7' }, { 16, 'Wardrobe 8' },
};

local C = {
    gold = { 0.90, 0.78, 0.40, 1.0 }, text = { 0.92, 0.92, 0.95, 1.0 }, dim = { 0.62, 0.66, 0.80, 1.0 },
    faint = { 0.42, 0.44, 0.52, 1.0 }, green = { 0.45, 0.88, 0.45, 1.0 }, red = { 1.00, 0.45, 0.45, 1.0 },
    blue = { 0.45, 0.70, 1.00, 1.0 }, yellow = { 1.00, 0.88, 0.35, 1.0 }, panel = { 0.07, 0.08, 0.13, 0.70 },
    link = { 0.60, 0.80, 1.00, 1.0 },
};

local function norm(s) return (tostring(s or ''):lower():gsub('[^%w]', '')); end

-- 'Tr. Insect Wing' matches 'Transparent Insect Wing': each word may be a prefix of the other.
local function name_matches(a, b)
    if a == nil or b == nil or a == '' or b == '' then return false; end
    if norm(a) == norm(b) then return true; end
    local x, y = {}, {};
    for t in a:lower():gmatch('[%w]+') do x[#x + 1] = t; end
    for t in b:lower():gmatch('[%w]+') do y[#y + 1] = t; end
    if #x ~= #y or #x == 0 then return false; end
    for i = 1, #x do
        local p, q = x[i], y[i];
        if #p > #q then p, q = q, p; end
        if q:sub(1, #p) ~= p then return false; end
    end
    return true;
end

----------------------------------------------------------------------------------------------------
-- What we watch: pop items and key items (needed or given by an NM).
----------------------------------------------------------------------------------------------------
local want_items, want_kis = {}, {};     -- norm(name) -> name
for _, z in ipairs(data.zones) do
    for _, nm in ipairs(z.nms) do
        for _, r in ipairs(nm.requirements or {}) do
            if r.type == 'item' then want_items[norm(r.name)] = r.name; else want_kis[norm(r.name)] = r.name; end
        end
        for _, r in ipairs(nm.rewards or {}) do
            if r.type == 'ki' then want_kis[norm(r.name)] = r.name; end
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Key items: name -> ids, then owned from the Key Item Log packet (0x055), chat, or memory.
----------------------------------------------------------------------------------------------------
local ki_ids = nil;        -- norm(name) -> { id, ... }
local ki_pages = {};       -- page -> true once a 0x055 for it was seen
local ki_bits = {};        -- id -> true (from 0x055)
local ki_live = {};        -- id -> true/false from "Obtained / Lost key item" chat lines
local ki_saved = {};       -- id -> true, last known from a previous session
local owner = nil;

local function build_ki_ids()
    ki_ids = {};
    local all = {};
    pcall(function ()
        local rm = AshitaCore:GetResourceManager();
        for id = 0, 65535 do
            local n = rm:GetString('keyitems.names', id);
            if n and #n > 1 then all[#all + 1] = { id, n }; end
        end
    end);
    for key, name in pairs(want_kis) do
        local ids = {};
        for _, e in ipairs(all) do if norm(e[2]) == key then ids[#ids + 1] = e[1]; end end
        if #ids == 0 then
            for _, e in ipairs(all) do if name_matches(name, e[2]) then ids[#ids + 1] = e[1]; end end
        end
        ki_ids[key] = ids;
    end
end

local function my_name()
    local n = nil;
    pcall(function () n = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
    if n == nil or n == '' then return nil; end
    return n;
end

local function save_path(name)
    local dir = string.format('%s\\config\\addons\\omni\\', AshitaCore:GetInstallPath());
    for _, fn in ipairs({ 'create_dir', 'create_directory' }) do
        if ashita and ashita.fs and ashita.fs[fn] then pcall(ashita.fs[fn], dir); end
    end
    return dir .. 'abypops_' .. name .. '.lua';
end

local function load_saved()
    local name = my_name();
    if name == nil or name == owner then return; end
    owner, ki_saved, ki_pages, ki_bits, ki_live = name, {}, {}, {}, {};
    pcall(function ()
        local fn = loadfile(save_path(name));
        if fn == nil then return; end
        local t = fn();
        if type(t) == 'table' then for _, id in ipairs(t) do ki_saved[id] = true; end end
    end);
    -- Also take what the Abyssea Tracker addon saw last time it ran (its saved key item list),
    -- so key items show straight away without having to change zone first.
    pcall(function ()
        local sid = 0;
        pcall(function () sid = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0); end);
        local base = string.format('%s\\config\\addons\\abyssea\\', AshitaCore:GetInstallPath());
        for _, folder in ipairs({ name .. '_' .. tostring(sid), 'defaults' }) do
            local fn = loadfile(base .. folder .. '\\settings.lua');
            if fn ~= nil then
                local ok, t = pcall(fn);
                local c = ok and type(t) == 'table' and t.characters and t.characters[name:lower()];
                if c and type(c.keyitems) == 'table' then
                    for k, v in pairs(c.keyitems) do
                        if v == true and tonumber(k) then ki_saved[tonumber(k)] = true; end
                    end
                end
            end
        end
    end);
end

local dirty = false;
local function save_now()
    if owner == nil or ki_ids == nil then return; end
    dirty = false;
    pcall(function ()
        local out = {};
        for _, ids in pairs(ki_ids) do
            for _, id in ipairs(ids) do
                local have = ki_live[id];
                if have == nil then
                    local page = math.floor(id / 0x200);
                    if ki_pages[page] then have = ki_bits[id] == true; else have = ki_saved[id] == true; end
                end
                if have then out[#out + 1] = tostring(id); end
            end
        end
        local f = io.open(save_path(owner), 'w');
        if f then f:write('return {' .. table.concat(out, ',') .. '}'); f:close(); end
    end);
end

local function has_ki(name)
    if ki_ids == nil then build_ki_ids(); end
    local ids = ki_ids[norm(name)];
    if ids == nil or #ids == 0 then return false; end
    local player = nil;
    pcall(function () player = AshitaCore:GetMemoryManager():GetPlayer(); end);
    for _, id in ipairs(ids) do
        local live = ki_live[id];
        if live ~= nil then
            if live then return true; end
        else
            local page = math.floor(id / 0x200);
            if ki_pages[page] then
                if ki_bits[id] then return true; end
            else
                local mem = false;
                if player then pcall(function () mem = player:HasKeyItem(id) == true; end); end
                if mem or ki_saved[id] then return true; end
            end
        end
    end
    return false;
end

local function on_keyitem_log(d)
    if #d < 0x88 then return; end
    local a, b, c, e = d:byte(0x84 + 1, 0x87 + 1);
    local page = a + b * 256 + c * 65536 + e * 16777216;
    if page < 0 or page > 127 then return; end
    local first = page * 0x200;
    for id = first, first + 0x1FF do ki_bits[id] = nil; ki_live[id] = nil; end
    for i = 0, 0x3F do
        local v = d:byte(0x04 + i + 1) or 0;
        if v ~= 0 then
            for k = 0, 7 do
                if bit.band(v, bit.lshift(1, k)) ~= 0 then ki_bits[first + i * 8 + k] = true; end
            end
        end
    end
    ki_pages[page] = true;
    dirty = true;
end

-- "Obtained key item: X" / "Lost key item: X" (sometimes the name is on the next line).
local pending_ki, pending_until = nil, 0;
local function find_ki_in(text)
    local t = norm(text);
    local best, best_len = nil, 0;
    for key, _ in pairs(want_kis) do
        if #key >= 4 and #key > best_len and t:find(key, 1, true) then best, best_len = key, #key; end
    end
    return best;
end
local function set_live(key, owned)
    if ki_ids == nil then build_ki_ids(); end
    for _, id in ipairs(ki_ids[key] or {}) do ki_live[id] = owned; end
    dirty = true;
end
local function on_text(msg)
    if type(msg) ~= 'string' then return; end
    local text = msg:gsub('[\30\31].', '');
    local t = norm(text);
    local act = nil;
    if t:find('obtainedkeyitem', 1, true) or t:find('obtainedakeyitem', 1, true) then act = true;
    elseif t:find('lostkeyitem', 1, true) or t:find('lostakeyitem', 1, true) then act = false; end
    local key = find_ki_in(text);
    if act ~= nil and key then set_live(key, act); pending_ki = nil; return; end
    if act ~= nil then pending_ki, pending_until = act, os.clock() + 2; return; end
    if pending_ki ~= nil and key and os.clock() <= pending_until then set_live(key, pending_ki); pending_ki = nil; end
end

ashita.events.register('packet_in', 'omni_abypops_in', function (e)
    if e.id == 0x055 then pcall(load_saved); pcall(on_keyitem_log, e.data); end
end);
ashita.events.register('text_in', 'omni_abypops_text', function (e)
    pcall(on_text, e.message);
end);

----------------------------------------------------------------------------------------------------
-- Pop items: look through every bag (only the items you own are checked, every 2 seconds).
----------------------------------------------------------------------------------------------------
local item_match = {};     -- item id -> norm(name) of a pop item, or false
local items_owned = {};    -- norm(name) -> { count, where = { 'Satchel', ... } }
local last_scan = -10;

local function res_names(res)
    local out = {};
    local function add(v) if type(v) == 'string' and #v > 0 then out[#out + 1] = v; end end
    for _, f in ipairs({ 'Name', 'LogNameSingular' }) do
        local v = res[f];
        if type(v) == 'string' then add(v);
        elseif v ~= nil then pcall(function () add(v[0]); add(v[1]); add(v[2]); end); end
    end
    return out;
end

local function scan_items()
    if os.clock() - last_scan < 2 then return; end
    last_scan = os.clock();
    local owned = {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local rm = AshitaCore:GetResourceManager();
        for _, c in ipairs(CONTAINERS) do
            local max = inv:GetContainerCountMax(c[1]) or 0;
            for slot = 0, max do
                local it = inv:GetContainerItem(c[1], slot);
                if it ~= nil and it.Id ~= 0 and it.Id ~= 65535 then
                    local m = item_match[it.Id];
                    if m == nil then
                        m = false;
                        local res = rm:GetItemById(it.Id);
                        if res then
                            for _, n in ipairs(res_names(res)) do
                                if want_items[norm(n)] then m = norm(n); break; end
                            end
                        end
                        item_match[it.Id] = m;
                    end
                    if m then
                        local o = owned[m] or { count = 0, where = {} };
                        o.count = o.count + (it.Count or 1);
                        local seen = false;
                        for _, w in ipairs(o.where) do if w == c[2] then seen = true; end end
                        if not seen then o.where[#o.where + 1] = c[2]; end
                        owned[m] = o;
                    end
                end
            end
        end
    end);
    items_owned = owned;
end

local function req_have(r)
    if r.type == 'item' then return items_owned[norm(r.name)] ~= nil, items_owned[norm(r.name)]; end
    return has_ki(r.name), nil;
end

----------------------------------------------------------------------------------------------------
-- Page
----------------------------------------------------------------------------------------------------
local st = { zone = nil, nm = nil, filter = 'all', last_game_zone = -1 };

local function u32c(c) return imgui.GetColorU32(c); end

local function head_button(label, on)
    imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Text, on and { 1, 0.96, 0.85, 1 } or C.dim);
    local text = label:gsub('##.*$', '');
    local clicked = imgui.Button(label, { imgui.CalcTextSize(text) + 22, 0 });
    imgui.PopStyleColor(2);
    return clicked;
end

local function fit_text(text, width)
    text = tostring(text or '');
    if imgui.CalcTextSize(text) <= width then return text; end
    local n = #text;
    while n > 1 and imgui.CalcTextSize(text:sub(1, n) .. '...') > width do n = n - 1; end
    return text:sub(1, n) .. '...';
end

local function card_begin(id, w, h, title, right)
    imgui.PushStyleColor(ImGuiCol_ChildBg, C.panel);
    imgui.PushStyleColor(ImGuiCol_Border, { 0.90, 0.78, 0.40, 0.25 });
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, 6);
    imgui.BeginChild(id, { w, h }, true, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse));
    local inner = math.floor(imgui.GetContentRegionAvail());
    local x0 = imgui.GetCursorPosX();
    imgui.TextColored(C.gold, title);
    if right and right ~= '' then
        right = fit_text(right, inner - imgui.CalcTextSize(title) - 20);
        imgui.SameLine(x0 + inner - imgui.CalcTextSize(right));
        imgui.TextColored(C.dim, right);
    end
    local sx, sy = imgui.GetCursorScreenPos();
    imgui.GetWindowDrawList():AddLine({ sx, sy }, { sx + inner, sy }, u32c({ 0.90, 0.78, 0.40, 0.30 }), 1);
    imgui.Dummy({ 1, 3 });
    return inner, x0;
end
local function card_end()
    imgui.EndChild();
    imgui.PopStyleVar(1);
    imgui.PopStyleColor(2);
end

-- Tick (have it) or cross (missing), drawn at the cursor.
local function mark(have)
    local x, y = imgui.GetCursorScreenPos();
    local dl = imgui.GetWindowDrawList();
    if have then
        dl:AddLine({ x + 2, y + 8 }, { x + 5, y + 12 }, u32c(C.green), 2);
        dl:AddLine({ x + 5, y + 12 }, { x + 12, y + 3 }, u32c(C.green), 2);
    else
        dl:AddLine({ x + 3, y + 3 }, { x + 11, y + 11 }, u32c(C.red), 2);
        dl:AddLine({ x + 11, y + 3 }, { x + 3, y + 11 }, u32c(C.red), 2);
    end
end

-- How far along an NM is: have, need (need 0 = no pop, it spawns on its own).
local function progress(nm)
    local have, need = 0, #(nm.requirements or {});
    for _, r in ipairs(nm.requirements or {}) do if req_have(r) then have = have + 1; end end
    return have, need;
end

local function short_spawn(nm)
    local s = (nm.spawn_type or ''):lower();
    if s:find('roaming') then return 'Roams'; end
    if s:find('fished') then return 'Fished'; end
    if s:find('time of day') then return 'Time of day'; end
    if s:find('timed') then return 'Timed'; end
    return 'Special';
end

local function find_nm(zone, name)
    if name == nil then return nil; end
    for _, nm in ipairs(zone.nms) do if norm(nm.name) == norm(name) then return nm; end end
    return nil;
end

local function in_list(list, name)
    for _, n in ipairs(list or {}) do if norm(n) == norm(name) then return true; end end
    return false;
end

local function game_zone()
    local z = 0;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    return tonumber(z) or 0;
end

-- Text that is a link to another NM on this page (click to open it).
local function nm_link(zone, text, target_name, id)
    local target = find_nm(zone, target_name);
    if target == nil then imgui.TextColored(C.faint, text); return; end
    imgui.PushStyleColor(ImGuiCol_Text, C.link);
    if imgui.Selectable(text .. '##' .. id, false, 0, { imgui.CalcTextSize(text), 0 }) then st.nm = target.name; end
    imgui.PopStyleColor(1);
    if imgui.IsItemHovered() then imgui.SetTooltip('Open ' .. target.name); end
end

pops.render = function (opts)
    pcall(load_saved);
    if dirty then save_now(); end
    scan_items();

    -- Open on the zone you are in (and follow you when you change zone).
    local gz = game_zone();
    if gz ~= st.last_game_zone then
        st.last_game_zone = gz;
        local here = ZONE_IDS[gz];
        if here then
            for i, z in ipairs(data.zones) do if z.short_name == here then st.zone = i; st.nm = nil; end end
        end
    end
    st.zone = st.zone or 1;
    local zone = data.zones[st.zone];
    local W = math.floor(imgui.GetContentRegionAvail());

    -- Zone buttons (wrapping onto a second line if they don't fit).
    local x = 0;
    for i, z in ipairs(data.zones) do
        local label = z.short_name .. ((ZONE_IDS[gz] == z.short_name) and ' *' or '');
        local bw = imgui.CalcTextSize(label) + 22;
        if i > 1 then
            if x + 6 + bw <= W then imgui.SameLine(0, 6); x = x + 6; else x = 0; end
        end
        if head_button(label .. '##abyz' .. i, i == st.zone) then st.zone = i; st.nm = nil; end
        if imgui.IsItemHovered() then imgui.SetTooltip(z.name .. ' (' .. z.expansion .. ')' .. ((ZONE_IDS[gz] == z.short_name) and ' - you are here' or '')); end
        x = x + bw;
    end
    zone = data.zones[st.zone];

    -- Filter buttons, and how many are ready.
    local list = {};
    local ready = 0;
    for _, nm in ipairs(zone.nms) do
        local have, need = progress(nm);
        if need > 0 and have == need then ready = ready + 1; end
        local show = st.filter == 'all' or (st.filter == 'pop' and need > 0) or (st.filter == 'ready' and need > 0 and have == need);
        if show then list[#list + 1] = { nm = nm, have = have, need = need }; end
    end
    table.sort(list, function (a, b) return a.nm.name:lower() < b.nm.name:lower(); end);

    imgui.Dummy({ 1, 2 });
    for i, f in ipairs({ { 'all', 'All NMs' }, { 'pop', 'Need pops' }, { 'ready', 'Ready to pop' } }) do
        if i > 1 then imgui.SameLine(0, 6); end
        if head_button(f[2] .. '##abyf' .. i, st.filter == f[1]) then st.filter = f[1]; end
    end
    local note = string.format('%d ready to pop in %s', ready, zone.short_name);
    imgui.SameLine(W - imgui.CalcTextSize(note));
    imgui.TextColored(ready > 0 and C.green or C.faint, note);
    imgui.Dummy({ 1, 2 });

    -- NM grid: three columns, name on the left, how far along on the right.
    local cols = 3;
    local rows = math.max(1, math.ceil(#list / cols));
    local row_h = 20;
    local _, th = imgui.CalcTextSize('Ag');
    th = th or 14;
    local grid_h = math.floor(th + 8 + rows * row_h + 24);
    local inner, x0 = card_begin('##abypops_grid', W, grid_h, zone.name, #list .. ' NMs');
    local cw = math.floor((inner - (cols - 1) * 8) / cols);
    local y0 = imgui.GetCursorPosY();
    if #list == 0 then imgui.TextColored(C.faint, 'Nothing here yet - you have no NM ready to pop in this zone.'); end
    for i, e in ipairs(list) do
        local c = (i - 1) % cols;
        local r = math.floor((i - 1) / cols);
        local cx, cy = x0 + c * (cw + 8), y0 + r * row_h;
        imgui.SetCursorPos({ cx, cy });
        local sel = st.nm == e.nm.name;
        if imgui.Selectable('##abynm' .. i, sel, 0, { cw, row_h - 2 }) then st.nm = (sel and nil) or e.nm.name; end
        local status, scol;
        if e.need == 0 then status, scol = short_spawn(e.nm), C.faint;
        elseif e.have == e.need then status, scol = 'Ready', C.green;
        else status, scol = string.format('%d/%d', e.have, e.need), (e.have > 0 and C.yellow or C.dim); end
        local sw = imgui.CalcTextSize(status);
        imgui.SetCursorPos({ cx + 6, cy + 1 });
        imgui.TextColored((e.need > 0 and e.have == e.need) and C.green or C.text, fit_text(e.nm.name, cw - sw - 20));
        imgui.SetCursorPos({ cx + cw - sw - 6, cy + 1 });
        imgui.TextColored(scol, status);
    end
    card_end();

    -- The chosen NM: what pops it, where that comes from, what it gives, what it drops.
    local nm = find_nm(zone, st.nm);
    imgui.Dummy({ 1, 4 });
    if nm == nil then
        imgui.TextColored(C.faint, 'Click an NM to see what pops it and where each piece comes from.');
        return;
    end

    local zdrops = (drops.zones or {})[zone.short_name] or {};
    local nd = zdrops[nm.name] or {};
    local reqs, gives = nm.requirements or {}, nm.rewards or {};

    -- Work out the drop chips' lines first so the card can be the right height.
    local chip_lines = 0;
    local inner_guess = W - 18;
    if #nd > 0 then
        local lx = 0;
        chip_lines = 1;
        for _, d in ipairs(nd) do
            local w = imgui.CalcTextSize(d.name) + 18;
            if lx > 0 and lx + w > inner_guess - 60 then chip_lines = chip_lines + 1; lx = 0; end
            lx = lx + w;
        end
    end
    local line = th + 6;
    local h = th + 8                                      -- title
        + line                                            -- spawn line
        + ((#reqs > 0) and (line + #reqs * line) or 0)    -- To pop
        + ((#gives > 0) and (line + #gives * line) or 0)  -- Gives
        + ((#nd > 0) and (line + chip_lines * line) or 0) -- Drops
        + 24;

    local right = (nm.location or '') .. ((nm.respawn and nm.respawn ~= '') and ('   respawn ' .. nm.respawn) or '');
    inner, x0 = card_begin('##abypops_nm', W, math.floor(h), nm.name, right);
    imgui.TextColored(C.dim, nm.spawn_type or '');
    if nm.source_note then imgui.SameLine(0, 10); imgui.TextColored(C.faint, nm.source_note); end

    local col_name, col_from = x0 + 22, x0 + math.floor(inner * 0.42);
    if #reqs > 0 then
        imgui.TextColored(C.gold, 'To pop');
        for i, r in ipairs(reqs) do
            local have, info = req_have(r);
            local y = imgui.GetCursorPosY();
            imgui.SetCursorPos({ x0 + 2, y + 1 });
            mark(have);
            imgui.SetCursorPos({ col_name, y });
            imgui.TextColored(have and C.green or C.text, r.name);
            if r.type == 'ki' and imgui.IsItemHovered() then
                local ids = ki_ids and ki_ids[norm(r.name)] or {};
                if #ids == 0 then imgui.SetTooltip('This key item was not found in the game data.');
                elseif not have then imgui.SetTooltip(string.format('Key item %d. If you do have it, change zone once to refresh.', ids[1])); end
            end
            imgui.SameLine(0, 8);
            imgui.TextColored(C.faint, r.type == 'ki' and 'key item' or 'trade item');
            imgui.SetCursorPos({ col_from, y });
            if have and info then
                imgui.TextColored(C.green, string.format('x%d in %s', info.count or 1, table.concat(info.where, ', ')));
            elseif have then
                imgui.TextColored(C.green, 'You have it');
            else
                local src = r.source or '';
                imgui.TextColored(C.faint, 'from ');
                imgui.SameLine(0, 0);
                nm_link(zone, src, src, 'req' .. i);
                local pyx = (r.type == 'item' and in_list(zone.gold_pyxis_items, r.name)) or (r.type == 'ki' and in_list(zone.gold_pyxis_keyitems, r.name));
                if pyx then imgui.SameLine(0, 8); imgui.TextColored(C.yellow, 'or a gold Pyxis'); end
            end
            imgui.SetCursorPos({ x0, y + line });
        end
    end

    if #gives > 0 then
        imgui.TextColored(C.gold, 'Gives');
        for i, r in ipairs(gives) do
            local y = imgui.GetCursorPosY();
            local have = r.type == 'ki' and has_ki(r.name) or (items_owned[norm(r.name)] ~= nil);
            imgui.SetCursorPos({ x0 + 2, y + 1 });
            mark(have);
            imgui.SetCursorPos({ col_name, y });
            imgui.TextColored(have and C.green or C.text, r.name);
            imgui.SameLine(0, 8);
            imgui.TextColored(C.faint, r.type == 'ki' and 'key item' or 'item');
            if r.used_for then
                imgui.SetCursorPos({ col_from, y });
                imgui.TextColored(C.faint, 'pops ');
                imgui.SameLine(0, 0);
                nm_link(zone, r.used_for, r.used_for, 'give' .. i);
            end
            imgui.SetCursorPos({ x0, y + line });
        end
    end

    if #nd > 0 then
        imgui.TextColored(C.gold, 'Drops');
        imgui.SameLine(0, 10);
        imgui.TextColored(C.red, 'red'); imgui.SameLine(0, 6);
        imgui.TextColored(C.blue, 'blue'); imgui.SameLine(0, 6);
        imgui.TextColored(C.yellow, 'yellow'); imgui.SameLine(0, 6);
        imgui.TextColored(C.faint, '= proc needed');
        local lx = 0;
        local y = imgui.GetCursorPosY();
        for _, d in ipairs(nd) do
            local w = imgui.CalcTextSize(d.name) + 18;
            if lx > 0 and lx + w > inner - 60 then lx = 0; y = y + line; end
            imgui.SetCursorPos({ x0 + lx, y });
            local col = (d.proc == 'red' and C.red) or (d.proc == 'blue' and C.blue) or (d.proc == 'yellow' and C.yellow) or C.text;
            imgui.TextColored(col, d.name);
            if d.quantity and imgui.IsItemHovered() then imgui.SetTooltip(d.quantity); end
            lx = lx + w;
        end
    end
    card_end();
end

return pops;
