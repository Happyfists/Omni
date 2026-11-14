--[[
    omni_schbar.lua - Scholar click bar.

    One action bar on screen while you are Scholar (like a WoW bar), square boxes in a row:

        Ice x2 / Strats 4/5 | 16 Magic Burst chains, grouped by burst element | 8 storms | Klimaform

    Magic Burst: 16 skillchains built in (Immanence opener + closer, then the burst). If you have your
    own script for one in VanaCore's scripts\sc_<name>.txt, that runs instead. omni runs each chain
    itself, line by line with its /waits, so a click can never go off twice. Buttons are coloured by the
    element you burst with; a star marks the ones that match your weather right now.
    Storms: the eight storm spells. Left-click casts it on you, right-click on a party member
    (<stpc>). The one that matches today's day is marked: storm + matching obi + day = +20%.

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
    for _, s in ipairs(sc.steps) do steps[#steps + 1] = s; end
    run = { sc = sc, steps = steps, i = 1, next_at = os.clock(), started = os.clock(), total = sc.total + prep,
            addendum = addendum };
end

sb.stop = function () if (run ~= nil) then say('Stopped ' .. run.sc.sc .. '.'); end run = nil; end

local function tick()
    if (run == nil) then return; end
    local now = os.clock();
    -- One command per frame; waits just move the clock on.
    while (run ~= nil and now >= run.next_at) do
        local step = run.steps[run.i];
        if (step == nil) then run = nil; break; end
        if (step.until_buff ~= nil) then
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
        if (hit == 2 and cd <= 0) then cast(('/ma "%s" <stpc>'):format(name)); end
        if (imgui.IsItemHovered()) then
            imgui.BeginTooltip();
            imgui.TextColored(GOLD, name);
            imgui.Text('Left-click: on you.   Right-click: pick a party member.');
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
            mb_row(e, have);
            storm_row(e);

            imgui.SameLine(0, 12);
            local kcd = spell_recast('Klimaform');
            local hit = slot('##sb_klima', { icon = ICON.klimaform, col = { 0.40, 0.40, 0.46, 1 }, label = 'Klim', cd = kcd, disabled = not knows('Klimaform') });
            if (hit ~= nil and kcd <= 0) then cast('/ma "Klimaform" <me>'); end
            if (imgui.IsItemHovered()) then
                imgui.SetTooltip('Klimaform: +15 magic accuracy for spells that match your weather.\n5 min, 3 min recast, 30 MP. Cast it after your storm, before the burst.');
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
