--[[
    omni_schbar.lua - Scholar click bar.

    One action bar on screen while you are Scholar (like a WoW bar), square boxes in a row:

        Ice x2 / Strats 4/5 | 16 Magic Burst chains, grouped by burst element | 8 storms | Klimaform

    Magic Burst: 16 skillchains built in (Immanence opener + closer, then the burst). If you have your
    own script for one in VanaCore's scripts\sc_<name>.txt, that runs instead. omni runs each chain
    itself, line by line with its /waits, so a click can never go off twice. Buttons are coloured by the
    element you burst with; a star marks the ones that match your weather right now.
    Storms: the eight storm spells. Left-click casts it on you. Right-click gives it to the whole
    party for twice as long: Light Arts (if needed) -> Accession -> Perpetuance -> storm, with your
    enhancing-duration gear on (2 stratagems; with only 1 it skips Perpetuance). The one that matches today's day is marked: storm + matching obi + day = +20%.

    Books (second row): a Light book and a Dark book. Left-click = that Arts (free), right-click =
    that Arts + its Addendum (1 stratagem). Beside them, that book's stratagems as buttons:
      Light: Penury, Celerity, Accession, Rapture, Addendum: White, Perpetuance.
      Dark:  Parsimony, Alacrity, Manifestation, Ebullience, Addendum: Black, Focalization, Immanence.
    White row (third row, shows while Light Arts or Addendum: White is up):
      Accession buffs - Stoneskin, Blink, Aquaveil, Phalanx, Regen, Protect, Shell, Sneak, Invisible.
        Left-click: Accession + the spell (whole party, 1 stratagem). Right-click: just the spell
        (on you for the self-only ones, pick a party member for the rest).
      Addendum: White spells - the -na spells, Erase, Raise, Reraise. Puts Light Arts / Addendum: White
        up first when needed.
    Gear: before a spell (and before the burst of a skillchain) the bar looks through your inventory and
    wardrobes for gear that helps that spell (MND / Stoneskin+ for Stoneskin, Enhancing skill for Phalanx,
    INT / Magic Atk. Bonus / matching obi for bursts...), puts it on, and puts your old gear back once
    the cast finishes. Weapons are never swapped, so you keep your TP.

    /schbar turns it on or off. Tools > SCH Bar has the switch and a short play guide.
]]

local imgui = require('imgui');

local sb = {};

local okv, vanadiel = pcall(require, 'lib.core.vanadiel');
if (not okv) then vanadiel = nil; end

----------------------------------------------------------------------------------------------------
-- Elements
----------------------------------------------------------------------------------------------------
local EL = {
    fire    = { name = 'Fire',    col = { 0.78, 0.26, 0.22, 1 }, storm = 'Firestorm',    day = 'Firesday' },
    ice     = { name = 'Ice',     col = { 0.30, 0.62, 0.80, 1 }, storm = 'Hailstorm',    day = 'Iceday' },
    wind    = { name = 'Wind',    col = { 0.30, 0.62, 0.36, 1 }, storm = 'Windstorm',    day = 'Windsday' },
    earth   = { name = 'Earth',   col = { 0.62, 0.50, 0.24, 1 }, storm = 'Sandstorm',    day = 'Earthsday' },
    thunder = { name = 'Thunder', col = { 0.56, 0.36, 0.78, 1 }, storm = 'Thunderstorm', day = 'Lightningday' },
    water   = { name = 'Water',   col = { 0.22, 0.40, 0.78, 1 }, storm = 'Rainstorm',    day = 'Watersday' },
    light   = { name = 'Light',   col = { 0.80, 0.78, 0.60, 1 }, storm = 'Aurorastorm',  day = 'Lightsday' },
    dark    = { name = 'Dark',    col = { 0.36, 0.26, 0.44, 1 }, storm = 'Voidstorm',    day = 'Darksday' },
};
local ORDER = { 'fire', 'ice', 'wind', 'earth', 'thunder', 'water', 'light', 'dark' };
-- What the "MB:" word in a script's /p line means.
local MB_WORD = {
    fire = 'fire', ice = 'ice', blizzard = 'ice', aero = 'wind', wind = 'wind', stone = 'earth', earth = 'earth',
    thunder = 'thunder', water = 'water', light = 'light', dark = 'dark',
};
-- What each storm does for the burst damage, for the tooltip.
local STORM_STAT = { fire = 'STR', ice = 'INT', wind = 'AGI', earth = 'VIT', thunder = 'DEX', water = 'MND', light = 'CHR', dark = 'MP' };

-- The skillchains: opener, closer (both after Immanence), then the burst. If you have your own
-- script for one in scripts\sc_<name>.txt (VanaCore's scripts folder) the bar runs that instead.
local CHAINS = {
    { 'sc_distortion',         'Distortion',    'ice',     'Luminohelix', 'Stone',       'Blizzard IV' },
    { 'sc_induration',         'Induration',    'ice',     'Water',       'Blizzard',    'Blizzard IV' },
    { 'sc_distortion_water',   'Distortion',    'water',   'Luminohelix', 'Stone',       'Water IV' },
    { 'sc_reverberation',      'Reverberation', 'water',   'Stone',       'Water',       'Water IV' },
    { 'sc_fusion',             'Fusion',        'fire',    'Fire',        'Thunder',     'Fire IV' },
    { 'sc_liquefaction',       'Liquefaction',  'fire',    'Stone',       'Fire',        'Fire IV' },
    { 'sc_fragmentation',      'Fragmentation', 'thunder', 'Blizzard',    'Water',       'Thunder IV' },
    { 'sc_impaction',          'Impaction',     'thunder', 'Blizzard',    'Thunder',     'Thunder IV' },
    { 'sc_fragmentation_aero', 'Fragmentation', 'wind',    'Blizzard',    'Water',       'Aero IV' },
    { 'sc_detonation',         'Detonation',    'wind',    'Stone',       'Aero',        'Aero IV' },
    { 'sc_gravitation',        'Gravitation',   'earth',   'Aero',        'Noctohelix',  'Stone IV' },
    { 'sc_scission',           'Scission',      'earth',   'Fire',        'Stone',       'Stone IV' },
    { 'sc_compression',        'Compression',   'dark',    'Blizzard',    'Noctohelix',  'Noctohelix' },
    { 'sc_gravitation_dark',   'Gravitation',   'dark',    'Aero',        'Noctohelix',  'Noctohelix' },
    { 'sc_fusion_light',       'Fusion',        'light',   'Fire',        'Thunder',     'Luminohelix' },
    { 'sc_transfixion',        'Transfixion',   'light',   'Noctohelix',  'Luminohelix', 'Luminohelix' },
};

local DIM  = { 0.62, 0.62, 0.66, 1 };
local GOLD = { 0.92, 0.80, 0.42, 1 };
local GOOD = { 0.45, 0.80, 0.50, 1 };
local BAD  = { 0.90, 0.48, 0.45, 1 };

local function lighten(c, f) return { math.min(1, c[1] * f), math.min(1, c[2] * f), math.min(1, c[3] * f), c[4] }; end

----------------------------------------------------------------------------------------------------
-- Game state
----------------------------------------------------------------------------------------------------
local function player() return AshitaCore:GetMemoryManager():GetPlayer(); end

local function is_sch()
    local ok, v = pcall(function () return player():GetMainJob() == 20; end);
    return ok and v;
end

local function main_level()
    local ok, v = pcall(function () return player():GetMainJobLevel(); end);
    return ok and v or 0;
end

local function has_target()
    local ok, v = pcall(function ()
        local t = AshitaCore:GetMemoryManager():GetTarget();
        return (t:GetTargetIndex(0) or 0) ~= 0;
    end);
    return ok and v;
end

local spell_ids = {};
local function spell_id(name)
    if (spell_ids[name] == nil) then
        local id = false;
        pcall(function ()
            local s = AshitaCore:GetResourceManager():GetSpellByName(name, 0);
            if (s ~= nil) then id = s.Index; end
        end);
        spell_ids[name] = id;
    end
    return spell_ids[name] or nil;
end

local function knows(name)
    local id = spell_id(name);
    if (id == nil) then return false; end
    local ok, v = pcall(function () return player():HasSpell(id); end);
    return ok and v;
end

local function spell_recast(name)
    local id = spell_id(name);
    if (id == nil) then return 0; end
    local ok, v = pcall(function () return AshitaCore:GetMemoryManager():GetRecast():GetSpellTimer(id); end);
    return (ok and v or 0) / 60;
end

-- Stratagem charges (CatsEyeXI: 5 at 75, one back every 48 s; the game only shows 4).
local STRAT_TIERS = { { 75, 5, 48 }, { 65, 4, 60 }, { 50, 3, 80 }, { 30, 2, 120 }, { 10, 1, 240 } };
local function stratagems()
    local lv = main_level();
    local max, rate = 0, 0;
    for _, t in ipairs(STRAT_TIERS) do if (lv >= t[1]) then max, rate = t[2], t[3]; break; end end
    if (max == 0) then return 0, 0; end
    local left = 0;
    pcall(function ()
        local rc = AshitaCore:GetMemoryManager():GetRecast();
        for i = 0, 31 do
            if (rc:GetAbilityTimerId(i) == 231) then left = (rc:GetAbilityTimer(i) or 0) / 60; break; end
        end
    end);
    if (left <= 0) then return max, max; end
    local have = max - math.ceil((left - 0.5) / rate);
    return math.max(0, math.min(max, have)), max;
end

local env = { at = -10, weather = nil, double = false, storm = nil, day = nil };
local function read_env()
    if (os.clock() - env.at < 1) then return env; end
    env.at = os.clock();
    if (vanadiel ~= nil) then
        local ok, w, d = pcall(vanadiel.zone_weather);
        env.weather, env.double = ok and w or nil, ok and d or false;
        local oks, st = pcall(vanadiel.storm); env.storm = oks and st or nil;
        local okd, dy = pcall(vanadiel.day); env.day = okd and dy or nil;
    end
    return env;
end
-- The weather your spells actually get: a storm on you replaces the zone's weather.
local function your_weather(e)
    if (e.storm ~= nil) then return e.storm, false; end
    return e.weather, e.double;
end

----------------------------------------------------------------------------------------------------
-- Skillchain scripts, run by omni itself
----------------------------------------------------------------------------------------------------
local scripts = { loaded_at = -100, list = {} };

-- Burst spell tiers, best first. IV and up need Addendum: Black on Scholar.
local TIERS = { 'V', 'IV', 'III', 'II', '' };
local function needs_addendum(tier) return tier == 'IV' or tier == 'V'; end
local function split_spell(name)
    local base, tier = name:match('^(%a+)%s+([IV]+)$');
    if (base == nil) then return name, ''; end
    return base, tier;
end
local function read_script(name)
    local f = io.open(AshitaCore:GetInstallPath() .. '\\scripts\\' .. name .. '.txt', 'r');
    if (f == nil) then return nil; end
    local sc = { file = name, steps = {}, spells = {}, total = 0, sc = nil, mb = nil };
    for line in f:lines() do
        line = line:gsub('\r', ''):gsub('^%s+', ''):gsub('%s+$', '');
        local lo = line:lower();
        local w = lo:match('^/wait%s+([%d%.]+)');
        if (w ~= nil) then
            sc.steps[#sc.steps + 1] = { wait = tonumber(w) or 0 };
            sc.total = sc.total + (tonumber(w) or 0);
        elseif (lo:sub(1, 1) == '/' and lo:find('^/scgate') == nil) then
            sc.steps[#sc.steps + 1] = { cmd = line };
            local chain, word = line:match('%((%a+)%)%s*MB:%s*(%a+)');
            if (chain ~= nil) then sc.sc, sc.mb = chain, MB_WORD[word:lower()]; end
            local sp = line:match('^/ma%s+"([^"]+)"');
            if (sp ~= nil) then sc.spells[#sc.spells + 1] = sp; end
        end
    end
    f:close();
    -- The last /ma is the burst: the bar casts the best tier you have of it when the time comes.
    for i = #sc.steps, 1, -1 do
        local st = sc.steps[i];
        local sp, tgt = st.cmd and st.cmd:match('^/ma%s+"([^"]+)"%s*(.*)$');
        if (sp ~= nil) then
            if (not sp:lower():find('helix')) then
                local base, tier = split_spell(sp);
                st.burst = { spell = sp, base = base, tier = tier, target = (tgt ~= '' and tgt or '<t>') };
            end
            break;
        end
    end
    -- Name from the file when the /p line does not say: sc_fusion_light -> Fusion.
    sc.sc = sc.sc or (name:match('^sc_(%a+)') or name):gsub('^%l', string.upper);
    return sc;
end

-- A chain from the table above, as the same steps a script would have.
local function built_in(c)
    local file, name, mb, a, b, burst = c[1], c[2], c[3], c[4], c[5], c[6];
    local el = EL[mb].name;
    local party = (sb.settings == nil or sb.settings.sch_bar_party ~= false);
    local lines = {};
    if (party) then lines[#lines + 1] = ('/p Starting %s - Magic Burst %s!'):format(name, el); end
    for _, l in ipairs({ '/ja "Immanence" <me>', '/wait 2', ('/ma "%s" <t>'):format(a), '/wait 5' }) do lines[#lines + 1] = l; end
    if (party) then lines[#lines + 1] = ('/p %s closing - burst %s now!'):format(name, el); end
    for _, l in ipairs({ '/ja "Immanence" <me>', '/wait 2', ('/ma "%s" <t>'):format(b), '/wait 2', ('/ma "%s" <t>'):format(burst), '/wait 1' }) do
        lines[#lines + 1] = l;
    end
    local sc = { file = file, steps = {}, spells = { a, b, burst }, total = 0, sc = name, mb = mb };
    for _, l in ipairs(lines) do
        local w = l:match('^/wait%s+([%d%.]+)');
        if (w ~= nil) then
            sc.steps[#sc.steps + 1] = { wait = tonumber(w) };
            sc.total = sc.total + tonumber(w);
        else
            sc.steps[#sc.steps + 1] = { cmd = l };
        end
    end
    if (not burst:lower():find('helix')) then
        local base, tier = split_spell(burst);
        sc.steps[#sc.steps - 1].burst = { spell = burst, base = base, tier = tier, target = '<t>' };
    end
    return sc;
end

local function load_scripts()
    if (os.clock() - scripts.loaded_at < 10) then return scripts.list; end
    scripts.loaded_at = os.clock();
    local list = {};
    for _, c in ipairs(CHAINS) do
        local sc = read_script(c[1]) or built_in(c);
        list[#list + 1] = sc;
    end
    -- Element order, then skillchain name.
    local rank = {};
    for i, e in ipairs(ORDER) do rank[e] = i; end
    table.sort(list, function (a, b)
        local ra, rb = rank[a.mb or ''] or 99, rank[b.mb or ''] or 99;
        if (ra ~= rb) then return ra < rb; end
        return a.sc < b.sc;
    end);
    scripts.list = list;
    return list;
end

-- Buff ids by name, from the game's own list (so they are right on this server).
local buff_ids = nil;
local function buff_id(name)
    if (buff_ids == nil) then
        buff_ids = {};
        pcall(function ()
            local res = AshitaCore:GetResourceManager();
            for id = 0, 1023 do
                local n = res:GetString('buffs.names', id);
                if (n ~= nil and n ~= '' and buff_ids[n:lower()] == nil) then buff_ids[n:lower()] = id; end
            end
        end);
    end
    return buff_ids[name:lower()];
end
local function has_buff(name)
    local id = buff_id(name);
    if (id == nil) then return false; end
    local found = false;
    pcall(function ()
        for _, b in ipairs(player():GetBuffs()) do if (b == id) then found = true; break; end end
    end);
    return found;
end

----------------------------------------------------------------------------------------------------
-- Gear: find what you own that helps a spell, put it on, put the old pieces back after the cast
----------------------------------------------------------------------------------------------------
-- Bags you can equip from: inventory, wardrobes 1-8.
local EQUIP_BAGS = { 0, 8, 10, 11, 12, 13, 14, 15, 16 };
local SINGLE_SLOTS = { 3, 4, 5, 6, 7, 8, 9, 10, 15 };   -- ammo head body hands legs feet neck waist back
local PAIR_SLOTS = { { 11, 12 }, { 13, 14 } };          -- ears, rings
-- Weapons (0 main, 1 sub, 2 range) are left alone so you keep your TP and staff/grip setup.

-- What the item descriptions say, read as signed numbers ("MND+5", "Enhancing magic skill +10").
local STAT_PAT = {
    mnd       = '%f[%a]mnd%s*([%+%-])(%d+)',
    int       = '%f[%a]int%s*([%+%-])(%d+)',
    enh       = 'enhancing magic skill%s*([%+%-])(%d+)',
    ele       = 'elemental magic skill%s*([%+%-])(%d+)',
    mab       = 'magic atk%.%s*bonus"?%s*([%+%-])(%d+)',
    macc      = 'magic acc%a*%.?%s*([%+%-])(%d+)',
    mbd       = 'magic burst damage%s*([%+%-])(%d+)',
    stoneskin = 'stoneskin"?%s*([%+%-])(%d+)',
    phalanx   = 'phalanx"?%s*([%+%-])(%d+)',
    aquaveil  = 'aquaveil"?%s*([%+%-])(%d+)',
    regen     = 'regen"?%s*potency%s*([%+%-])(%d+)',
    enhdur    = 'enhancing magic%s*%a*%s*duration%s*([%+%-])(%d+)',
};
-- How much each stat is worth for each kind of spell.
local PROFILES = {
    stoneskin = { mnd = 1, enh = 0.33, stoneskin = 1 },
    phalanx   = { enh = 1, phalanx = 10 },
    aquaveil  = { enh = 0.5, aquaveil = 5 },
    regen     = { regen = 5, enhdur = 0.5 },
    enh       = { enhdur = 1 },
    nuke      = { int = 1, mab = 2, ele = 0.5, macc = 0.5, mbd = 3 },
};
local PROFILE_WHAT = {
    stoneskin = 'MND, Enhancing skill, Stoneskin+', phalanx = 'Enhancing skill, Phalanx+',
    aquaveil = 'Enhancing skill, Aquaveil+', regen = 'Regen potency, enhancing duration',
    enh = 'Enhancing magic duration', nuke = 'INT, Magic Atk. Bonus, Elemental skill, Magic Acc., MB damage, obi',
};
local OBI = {
    fire = 'karin obi', ice = 'hyorin obi', wind = 'furin obi', earth = 'dorin obi',
    thunder = 'rairin obi', water = 'suirin obi', light = 'korin obi', dark = 'anrin obi',
};

local function stat_value(desc, pat)
    local total = 0;
    for sign, n in desc:gmatch(pat) do total = total + ((sign == '-') and -1 or 1) * (tonumber(n) or 0); end
    return total;
end

local score_cache = {};
local function item_score(id, r, prof, el, obi_on)
    local key = id .. ':' .. prof .. ':' .. ((obi_on and el) or '');
    if (score_cache[key] ~= nil) then return score_cache[key]; end
    local s = 0;
    local desc = '';
    pcall(function () desc = (r.Description[1] or ''):lower(); end);
    for stat, weight in pairs(PROFILES[prof] or {}) do s = s + weight * stat_value(desc, STAT_PAT[stat]); end
    if (obi_on and el ~= nil) then
        local nm = '';
        pcall(function () nm = (r.Name[1] or ''):lower(); end);
        if (nm == OBI[el] or nm == 'hachirin-no-obi') then s = s + 100; end
    end
    score_cache[key] = s;
    return s;
end

-- Works out which pieces to put on. Returns a list of { slot, c, i, name } and what is on now.
local function plan_gear(prof, el)
    local plan, worn = {}, {};
    if (PROFILES[prof] == nil) then return plan, worn; end
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();
        local lv = main_level();
        local obi_on = false;
        if (el ~= nil) then
            local e = read_env();
            obi_on = (your_weather(e) == el) or (e.day == el);
        end
        for s = 3, 15 do
            local item = inv:GetEquippedItem(s);
            local idx = item and bit.band(item.Index, 0x00FF) or 0;
            if (idx ~= 0) then
                local c = bit.band(item.Index, 0xFF00) / 256;
                worn[s] = { key = c .. ':' .. idx, c = c, i = idx };
            end
        end
        local per = {};
        for _, c in ipairs(EQUIP_BAGS) do
            local max = 0;
            pcall(function () max = inv:GetContainerCountMax(c) or 0; end);
            for i = 1, max do
                local it = inv:GetContainerItem(c, i);
                if (it ~= nil and it.Id ~= 0 and it.Id ~= 65535 and it.Count > 0) then
                    local r = res:GetItemById(it.Id);
                    if (r ~= nil and bit.band(r.Flags, 0x800) ~= 0 and r.Level <= lv and bit.band(r.Jobs, 0x100000) ~= 0) then
                        local sc = item_score(it.Id, r, prof, el, obi_on);
                        local name = r.Name[1];
                        for s = 3, 15 do
                            if (bit.band(r.Slots, bit.lshift(1, s)) ~= 0) then
                                per[s] = per[s] or {};
                                table.insert(per[s], { key = c .. ':' .. i, c = c, i = i, score = sc, name = name });
                            end
                        end
                    end
                end
            end
        end
        local function score_of(s, key)
            for _, x in ipairs(per[s] or {}) do if (x.key == key) then return x.score; end end
            return 0;
        end
        -- One-piece slots: the best piece, if it beats what is on.
        for _, s in ipairs(SINGLE_SLOTS) do
            local best = nil;
            for _, x in ipairs(per[s] or {}) do if (best == nil or x.score > best.score) then best = x; end end
            local cur = worn[s] and score_of(s, worn[s].key) or 0;
            if (best ~= nil and best.score > 0 and best.score > cur and (worn[s] == nil or best.key ~= worn[s].key)) then
                plan[#plan + 1] = { slot = s, c = best.c, i = best.i, name = best.name };
            end
        end
        -- Ears and rings: the best two, keeping what's on where it is.
        for _, pair in ipairs(PAIR_SLOTS) do
            local pool, seen = {}, {};
            for _, s in ipairs(pair) do
                for _, x in ipairs(per[s] or {}) do
                    if (not seen[x.key]) then seen[x.key] = true; pool[#pool + 1] = x; end
                end
                if (worn[s] ~= nil and not seen[worn[s].key]) then
                    seen[worn[s].key] = true;
                    pool[#pool + 1] = { key = worn[s].key, c = worn[s].c, i = worn[s].i, score = 0, name = '?' };
                end
            end
            local on = {};
            for _, s in ipairs(pair) do if (worn[s] ~= nil) then on[worn[s].key] = true; end end
            table.sort(pool, function (a, b)
                if (a.score ~= b.score) then return a.score > b.score; end
                return (on[a.key] and 1 or 0) > (on[b.key] and 1 or 0);
            end);
            local pick = { pool[1], pool[2] };
            local placed, free = {}, {};
            for _, s in ipairs(pair) do
                local kept = false;
                for n, x in pairs(pick) do
                    if (x ~= nil and worn[s] ~= nil and x.key == worn[s].key) then pick[n] = nil; kept = true; break; end
                end
                if (not kept) then free[#free + 1] = s; end
            end
            local f = 1;
            for n = 1, 2 do
                local x = pick[n];
                if (x ~= nil and f <= #free) then
                    if (x.score > 0) then plan[#plan + 1] = { slot = free[f], c = x.c, i = x.i, name = x.name }; end
                    f = f + 1;
                end
            end
        end
    end);
    return plan, worn;
end

-- Sends the equip packets (same as LuAshitacast does, so it works mid-cast).
local function equip_packet(slot, c, i)
    local packet = { 0x00, 0x00, 0x00, 0x00, i or 0, slot, c or 0, 0x00 };
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x50, packet);
end

-- Puts the gear on and returns what to put back, or nil if nothing changed.
local function wear_for(prof, el)
    local plan, worn = plan_gear(prof, el);
    if (#plan == 0) then return nil; end
    local back = {};
    for _, p in ipairs(plan) do
        back[#back + 1] = { slot = p.slot, old = worn[p.slot] };
        pcall(equip_packet, p.slot, p.c, p.i);
    end
    return back;
end

local function put_back(back)
    if (back == nil) then return; end
    for _, b in ipairs(back) do
        if (b.old ~= nil) then
            pcall(equip_packet, b.slot, b.old.c, b.old.i);
        else
            pcall(equip_packet, b.slot, 0, 0);
        end
    end
end

-- For the tooltips: what would go on, looked at every few seconds.
local preview = {};
local function gear_preview(prof, el)
    local key = prof .. ':' .. tostring(el);
    local p = preview[key];
    if (p == nil or os.clock() - p.at > 3) then
        local plan = plan_gear(prof, el);
        local names = {};
        for _, x in ipairs(plan) do names[#names + 1] = x.name; end
        p = { at = os.clock(), names = names };
        preview[key] = p;
    end
    return p.names;
end

-- When your own cast finishes (or is interrupted), from the action packet.
local cast_done = { at = -100, id = nil };
ashita.events.register('packet_in', 'omni_schbar_cast', function (e)
    if (e.id ~= 0x028) then return; end
    pcall(function ()
        local actor = struct.unpack('I', e.data, 0x05 + 1);
        if (actor ~= AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0)) then return; end
        local category = ashita.bits.unpack_be(e.data_raw, 82, 4);
        local param = ashita.bits.unpack_be(e.data_raw, 86, 16);
        if (category == 4) then
            cast_done.at, cast_done.id = os.clock(), param;
        elseif (category == 8 and param == 28787) then   -- interrupted
            cast_done.at, cast_done.id = os.clock(), 'any';
        end
    end);
end);

-- The best tier of this spell you can cast right now (known, off recast, Addendum up when it needs it).
local function best_tier(base, addendum_up, top)
    local started = (top == nil);
    for _, t in ipairs(TIERS) do
        if (t == top) then started = true; end
        if (started) then
            local name = (t == '') and base or (base .. ' ' .. t);
            if (knows(name) and spell_recast(name) <= 0 and (addendum_up or not needs_addendum(t))) then return name; end
        end
    end
    return nil;
end

local function opt(key, default)
    local st = sb.settings or {};
    if (st[key] == nil) then return default; end
    return st[key];
end

local run = nil;   -- { sc, steps, i, next_at, started, total }
local last_msg = { text = nil, at = -100 };
local function say(text) last_msg.text, last_msg.at = text, os.clock(); print('\30\81[SCH bar]\30\01 ' .. text); end
local function queue(cmd) AshitaCore:GetChatManager():QueueCommand(1, cmd); end

-- Build the run: get ready (arts, addendum, storm, Klimaform), then the script, with the burst
-- spell picked when it is cast.
local function start(sc)
    if (run ~= nil) then say('Already running ' .. run.sc.sc .. ' - wait for it or Stop.'); return; end
    if (not has_target()) then say('Target the monster first.'); return; end
    local have = stratagems();
    if (have < 2) then say('Only ' .. have .. ' stratagem left - a skillchain needs 2.'); return; end

    local steps, prep = {}, 0;
    local function add(s, secs) steps[#steps + 1] = s; prep = prep + (secs or 0); end
    local dark = has_buff('Dark Arts');
    local addendum = has_buff('Addendum: Black');
    -- Immanence only works under Dark Arts.
    if (not dark and not addendum) then
        add({ cmd = '/ja "Dark Arts" <me>' }); add({ wait = 1.5 }, 1.5);
    end
    -- Addendum: Black for a tier IV burst - only if there's a stratagem to spare for it.
    local burst = nil;
    for _, s in ipairs(sc.steps) do if (s.burst ~= nil) then burst = s.burst; end end
    if (burst ~= nil and needs_addendum(burst.tier) and not addendum and opt('sch_bar_addendum', true)) then
        if (have >= 3) then
            add({ cmd = '/ja "Addendum: Black" <me>' }); add({ wait = 1.5 }, 1.5);
            addendum = true;
        else
            say('Not enough stratagems for Addendum: Black too - bursting with a lower tier.');
        end
    end
    -- The storm for the burst element, unless the zone already gives you double of it.
    local e = read_env();
    local el = sc.mb and EL[sc.mb];
    if (el ~= nil and opt('sch_bar_storm', true) and e.storm ~= sc.mb and not (e.weather == sc.mb and e.double)) then
        local storm = knows(el.storm .. ' II') and (el.storm .. ' II') or el.storm;
        if (knows(storm) and spell_recast(storm) <= 0) then
            add({ cmd = ('/ma "%s" <me>'):format(storm) });
            add({ until_buff = el.storm, timeout = 9 }, 5);
            add({ wait = 1.2 }, 1.2);
        end
    end
    -- Klimaform (optional: 7 s cast).
    if (opt('sch_bar_klima', false) and knows('Klimaform') and spell_recast('Klimaform') <= 0 and not has_buff('Klimaform')) then
        add({ cmd = '/ma "Klimaform" <me>' });
        add({ until_buff = 'Klimaform', timeout = 11 }, 8);
        add({ wait = 1.2 }, 1.2);
    end
    local nuke_gear = opt('sch_bar_gear', true) and opt('sch_bar_burst_gear', true);
    for _, s in ipairs(sc.steps) do
        if (s.burst ~= nil and nuke_gear) then
            steps[#steps + 1] = { gear = 'nuke', el = sc.mb };
            steps[#steps + 1] = s;
            steps[#steps + 1] = { restore = true };
        else
            steps[#steps + 1] = s;
        end
    end
    run = { sc = sc, steps = steps, i = 1, next_at = os.clock(), started = os.clock(), total = sc.total + prep,
            addendum = addendum };
end

sb.stop = function ()
    if (run ~= nil) then
        say('Stopped ' .. run.sc.sc .. '.');
        if (run.back ~= nil) then put_back(run.back); end
    end
    run = nil;
end

-- White magic: Accession buffs and Addendum: White spells.
local function pick_tier(w)
    for _, n in ipairs(w.tiers) do if (knows(n)) then return n; end end
    return nil;
end

local function white_start(w, accession)
    if (run ~= nil) then say('Busy with ' .. run.sc.sc .. ' - wait for it or Stop.'); return; end
    local name = pick_tier(w);
    if (name == nil) then say("You don't know " .. w.tiers[#w.tiers] .. '.'); return; end
    if (spell_recast(name) > 0) then say(name .. ' is on recast.'); return; end
    local have = stratagems();
    local la, aw = has_buff('Light Arts'), has_buff('Addendum: White');
    local need_add = (w.addendum ~= nil) and w.addendum(name) and not aw;
    local perp = (w.perp == true);
    local cost = (accession and 1 or 0) + (need_add and 1 or 0) + (perp and 1 or 0);
    if (perp and have == cost - 1) then
        -- One short: still give the whole party the storm, just at normal length.
        perp = false;
        cost = cost - 1;
        say('Only ' .. have .. ' stratagem' .. (have == 1 and '' or 's') .. ' - skipping Perpetuance, normal duration.');
    end
    if (have < cost) then say(('Needs %d stratagem%s, you have %d.'):format(cost, cost == 1 and '' or 's', have)); return; end

    local steps, total = {}, 0;
    local function add(s, secs) steps[#steps + 1] = s; total = total + (secs or 0); end
    if (not la and not aw) then add({ cmd = '/ja "Light Arts" <me>' }); add({ wait = 1.5 }, 1.5); end
    if (need_add) then add({ cmd = '/ja "Addendum: White" <me>' }); add({ wait = 1.5 }, 1.5); end
    if (accession) then add({ cmd = '/ja "Accession" <me>' }); add({ wait = 1.5 }, 1.5); end
    if (perp) then add({ cmd = '/ja "Perpetuance" <me>' }); add({ wait = 1.5 }, 1.5); end
    local gear = (w.prof ~= nil) and opt('sch_bar_gear', true);
    if (gear) then add({ gear = w.prof }); end
    local target = (accession or w.self) and '<me>' or '<stpc>';
    add({ cast = ('/ma "%s" %s'):format(name, target), spell = name }, 4);
    if (gear) then add({ restore = true }); end
    local label = (accession and 'Acc. ' or '') .. (perp and 'Perp. ' or '') .. name;
    run = { sc = { sc = label }, steps = steps, i = 1, next_at = os.clock(), started = os.clock(), total = total };
end

local function tick()
    if (run == nil) then return; end
    local now = os.clock();
    -- One command per frame; waits just move the clock on.
    while (run ~= nil and now >= run.next_at) do
        local step = run.steps[run.i];
        if (step == nil) then
            if (run.back ~= nil) then put_back(run.back); end
            run = nil;
            break;
        end
        if (step.gear ~= nil) then
            -- Put the gear on; a moment for it to land before the cast.
            run.i = run.i + 1;
            if (run.back == nil) then run.back = wear_for(step.gear, step.el); end
            run.next_at = now + ((run.back ~= nil) and 0.3 or 0);
            if (run.back ~= nil) then break; end
        elseif (step.restore ~= nil) then
            -- Wait for the cast to finish (or 30 s, e.g. if you never picked a <stpc> target), then put the old gear back.
            local since = run.cast_at or now;
            local done = cast_done.at >= since and (cast_done.id == 'any' or cast_done.id == run.cast_id);
            if (run.back == nil or done or now - since > 30) then
                if (run.back ~= nil) then put_back(run.back); run.back = nil; end
                run.i = run.i + 1;
                run.next_at = now + 0.2;
            end
            break;
        elseif (step.cast ~= nil) then
            run.i = run.i + 1;
            queue(step.cast);
            run.cast_at, run.cast_id = now, spell_id(step.spell);
            run.next_at = now + 0.5;
            break;
        elseif (step.until_buff ~= nil) then
            step.since = step.since or now;
            if (has_buff(step.until_buff) or now - step.since > step.timeout) then
                step.since = nil;
                run.i = run.i + 1;
            else
                break;
            end
        else
            run.i = run.i + 1;
            if (step.wait ~= nil) then
                run.next_at = now + step.wait;
            elseif (step.burst ~= nil) then
                -- The best burst spell you can cast right now.
                local b = step.burst;
                local name = best_tier(b.base, run.addendum or has_buff('Addendum: Black'), b.tier ~= '' and b.tier or nil)
                    or best_tier(b.base, run.addendum or has_buff('Addendum: Black'), nil) or b.spell;
                queue(('/ma "%s" %s'):format(name, b.target));
                run.cast_at, run.cast_id = now, spell_id(name);
                run.next_at = now;
                break;
            else
                queue(step.cmd);
                run.next_at = now;
                break;
            end
        end
    end
end

ashita.events.register('d3d_present', 'omni_schbar_tick', function () pcall(tick); end);

local function cast(line) AshitaCore:GetChatManager():QueueCommand(1, line); end

----------------------------------------------------------------------------------------------------
-- Drawing: square icon buttons, like an action bar
----------------------------------------------------------------------------------------------------
-- Status icons from the game (omni_status.lua turns them into textures).
local ICON = {
    storm = { fire = 178, ice = 179, wind = 180, earth = 181, thunder = 182, water = 183, light = 184, dark = 185 },
    klimaform = 407, immanence = 470, stop = 0,
};
local function icon(id)
    local st = package.loaded['omni_status'];
    if (st == nil or st.icon == nil or id == nil) then return nil; end
    local ok, h = pcall(st.icon, id);
    return ok and h or nil;
end

local S = 38;   -- button size
local function u32(c) return imgui.GetColorU32(c); end

-- One square button. o = { icon, col, label (small, at the bottom), star, cd (seconds), active, disabled, open }
-- Returns 1 for a left click, 2 for a right click, nil otherwise.
local function slot(id, o)
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local clicked = imgui.InvisibleButton(id, { S, S });
    local right = imgui.IsItemClicked(1);
    local hover = imgui.IsItemHovered();
    local col = o.col or { 0.3, 0.3, 0.3, 1 };
    -- Frame, then the picture (or the element colour when there is no picture).
    dl:AddRectFilled({ x, y }, { x + S, y + S }, u32({ 0.05, 0.05, 0.06, 1 }), 3);
    local h = icon(o.icon);
    if (h ~= nil) then
        dl:AddImage(h, { x + 2, y + 2 }, { x + S - 2, y + S - 2 });
    else
        dl:AddRectFilled({ x + 2, y + 2 }, { x + S - 2, y + S - 2 }, u32(col), 2);
    end
    -- Element tint along the bottom so the colour reads at a glance.
    dl:AddRectFilled({ x + 2, y + S - 5 }, { x + S - 2, y + S - 2 }, u32({ col[1], col[2], col[3], 0.95 }));
    if (o.disabled or (o.cd or 0) > 0) then
        dl:AddRectFilled({ x + 2, y + 2 }, { x + S - 2, y + S - 2 }, u32({ 0, 0, 0, 0.62 }), 2);
    end
    if (o.label ~= nil) then
        local tw = imgui.CalcTextSize(o.label);
        local tx, ty = x + (S - tw) / 2, y + S - 19;
        dl:AddText({ tx + 1, ty + 1 }, u32({ 0, 0, 0, 1 }), o.label);
        dl:AddText({ tx, ty }, u32({ 1, 1, 1, 1 }), o.label);
    end
    if ((o.cd or 0) > 0) then
        local t = ('%d'):format(math.ceil(o.cd));
        local tw = imgui.CalcTextSize(t);
        dl:AddText({ x + (S - tw) / 2 + 1, y + 4 }, u32({ 0, 0, 0, 1 }), t);
        dl:AddText({ x + (S - tw) / 2, y + 3 }, u32({ 1.0, 0.85, 0.40, 1 }), t);
    end
    if (o.star) then
        dl:AddText({ x + S - 10, y + 0 }, u32({ 0, 0, 0, 1 }), '*');
        dl:AddText({ x + S - 11, y - 1 }, u32(GOLD), '*');
    end
    -- Border: gold when hovered, green when the effect is on you, bright when its flyout is open.
    local border = { 0.30, 0.30, 0.32, 1 };
    if (o.active) then border = GOOD; end
    if (o.open) then border = GOLD; end
    if (hover and not o.disabled) then border = { 1.0, 0.92, 0.60, 1 }; end
    dl:AddRect({ x, y }, { x + S, y + S }, u32(border), 3, 0, (hover or o.active or o.open) and 2 or 1);
    if (o.disabled) then return nil; end
    if (clicked) then return 1; end
    if (right) then return 2; end
    return nil;
end

local ABBR = {
    Distortion = 'Dist', Induration = 'Indu', Reverberation = 'Rev', Fusion = 'Fus', Liquefaction = 'Liq',
    Fragmentation = 'Frag', Impaction = 'Imp', Detonation = 'Det', Gravitation = 'Grav', Scission = 'Sci',
    Compression = 'Comp', Transfixion = 'Tran',
};

local function gear_lines(prof, el)
    if (prof == nil or not opt('sch_bar_gear', true)) then return; end
    local names = gear_preview(prof, el);
    if (#names > 0) then
        imgui.TextColored(GOOD, 'Gear swap: ' .. table.concat(names, ', '));
    else
        imgui.TextColored(DIM, 'Gear: nothing better than what you have on (' .. PROFILE_WHAT[prof] .. ').');
    end
end

local function mb_tooltip(sc, el, w, have)
    imgui.BeginTooltip();
    imgui.TextColored(GOLD, sc.sc .. '  ->  burst ' .. el.name);
    imgui.Text(table.concat(sc.spells, '  >  '));
    imgui.TextColored(DIM, ('Uses 2 stratagems (Immanence), about %d s.'):format(math.floor(sc.total + 0.5)));
    if (sc.mb ~= nil) then
        if (sc.mb == w) then
            imgui.TextColored(GOOD, 'Your weather matches this burst: +10% (every time with the obi).');
        else
            imgui.TextColored(DIM, 'Best with ' .. EL[sc.mb].storm .. ' on you and the ' .. el.name .. ' obi (or Hachirin-no-Obi).');
        end
    end
    if (opt('sch_bar_burst_gear', true)) then gear_lines('nuke', sc.mb); end
    if (run ~= nil) then imgui.TextColored(BAD, 'A skillchain is already running.'); end
    if (have < 2) then imgui.TextColored(BAD, 'Not enough stratagems (needs 2).'); end
    imgui.EndTooltip();
end

-- Magic Burst boxes: one row, the chains of each burst element side by side.
local function mb_row(e, have)
    local list = load_scripts();
    
    local w = your_weather(e);
    local busy = (run ~= nil) or have < 2;
    local prev = nil;
    for i, sc in ipairs(list) do
        if (i > 1) then imgui.SameLine(0, (sc.mb ~= prev) and 7 or 2); end
        prev = sc.mb;
        local el = EL[sc.mb or ''] or { name = '?', col = { 0.4, 0.4, 0.4, 1 } };
        local hit = slot('##sb_mb_' .. sc.file, {
            icon = ICON.storm[sc.mb or ''], col = el.col, label = ABBR[sc.sc] or sc.sc:sub(1, 4),
            star = (sc.mb ~= nil and sc.mb == w), disabled = busy,
        });
        if (hit == 1) then start(sc); end
        if (imgui.IsItemHovered()) then mb_tooltip(sc, el, w, have); end
    end
end

local function storm_row(e)
    for i, key in ipairs(ORDER) do
        imgui.SameLine(0, (i == 1) and 12 or 2);
        local el = EL[key];
        local name = el.storm;
        if (knows(name .. ' II')) then name = name .. ' II'; end
        local known = knows(name);
        local cd = spell_recast(name);
        local today = (e.day == key);
        local hit = slot('##sb_storm_' .. key, {
            icon = ICON.storm[key], col = el.col, star = today, cd = cd, active = (e.storm == key), disabled = not known,
        });
        if (hit == 1 and cd <= 0) then cast(('/ma "%s" <me>'):format(name)); end
        if (hit == 2 and cd <= 0) then
            -- Whole party, double length: Light Arts -> Accession -> Perpetuance -> storm (+ duration gear).
            white_start({ tiers = { name }, prof = 'enh', self = true, perp = true }, true);
        end
        if (imgui.IsItemHovered()) then
            imgui.BeginTooltip();
            imgui.TextColored(GOLD, name);
            imgui.Text('Left-click: on you.');
            imgui.Text('Right-click: whole party, double length - Accession + Perpetuance (2 stratagems).');
            imgui.TextColored(DIM, 'Puts Light Arts up first if it is down. With 1 stratagem: party, normal length.');
            imgui.TextColored(DIM, el.name .. " weather on the target - it replaces the zone's weather for them.");
            imgui.TextColored(DIM, ('With Stormsurge merits it also gives %s.'):format(STORM_STAT[key]));
            if (e.storm == key) then imgui.TextColored(GOOD, 'On you now.'); end
            if (today) then imgui.TextColored(GOOD, "Today's element: with the " .. el.name .. ' obi, ' .. el.name .. ' nukes get +20%.'); end
            if (key == e.weather and e.double) then
                imgui.TextColored(BAD, 'The zone already has double ' .. el.name .. ' - a storm would drop you to single.');
            end
            if (not known) then imgui.TextColored(BAD, "You don't know this spell."); end
            imgui.EndTooltip();
        end
    end
end

-- Second row: white magic. Accession buffs, then Addendum: White spells.
local function not_raise1(name) return name ~= 'Raise'; end
local function always() return true; end
local WHITE_ACC = {
    { key = 'stoneskin', tiers = { 'Stoneskin' }, label = 'Skin', buff = 'Stoneskin', prof = 'stoneskin', self = true },
    { key = 'blink',     tiers = { 'Blink' },     label = 'Blnk', buff = 'Blink',     prof = 'enh',       self = true },
    { key = 'aquaveil',  tiers = { 'Aquaveil' },  label = 'Aqua', buff = 'Aquaveil',  prof = 'aquaveil',  self = true },
    { key = 'phalanx',   tiers = { 'Phalanx' },   label = 'Phal', buff = 'Phalanx',   prof = 'phalanx',   self = true },
    { key = 'regen',     tiers = { 'Regen III', 'Regen II', 'Regen' }, label = 'Rgn', buff = 'Regen', prof = 'regen' },
    { key = 'protect',   tiers = { 'Protect V', 'Protect IV', 'Protect III', 'Protect II', 'Protect' }, label = 'Pro', buff = 'Protect', prof = 'enh' },
    { key = 'shell',     tiers = { 'Shell V', 'Shell IV', 'Shell III', 'Shell II', 'Shell' }, label = 'Shl', buff = 'Shell', prof = 'enh' },
    { key = 'sneak',     tiers = { 'Sneak' },     label = 'Snk',  buff = 'Sneak',     prof = 'enh' },
    { key = 'invisible', tiers = { 'Invisible' }, label = 'Invi', buff = 'Invisible', prof = 'enh' },
};
local WHITE_ADD = {
    { key = 'poisona',  tiers = { 'Poisona' },  label = 'Pois', icon = 'Poison',        addendum = always },
    { key = 'paralyna', tiers = { 'Paralyna' }, label = 'Para', icon = 'Paralysis',     addendum = always },
    { key = 'blindna',  tiers = { 'Blindna' },  label = 'Blnd', icon = 'Blindness',     addendum = always },
    { key = 'silena',   tiers = { 'Silena' },   label = 'Sil',  icon = 'Silence',       addendum = always },
    { key = 'stona',    tiers = { 'Stona' },    label = 'Ston', icon = 'Petrification', addendum = always },
    { key = 'viruna',   tiers = { 'Viruna' },   label = 'Viru', icon = 'Disease',       addendum = always },
    { key = 'erase',    tiers = { 'Erase' },    label = 'Eras', icon = 'Slow',          addendum = always },
    { key = 'raise',    tiers = { 'Raise III', 'Raise II', 'Raise' }, label = 'Rais', icon = 'Reraise', addendum = not_raise1 },
    { key = 'reraise',  tiers = { 'Reraise III', 'Reraise II', 'Reraise' }, label = 'RR', icon = 'Reraise', addendum = always, self = true },
};
local ACC_COL = { 0.82, 0.78, 0.56, 1 };
local ADD_COL = { 0.62, 0.78, 0.92, 1 };

local function white_row(have)
    local busy = (run ~= nil);
    for n, w in ipairs(WHITE_ACC) do
        if (n > 1) then imgui.SameLine(0, 2); end
        local name = pick_tier(w);
        local cd = name and spell_recast(name) or 0;
        local hit = slot('##sb_acc_' .. w.key, {
            icon = buff_id(w.buff), col = ACC_COL, label = w.label, cd = cd,
            active = has_buff(w.buff), disabled = busy or name == nil,
        });
        if (hit == 1) then white_start(w, true); elseif (hit == 2) then white_start(w, false); end
        if (imgui.IsItemHovered()) then
            imgui.BeginTooltip();
            imgui.TextColored(GOLD, name or w.tiers[#w.tiers]);
            if (name == nil) then
                imgui.TextColored(BAD, "You don't know this spell.");
            else
                imgui.Text('Left-click: Accession + ' .. name .. ' (whole party, 1 stratagem).');
                imgui.Text('Right-click: just ' .. name .. (w.self and ' on you.' or ' - pick a party member.'));
                imgui.TextColored(DIM, 'Light Arts goes up first if it is down.');
                if (have < 1) then imgui.TextColored(BAD, 'No stratagems left for Accession.'); end
                gear_lines(w.prof);
            end
            imgui.EndTooltip();
        end
    end
    for n, w in ipairs(WHITE_ADD) do
        imgui.SameLine(0, (n == 1) and 12 or 2);
        local name = pick_tier(w);
        local cd = name and spell_recast(name) or 0;
        local hit = slot('##sb_add_' .. w.key, {
            icon = buff_id(w.icon), col = ADD_COL, label = w.label, cd = cd, disabled = busy or name == nil,
        });
        if (hit ~= nil) then white_start(w, false); end
        if (imgui.IsItemHovered()) then
            imgui.BeginTooltip();
            imgui.TextColored(GOLD, name or w.tiers[#w.tiers]);
            if (name == nil) then
                imgui.TextColored(BAD, "You don't know this spell.");
            else
                imgui.Text('Click: ' .. name .. (w.self and ' on you.' or ' - pick a party member.'));
                if (w.addendum(name) and not has_buff('Addendum: White')) then
                    imgui.TextColored(DIM, 'Puts Addendum: White up first (1 stratagem).');
                    if (have < 1) then imgui.TextColored(BAD, 'No stratagems left for Addendum: White.'); end
                end
            end
            imgui.EndTooltip();
        end
    end
end

-- Light and Dark books: switch Arts, and that book's stratagems as buttons beside them.
local BOOK_COL = { light = { 0.95, 0.90, 0.70, 1 }, dark = { 0.45, 0.35, 0.65, 1 } };
local STRATS = {
    light = {
        { 'Penury',          'Pen',  'Your next white magic spell costs half the MP.' },
        { 'Celerity',        'Cel',  'Your next white magic spell casts and recasts faster.' },
        { 'Accession',       'Acc',  'Your next healing or enhancing white magic spell also hits your party.' },
        { 'Rapture',         'Rap',  'Boosts the potency of your next white magic spell.' },
        { 'Addendum: White', 'AdW', 'Opens extra white magic (-na spells, Erase, Raise II, Reraise...).' },
        { 'Perpetuance',     'Prp', 'Doubles the duration of your next white enhancing spell.' },
    },
    dark = {
        { 'Parsimony',       'Par', 'Your next black magic spell costs half the MP.' },
        { 'Alacrity',        'Ala', 'Your next black magic spell casts and recasts faster.' },
        { 'Manifestation',   'Man', 'Your next enfeebling or dark magic spell also hits enemies around the target.' },
        { 'Ebullience',      'Ebu', 'Boosts the power of your next black magic spell.' },
        { 'Addendum: Black', 'AdB', 'Opens extra black magic (tier IV nukes and more).' },
        { 'Focalization',    'Foc', 'Your next black magic spell is more accurate.' },
        { 'Immanence',       'Imm',  'Your next elemental spell can open or close a skillchain.' },
    },
};

local function arts_side()
    if (has_buff('Light Arts') or has_buff('Addendum: White')) then return 'light'; end
    if (has_buff('Dark Arts') or has_buff('Addendum: Black')) then return 'dark'; end
    return nil;
end

-- Book: left-click = that Arts, right-click = that Arts + its Addendum.
local function book_start(side, addendum)
    if (run ~= nil) then say('Busy with ' .. run.sc.sc .. ' - wait for it or Stop.'); return; end
    local arts = (side == 'light') and 'Light Arts' or 'Dark Arts';
    local add = (side == 'light') and 'Addendum: White' or 'Addendum: Black';
    if (not addendum) then
        if (arts_side() == side) then say('Already in ' .. arts .. '.'); return; end
        cast('/ja "' .. arts .. '" <me>');
        return;
    end
    if (has_buff(add)) then say(add .. ' is already up.'); return; end
    if (stratagems() < 1) then say('No stratagems left for ' .. add .. '.'); return; end
    local steps = {};
    if (arts_side() ~= side) then steps[#steps + 1] = { cmd = '/ja "' .. arts .. '" <me>' }; steps[#steps + 1] = { wait = 1.5 }; end
    steps[#steps + 1] = { cmd = '/ja "' .. add .. '" <me>' };
    run = { sc = { sc = add }, steps = steps, i = 1, next_at = os.clock(), started = os.clock(), total = (#steps > 1) and 1.5 or 0 };
end

local function book_row(have, row_x)
    local busy = (run ~= nil);
    local side = arts_side();
    for n, b in ipairs({ { 'light', 'Light Arts', 'Addendum: White', 'LA' }, { 'dark', 'Dark Arts', 'Addendum: Black', 'DA' } }) do
        if (n > 1) then imgui.SameLine(0, 2); end
        local hit = slot('##sb_book_' .. b[1], {
            icon = buff_id(b[2]), col = BOOK_COL[b[1]], label = b[4], active = (side == b[1]), disabled = busy,
        });
        if (hit == 1) then book_start(b[1], false); elseif (hit == 2) then book_start(b[1], true); end
        if (imgui.IsItemHovered()) then
            imgui.BeginTooltip();
            imgui.TextColored(GOLD, b[2]);
            imgui.Text('Left-click: ' .. b[2] .. ' (free).');
            imgui.Text('Right-click: ' .. b[2] .. ' + ' .. b[3] .. ' (1 stratagem).');
            imgui.TextColored(DIM, 'Its stratagems show up next to the books while it is on.');
            if (side == b[1]) then imgui.TextColored(GOOD, 'On now.'); end
            imgui.EndTooltip();
        end
    end
    -- Line the stratagems up under the skillchain buttons.
    imgui.SameLine(0, 8);
    if (type(row_x) == 'number' and imgui.GetCursorPosX() < row_x) then imgui.SetCursorPosX(row_x); end
    if (side == nil) then
        imgui.TextColored(DIM, 'Pick a book (LA / DA) to see its stratagems.');
        return side;
    end
    for n, st in ipairs(STRATS[side]) do
        if (n > 1) then imgui.SameLine(0, 2); end
        local name = st[1];
        local on = has_buff(name);
        local hit = slot('##sb_strat_' .. side .. n, {
            icon = buff_id(name), col = BOOK_COL[side], label = st[2], active = on, disabled = busy or have < 1,
        });
        if (hit ~= nil and not on) then cast('/ja "' .. name .. '" <me>'); end
        if (imgui.IsItemHovered()) then
            imgui.BeginTooltip();
            imgui.TextColored(GOLD, name .. '  (1 stratagem)');
            imgui.Text(st[3]);
            if (on) then imgui.TextColored(GOOD, 'Up now - your next spell uses it.'); end
            if (have < 1) then imgui.TextColored(BAD, 'No stratagems left.'); end
            imgui.EndTooltip();
        end
    end
    return side;
end

local pos_saved_at = 0;

-- The bar itself. opts: { settings, save }
sb.render_bar = function (opts)
    local st = opts.settings or {};
    if (st.sch_bar == false or not is_sch()) then return; end
    local e = read_env();
    local have, max = stratagems();
    local w, dbl = your_weather(e);

    imgui.SetNextWindowPos({ st.sch_bar_x or 420, st.sch_bar_y or 520 }, ImGuiCond_FirstUseEver);
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 4);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 4, 4 });
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 3, 3 });
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.06, 0.06, 0.07, 0.88 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.32, 0.30, 0.26, 1 });
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_AlwaysAutoResize);
    if (imgui.Begin('SCH Bar##omni_schbar', true, flags)) then
        local ok, err = pcall(function ()
            -- One bar: the readout, every Magic Burst chain, the storms, Klimaform.
            imgui.BeginGroup();
            if (run ~= nil) then
                local p = math.min(1, (os.clock() - run.started) / math.max(1, run.total));
                imgui.ProgressBar(p, { 74, 16 }, run.sc.sc);
                imgui.PushStyleColor(ImGuiCol_Button, { 0.55, 0.20, 0.18, 1 });
                if (imgui.Button('Stop##sb_stop', { 74, 18 })) then sb.stop(); end
                imgui.PopStyleColor(1);
            else
                if (last_msg.text ~= nil and os.clock() - last_msg.at < 6) then
                    imgui.TextColored(BAD, 'Can\'t');
                    if (imgui.IsItemHovered()) then imgui.SetTooltip(last_msg.text); end
                elseif (w ~= nil) then
                    imgui.TextColored(lighten(EL[w].col, 1.4), EL[w].name .. (dbl and ' x2' or ''));
                    if (imgui.IsItemHovered()) then imgui.SetTooltip('Your weather' .. (e.storm and ' (from your storm)' or ' (the zone)') .. (e.day and ('\nDay: ' .. EL[e.day].day) or '')); end
                else
                    imgui.TextColored(DIM, 'No weather');
                    if (imgui.IsItemHovered() and e.day) then imgui.SetTooltip('Day: ' .. EL[e.day].day); end
                end
                imgui.TextColored(have >= 2 and GOOD or BAD, ('Strats %d/%d'):format(have, max));
            end
            imgui.EndGroup();

            imgui.SameLine(0, 8);
            local row_x = imgui.GetCursorPosX();
            mb_row(e, have);
            storm_row(e);

            imgui.SameLine(0, 12);
            local kcd = spell_recast('Klimaform');
            local hit = slot('##sb_klima', { icon = ICON.klimaform, col = { 0.40, 0.40, 0.46, 1 }, label = 'Klim', cd = kcd, disabled = not knows('Klimaform') });
            if (hit ~= nil and kcd <= 0) then cast('/ma "Klimaform" <me>'); end
            if (imgui.IsItemHovered()) then
                imgui.SetTooltip('Klimaform: +15 magic accuracy for spells that match your weather.\n5 min, 3 min recast, 30 MP. Cast it after your storm, before the burst.');
            end

            -- Second row: the Light / Dark books and that book's stratagems.
            local side = book_row(have, row_x);
            -- Third row: white magic, while Light Arts / Addendum: White is up (or always, in Options).
            if (side == 'light' or opt('sch_bar_white_always', false)) then
                if (type(row_x) == 'number') then imgui.SetCursorPosX(row_x); end
                white_row(have);
            end

            -- Remember where it was dragged to.
            local x, y = imgui.GetWindowPos();
            if (type(x) == 'number' and (math.floor(x) ~= st.sch_bar_x or math.floor(y) ~= st.sch_bar_y)
                and not imgui.IsMouseDown(0) and os.clock() - pos_saved_at > 1) then
                st.sch_bar_x, st.sch_bar_y = math.floor(x), math.floor(y);
                pos_saved_at = os.clock();
                if (opts.save) then pcall(opts.save); end
            end
        end);
        if (not ok) then imgui.TextColored(BAD, 'SCH bar: ' .. tostring(err)); end
    end
    imgui.End();
    imgui.PopStyleColor(2);
    imgui.PopStyleVar(3);
end

----------------------------------------------------------------------------------------------------
-- Tools > SCH Bar: the switch and a short guide
----------------------------------------------------------------------------------------------------
local GUIDE = {
    { 'Storms', {
        'A storm gives the target single weather of its element for as long as it lasts.',
        "It replaces the zone's weather for that person - it does not add to it. In double weather of your",
        'element (e.g. Dynamis dark), leave the storm off: you would drop from double to single.',
        'Each storm gives a stat with Stormsurge merits: Hailstorm INT is the one for nuking.',
        'Right-click a storm to give it to the whole party for twice as long (Accession + Perpetuance, 2 stratagems).',
    } },
    { 'Obi and day', {
        'Weather and day only sometimes boost a spell. The element obi (or Hachirin-no-Obi) makes it every time.',
        'Storm + obi = always +10% on that element. If it is also that element\'s day: +20%.',
        'So: cast the storm for today\'s element and burst with that element when the chain allows.',
        'Helixes always get the day/weather bonus without the obi - no need to swap it in for them.',
    } },
    { 'Klimaform', {
        '+15 magic accuracy for spells that match your weather (5 min, 3 min recast, 30 MP).',
        'Order: storm on yourself, then Klimaform, then the skillchain. Fewer resists on the burst.',
    } },
    { 'Skillchains (Immanence)', {
        'Each skillchain uses 2 stratagems. On CatsEyeXI you have 5 at 75 (the game only shows 4),',
        'one comes back every 48 s - so 2 chains back to back, then about a minute and a half to refill.',
        'The bar won\'t start a chain with fewer than 2, and won\'t start a second while one is running.',
        'A * on a burst button: its element matches your weather. A * on a storm: it matches today.',
    } },
    { 'Books and stratagems', {
        'Light book / Dark book: left-click switches Arts (free); right-click also puts that Addendum up (1 stratagem).',
        'The stratagems of the book you are in show beside them - click one to use it (1 stratagem each).',
        'A green border = that Arts or stratagem is on you now.',
    } },
    { 'White row (Light Arts / Addendum: White)', {
        'Gold boxes: left-click = Accession + the spell on the whole party (1 stratagem); right-click = just the spell.',
        'Blue boxes: the -na spells, Erase, Raise and Reraise. Click, then pick the party member.',
        'Addendum: White goes up by itself when one of these needs it (1 stratagem). Greyed out = you do not know it.',
        'A green border on a gold box: that buff is on you now.',
    } },
    { 'Picking a chain', {
        'Burst with the element the monster is weak to (see the monster info strip).',
        'If two chains burst the same element, pick the one whose burst also matches your storm.',
        'With Stormsurge merits, Hailstorm also gives INT - handy for ice bursts.',
    } },
};

sb.render_page = function (opts)
    local st = opts.settings or {};
    local on = { st.sch_bar ~= false };
    if (imgui.Checkbox('Show the SCH bar while I am Scholar##sb_on', on)) then
        st.sch_bar = on[1];
        if (opts.save) then pcall(opts.save); end
    end
    imgui.SameLine();
    imgui.TextColored(DIM, '(/schbar turns it on and off)');
    if (not is_sch()) then imgui.TextColored(DIM, 'You are not Scholar right now, so the bar is hidden.'); end
    imgui.Spacing();
    imgui.TextColored(GOLD, 'Before each skillchain the bar gets you ready:');
    local function box(key, default, label, tip)
        local v = { (st[key] == nil) and default or st[key] };
        if (imgui.Checkbox(label .. '##sb_' .. key, v)) then st[key] = v[1]; if (opts.save) then pcall(opts.save); end end
        if (imgui.IsItemHovered()) then imgui.SetTooltip(tip); end
    end
    imgui.TextColored(DIM, 'Dark Arts goes up first if it is down (Immanence needs it).');
    box('sch_bar_addendum', true, 'Addendum: Black for tier IV bursts',
        'Puts Addendum: Black up when the burst is a tier IV and it is down.\nIt uses a stratagem, so only when you have 3 or more; otherwise the burst drops to tier III.');
    box('sch_bar_storm', true, 'Storm for the burst element',
        'Casts the matching storm on you first (e.g. Hailstorm for an ice burst), unless it is already on\nor the zone has double weather of that element (better than a storm).\nWith the storm on, an elemental obi (or Hachirin-no-Obi) in your nuke set always gets its bonus.');
    box('sch_bar_party', true, 'Say the chain in party chat',
        'Built-in chains say "Starting Distortion - Magic Burst Ice!" and "Distortion closing - burst Ice now!" in /p.\n(Your own scripts in scripts\\sc_*.txt say whatever you wrote in them.)');
    box('sch_bar_klima', false, 'Klimaform too (adds about 8 s)',
        '+15 magic accuracy on the burst. It has a 7 s cast, so it slows the chain down - off by default.');
    imgui.TextColored(DIM, 'The burst spell is the best tier you can cast at that moment (off recast, Addendum up).');
    imgui.Spacing();
    imgui.TextColored(GOLD, 'Gear and the white row:');
    box('sch_bar_gear', true, 'Swap in gear that helps the spell, then put my gear back',
        'Looks through your inventory and wardrobes for pieces that help the spell (from their descriptions):\nStoneskin: MND, Enhancing skill, Stoneskin+.  Phalanx: Enhancing skill, Phalanx+.  Regen: Regen potency.\nProtect, Shell, Blink, Sneak, Invisible: enhancing duration.  Bursts: INT, Magic Atk. Bonus, Elemental skill, obi.\nOnly pieces better than what you have on go on, weapons are never touched, and your old gear goes back\nas soon as the cast lands (or is interrupted).');
    box('sch_bar_burst_gear', true, 'Nuke gear for the skillchain burst',
        'Puts on your best INT / Magic Atk. Bonus pieces just before the burst, plus the matching obi\n(or Hachirin-no-Obi) when your weather or the day is that element.');
    box('sch_bar_white_always', false, 'Always show the white row',
        'Off: the white row (Accession buffs, -na, Raise) shows while Light Arts or Addendum: White is up.');
    imgui.Spacing();
    for _, sec in ipairs(GUIDE) do
        imgui.TextColored(GOLD, sec[1]);
        for _, l in ipairs(sec[2]) do imgui.TextWrapped(l); end
        imgui.Spacing();
    end
end

-- /schbar
sb.settings = nil;
sb.save = nil;
ashita.events.register('command', 'omni_schbar_cmd', function (e)
    local c = (e.command or ''):lower();
    if (c ~= '/schbar' and c:find('^/schbar%s') == nil) then return; end
    e.blocked = true;
    if (c:find('stop') ~= nil) then sb.stop(); return; end
    if (sb.settings == nil) then return; end
    sb.settings.sch_bar = (sb.settings.sch_bar == false);
    if (sb.save) then pcall(sb.save); end
    print('[omni] SCH bar ' .. (sb.settings.sch_bar and 'on' or 'off') .. '.');
end);

sb.scripts = load_scripts;   -- the list, for other pages
sb.start = start;

return sb;
