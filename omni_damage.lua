--[[
    omni_damage.lua - the Advanced page of omni's Damage tab.

    Reads every action packet (0x028) and keeps a detailed record for you, your party and
    alliance, and your pets: melee (main hand, off hand, kicks), ranged, each weapon skill,
    each spell, each job ability, skillchains, added effects, pet damage, healing done, and
    the damage you take (with evades, parries and shadows).

    The page shows everyone on the left (click a name) and that person's breakdown on the
    right. Written for omni; the layout ideas came from the "metrics" addon.
]]

local imgui = require('imgui');

local dmg = {};
dmg.height = 300;

----------------------------------------------------------------------------------------------------
-- Message ids
----------------------------------------------------------------------------------------------------
local function set(list) local t = {}; for _, v in ipairs(list) do t[v] = true; end return t; end

local MELEE_HIT    = set { 1 };
local MELEE_CRIT   = set { 67 };
local MELEE_MISS   = set { 15, 63 };
local PARRIED      = set { 70 };
local SHADOWS      = set { 31 };
local RANGED_HIT   = set { 352, 576, 577, 157 };
local RANGED_CRIT  = set { 353 };
local RANGED_MISS  = set { 354 };
local WS_HIT       = set { 185, 197 };
local WS_MISS      = set { 188 };
local SPELL_DMG    = set { 2, 264 };
local SPELL_BURST  = set { 252 };
local SPELL_RESIST = set { 85, 284 };
local JA_DMG       = set { 110, 317, 77 };
local HEAL         = set { 7, 263, 102, 103, 306, 318 };
local ADD_EFFECT   = set { 163, 229 };
local SKILLCHAIN   = set {
    288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302,
    385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398,
    732, 767, 768, 769, 770,
};

local IDLE = 8;   -- seconds without damage before the fight clock pauses

----------------------------------------------------------------------------------------------------
-- Records
----------------------------------------------------------------------------------------------------
local data = { people = {}, active = 0, last = nil };
local roster, pets, roster_at = {}, {}, -10;
local selected = nil;

local function stat() return { n = 0, dmg = 0, min = nil, max = 0 }; end
local function add_stat(t, v)
    t.n = t.n + 1;
    t.dmg = t.dmg + v;
    if t.min == nil or v < t.min then t.min = v; end
    if v > t.max then t.max = v; end
end

local function person(name)
    local p = data.people[name];
    if p == nil then
        p = {
            name = name, total = 0,
            melee = { hits = 0, crits = 0, miss = 0, dmg = 0, min = nil, max = 0, crit_max = 0,
                      rounds = 0, swings = 0, main = 0, off = 0, kick = 0 },
            ranged = { hits = 0, crits = 0, miss = 0, dmg = 0, min = nil, max = 0 },
            ws = {}, magic = {}, ja = {}, pet = { dmg = 0, moves = {} },
            sc = stat(), add = 0, heal = { total = 0, n = 0 },
            taken = { dmg = 0, hits = 0, evaded = 0, parried = 0, shadows = 0, spells = 0, tp = 0 },
            resists = 0,
        };
        data.people[name] = p;
    end
    return p;
end

local function named(list, name) list[name] = list[name] or { n = 0, dmg = 0, min = nil, max = 0, miss = 0, burst = 0 }; return list[name]; end

-- Who is in the party/alliance, and whose pet is whose (refreshed once a second).
local function refresh_roster()
    if os.clock() - roster_at < 1 then return; end
    roster_at = os.clock();
    roster, pets = {}, {};
    pcall(function ()
        local party = AshitaCore:GetMemoryManager():GetParty();
        for i = 0, 17 do
            if party:GetMemberIsActive(i) == 1 then
                local id, name = party:GetMemberServerId(i), party:GetMemberName(i);
                if id and id ~= 0 and name and name ~= '' then
                    roster[id] = name;
                    local ent = GetEntity(party:GetMemberTargetIndex(i));
                    local pidx = ent and ent.PetTargetIndex or 0;
                    if pidx and pidx > 0 then
                        local pet = GetEntity(pidx);
                        if pet and pet.ServerId and pet.ServerId ~= 0 then pets[pet.ServerId] = name; end
                    end
                end
            end
        end
    end);
end

local res_cache = {};
local function res_name(kind, id)
    local key = kind .. id;
    if res_cache[key] then return res_cache[key]; end
    local name = nil;
    pcall(function ()
        local res = AshitaCore:GetResourceManager();
        local r;
        if kind == 'spell' then r = res:GetSpellById(id);
        elseif kind == 'ws' then r = res:GetAbilityById(id);
        elseif kind == 'ja' then r = res:GetAbilityById(id + 512);
        elseif kind == 'abil' then r = res:GetAbilityById(id);
        end
        if r and r.Name then name = r.Name[1]; end
    end);
    if name == nil or name == '' then
        name = ({ spell = 'Spell #', ws = 'Weapon skill #', ja = 'Ability #', abil = 'Move #' })[kind] .. id;
    end
    res_cache[key] = name;
    return name;
end

local function tick_clock()
    local now = os.time();
    if data.last ~= nil then
        local gap = now - data.last;
        if gap > 0 and gap <= IDLE then data.active = data.active + gap; end
    end
    data.last = now;
end

-- Every action packet, already parsed by omni_action.parse.
dmg.on_action = function (act)
    refresh_roster();
    local cat = act.category;
    local me = roster[act.actor_id];
    local owner = pets[act.actor_id];
    local dealt = false;

    if me ~= nil then
        local p = person(me);
        for _, t in ipairs(act.targets) do
            local swings = 0;
            for _, a in ipairs(t.actions) do
                local m, v = a.message, a.param or 0;
                if cat == 1 then
                    if MELEE_HIT[m] or MELEE_CRIT[m] then
                        local ml = p.melee;
                        ml.hits = ml.hits + 1; ml.dmg = ml.dmg + v; swings = swings + 1;
                        if MELEE_CRIT[m] then ml.crits = ml.crits + 1; if v > ml.crit_max then ml.crit_max = v; end
                        else
                            if ml.min == nil or v < ml.min then ml.min = v; end
                            if v > ml.max then ml.max = v; end
                        end
                        local anim = a.animation or 0;
                        if anim == 1 then ml.off = ml.off + v; elseif anim == 2 or anim == 3 then ml.kick = ml.kick + v; else ml.main = ml.main + v; end
                        p.total = p.total + v; dealt = true;
                    elseif MELEE_MISS[m] or PARRIED[m] or SHADOWS[m] then
                        p.melee.miss = p.melee.miss + 1; swings = swings + 1; dealt = true;
                    end
                elseif cat == 2 then
                    local r = p.ranged;
                    if RANGED_HIT[m] or RANGED_CRIT[m] then
                        r.hits = r.hits + 1; r.dmg = r.dmg + v;
                        if RANGED_CRIT[m] then r.crits = r.crits + 1; end
                        if r.min == nil or v < r.min then r.min = v; end
                        if v > r.max then r.max = v; end
                        p.total = p.total + v; dealt = true;
                    elseif RANGED_MISS[m] or SHADOWS[m] then
                        r.miss = r.miss + 1; dealt = true;
                    end
                elseif cat == 3 then
                    local w = named(p.ws, res_name('ws', act.param));
                    if WS_HIT[m] then add_stat(w, v); p.total = p.total + v; dealt = true;
                    elseif WS_MISS[m] or SHADOWS[m] then w.miss = w.miss + 1; dealt = true; end
                elseif cat == 4 then
                    local sname = res_name('spell', act.param);
                    if SPELL_DMG[m] or SPELL_BURST[m] then
                        local s = named(p.magic, sname);
                        add_stat(s, v);
                        if SPELL_BURST[m] then s.burst = s.burst + 1; end
                        p.total = p.total + v; dealt = true;
                    elseif HEAL[m] then
                        p.heal.total = p.heal.total + v; p.heal.n = p.heal.n + 1;
                    elseif SPELL_RESIST[m] then
                        p.resists = p.resists + 1;
                    end
                elseif cat == 6 or cat == 14 or cat == 15 then
                    if JA_DMG[m] then
                        add_stat(named(p.ja, res_name('ja', act.param)), v);
                        p.total = p.total + v; dealt = true;
                    elseif HEAL[m] then
                        p.heal.total = p.heal.total + v; p.heal.n = p.heal.n + 1;
                    end
                end
                -- Skillchains and added effects ride on the same hit.
                if a.add ~= nil then
                    local am, av = a.add.message, a.add.param or 0;
                    if SKILLCHAIN[am] then add_stat(p.sc, av); p.total = p.total + av; dealt = true;
                    elseif ADD_EFFECT[am] then p.add = p.add + av; p.total = p.total + av; dealt = true; end
                end
            end
            if cat == 1 and swings > 0 then
                p.melee.rounds = p.melee.rounds + 1;
                p.melee.swings = p.melee.swings + swings;
            end
        end
    elseif owner ~= nil then
        -- A pet's damage counts towards its owner.
        local p = person(owner);
        for _, t in ipairs(act.targets) do
            for _, a in ipairs(t.actions) do
                local m, v = a.message, a.param or 0;
                local hit = MELEE_HIT[m] or MELEE_CRIT[m] or WS_HIT[m] or JA_DMG[m] or SPELL_DMG[m] or SPELL_BURST[m];
                if hit then
                    p.pet.dmg = p.pet.dmg + v;
                    p.total = p.total + v;
                    dealt = true;
                    if cat ~= 1 then
                        local mv = (cat == 4) and res_name('spell', act.param) or res_name('abil', act.param);
                        add_stat(named(p.pet.moves, mv), v);
                    end
                end
            end
        end
    else
        -- Something else acting on us: count it as damage taken.
        for _, t in ipairs(act.targets) do
            local victim = roster[t.id];
            if victim ~= nil then
                local p = person(victim);
                for _, a in ipairs(t.actions) do
                    local m, v = a.message, a.param or 0;
                    local tk = p.taken;
                    if cat == 1 then
                        if MELEE_HIT[m] or MELEE_CRIT[m] then tk.dmg = tk.dmg + v; tk.hits = tk.hits + 1;
                        elseif MELEE_MISS[m] then tk.evaded = tk.evaded + 1;
                        elseif PARRIED[m] then tk.parried = tk.parried + 1;
                        elseif SHADOWS[m] then tk.shadows = tk.shadows + 1; end
                    elseif cat == 4 and (SPELL_DMG[m] or SPELL_BURST[m]) then
                        tk.dmg = tk.dmg + v; tk.spells = tk.spells + v;
                    elseif (cat == 11 or cat == 3) and (WS_HIT[m] or MELEE_HIT[m]) then
                        tk.dmg = tk.dmg + v; tk.tp = tk.tp + v;
                    elseif SHADOWS[m] then
                        tk.shadows = tk.shadows + 1;
                    end
                end
            end
        end
    end

    if dealt then tick_clock(); end
end

dmg.reset = function ()
    data.people = {};
    data.active = 0;
    data.last = nil;
end

----------------------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------------------
local GOLD  = { 0.79, 0.69, 0.42, 1.0 };
local WHITE = { 1.00, 1.00, 1.00, 1.0 };
local DIM   = { 0.66, 0.68, 0.76, 1.0 };
local GREEN = { 0.45, 0.85, 0.45, 1.0 };
local RED   = { 0.95, 0.45, 0.45, 1.0 };
local PART_COLORS = {
    Melee = { 0.80, 0.32, 0.30, 1 }, Ranged = { 0.85, 0.60, 0.25, 1 }, ['Weapon skills'] = { 0.80, 0.70, 0.25, 1 },
    Magic = { 0.35, 0.55, 0.90, 1 }, Abilities = { 0.60, 0.42, 0.85, 1 }, Skillchains = { 0.30, 0.72, 0.72, 1 },
    ['Added effects'] = { 0.45, 0.75, 0.40, 1 }, Pet = { 0.75, 0.45, 0.65, 1 },
};
local PART_ORDER = { 'Melee', 'Ranged', 'Weapon skills', 'Magic', 'Abilities', 'Skillchains', 'Added effects', 'Pet' };

local function commas(n)
    local out = tostring(math.floor((n or 0) + 0.5)):reverse():gsub('(%d%d%d)', '%1,'):reverse();
    if out:sub(1, 1) == ',' then out = out:sub(2); end
    return out;
end
local function pct(a, b) if b == nil or b <= 0 then return '-'; end return string.format('%d%%', math.floor(a / b * 100 + 0.5)); end
local function u32(c) return imgui.GetColorU32(c); end

local function sum(list) local t = 0; for _, v in pairs(list) do t = t + v.dmg; end return t; end

local function parts(p)
    return {
        Melee = p.melee.dmg, Ranged = p.ranged.dmg, ['Weapon skills'] = sum(p.ws), Magic = sum(p.magic),
        Abilities = sum(p.ja), Skillchains = p.sc.dmg, ['Added effects'] = p.add, Pet = p.pet.dmg,
    };
end

-- Draw helpers work in window-local positions; `ctx` carries the draw list and origin.
local ctx = {};
local function text(x, y, col, s) ctx.dl:AddText({ ctx.wx + x, ctx.wy + y }, u32(col), s); end
local function rtext(x, y, col, s) text(x - imgui.CalcTextSize(s), y, col, s); end

-- A section heading with a thin line; returns the y below it.
local function heading(x, y, w, title, right)
    text(x, y, GOLD, title);
    if right then rtext(x + w, y, DIM, right); end
    ctx.dl:AddLine({ ctx.wx + x, ctx.wy + y + ctx.lh + 3 }, { ctx.wx + x + w, ctx.wy + y + ctx.lh + 3 }, u32({ 0.79, 0.69, 0.42, 0.35 }), 1);
    return y + ctx.lh + 9;
end

-- Label/value pairs laid out in `cols` columns.
local function stats(x, y, w, cols, list)
    local cw = math.floor(w / cols);
    for i, kv in ipairs(list) do
        local cx = x + ((i - 1) % cols) * cw;
        local cy = y + math.floor((i - 1) / cols) * (ctx.lh + 4);
        text(cx, cy, DIM, kv[1]);
        rtext(cx + cw - 12, cy, kv[3] or WHITE, kv[2]);
    end
    return y + math.ceil(#list / cols) * (ctx.lh + 4) + 6;
end

-- A table: headers, column right edges (first column is left-aligned), rows of strings.
local function tbl(x, y, w, headers, edges, rows, limit)
    for i, h in ipairs(headers) do
        if i == 1 then text(x, y, DIM, h); else rtext(x + edges[i], y, DIM, h); end
    end
    y = y + ctx.lh + 4;
    for r, row in ipairs(rows) do
        if limit and r > limit then
            text(x, y, DIM, string.format('... and %d more', #rows - limit));
            y = y + ctx.lh + 3;
            break;
        end
        if r % 2 == 0 then
            ctx.dl:AddRectFilled({ ctx.wx + x - 4, ctx.wy + y - 1 }, { ctx.wx + x + w, ctx.wy + y + ctx.lh + 1 }, u32({ 1, 1, 1, 0.04 }), 2);
        end
        for i, cell in ipairs(row) do
            if i == 1 then text(x, y, WHITE, cell); else rtext(x + edges[i], y, WHITE, cell); end
        end
        y = y + ctx.lh + 3;
    end
    return y + 6;
end

local function sorted_named(list)
    local rows = {};
    for name, s in pairs(list) do rows[#rows + 1] = { name = name, s = s }; end
    table.sort(rows, function (a, b) return a.s.dmg > b.s.dmg; end);
    return rows;
end

-- The right-hand breakdown for one person. Returns the bottom y.
local function detail(p, x, y, w, seconds, group_total)
    -- Overview.
    y = heading(x, y, w, p.name, string.format('%s damage', commas(p.total)));
    local ml, rg = p.melee, p.ranged;
    local hits, tries = ml.hits + rg.hits, ml.hits + ml.miss + rg.hits + rg.miss;
    local crits = ml.crits + rg.crits;
    y = stats(x, y, w, 3, {
        { 'Share', pct(p.total, group_total) },
        { 'DPS', commas(p.total / math.max(seconds, 1)) },
        { 'Accuracy', pct(hits, tries) },
        { 'Critical rate', pct(crits, hits) },
        { 'Healing done', commas(p.heal.total), GREEN },
        { 'Damage taken', commas(p.taken.dmg), RED },
    });

    -- Where the damage came from: one bar split into colours, with a key.
    local pt = parts(p);
    if p.total > 0 then
        local bx, bw, bh = x, w, 12;
        local cx = bx;
        for _, k in ipairs(PART_ORDER) do
            local v = pt[k];
            if v > 0 then
                local seg = bw * v / p.total;
                ctx.dl:AddRectFilled({ ctx.wx + cx, ctx.wy + y }, { ctx.wx + cx + seg, ctx.wy + y + bh }, u32(PART_COLORS[k]), 0);
                cx = cx + seg;
            end
        end
        y = y + bh + 6;
        local kx = x;
        for _, k in ipairs(PART_ORDER) do
            local v = pt[k];
            if v > 0 then
                local label = string.format('%s %s', k, pct(v, p.total));
                local lw = imgui.CalcTextSize(label) + 22;
                if kx + lw > x + w then kx = x; y = y + ctx.lh + 4; end
                ctx.dl:AddRectFilled({ ctx.wx + kx, ctx.wy + y + 3 }, { ctx.wx + kx + 10, ctx.wy + y + 13 }, u32(PART_COLORS[k]), 2);
                text(kx + 14, y, WHITE, label);
                kx = kx + lw;
            end
        end
        y = y + ctx.lh + 12;
    end

    -- Melee.
    if ml.hits + ml.miss > 0 then
        y = heading(x, y, w, 'Melee', commas(ml.dmg));
        local list = {
            { 'Accuracy', pct(ml.hits, ml.hits + ml.miss) },
            { 'Critical rate', pct(ml.crits, ml.hits) },
            { 'Average hit', commas(ml.dmg / math.max(ml.hits, 1)) },
            { 'Lowest / highest', string.format('%s / %s', commas(ml.min or 0), commas(ml.max)) },
            { 'Best critical', commas(ml.crit_max) },
            { 'Swings per round', ml.rounds > 0 and string.format('%.2f', ml.swings / ml.rounds) or '-' },
            { 'Main hand', commas(ml.main) },
        };
        if ml.off > 0 then list[#list + 1] = { 'Off hand', commas(ml.off) }; end
        if ml.kick > 0 then list[#list + 1] = { 'Kicks', commas(ml.kick) }; end
        y = stats(x, y, w, 3, list);
    end

    -- Ranged.
    if rg.hits + rg.miss > 0 then
        y = heading(x, y, w, 'Ranged', commas(rg.dmg));
        y = stats(x, y, w, 3, {
            { 'Accuracy', pct(rg.hits, rg.hits + rg.miss) },
            { 'Critical rate', pct(rg.crits, rg.hits) },
            { 'Average hit', commas(rg.dmg / math.max(rg.hits, 1)) },
            { 'Lowest / highest', string.format('%s / %s', commas(rg.min or 0), commas(rg.max)) },
            { 'Shots', commas(rg.hits + rg.miss) },
        });
    end

    -- Weapon skills, spells, abilities and pet moves: one row each.
    local c = { 0, w * 0.52, w * 0.64, w * 0.76, w * 0.88, w };
    local ws = sorted_named(p.ws);
    if #ws > 0 then
        y = heading(x, y, w, 'Weapon skills', commas(sum(p.ws)));
        local rows = {};
        for _, r in ipairs(ws) do
            rows[#rows + 1] = { r.name, tostring(r.s.n) .. (r.s.miss > 0 and (' (' .. r.s.miss .. ' miss)') or ''),
                commas(r.s.dmg / math.max(r.s.n, 1)), commas(r.s.min or 0), commas(r.s.max), commas(r.s.dmg) };
        end
        y = tbl(x, y, w, { 'Name', 'Used', 'Average', 'Low', 'High', 'Total' }, c, rows, 8);
    end
    local mg = sorted_named(p.magic);
    if #mg > 0 then
        y = heading(x, y, w, 'Magic', commas(sum(p.magic)) .. (p.resists > 0 and string.format('  (%d resisted)', p.resists) or ''));
        local rows = {};
        for _, r in ipairs(mg) do
            rows[#rows + 1] = { r.name, tostring(r.s.n), commas(r.s.dmg / math.max(r.s.n, 1)), commas(r.s.max),
                r.s.burst > 0 and tostring(r.s.burst) or '-', commas(r.s.dmg) };
        end
        y = tbl(x, y, w, { 'Spell', 'Cast', 'Average', 'High', 'Bursts', 'Total' }, c, rows, 8);
    end
    local ja = sorted_named(p.ja);
    if #ja > 0 then
        y = heading(x, y, w, 'Abilities', commas(sum(p.ja)));
        local rows = {};
        for _, r in ipairs(ja) do
            rows[#rows + 1] = { r.name, tostring(r.s.n), commas(r.s.dmg / math.max(r.s.n, 1)), commas(r.s.min or 0), commas(r.s.max), commas(r.s.dmg) };
        end
        y = tbl(x, y, w, { 'Ability', 'Used', 'Average', 'Low', 'High', 'Total' }, c, rows, 6);
    end
    if p.sc.n > 0 or p.add > 0 then
        y = heading(x, y, w, 'Skillchains and added effects');
        y = stats(x, y, w, 3, {
            { 'Skillchains', tostring(p.sc.n) },
            { 'Skillchain damage', commas(p.sc.dmg) },
            { 'Best skillchain', commas(p.sc.max) },
            { 'Added effects', commas(p.add) },
        });
    end
    if p.pet.dmg > 0 then
        y = heading(x, y, w, 'Pet', commas(p.pet.dmg));
        local mv = sorted_named(p.pet.moves);
        if #mv > 0 then
            local rows = {};
            for _, r in ipairs(mv) do
                rows[#rows + 1] = { r.name, tostring(r.s.n), commas(r.s.dmg / math.max(r.s.n, 1)), commas(r.s.min or 0), commas(r.s.max), commas(r.s.dmg) };
            end
            y = tbl(x, y, w, { 'Move', 'Used', 'Average', 'Low', 'High', 'Total' }, c, rows, 6);
        else
            y = stats(x, y, w, 3, { { 'Melee', commas(p.pet.dmg) } });
        end
    end

    -- Defence.
    local tk = p.taken;
    local attacks = tk.hits + tk.evaded + tk.parried + tk.shadows;
    if attacks > 0 or tk.dmg > 0 then
        y = heading(x, y, w, 'Defence', commas(tk.dmg) .. ' taken');
        y = stats(x, y, w, 3, {
            { 'Hits taken', tostring(tk.hits) },
            { 'Evaded', pct(tk.evaded, attacks) },
            { 'Parried', pct(tk.parried, attacks) },
            { 'Shadows used', tostring(tk.shadows) },
            { 'From spells', commas(tk.spells) },
            { 'From TP moves', commas(tk.tp) },
        });
    end
    if p.heal.n > 0 then
        y = heading(x, y, w, 'Healing', commas(p.heal.total));
        y = stats(x, y, w, 3, {
            { 'Heals', tostring(p.heal.n) },
            { 'Average heal', commas(p.heal.total / math.max(p.heal.n, 1)) },
        });
    end
    return y;
end

-- Draws the page. `colors` is omni's colour table (for the bars).
dmg.render = function (colors)
    local W = imgui.GetContentRegionAvail();
    ctx.lh = select(2, imgui.CalcTextSize('Ag')) or 14;
    ctx.dl = imgui.GetWindowDrawList();
    local x0, y0 = imgui.GetCursorPos();
    ctx.wx, ctx.wy = imgui.GetWindowPos();
    ctx.wx = ctx.wx - imgui.GetScrollX();
    ctx.wy = ctx.wy - imgui.GetScrollY();

    local rows, total = {}, 0;
    for _, p in pairs(data.people) do
        if p.total > 0 or p.heal.total > 0 or p.taken.dmg > 0 then rows[#rows + 1] = p; total = total + p.total; end
    end
    table.sort(rows, function (a, b) if a.total ~= b.total then return a.total > b.total; end return a.name < b.name; end);
    local seconds = math.max(data.active, 1);

    -- Top line: totals and Reset.
    imgui.SetCursorPos({ x0, y0 });
    imgui.TextColored(GOLD, 'Total');
    imgui.SameLine(0, 6); imgui.Text(commas(total));
    imgui.SameLine(0, 18); imgui.TextColored(GOLD, 'Time');
    imgui.SameLine(0, 6); imgui.Text(string.format('%d:%02d', math.floor(data.active / 60), data.active % 60));
    imgui.SameLine(0, 18); imgui.TextColored(GOLD, 'Group DPS');
    imgui.SameLine(0, 6); imgui.Text(commas(total / seconds));
    imgui.SameLine(W - 70);
    if imgui.Button('Reset##dmg_adv', { 64, 0 }) then dmg.reset(); selected = nil; return; end

    local top = y0 + ctx.lh + 14;
    if #rows == 0 then
        imgui.SetCursorPos({ x0, top });
        imgui.TextColored(DIM, 'Nothing recorded yet. It starts counting when you or your party fight.');
        dmg.height = top + ctx.lh + 20;
        return;
    end
    if selected == nil or data.people[selected] == nil then
        local me = nil;
        pcall(function () me = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
        selected = (me and data.people[me]) and me or rows[1].name;
    end

    -- Left: everyone, with a bar for their share. Click to see their breakdown.
    local listW = 230;
    local rowH = ctx.lh + 12;
    local best = math.max(rows[1].total, 1);
    for i, p in ipairs(rows) do
        local ry = top + (i - 1) * (rowH + 4);
        local sel = (p.name == selected);
        local bg = sel and { 0.79, 0.69, 0.42, 0.30 } or { 1, 1, 1, 0.05 };
        ctx.dl:AddRectFilled({ ctx.wx + x0, ctx.wy + ry }, { ctx.wx + x0 + listW, ctx.wy + ry + rowH }, u32(bg), 4);
        local frac = p.total / best;
        local bar = (colors and colors.xp) or { 0.35, 0.55, 0.90, 1 };
        ctx.dl:AddRectFilled({ ctx.wx + x0 + 3, ctx.wy + ry + rowH - 5 },
            { ctx.wx + x0 + 3 + (listW - 6) * frac, ctx.wy + ry + rowH - 2 }, u32(bar), 2);
        text(x0 + 8, ry + 4, sel and GOLD or WHITE, string.format('%d. %s', i, p.name));
        rtext(x0 + listW - 8, ry + 4, DIM, pct(p.total, total));
        imgui.SetCursorPos({ x0, ry });
        if imgui.InvisibleButton('##dmg_pick' .. i, { listW, rowH }) then selected = p.name; end
        if imgui.IsItemHovered() then imgui.SetTooltip(string.format('%s: %s damage', p.name, commas(p.total))); end
    end
    local left_bottom = top + #rows * (rowH + 4);

    -- Right: the picked person's breakdown.
    local dx = x0 + listW + 16;
    local dw = W - listW - 22;
    ctx.dl:AddLine({ ctx.wx + dx - 9, ctx.wy + top }, { ctx.wx + dx - 9, ctx.wy + math.max(left_bottom, top + 40) }, u32({ 0.79, 0.69, 0.42, 0.25 }), 1);
    local bottom = detail(data.people[selected], dx, top, dw, seconds, total);

    local h = math.max(left_bottom, bottom) + 6;
    imgui.SetCursorPos({ x0, h });
    imgui.Dummy({ 1, 1 });
    dmg.height = h;
end

return dmg;
