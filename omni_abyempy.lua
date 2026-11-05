--[[
    omni_abyempy.lua - "Empyrean" page of omni's Abyssea tab: Empyrean armor for all 20 jobs.

    Pick a job (it starts on your main job). For each piece: what you have (none / NQ / +1 / +2,
    from all your bags), the next step and how far along it is (seals or +2 materials counted
    from your bags), and where the base piece comes from. Hover a step for the Abyssea NMs that
    drop that seal or material. "Where to farm" lists those NMs by zone for the job's set.

    Upgrades are Magian trials at the Magian Moogle with the blue puffball:
        base -> +1   trade 8 of the piece's seal (10 for the body)
        +1   -> +2   trade 6 of a stone / jewel / card / coin (9 for the body)

    Data: abydata/empy_data.lua (LandSandBoat server data + bg-wiki, see that file).
]]

local imgui = require('imgui');

local empy = {};

local data = require('abydata.empy_data');

local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD',
               'RNG', 'SAM', 'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH' };

local C = {
    gold = { 0.90, 0.78, 0.40, 1.0 }, text = { 0.92, 0.92, 0.95, 1.0 }, dim = { 0.62, 0.66, 0.80, 1.0 },
    faint = { 0.42, 0.44, 0.52, 1.0 }, green = { 0.45, 0.88, 0.45, 1.0 }, blue = { 0.45, 0.70, 1.00, 1.0 },
    yellow = { 1.00, 0.88, 0.35, 1.0 }, purple = { 0.78, 0.60, 1.00, 1.0 },
};
local TIER_COL = { [0] = C.faint, [1] = C.text, [2] = C.blue, [3] = C.purple };
local TIER_TXT = { [0] = 'none', [1] = 'NQ', [2] = '+1', [3] = '+2' };

local st = { job = nil, auto = true, view = 'set', search = { '' } };

-- Item names from the game (cached).
local names = {};
local function iname(id)
    if names[id] == nil then
        local n = nil;
        pcall(function () local r = AshitaCore:GetResourceManager():GetItemById(id); n = r and r.Name and r.Name[1]; end);
        names[id] = (type(n) == 'string' and n ~= '') and n or ('item ' .. id);
    end
    return names[id];
end

-- Counts of every item in every bag, refreshed every few seconds.
local counts, counted_at = {}, -100;
local function recount()
    if os.clock() - counted_at < 3 then return; end
    counted_at = os.clock();
    local c = {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for bag = 0, 16 do
            local max = 0;
            pcall(function () max = inv:GetContainerCountMax(bag) or 0; end);
            for slot = 1, max do
                local it = inv:GetContainerItem(bag, slot);
                if it ~= nil and it.Id ~= nil and it.Id ~= 0 and it.Id ~= 65535 then
                    c[it.Id] = (c[it.Id] or 0) + (tonumber(it.Count) or 1);
                end
            end
        end
    end);
    counts = c;
end
local function have(id) return counts[id] or 0; end

local function tier(p)
    if have(p.p2) > 0 then return 3; end
    if have(p.p1) > 0 then return 2; end
    if have(p.nq) > 0 then return 1; end
    return 0;
end

local function main_job()
    local j = 0;
    pcall(function () j = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob() or 0; end);
    return JOBS[j];
end

local function set_of(job)
    for _, s in ipairs(data.sets) do if s.job == job then return s; end end
    return nil;
end

local function sources_tip(id, title)
    local lines = { title };
    local list = data.sources[id] or {};
    if #list == 0 then lines[#lines + 1] = '(no Abyssea NM drop in the server data)'; end
    for _, s in ipairs(list) do
        lines[#lines + 1] = ('  %s  (%s) - %s'):format(s.nm, s.zone, s.how);
    end
    imgui.SetTooltip(table.concat(lines, '\n'));
end

local function job_button(job, on, done)
    imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Text, on and { 1, 0.96, 0.85, 1 } or (done > 0 and C.text or C.dim));
    local clicked = imgui.Button(job .. '##empj_' .. job, { 44, 0 });
    imgui.PopStyleColor(2);
    return clicked;
end

local function render_set(s, W)
    -- Columns: piece | have | next step | progress | base comes from
    local cx = imgui.GetCursorPosX();
    local c2, c3, c4, c5 = cx + 230, cx + 280, cx + 560, cx + 640;
    imgui.TextColored(C.dim, 'Piece');
    imgui.SameLine(c2); imgui.TextColored(C.dim, 'Have');
    imgui.SameLine(c3); imgui.TextColored(C.dim, 'Next step');
    imgui.SameLine(c4); imgui.TextColored(C.dim, 'Bags');
    imgui.SameLine(c5); imgui.TextColored(C.dim, 'Base piece from');
    imgui.Separator();
    local done = 0;
    for i, p in ipairs(s.pieces) do
        local t = tier(p);
        if t == 3 then done = done + 1; end
        local shown = (t == 3) and p.p2 or ((t == 2) and p.p1 or p.nq);
        imgui.TextColored(C.dim, p.slot);
        imgui.SameLine(cx + 52);
        imgui.TextColored(TIER_COL[t], iname(shown));
        imgui.SameLine(c2);
        imgui.TextColored(TIER_COL[t], TIER_TXT[t]);
        imgui.SameLine(c3);
        if t == 3 then
            imgui.TextColored(C.green, 'Done');
        elseif t == 0 then
            imgui.TextColored(C.text, 'Get the base piece');
            if imgui.IsItemHovered() then imgui.SetTooltip(iname(p.nq) .. '\n' .. p.base); end
        else
            local id, need = p.seal, p.seal_n;
            local what = '+1';
            if t == 2 then id, need, what = p.mat, p.mat_n, '+2'; end
            local got = have(id);
            imgui.TextColored(got >= need and C.green or C.text, ('%s: %s x%d'):format(what, iname(id), need));
            if imgui.IsItemHovered() then
                sources_tip(id, ('%s  (you have %d of %d)\nTrade with the %s to the Magian Moogle (blue puffball).\nDropped by:'):format(
                    iname(id), got, need, iname(shown)));
            end
            imgui.SameLine(c4);
            imgui.TextColored(got >= need and C.green or (got > 0 and C.yellow or C.faint), ('%d / %d'):format(got, need));
        end
        imgui.SameLine(c5);
        imgui.TextColored(C.faint, p.base);
    end
    imgui.Separator();
    imgui.TextColored(done == 5 and C.green or C.dim, ('%d of 5 pieces at +2.'):format(done));
end

-- Every NM that drops a seal or +2 material this set still needs, by zone.
local function render_farm(s)
    local by_zone, order = {}, {};
    for _, p in ipairs(s.pieces) do
        local t = tier(p);
        local needs = {};
        if t <= 1 then needs[#needs + 1] = { p.seal, p.seal_n }; end
        if t <= 2 then needs[#needs + 1] = { p.mat, p.mat_n }; end
        for _, n in ipairs(needs) do
            if have(n[1]) < n[2] then
                for _, src in ipairs(data.sources[n[1]] or {}) do
                    local z = by_zone[src.zone];
                    if z == nil then z = { nms = {}, list = {} }; by_zone[src.zone] = z; order[#order + 1] = src.zone; end
                    local e = z.nms[src.nm];
                    if e == nil then e = { nm = src.nm, items = {} }; z.nms[src.nm] = e; z.list[#z.list + 1] = e; end
                    e.items[#e.items + 1] = ('%s (%d/%d)'):format(iname(n[1]), have(n[1]), n[2]);
                end
            end
        end
    end
    table.sort(order);
    if #order == 0 then imgui.TextColored(C.green, 'Nothing left to farm for this set.'); return; end
    imgui.TextColored(C.dim, 'Abyssea NMs that drop what this set still needs:');
    for _, zn in ipairs(order) do
        imgui.Spacing();
        imgui.TextColored(C.gold, 'Abyssea - ' .. zn);
        local z = by_zone[zn];
        table.sort(z.list, function (a, b) return #a.items > #b.items; end);
        for _, e in ipairs(z.list) do
            imgui.TextColored(C.text, '  ' .. e.nm);
            imgui.SameLine(0, 10);
            imgui.TextColored(C.faint, table.concat(e.items, ', '));
        end
    end
end

local function find_items(text)
    local out = {};
    local words = {};
    for w in (text or ''):lower():gmatch('%S+') do if #w >= 2 then words[#words + 1] = w; end end
    if #words == 0 then return out; end
    local seen = {};
    for _, s in ipairs(data.sets) do
        for _, p in ipairs(s.pieces) do
            for _, id in ipairs({ p.nq, p.p1, p.p2, p.seal, p.mat }) do
                local n = iname(id):lower();
                local ok = true;
                for _, w in ipairs(words) do if not n:find(w, 1, true) then ok = false; break; end end
                local key = s.job .. ':' .. id;
                if ok and not seen[key] then seen[key] = true; out[#out + 1] = { job = s.job, slot = p.slot, id = id }; end
            end
        end
    end
    return out;
end

empy.render = function (opts)
    recount();
    local W = math.floor(imgui.GetContentRegionAvail());
    if st.auto or st.job == nil then st.job = main_job() or st.job or 'WAR'; end

    for i, j in ipairs(JOBS) do
        if i > 1 and (i - 1) % 10 ~= 0 then imgui.SameLine(0, 3); end
        local s = set_of(j);
        local plus2 = 0;
        if s then for _, p in ipairs(s.pieces) do if tier(p) == 3 then plus2 = plus2 + 1; end end end
        if job_button(j, st.job == j, plus2) then st.job = j; st.auto = (j == main_job()); end
        if imgui.IsItemHovered() then imgui.SetTooltip(('%s: %d of 5 at +2%s'):format(j, plus2, (j == main_job()) and ' (your main job)' or '')); end
    end
    local follow = { st.auto };
    if imgui.Checkbox('Follow my main job##empy_auto', follow) then st.auto = follow[1]; end
    imgui.SameLine(0, 20);
    if imgui.RadioButton('Set##empy_vset', st.view == 'set') then st.view = 'set'; end
    imgui.SameLine(0, 10);
    if imgui.RadioButton('Where to farm##empy_vfarm', st.view == 'farm') then st.view = 'farm'; end
    imgui.SameLine(0, 20);
    imgui.PushItemWidth(220);
    imgui.InputTextWithHint('##empy_search', 'Search pieces, seals, stones', st.search, 64);
    imgui.PopItemWidth();
    if st.search[1] ~= '' then
        imgui.SameLine(0, 4);
        if imgui.SmallButton('x##empy_clear') then st.search[1] = ''; end
    end
    imgui.Separator();

    if st.search[1] ~= '' then
        local hits = find_items(st.search[1]);
        if #hits == 0 then imgui.TextColored(C.faint, 'Nothing matches.'); end
        for i, h in ipairs(hits) do
            if i > 40 then imgui.TextColored(C.faint, ('...and %d more - type more of the name.'):format(#hits - 40)); break; end
            if imgui.Selectable(('%s  -  %s %s  (you have %d)##empy_hit%d'):format(iname(h.id), h.job, h.slot, have(h.id), i), false) then
                st.job, st.auto, st.view, st.search[1] = h.job, false, 'set', '';
            end
            if imgui.IsItemHovered() and data.sources[h.id] then sources_tip(h.id, iname(h.id) .. '  -  click to open ' .. h.job .. '\nDropped by:'); end
        end
        return;
    end

    local s = set_of(st.job);
    if s == nil then imgui.TextColored(C.faint, 'No Empyrean armor for ' .. tostring(st.job) .. '.'); return; end
    if st.view == 'farm' then render_farm(s); else render_set(s, W); end
end

-- For other pages: pieces / seals / materials whose name matches.
empy.find = find_items;

return empy;
