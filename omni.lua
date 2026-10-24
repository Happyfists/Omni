--[[
    omni - all-in-one addon for CatsEyeXI (Ashita v4), by Happyfists.

    On screen
      * Main bar: job picture with main/sub levels, XP/LP counter on a fill bar (XP/hr), chain, wallet,
        Follow button. In Abyssea it shows Visitant time and lights instead.
      * Sneak / Invisible buttons on the bar: magic, ninjutsu, Spectral Jig or Silent Oil / Prism
        Powder, whichever you can use (omni_stealth.lua).
      * Looks (Options > Look): Crystal & Gold, Classic, and themes (THEMES in omni.lua, themes/<id>.lua
        for the Trove screens): Obsidian & Gold, Slate Minimal, Crimson Night, Emerald Grove, Amethyst, Frost.
      * Row under it: your buffs (left) and the target bar (right): name, HP, TH, distance, target's buffs.
      * Party jobs: see-through columns of FFXI job pictures beside the game's party and alliance
        lists; each grows upwards as people join (omni_party.lua, assets/jobs/ from HXUI).
      * Brighter chat colours for party, linkshells and tells (omni_chatcolors.lua; Options).
      * Happy Talks: spoken alerts (tells, invites, trades, skill-ups...) with 16 voice packs
        (omni_talks.lua, assets/alerts/; Options > Happy Talks). Based on chatmon by atom0s.
      * Spell lines: targetlines-style lines with an animation per element - lightning, fireballs,
        ice shards, cures... (omni_fx.lua, maths from Jyouya's targetlines; Options, /omni fx).
      * Pop-out: the Abyssea proc tracker.
      * Happy Healer is now its own addon (happyhealer) - not part of omni.
      * Panel (drops down under the bars): tabs in two rows, then the chosen tab's page.

    Panel tabs (and the file that draws each one)
      Top row
        Abyssea    - Procs (+ pop-out), NM Pops and Weapons (omni_abyssea.lua, omni_abypops.lua, omni_abyweapons.lua, abydata/)
        Quests     - Journey overview, quests by region, mission storylines (omni_quests.lua, qdata/)
        Multisend  - Follow Me, sim-cast and quick commands (omni_multisend.lua)
        Damage     - Simple meter and Advanced breakdown (this file, omni_damage.lua, omni_action.lua)
      Second row
        Character  - Trove's Profile (jobs + AF/Relic armour, crafts, skills), its Magic screen, and Craftbook under Crafts
                     (plugins/profile.lua, plugins/scrolls.lua, omni_craftbook.lua + craft_recipes.lua)
        Currency   - Currency and Points (Trove: core/currency.lua, core/points.lua)
        Dailies, Codex - Trove screens (trove_host.lua, plugins/)
        Sky        - Sky / Sky 2.0 / Pops: pop items, god drops, the server's !pops list (omni_sky.lua)
        Sea        - Sea (Lumoria) and AV, the Absolute Virtue helper (plugins/lumoria.lua, omni_av.lua)
        Ventures   - Ventures and VNM Armor (omni_ventures.lua, plugins/vnm.lua)
        Sparks     - Sparks shop and Sell It (omni_sparks.lua, omni_sell.lua)
        Options    - AV helper (Al'Taieu only / everywhere / off), bars, native buff icons, party job pictures,
                     pop-outs, Follow Me
        TH         - Treasure Hunter per monster ("NAME lands THn on MOB" in party), TH on the target bar (omni_th.lua)
      The row layout is TAB_ROWS in this file.

    Credits (licences in this folder)
      * Bar style and job icon sheet adapted from the points addon by Shinzaku, based on Pointwatch by
        Byrthnoth (BSD-style licence, POINTS_LICENSE).
      * Trove by Loxley (TROVE_LICENSE).
      * AVHelper by ClutchHawks (AVHELPER_LICENSE).
      * Quest / mission data and storyline pictures from FFXI Journal by AndreYMods (JOURNAL_LICENSE).
      * TH helper idea from easyTH by Arielfy. Spell lines based on targetlines by Jyouya.
      * Abyssea status, NM / pop / drop data (abydata/) from Abyssea Tracker - CatsEyeXI Edition by
        IntegReady, and Abystagger by Laudout.
      * FFXI job pictures (assets/jobs/) from HXUI by Team HXUI (MIT, HXUI_LICENSE).
      * Craftbook by Happys (github.com/Happyfists/Craftbook); recipes from the LandSandBoat database (GNU GPL v3).
]]

addon.name    = 'omni';
addon.author  = 'Happyfists';
addon.version = '3.12';
addon.desc    = 'All-in-one addon.';

require('common');
local imgui    = require('imgui');
local settings = require('settings');
local ffi      = require('ffi');
local d3d      = require('d3d8');

----------------------------------------------------------------------------------------------------
-- Settings (saved per character by Ashita)
----------------------------------------------------------------------------------------------------
local default_settings = T{
    deeps_top = 5,      -- how many damage dealers the Deeps tab lists
    bar_x = 130,
    bar_y = 60,
    -- "Vana'diel classic": navy panels with gold trim. These are not saved; edit them here.
    colors = T{
        text       = { 0.96, 0.96, 0.98, 1.0 },
        bg         = { 0.055, 0.075, 0.16, 0.90 },    -- bars
        panel      = { 0.045, 0.060, 0.14, 0.95 },    -- drop-down panel
        border     = { 0.79, 0.69, 0.42, 1.0 },       -- gold trim
        button     = { 0.13, 0.17, 0.34, 1.0 },
        hover      = { 0.24, 0.30, 0.52, 1.0 },
        heading    = { 0.91, 0.84, 0.59, 1.0 },       -- pale gold
        label      = { 0.91, 0.84, 0.59, 1.0 },       -- "HP", "LP" and other labels
        dim        = { 0.62, 0.66, 0.80, 1.0 },       -- secondary text
        tab        = { 0.10, 0.13, 0.27, 1.0 },
        tab_active = { 0.60, 0.51, 0.27, 1.0 },
        bar_bg     = { 0.02, 0.04, 0.11, 1.0 },       -- the empty part of a bar
        hp         = { 0.86, 0.20, 0.20, 1.0 },       -- red
        mp         = { 0.24, 0.48, 0.92, 1.0 },       -- blue
        tp         = { 0.80, 0.62, 0.18, 1.0 },       -- gold
        tp_ready   = { 1.00, 0.82, 0.30, 1.0 },       -- bright gold at 1000+
        xp         = { 0.86, 0.69, 0.34, 1.0 },
    },
};

local omni = T{
    settings  = settings.load(default_settings, 'omni'),   -- own file; the Dailies tab uses the default one
    expanded  = false,       -- is the drop-down panel open?
    bar_width = 400,         -- measured each frame so the panel can match it
    active    = nil,         -- the tab showing in the panel
    exp_h     = 0,           -- height of the XP bar this frame
    target_h  = 0,           -- height of the target bar this frame (0 when there is no target)
    bar_open  = { true, },
    icons     = nil,         -- job icon texture, nil if it could not be loaded
    suffix    = '',
};

-- The look is fixed in code, so colours from an older saved file never override it.
omni.settings.colors = default_settings.colors;

-- A rounded bar: dark outline, dark empty part, coloured fill with a lighter gloss along the top.
local BAR_HEIGHT = 32;

-- Look: 'crystal' (thin gold lines, slim bars - design B, the default) or 'classic' (the rounded pills).
local function crystal() return omni.settings.look ~= 'classic'; end
-- Black & Gold (on trial): the Crystal bar, but tabs without a painted background get near-black
-- panels, grey pill buttons and bright gold for the chosen ones (like the Self Chains window).
local GOLD     = { 0.90, 0.77, 0.42, 1.0 };
local GOLD_DIM = { 0.90, 0.77, 0.42, 0.35 };

-- Themes (Options > Look). 'crystal' and 'classic' are the original looks; every other look is a
-- set of colours used for the bar, the row under it, the panel and every tab without a painted
-- background (Sea and Sky keep their pictures). style: 'card' = rounded, 'flat' = square 1px lines.
--   bg: panel  bar: bar / row  line: borders  accent: highlights and chosen tabs  pill: buttons
--   hover: buttons under the mouse  inner: boxes inside pages  tint: what navy colours turn into
local THEMES = {
    blackgold = { label = 'Obsidian & Gold', style = 'card', radius = 8,
        bg = { 0.086, 0.086, 0.090, 0.97 }, bar = { 0.070, 0.070, 0.075, 0.96 }, line = { 0.20, 0.20, 0.21, 1.0 },
        accent = { 0.91, 0.73, 0.29, 1.0 }, pill = { 0.150, 0.150, 0.165, 1.0 }, hover = { 0.215, 0.215, 0.235, 1.0 },
        inner = { 0.062, 0.062, 0.066, 1.0 }, tint = { 1.00, 1.00, 1.03 } },
    slate = { label = 'Slate Minimal', style = 'flat', radius = 0,
        bg = { 0.078, 0.086, 0.094, 0.95 }, bar = { 0.070, 0.078, 0.086, 0.95 }, line = { 0.18, 0.196, 0.212, 1.0 },
        accent = { 0.37, 0.83, 0.78, 1.0 }, pill = { 0.140, 0.155, 0.170, 1.0 }, hover = { 0.190, 0.210, 0.230, 1.0 },
        inner = { 0.060, 0.067, 0.075, 1.0 }, tint = { 0.97, 1.00, 1.04 } },
    crimson = { label = 'Crimson Night', style = 'card', radius = 8,
        bg = { 0.092, 0.070, 0.075, 0.97 }, bar = { 0.078, 0.058, 0.062, 0.96 }, line = { 0.26, 0.17, 0.18, 1.0 },
        accent = { 0.88, 0.36, 0.38, 1.0 }, pill = { 0.175, 0.130, 0.140, 1.0 }, hover = { 0.245, 0.175, 0.190, 1.0 },
        inner = { 0.066, 0.050, 0.054, 1.0 }, tint = { 1.06, 0.96, 0.97 } },
    emerald = { label = 'Emerald Grove', style = 'card', radius = 8,
        bg = { 0.060, 0.086, 0.074, 0.97 }, bar = { 0.050, 0.072, 0.062, 0.96 }, line = { 0.15, 0.25, 0.20, 1.0 },
        accent = { 0.38, 0.82, 0.56, 1.0 }, pill = { 0.110, 0.170, 0.140, 1.0 }, hover = { 0.150, 0.230, 0.190, 1.0 },
        inner = { 0.045, 0.066, 0.056, 1.0 }, tint = { 0.95, 1.05, 1.00 } },
    amethyst = { label = 'Amethyst', style = 'card', radius = 8,
        bg = { 0.086, 0.070, 0.112, 0.97 }, bar = { 0.072, 0.058, 0.096, 0.96 }, line = { 0.23, 0.18, 0.31, 1.0 },
        accent = { 0.74, 0.58, 0.96, 1.0 }, pill = { 0.160, 0.130, 0.210, 1.0 }, hover = { 0.220, 0.180, 0.290, 1.0 },
        inner = { 0.060, 0.050, 0.080, 1.0 }, tint = { 1.00, 0.96, 1.10 } },
    frost = { label = 'Frost', style = 'card', radius = 10,
        bg = { 0.070, 0.090, 0.115, 0.96 }, bar = { 0.060, 0.078, 0.100, 0.95 }, line = { 0.22, 0.30, 0.38, 1.0 },
        accent = { 0.55, 0.80, 1.00, 1.0 }, pill = { 0.130, 0.165, 0.205, 1.0 }, hover = { 0.180, 0.225, 0.280, 1.0 },
        inner = { 0.050, 0.066, 0.086, 1.0 }, tint = { 0.94, 1.00, 1.12 } },
};
-- Order shown in Options > Look.
local LOOK_ORDER = { 'crystal', 'blackgold', 'slate', 'crimson', 'emerald', 'amethyst', 'frost', 'classic' };
local LOOK_LABEL = { crystal = 'Crystal & Gold', classic = 'Classic' };
for id, t in pairs(THEMES) do
    LOOK_LABEL[id] = t.label;
    -- Accent buttons are a touch darker than the accent so their light text stays readable.
    t.btn = { t.accent[1] * 0.78, t.accent[2] * 0.78, t.accent[3] * 0.78, 1.0 };
end
local function theme() return THEMES[omni.settings.look]; end
local function black_tab() return theme() ~= nil and omni.active ~= nil and omni.active.bg == nil; end
-- GOLD / GOLD_DIM follow the theme's accent, so every gold heading and chosen tab changes with it.
local GOLD_BASE = { GOLD[1], GOLD[2], GOLD[3] };
local function apply_accent()
    local t = theme();
    local a = t and t.accent or GOLD_BASE;
    GOLD[1], GOLD[2], GOLD[3] = a[1], a[2], a[3];
    GOLD_DIM[1], GOLD_DIM[2], GOLD_DIM[3] = a[1], a[2], a[3];
end
omni.theme = theme;
-- A themed frame: soft shadow, body, 1px line and a faint highlight along the top.
local function theme_frame(dl, x1, y1, x2, y2, fill)
    local t = theme();
    if (t == nil) then return; end
    local r = math.min(t.radius, math.floor((y2 - y1) / 2));
    local u = imgui.GetColorU32;
    if (t.style ~= 'flat') then
        dl:AddRectFilled({ x1 + 1, y1 + 3 }, { x2 + 1, y2 + 4 }, u({ 0, 0, 0, 0.35 }), r);
    end
    dl:AddRectFilled({ x1, y1 }, { x2, y2 }, u(fill or t.bar), r);
    -- Outline in the theme's accent (like Crystal's gold edge), with a faint second line inside it.
    local ac = t.accent;
    dl:AddRect({ x1, y1 }, { x2, y2 }, u({ ac[1], ac[2], ac[3], 0.80 }), r);
    if (y2 - y1 > 14) then
        local ri = math.max(0, r - 3);
        dl:AddRect({ x1 + 3, y1 + 3 }, { x2 - 3, y2 - 3 }, u({ ac[1], ac[2], ac[3], 0.18 }), ri);
    end
    dl:AddLine({ x1 + r + 4, y1 + 1 }, { x2 - r - 4, y1 + 1 }, u({ 1, 1, 1, 0.06 }), 1);
end
omni.theme_frame = theme_frame;

-- A slim flat bar (Crystal look): empty track, filled part, nothing rounded.
local function draw_line_bar(dl, x1, y1, x2, y2, fraction, color)
    fraction = math.max(0, math.min(1, fraction or 0));
    dl:AddRectFilled({ x1, y1 }, { x2, y2 }, imgui.GetColorU32({ 0.15, 0.17, 0.25, 1.0 }));
    if (fraction > 0) then
        dl:AddRectFilled({ x1, y1 }, { x1 + (x2 - x1) * fraction, y2 }, imgui.GetColorU32(color));
    end
end


-- Ornate frame (Crystal look, from the "ornate gold" + "crystal" concepts): a navy glass body with
-- either pointed ends ('point', for bars) or cut corners ('bevel', for panels), a double gold rule,
-- a faint crystal sheen across the top and small gold diamonds as ornaments.
local function u32(c) return imgui.GetColorU32(c); end
local function diamond(dl, cx, cy, r, col)
    dl:AddTriangleFilled({ cx - r, cy }, { cx, cy - r }, { cx + r, cy }, u32(col));
    dl:AddTriangleFilled({ cx - r, cy }, { cx + r, cy }, { cx, cy + r }, u32(col));
end
local function ornate(dl, x1, y1, x2, y2, kind, fill, c)
    fill = fill or { 0.035, 0.055, 0.13, 0.93 };
    local h = y2 - y1;
    local ym = y1 + h / 2;
    local pts;
    if (kind == 'point') then
        c = c or math.floor(h / 2);
        dl:AddRectFilled({ x1 + c, y1 }, { x2 - c, y2 }, u32(fill));
        dl:AddTriangleFilled({ x1 + c, y1 }, { x1, ym }, { x1 + c, y2 }, u32(fill));
        dl:AddTriangleFilled({ x2 - c, y1 }, { x2 - c, y2 }, { x2, ym }, u32(fill));
        pts = { { x1 + c, y1 }, { x2 - c, y1 }, { x2, ym }, { x2 - c, y2 }, { x1 + c, y2 }, { x1, ym } };
    else
        c = c or 10;
        dl:AddRectFilled({ x1 + c, y1 }, { x2 - c, y2 }, u32(fill));
        dl:AddRectFilled({ x1, y1 + c }, { x1 + c, y2 - c }, u32(fill));
        dl:AddRectFilled({ x2 - c, y1 + c }, { x2, y2 - c }, u32(fill));
        dl:AddTriangleFilled({ x1 + c, y1 }, { x1, y1 + c }, { x1 + c, y1 + c }, u32(fill));
        dl:AddTriangleFilled({ x2 - c, y1 }, { x2 - c, y1 + c }, { x2, y1 + c }, u32(fill));
        dl:AddTriangleFilled({ x1, y2 - c }, { x1 + c, y2 }, { x1 + c, y2 - c }, u32(fill));
        dl:AddTriangleFilled({ x2, y2 - c }, { x2 - c, y2 - c }, { x2 - c, y2 }, u32(fill));
        pts = { { x1 + c, y1 }, { x2 - c, y1 }, { x2, y1 + c }, { x2, y2 - c }, { x2 - c, y2 }, { x1 + c, y2 }, { x1, y2 - c }, { x1, y1 + c } };
    end
    -- crystal sheen on the upper part
    dl:AddRectFilled({ x1 + c, y1 + 2 }, { x2 - c, y1 + math.floor(h * 0.42) }, u32({ 0.55, 0.75, 1.00, 0.045 }));
    -- double gold rule: bright outer line, faint inner line
    for i = 1, #pts do
        local a, b = pts[i], pts[(i % #pts) + 1];
        dl:AddLine(a, b, u32({ 0.90, 0.77, 0.42, 0.85 }), 1.2);
    end
    if (kind ~= 'point') then
        local k = 4;
        dl:AddLine({ x1 + c + 2, y1 + k }, { x2 - c - 2, y1 + k }, u32({ 0.90, 0.77, 0.42, 0.22 }), 1);
        dl:AddLine({ x1 + c + 2, y2 - k }, { x2 - c - 2, y2 - k }, u32({ 0.90, 0.77, 0.42, 0.22 }), 1);
        -- corner ornaments
        for _, q in ipairs({ { x1 + c / 2 + 1, y1 + c / 2 + 1 }, { x2 - c / 2 - 1, y1 + c / 2 + 1 }, { x1 + c / 2 + 1, y2 - c / 2 - 1 }, { x2 - c / 2 - 1, y2 - c / 2 - 1 } }) do
            diamond(dl, q[1], q[2], 3, { 0.95, 0.83, 0.50, 1.0 });
        end
        -- centre crest on the top edge
        diamond(dl, (x1 + x2) / 2, y1, 4, { 0.95, 0.83, 0.50, 1.0 });
        diamond(dl, (x1 + x2) / 2, y1, 2, { 0.45, 0.70, 1.00, 1.0 });
    else
        -- gem at each pointed end
        diamond(dl, x1 + 4, ym, 3, { 0.95, 0.83, 0.50, 1.0 });
        diamond(dl, x2 - 4, ym, 3, { 0.95, 0.83, 0.50, 1.0 });
        dl:AddLine({ x1 + c, y1 + 3 }, { x2 - c, y1 + 3 }, u32({ 0.90, 0.77, 0.42, 0.20 }), 1);
        dl:AddLine({ x1 + c, y2 - 3 }, { x2 - c, y2 - 3 }, u32({ 0.90, 0.77, 0.42, 0.20 }), 1);
    end
end
omni.ornate = ornate;

local function draw_pill(dl, x1, y1, x2, y2, fraction, color)
    local c = omni.settings.colors;
    local h = y2 - y1;
    local round = h / 2;
    fraction = math.max(0, math.min(1, fraction));

    dl:AddRectFilled({ x1 - 1, y1 - 1 }, { x2 + 1, y2 + 1 }, imgui.GetColorU32({ 0.0, 0.0, 0.0, 1.0 }), round + 1);
    dl:AddRectFilled({ x1, y1 }, { x2, y2 }, imgui.GetColorU32(c.bar_bg), round);
    if (fraction > 0) then
        local fx = x1 + math.max((x2 - x1) * fraction, h);
        dl:AddRectFilled({ x1, y1 }, { fx, y2 }, imgui.GetColorU32(color), round);
        dl:AddRectFilled({ x1 + 2, y1 + 1 }, { fx - 2, y1 + h * 0.45 }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.22 }), round);
    end
end

settings.register('omni', 'omni_settings_update', function (s)
    if (s ~= nil) then
        omni.settings = s;
        omni.settings.colors = default_settings.colors;
    end
    settings.save('omni');
end);

-- The Trove screens shown in the drop-down (see trove_host.lua).
local trove = require('trove_host');

----------------------------------------------------------------------------------------------------
-- XP tracking (same method as points)
----------------------------------------------------------------------------------------------------
local xp = T{
    ready     = false,  -- have the starting values been read yet?
    curr      = 0,      -- XP on the current level
    max       = 0,      -- XP needed for the level
    limit     = 0,      -- limit points towards the next merit
    kills     = T{},    -- recent kills, used for the per-hour estimate
    last_kill = 0,
    chain     = 0,
    timer     = 0,      -- seconds left to keep the chain
    per_hour  = 0,
    tick      = 0,
};

-- Seconds allowed to continue a chain, by level, for chain #0 to #5+.
local chain_timers = T{
    { lvl = 10, maxtime = { 80, 80, 60, 40, 30, 15, }, },
    { lvl = 20, maxtime = { 130, 130, 110, 80, 60, 25, }, },
    { lvl = 30, maxtime = { 160, 150, 120, 90, 60, 30, }, },
    { lvl = 40, maxtime = { 200, 200, 170, 130, 80, 40, }, },
    { lvl = 50, maxtime = { 290, 290, 230, 170, 110, 50, }, },
    { lvl = 99, maxtime = { 300, 300, 240, 180, 120, 60, }, },
};

local chain_color = { 0.91, 0.91, 0.23, 1.0 };
local ICON_CHAIN  = '\xef\x83\x81';

local function abbreviate(val)
    if (val >= 1000000) then
        return string.format('%.1fM', val / 1000000);
    elseif (val >= 100000) then
        return string.format('%.1fK', val / 1000);
    end
    return string.format('%d', val);
end

local function xp_init(player)
    xp.curr  = player:GetExpCurrent();
    xp.max   = player:GetExpNeeded();
    xp.limit = player:GetLimitPoints();
    xp.tick  = math.floor(os.clock());
    xp.ready = true;
end

-- Called when an XP or limit point message arrives for us.
local function xp_gained(amount, chain, level)
    local now = os.clock();
    if (xp.last_kill ~= 0) then
        xp.kills:append({ time = now - xp.last_kill, xp = amount });
    else
        xp.kills:append({ time = 1, xp = amount });
    end
    if (#xp.kills > 50) then
        table.remove(xp.kills, 1);
    end
    xp.last_kill = now;
    xp.chain = chain;
    xp.timer = 60;
    for _, v in ipairs(chain_timers) do
        if (level <= v.lvl) then
            xp.timer = v.maxtime[math.min(chain, 5) + 1];
            break;
        end
    end

    xp.curr = xp.curr + amount;
    if (xp.max > 0 and xp.curr > xp.max) then
        xp.curr = xp.max - 1;
    end
    xp.limit = xp.limit + amount;
    if (xp.limit > 10000) then
        xp.limit = xp.limit - 10000;
    end
end

-- Once a second: run the chain timer down and refresh the per-hour estimate.
local function xp_tick()
    local now = math.floor(os.clock());
    if (now <= xp.tick) then
        return;
    end
    xp.tick = now;

    if (xp.timer > 0) then
        xp.timer = xp.timer - 1;
    else
        xp.chain = 0;
    end

    if (#xp.kills > 0) then
        local total_xp, total_time = 0, 0;
        for _, v in ipairs(xp.kills) do
            total_xp = total_xp + v.xp;
            total_time = total_time + v.time;
        end
        local avg_xp = total_xp / #xp.kills;
        local avg_time = (total_time + (os.clock() - xp.last_kill)) / (#xp.kills + 1);
        if (avg_time > 0) then
            xp.per_hour = (3600 / avg_time) * avg_xp;
        end
    end
end

local function draw_xp(player)
    local c = omni.settings.colors;
    -- Capped or locked XP goes to limit points instead.
    local limit_mode = (xp.curr == 55999 or player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked());
    local label = limit_mode and 'LP' or 'XP';

    -- "XP 4462/7100 (38358 XP/hr)" sits on a bar that fills as you level (or as limit points build).
    local value = limit_mode and string.format('%d/%d', xp.limit, 10000) or string.format('%d/%d', xp.curr, xp.max);
    local rate = string.format('(%s %s/hr)', abbreviate(xp.per_hour), label);
    local frac = limit_mode and (xp.limit / 10000) or ((xp.max > 0) and (xp.curr / xp.max) or 0);
    local chain = (xp.timer > 0) and string.format('%d (%s)', xp.chain,
        (math.floor(xp.timer / 60) > 0) and string.format('%dm %ds', math.floor(xp.timer / 60), xp.timer % 60) or string.format('%ds', xp.timer))
        or string.format('%d (0s)', xp.chain);
    local chain_col = (xp.timer > 0) and chain_color or c.dim;

    -- Everything is drawn at fixed spots from the real text size, so it all sits on one line
    -- and inside the bar whatever font size the game uses.
    local lw, vw, rw = imgui.CalcTextSize(label), imgui.CalcTextSize(value), imgui.CalcTextSize(rate);
    local _, th = imgui.CalcTextSize('Ag');
    th = math.floor(th or 14);
    local w = lw + 5 + vw + 6 + rw;
    local sx, sy = imgui.GetCursorScreenPos();
    local wx, wy = imgui.GetWindowPos();
    local ty = math.floor(wy + (BAR_HEIGHT - th) / 2);          -- text centred in the bar
    local dl = imgui.GetWindowDrawList();
    local y1, y2 = ty - 2, ty + th + 2;
    if (not crystal()) then draw_pill(dl, sx - 7, y1, sx + w + 7, y2, frac, { c.xp[1], c.xp[2], c.xp[3], 0.55 }); end
    local okh, over = pcall(imgui.IsMouseHoveringRect, { sx - 7, y1 }, { sx + w + 7, y2 });
    if (okh and over and not crystal()) then
        imgui.SetTooltip(string.format('%s %s  -  %d%%', label, value, math.floor(math.max(0, math.min(1, frac)) * 100)));
    end
    local function put(x, text, col)
        dl:AddText({ x + 1, ty + 1 }, imgui.GetColorU32({ 0, 0, 0, 0.6 }), text);
        dl:AddText({ x, ty }, imgui.GetColorU32(col), text);
    end
    if (crystal()) then
        -- Design B: "LP 9999/10000" left and "0 LP/hr - chain 0" right on one line, a thin gold bar under.
        local right = string.format('%s/hr  %s %s', (rate:gsub('[()]', ''):gsub('/hr', '')), ICON_CHAIN, chain);
        local left_w = lw + 5 + vw;
        local rw2 = imgui.CalcTextSize(right);
        local bw = math.max(260, left_w + 18 + rw2);
        local ty2 = wy + 5;
        local function put2(x, text, col) dl:AddText({ x, ty2 }, imgui.GetColorU32(col), text); end
        put2(sx, label, GOLD);
        put2(sx + lw + 5, value, c.text);
        put2(sx + bw - rw2, right, (xp.timer > 0) and chain_color or c.dim);
        local by = ty2 + th + 2;
        dl:AddRectFilled({ sx, by }, { sx + bw, by + 5 }, imgui.GetColorU32({ 0.10, 0.12, 0.20, 1.0 }));
        local ff = math.max(0, math.min(1, frac));
        if (ff > 0) then
            dl:AddRectFilled({ sx, by }, { sx + bw * ff, by + 5 }, imgui.GetColorU32(GOLD));
            dl:AddRectFilled({ sx, by }, { sx + bw * ff, by + 2 }, imgui.GetColorU32({ 1, 1, 1, 0.30 }));
        end
        dl:AddRect({ sx - 1, by - 1 }, { sx + bw + 1, by + 6 }, imgui.GetColorU32({ 0.90, 0.77, 0.42, 0.45 }));
        diamond(dl, sx + bw * ff, by + 2.5, 3.5, { 0.98, 0.92, 0.75, 1.0 });
        local okh2, over2 = pcall(imgui.IsMouseHoveringRect, { sx, wy }, { sx + bw, wy + BAR_HEIGHT });
        if (okh2 and over2) then
            imgui.SetTooltip(string.format('%s %s  -  %d%%', label, value, math.floor(math.max(0, math.min(1, frac)) * 100)));
        end
        imgui.Dummy({ bw, th });
        return;
    end
    local x = sx;
    put(x, label, c.label);                                   x = x + lw + 5;
    put(x, value, c.text);                                    x = x + vw + 6;
    put(x, rate, { 0.90, 0.92, 1.0, 1.0 });                    x = x + rw + 18;
    local cl = label .. ICON_CHAIN;
    put(x, cl, c.label);                                      x = x + imgui.CalcTextSize(cl) + 5;
    put(x, chain, chain_col);                                 x = x + imgui.CalcTextSize(chain);
    imgui.Dummy({ x - sx, th });
end

----------------------------------------------------------------------------------------------------
-- Sparks, unity accolades and gil (same method as points)
----------------------------------------------------------------------------------------------------
local wallet = T{
    ready     = false,
    sparks    = 0,
    accolades = 0,
};

local ICON_DIVIDER   = '\xef\x85\x82';
local divider_color  = { 0.33, 0.38, 0.60, 1.0 };

local function wallet_init(player)
    wallet.ready = true;
    -- Sparks are not exposed by Ashita, so they are read from game memory.
    pcall(function ()
        local ptr = ashita.memory.find('FFXiMain.dll', 0, '8B4C240C8B4104??????????', 0, 0);
        if (ptr ~= nil and ptr ~= 0) then
            wallet.sparks = ashita.memory.read_uint32(ashita.memory.read_uint32(ptr + 8));
        end
    end);
    pcall(function ()
        wallet.accolades = player:GetUnityPoints();
    end);
end

-- A small rounded bar with its number in the middle, drawn inline on the main bar.
local VITAL_WIDTH  = 84;
local VITAL_HEIGHT = 14;

local function draw_vital(label, value, fraction, color)
    imgui.SameLine();
    if (crystal()) then
        -- Design B: "HP ..... 1041" with a thin bar under it.
        local dl = imgui.GetWindowDrawList();
        local x = imgui.GetCursorScreenPos();
        local _, wy = imgui.GetWindowPos();
        local _, th = imgui.CalcTextSize('Ag');
        th = math.floor(th or 14);
        local text = string.format('%d', value);
        local w = math.max(104, imgui.CalcTextSize(label) + imgui.CalcTextSize(text) + 16);
        local ty = wy + 5;
        dl:AddText({ x, ty }, imgui.GetColorU32(omni.settings.colors.dim), label);
        dl:AddText({ x + w - imgui.CalcTextSize(text), ty }, imgui.GetColorU32({ 1, 1, 1, 1 }), text);
        local vy1, vy2 = ty + th + 2, ty + th + 7;
        dl:AddRectFilled({ x, vy1 }, { x + w, vy2 }, imgui.GetColorU32({ 0.10, 0.12, 0.20, 1.0 }));
        local f = math.max(0, math.min(1, fraction or 0));
        if (f > 0) then
            dl:AddRectFilled({ x, vy1 }, { x + w * f, vy2 }, imgui.GetColorU32(color));
            dl:AddRectFilled({ x, vy1 }, { x + w * f, vy1 + 2 }, imgui.GetColorU32({ 1, 1, 1, 0.25 }));   -- glassy shine
        end
        dl:AddRect({ x - 1, vy1 - 1 }, { x + w + 1, vy2 + 1 }, imgui.GetColorU32({ 0.90, 0.77, 0.42, 0.45 }));
        diamond(dl, x + w * f, (vy1 + vy2) / 2, 3.5, { 0.98, 0.92, 0.75, 1.0 });
        imgui.Dummy({ w, th });
        return;
    end
    imgui.TextColored(omni.settings.colors.label, label);
    imgui.SameLine(0, 4);

    local dl = imgui.GetWindowDrawList();
    local x = imgui.GetCursorScreenPos();
    local _, wy = imgui.GetWindowPos();
    local text = string.format('%d', value);
    local tw, th = imgui.CalcTextSize(text);
    th = math.floor(th or 14);
    local width = math.max(VITAL_WIDTH, tw + 16);
    local h = math.max(VITAL_HEIGHT, th + 2);
    local y = math.floor(wy + (BAR_HEIGHT - h) / 2);             -- centred in the bar
    draw_pill(dl, x, y, x + width, y + h, fraction, color);

    local ty = y + math.floor((h - th) / 2);
    dl:AddText({ x + (width - tw) / 2 + 1, ty + 1 }, imgui.GetColorU32({ 0.0, 0.0, 0.0, 0.8 }), text);
    dl:AddText({ x + (width - tw) / 2, ty }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 1.0 }), text);

    imgui.Dummy({ width, th });
end

-- HP, MP and TP bars, then gil. (Sparks and accolades are shown in the Points tab.)
local function draw_wallet()
    local party = AshitaCore:GetMemoryManager():GetParty();
    local tp = party:GetMemberTP(0) or 0;

    imgui.SameLine(0, 14);
    imgui.TextColored(crystal() and GOLD_DIM or divider_color, ICON_DIVIDER);
    local c = omni.settings.colors;
    draw_vital('HP', party:GetMemberHP(0) or 0, (party:GetMemberHPPercent(0) or 0) / 100, c.hp);
    draw_vital('MP', party:GetMemberMP(0) or 0, (party:GetMemberMPPercent(0) or 0) / 100, c.mp);
    -- TP fills at 3000 and brightens once a weapon skill is ready (1000).
    draw_vital('TP', tp, tp / 3000, (tp >= 1000) and c.tp_ready or c.tp);

    local gil = AshitaCore:GetMemoryManager():GetInventory():GetContainerItem(0, 0);
    if (gil ~= nil) then
        -- Divider and gil, centred top-to-bottom in the bar.
        imgui.SameLine(0, 14);
        local dl = imgui.GetWindowDrawList();
        local x = imgui.GetCursorScreenPos();
        local _, wy = imgui.GetWindowPos();
        local text = string.format('%d G', gil.Count);
        local dw, th = imgui.CalcTextSize(ICON_DIVIDER);
        th = math.floor(th or 14);
        local ty = math.floor(wy + (BAR_HEIGHT - th) / 2);
        dl:AddText({ x, ty }, imgui.GetColorU32(crystal() and GOLD_DIM or divider_color), ICON_DIVIDER);
        local gx = x + dw + 14;
        dl:AddText({ gx, ty }, imgui.GetColorU32(crystal() and GOLD or omni.settings.colors.text), text);
        imgui.Dummy({ dw + 14 + imgui.CalcTextSize(text), th });
    end
end

-- Icons from the font Ashita already uses (same trick points uses for its divider).
local ICON_DOWN = '\xef\x81\xb8';
local ICON_UP   = '\xef\x81\xb7';
local ICON_EYE      = '\xef\x81\xae';   -- everything showing
local ICON_EYE_OFF  = '\xef\x81\xb0';   -- only the main bar showing


----------------------------------------------------------------------------------------------------
-- Job icon sheet
----------------------------------------------------------------------------------------------------
pcall(ffi.cdef, [[
    HRESULT __stdcall D3DXCreateTextureFromFileA(IDirect3DDevice8* pDevice, const char* pSrcFile, IDirect3DTexture8** ppTexture);
]]);

local function load_icons()
    local ok, result = pcall(function ()
        local texture_ptr = ffi.new('IDirect3DTexture8*[1]');
        local path = string.format('%s/assets/jobicons.png', addon.path);
        local res = ffi.C.D3DXCreateTextureFromFileA(d3d.get_device(), path, texture_ptr);
        if (res ~= ffi.C.S_OK) then
            return nil;
        end
        local texture = ffi.new('IDirect3DTexture8*', texture_ptr[0]);
        d3d.gc_safe_release(texture);
        return texture;
    end);
    if (ok) then
        return result;
    end
    return nil;
end

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------
local function toggle_button(id)
    local c = omni.settings.colors;
    imgui.PushStyleColor(ImGuiCol_Button, crystal() and { 0, 0, 0, 0 } or c.button);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, c.hover);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, c.hover);
    local clicked = imgui.Button((omni.expanded and ICON_UP or ICON_DOWN) .. '##' .. id, { 26, 22 });
    imgui.PopStyleColor(3);
    return clicked;
end

----------------------------------------------------------------------------------------------------
-- The bar
----------------------------------------------------------------------------------------------------
local abyssea = nil;
do
    local ok, mod = pcall(require, 'omni_abyssea');
    if (ok) then abyssea = mod; else print('[omni] Abyssea could not load: ' .. tostring(mod)); end
end

-- Dynamis on the bar: time left and the five time extensions (omni_dynamis.lua).
local dynamis = nil;
do
    local ok, mod = pcall(require, 'omni_dynamis');
    if (ok) then dynamis = mod; else print('[omni] Dynamis could not load: ' .. tostring(mod)); end
end

-- Nyzul Isle on the bar: floor, objective and time left (omni_nyzul.lua).
local nyzul = nil;
do
    local ok, mod = pcall(require, 'omni_nyzul');
    if (ok) then nyzul = mod; else print('[omni] Nyzul Isle could not load: ' .. tostring(mod)); end
end

local function draw_bar(player, job)
    local s = omni.settings;
    local level = player:GetMainJobLevel();

    imgui.SetNextWindowSize({ -1, BAR_HEIGHT }, ImGuiCond_Always);
    imgui.SetNextWindowPos({ s.bar_x, s.bar_y }, ImGuiCond_Appearing);
    local orn = crystal();
    imgui.PushStyleColor(ImGuiCol_WindowBg, orn and { 0, 0, 0, 0 } or s.colors.bg);
    imgui.PushStyleColor(ImGuiCol_Border, orn and { 0, 0, 0, 0 } or s.colors.border);
    imgui.PushStyleColor(ImGuiCol_Text, s.colors.text);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    local square = crystal();
    if (square) then imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 0); end

    if (imgui.Begin('OmniBar' .. omni.suffix, omni.bar_open, ImGuiWindowFlags_NoDecoration)) then
        local x = 10;
        local lead = 0;   -- room for the pointed left end in the Crystal look
        if (orn) then
            lead = 18;
            local bwx, bwy = imgui.GetWindowPos();
            local bww = imgui.GetWindowWidth();
            if (type(bww) == 'number' and bww > 40) then
                if (theme() ~= nil) then
                    pcall(theme_frame, imgui.GetWindowDrawList(), bwx + 1, bwy + 1, bwx + bww - 1, bwy + BAR_HEIGHT - 1);
                else
                    pcall(ornate, imgui.GetWindowDrawList(), bwx + 1, bwy + 1, bwx + bww - 1, bwy + BAR_HEIGHT - 1, 'point');
                end
            end
        end

        -- Job icon and level, laid out the same way as points.
        if (omni.icons ~= nil) then
            local u1 = (1.0 / 6.0) * math.fmod(job - 1.0, 6.0);
            local v1 = 0.25 * math.floor((job - 1) / 6.0);
            imgui.SetCursorPos({ lead, lead > 0 and 2 or 0 });
            -- Only the picture half of the sprite is drawn; the job letters and level are left off.
            local isz = (lead > 0) and 28 or 32;
            imgui.Image(tonumber(ffi.cast('uint32_t', omni.icons)), { isz, isz }, { u1, v1 }, { u1 + (1.0 / 12.0), v1 + 0.25 }, { 1, 1, 1, 1 }, { 1, 1, 1, 0 });
            if (lead > 0) then
                -- a thin gold diamond frame round the job picture
                local px, py = imgui.GetItemRectMin();
                if (type(px) == 'number') then
                    local cx, cy, r = px + isz / 2, py + isz / 2, isz / 2 + 2;
                    local dl0 = imgui.GetWindowDrawList();
                    local g = imgui.GetColorU32({ 0.90, 0.77, 0.42, 0.70 });
                    dl0:AddLine({ cx - r, cy }, { cx, cy - r }, g, 1); dl0:AddLine({ cx, cy - r }, { cx + r, cy }, g, 1);
                    dl0:AddLine({ cx + r, cy }, { cx, cy + r }, g, 1); dl0:AddLine({ cx, cy + r }, { cx - r, cy }, g, 1);
                end
            end
            x = lead + isz + 4;
            -- Main job and level over support job and level, beside the picture.
            local res = AshitaCore:GetResourceManager();
            local main_txt = string.format('%s%d', res:GetString('jobs.names_abbr', job) or '???', level);
            local sub, sub_txt = player:GetSubJob(), nil;
            if (sub ~= nil and sub > 0) then
                sub_txt = string.format('%s%d', res:GetString('jobs.names_abbr', sub) or '???', player:GetSubJobLevel());
            end
            imgui.SetWindowFontScale(0.8);
            local w1 = imgui.CalcTextSize(main_txt);
            local w2 = sub_txt and imgui.CalcTextSize(sub_txt) or 0;
            imgui.SetCursorPos({ x, sub_txt and 2 or 9 });
            imgui.TextColored(s.colors.text, main_txt);
            if (sub_txt) then
                imgui.SetCursorPos({ x, 16 });
                imgui.TextColored(s.colors.dim, sub_txt);
            end
            imgui.SetWindowFontScale(1.0);
            x = x + math.max(w1, w2) + 12;
        else
            local abbr = AshitaCore:GetResourceManager():GetString('jobs.names_abbr', job) or '???';
            imgui.SetCursorPos({ x, 9 });
            imgui.Text(string.format('%s %02d', abbr, level));
            imgui.SameLine();
            x = imgui.GetCursorPosX() + 6;
        end

        imgui.SameLine();
        imgui.SetCursorPos({ x, 9 });
        -- In Abyssea the bar shows Visitant time and lights instead (omni_abyssea.lua).
        if (abyssea ~= nil and omni.settings.aby_bar ~= false and abyssea.inside()) then
            abyssea.draw_bar(s.colors);
        elseif (dynamis ~= nil and omni.settings.dyna_bar ~= false and dynamis.inside()) then
            -- In Dynamis: time left and which time extensions are done.
            dynamis.draw_bar(s.colors);
        elseif (nyzul ~= nil and omni.settings.nyzul_bar ~= false and nyzul.inside()) then
            -- On Nyzul Isle: floor, objective and time left.
            nyzul.draw_bar(s.colors);
        else
            draw_xp(player);
            draw_wallet();
        end

        -- Buttons: outlined in gold with gold text in the Crystal look.
        local cb = crystal();
        if (cb) then
            imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1);
            imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 0);
            imgui.PushStyleColor(ImGuiCol_Border, GOLD);
            imgui.PushStyleColor(ImGuiCol_Text, GOLD);
        end
        -- Drop-down button.
        imgui.SameLine(0, 14);
        imgui.SetCursorPosX(imgui.GetCursorPosX() + 8);
        imgui.SetCursorPosY(5);
        if (not s.minimal and toggle_button('bar')) then
            omni.expanded = not omni.expanded;
        end
        -- Hide / show everything else (XP strip, target bar, panel, pop-outs).
        if (not s.minimal) then imgui.SameLine(0, 4); end
        imgui.SetCursorPosY(5);
        imgui.PushStyleColor(ImGuiCol_Button, s.minimal and s.colors.tab_active or (cb and { 0, 0, 0, 0 } or s.colors.button));
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, s.colors.hover);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, s.colors.hover);
        if (imgui.Button((s.minimal and ICON_EYE_OFF or ICON_EYE) .. '##omni_min', { 26, 22 })) then
            s.minimal = not s.minimal;
            if (s.minimal) then omni.expanded = false; end
            settings.save('omni');
        end
        imgui.PopStyleColor(3);
        if (imgui.IsItemHovered()) then
            imgui.SetTooltip(s.minimal and 'Show everything again' or 'Hide everything but this bar');
        end
        -- Multisend Follow Me: green while your other character is following you.
        if (omni.msend ~= nil) then
            local on = omni.msend.following();
            imgui.SameLine(0, 4);
            imgui.SetCursorPosY(5);
            imgui.PushStyleColor(ImGuiCol_Button, on and { 0.20, 0.55, 0.22, 1.0 } or (cb and { 0, 0, 0, 0 } or s.colors.button));
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, on and { 0.26, 0.64, 0.28, 1.0 } or s.colors.hover);
            imgui.PushStyleColor(ImGuiCol_ButtonActive, s.colors.hover);
            if (imgui.Button((cb and 'FOLLOW' or 'Follow') .. '##omni_follow', { 0, 22 })) then
                omni.msend.toggle_follow();
            end
            imgui.PopStyleColor(3);
            if (imgui.IsItemHovered()) then
                imgui.SetTooltip(on and 'Follow Me is ON - click to stop your other character following'
                    or 'Follow Me is off - click to have your other character follow you (Multisend)');
            end
        end
        -- Sneak / Invisible: whatever you can use right now (magic, ninjutsu, Spectral Jig or items).
        if (omni.stealth ~= nil and s.stealth_bar ~= false) then
            pcall(omni.stealth.draw, { idle = cb and { 0, 0, 0, 0 } or s.colors.button, hover = s.colors.hover });
        end
        if (cb) then
            imgui.PopStyleColor(2);
            imgui.PopStyleVar(2);
        end
        imgui.SameLine();
        imgui.SetCursorPosY(9);
        imgui.Text(' ');
        if (lead > 0) then imgui.SameLine(0, 0); imgui.Dummy({ lead - 4, 1 }); end   -- room for the pointed right end

        -- Measure the bar so the panel can match its width.
        local ok, width = pcall(imgui.GetWindowWidth);
        if (ok and type(width) == 'number' and width > 0) then
            omni.bar_width = width;
        end

        -- Drag to move; remember where it was left.
        if (imgui.IsWindowFocused() and imgui.IsWindowHovered() and imgui.IsMouseDown(ImGuiMouseButton_Left)) then
            local new_x, new_y = imgui.GetWindowPos();
            s.bar_x = new_x;
            s.bar_y = new_y;
        else
            imgui.SetWindowPos({ s.bar_x, s.bar_y });
        end
    end
    imgui.End();

    imgui.PopStyleVar(square and 2 or 1);
    imgui.PopStyleColor(3);
end

----------------------------------------------------------------------------------------------------
-- The XP bar (hangs under the main bar, same width)
----------------------------------------------------------------------------------------------------
local status = require('omni_status');   -- buffs and debuffs (used by the XP bar and the target bar)
do
    local ok, mod = pcall(require, 'omni_stealth');   -- Sneak / Invisible buttons on the main bar
    if (ok) then omni.stealth = mod; else print('[omni] Sneak/Invis buttons could not load: ' .. tostring(mod)); end
end

local EXP_HEIGHT = 24;         -- one slim row: your buffs (time beside each), merits on the right
local EXP_HEIGHT_BUFFS = 28;   -- buffs inside the frame; their times hang just under it
local BUFF_TIME_H = 12;         -- room under the row for those times
local EXP_BUFF_ICON = 16;

-- Returns the height of the bar it drew.
local function draw_exp(player, job, ox, ow, oh)
    local s = omni.settings;

    -- Capped or locked XP goes to limit points, the same switch the main bar makes.
    local limit_mode = (xp.curr == 55999 or player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked());

    local right;
    if (limit_mode) then
        -- Merit points on the right, e.g. "MP16/65" (limit points are on the main bar).
        right = string.format('MP%d/%d', player:GetMeritPoints(), player:GetMeritPointsMax());
    else
        right = '';
    end

    -- Your own buffs, shown in the middle of the strip.
    local ok, buffs = pcall(status.player_buffs);
    if (not ok or type(buffs) ~= 'table') then
        buffs = {};
    end
    local height = (#buffs > 0) and EXP_HEIGHT_BUFFS or EXP_HEIGHT;
    -- Nothing to show (no buffs, no merits): no strip at all.
    if (#buffs == 0 and right == '') then
        return 1;
    end
    local W = ow or omni.bar_width;
    height = math.max(height, oh or 0);

    imgui.SetNextWindowPos({ s.bar_x + (ox or 0), s.bar_y + BAR_HEIGHT - 1 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ W, height }, ImGuiCond_Always);
    local orn = crystal();
    imgui.PushStyleColor(ImGuiCol_WindowBg, orn and { 0, 0, 0, 0 } or s.colors.bg);
    imgui.PushStyleColor(ImGuiCol_Border, orn and { 0, 0, 0, 0 } or s.colors.border);
    imgui.PushStyleColor(ImGuiCol_Text, s.colors.text);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 10, 4 });
    local square = crystal();
    if (square) then imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 0); end

    -- (Mouse input is left on so hovering a buff can show its name.)
    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing);

    if (imgui.Begin('OmniExp' .. omni.suffix, omni.bar_open, flags)) then
        local dl = imgui.GetWindowDrawList();
        local wx, wy = imgui.GetWindowPos();
        if (orn and theme() ~= nil) then pcall(theme_frame, dl, wx + 1, wy + 1, wx + W - 1, wy + height - 1);
        elseif (orn) then pcall(ornate, dl, wx + 1, wy + 1, wx + W - 1, wy + height - 1, 'bevel', nil, 5); end
        local white = imgui.GetColorU32({ 1.0, 1.0, 1.0, 1.0 });
        local _, text_h = imgui.CalcTextSize('Ag');
        text_h = text_h or 14;

        -- One row: your buffs in the middle, merits on the right.
        -- (The XP bar itself now sits behind the XP counter on the main bar.)
        -- (Jobs now sit beside the job picture on the main bar.)
        local right_w = imgui.CalcTextSize(right);
        local row_mid = wy + math.floor(height / 2);
        local ty = math.floor(row_mid - text_h / 2);
        dl:AddText({ wx + W - 10 - right_w, ty }, white, right);

        -- Your buffs from the left, each with its time under it, packed close together.
        if (#buffs > 0) then
            local room = W - 20 - ((right_w > 0) and (right_w + 16) or 0);
            -- Icons sit inside the frame lines; each time goes just under the bottom line.
            local top = math.floor((height - EXP_BUFF_ICON) / 2) + 1;
            local tdl = nil;
            pcall(function () tdl = imgui.GetForegroundDrawList(); end);
            status.draw_stacked(buffs, 8, top, EXP_BUFF_ICON, room, 0.75, 3, tdl, wy + height + 1);
            omni.buff_times = true;
        end
    end
    imgui.End();

    imgui.PopStyleVar(square and 2 or 1);
    imgui.PopStyleColor(3);
    return height;
end

----------------------------------------------------------------------------------------------------
-- The target bar (hangs under the main bar while you have something targeted)
----------------------------------------------------------------------------------------------------
local TARGET_HEIGHT = 24;   -- the HP bar, with its buffs, name, HP% and distance all inside it
local TARGET_ICON   = 14;   -- size of a buff/debuff icon (drawn inside the HP bar)
local TARGET_PILL   = 18;   -- thickness of the rounded HP bar

-- Name colour, the same scheme HXUI uses.
local function target_color(entity, index)
    local flags = entity.SpawnFlags or 0;
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (bit.band(flags, 0x0001) == 0x0001) then
        -- A player: cyan if they are in your party or alliance, otherwise white.
        for i = 0, 17 do
            if (party:GetMemberIsActive(i) == 1 and party:GetMemberTargetIndex(i) == index) then
                return { 0.0, 1.0, 1.0, 1.0 };
            end
        end
        return { 1.0, 1.0, 1.0, 1.0 };
    elseif (bit.band(flags, 0x0002) == 0x0002) then
        return { 0.4, 1.0, 0.4, 1.0 };      -- NPC: green
    end
    -- A monster: yellow unclaimed, red claimed by your group, purple claimed by someone else.
    local claim = bit.band(AshitaCore:GetMemoryManager():GetEntity():GetClaimStatus(index), 0xFFFF);
    if (claim == 0) then
        return { 1.0, 1.0, 0.4, 1.0 };
    end
    for i = 0, 17 do
        if (party:GetMemberIsActive(i) == 1 and party:GetMemberServerId(i) == claim) then
            return { 1.0, 0.4, 0.4, 1.0 };
        end
    end
    return { 1.0, 0.4, 1.0, 1.0 };
end

-- Returns the height of the bar it drew, or 0 if there is no target.
local function draw_target(ox, ow, oh)
    local target = AshitaCore:GetMemoryManager():GetTarget();
    if (target == nil) then
        return 0;
    end
    -- With a sub-target cursor open, the real target moves to slot 1.
    local index = target:GetTargetIndex((target:GetIsSubTargetActive() == 1) and 1 or 0);
    if (index == nil or index == 0) then
        return 0;
    end
    local entity = GetEntity(index);
    if (entity == nil or entity.Name == nil or entity.Name == '') then
        return 0;
    end

    local s = omni.settings;
    local color = target_color(entity, index);
    local hpp = math.max(0, math.min(100, entity.HPPercent or 0));
    local distance = string.format('%.1f', math.sqrt(entity.Distance or 0));

    -- Buffs (yourself or a party member) or tracked debuffs (a monster).
    local ok, ids = pcall(status.ids_for, entity, index);
    if (not ok or type(ids) ~= 'table') then
        -- Say what went wrong, once, instead of failing silently.
        if (not omni.status_error_shown) then
            omni.status_error_shown = true;
            print('[omni] Could not read buffs for the target: ' .. tostring(ids));
        end
        ids = {};
    end
    local height = math.max(TARGET_HEIGHT, oh or 0);
    local W = ow or omni.bar_width;

    imgui.SetNextWindowPos({ s.bar_x + (ox or 0), s.bar_y + BAR_HEIGHT - 1 }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ W, height }, ImGuiCond_Always);
    local orn = crystal();
    imgui.PushStyleColor(ImGuiCol_WindowBg, orn and { 0, 0, 0, 0 } or s.colors.bg);
    imgui.PushStyleColor(ImGuiCol_Border, orn and { 0, 0, 0, 0 } or s.colors.border);
    imgui.PushStyleColor(ImGuiCol_Text, s.colors.text);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 10, 4 });
    local square = crystal();
    if (square) then imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 0); end

    -- (Mouse input is left on so hovering a status icon can show its name.)
    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing);

    if (imgui.Begin('OmniTarget' .. omni.suffix, omni.bar_open, flags)) then
        -- HP bar: a rounded pill like HXUI's, drawn by hand so it can have that shape.
        local dl = imgui.GetWindowDrawList();
        local wx, wy = imgui.GetWindowPos();
        if (orn and theme() ~= nil) then pcall(theme_frame, dl, wx + 1, wy + 1, wx + W - 1, wy + height - 1);
        elseif (orn) then pcall(ornate, dl, wx + 1, wy + 1, wx + W - 1, wy + height - 1, 'bevel', nil, 5); end
        -- The HP bar fills the row; the target's buffs / debuffs sit inside it at the left end.
        local icons_w = 0;
        if (#ids > 0) then
            icons_w = math.min(#ids * (TARGET_ICON + 2), math.floor(W * 0.35));
        end
        local x1, x2 = wx + 10, wx + W - 10;
        local y1 = wy + math.floor((height - TARGET_PILL) / 2);
        local y2 = y1 + TARGET_PILL;

        if (crystal()) then
            -- Square bar, dark red fill, thin gold frame.
            local cap = math.floor(TARGET_PILL / 2);
            local bx1, bx2 = x1 + cap, x2 - cap;
            local fillc = { s.colors.hp[1] * 0.60, s.colors.hp[2] * 0.55, s.colors.hp[3] * 0.60, 1.0 };
            local ym = (y1 + y2) / 2;
            dl:AddRectFilled({ bx1, y1 }, { bx2, y2 }, imgui.GetColorU32({ 0.12, 0.10, 0.14, 1.0 }));
            dl:AddTriangleFilled({ bx1, y1 }, { x1, ym }, { bx1, y2 }, imgui.GetColorU32(hpp > 0 and fillc or { 0.12, 0.10, 0.14, 1.0 }));
            dl:AddTriangleFilled({ bx2, y1 }, { bx2, y2 }, { x2, ym }, imgui.GetColorU32(hpp >= 100 and fillc or { 0.12, 0.10, 0.14, 1.0 }));
            dl:AddRectFilled({ bx1, y1 }, { bx1 + (bx2 - bx1) * math.max(0, math.min(1, hpp / 100)), y2 }, imgui.GetColorU32(fillc));
            dl:AddRectFilled({ bx1, y1 + 1 }, { bx2, y1 + math.floor(TARGET_PILL * 0.4) }, imgui.GetColorU32({ 1, 1, 1, 0.06 }));
            local gl = imgui.GetColorU32({ 0.90, 0.77, 0.42, 0.75 });
            dl:AddLine({ bx1, y1 }, { bx2, y1 }, gl, 1); dl:AddLine({ bx1, y2 }, { bx2, y2 }, gl, 1);
            dl:AddLine({ bx1, y1 }, { x1, ym }, gl, 1); dl:AddLine({ x1, ym }, { bx1, y2 }, gl, 1);
            dl:AddLine({ bx2, y1 }, { x2, ym }, gl, 1); dl:AddLine({ x2, ym }, { bx2, y2 }, gl, 1);
        else
            draw_pill(dl, x1, y1, x2, y2, hpp / 100, s.colors.hp);
        end

        -- Text inside the bar gets a dark edge so it reads on both the filled and empty part.
        -- Centred top-to-bottom on the bar using the real text height (nudged up a pixel,
        -- because the font leaves more empty space above the letters than below).
        local _, text_h = imgui.CalcTextSize('Ag');
        local ty = math.floor(y1 + (TARGET_PILL - (text_h or 14)) / 2) - 1;
        local function inside(x, text, col)
            local edge = imgui.GetColorU32({ 0.0, 0.0, 0.0, 0.9 });
            for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
                dl:AddText({ x + o[1], ty + o[2] }, edge, text);
            end
            dl:AddText({ x, ty }, imgui.GetColorU32(col), text);
        end

        -- Name (in its claim colour) and percentage together in the middle of the bar.
        local pct = string.format('%d%%', hpp);
        local name_w, gap = imgui.CalcTextSize(entity.Name), 10;
        local start = (x1 + x2) / 2 - (name_w + gap + imgui.CalcTextSize(pct)) / 2;
        -- Keep the name clear of the icons at the left end.
        -- ...and clear of the TH label and distance at the right end.
        local t, procced = nil, false;
        if (omni.th ~= nil and omni.th.label_for ~= nil) then t, procced = omni.th.label_for(entity.ServerId); end
        local right_w = imgui.CalcTextSize(distance or '') + 8 + (t and (imgui.CalcTextSize(t) + 10) or 0);
        start = math.min(start, x2 - right_w - 10 - (name_w + gap + imgui.CalcTextSize(pct)));
        if (icons_w > 0) then start = math.max(start, x1 + 6 + icons_w + 6); end
        inside(start, entity.Name, color);
        inside(start + name_w + gap, pct, { 1.0, 1.0, 1.0, 1.0 });

        -- Distance at the right end of the bar: green in casting range, yellow just
        -- outside it, red too far away.
        local yalms = tonumber(distance) or 0;
        local dist_col;
        if (yalms <= 20.0) then
            dist_col = { 0.40, 1.00, 0.40, 1.0 };
        elseif (yalms <= 30.0) then
            dist_col = { 1.00, 0.92, 0.30, 1.0 };
        else
            dist_col = { 1.00, 0.35, 0.35, 1.0 };
        end
        inside(x2 - imgui.CalcTextSize(distance) - 8, distance, dist_col);
        -- Treasure Hunter on this monster, left of the distance (omni_th.lua).
        if (t ~= nil) then
            inside(x2 - imgui.CalcTextSize(distance) - 8 - imgui.CalcTextSize(t) - 10, t,
                procced and { 0.55, 0.95, 0.55, 1.0 } or { 0.80, 0.82, 0.90, 1.0 });
        end

        -- Buff / debuff icons inside the bar, at its left end.
        if (#ids > 0) then
            imgui.SetCursorPos({ 10 + 6, math.floor(y1 - wy + (TARGET_PILL - TARGET_ICON) / 2) });
            status.draw(ids, TARGET_ICON, math.max(1, math.floor(icons_w / (TARGET_ICON + 2))));
        end
    end
    imgui.End();

    imgui.PopStyleVar(square and 2 or 1);
    imgui.PopStyleColor(3);
    return height;
end

----------------------------------------------------------------------------------------------------
-- Deeps: damage meter for you and your party/alliance
----------------------------------------------------------------------------------------------------
local action = require('omni_action');
local damage_adv = require('omni_damage');   -- Advanced page of the Damage tab

local DEEPS_IDLE = 8;   -- seconds without damage before the fight clock pauses

local deeps = {
    actors    = {},     -- name -> { name, total, hits, misses, best }
    active    = 0,      -- seconds of fighting
    last      = nil,    -- time of the last counted action
    roster    = {},     -- server id -> name, for party and alliance members
    roster_at = -10,
};

local deeps_colors = {
    { 0.80, 0.30, 0.30, 0.85 }, { 0.30, 0.55, 0.85, 0.85 }, { 0.35, 0.70, 0.35, 0.85 },
    { 0.80, 0.65, 0.25, 0.85 }, { 0.60, 0.40, 0.80, 0.85 }, { 0.30, 0.70, 0.70, 0.85 },
};

local function commas(n)
    local out = tostring(math.floor(n + 0.5)):reverse():gsub('(%d%d%d)', '%1,'):reverse();
    if (out:sub(1, 1) == ',') then
        out = out:sub(2);
    end
    return out;
end

local function deeps_reset()
    pcall(damage_adv.reset);
    deeps.actors = {};
    deeps.active = 0;
    deeps.last   = nil;
end

local function deeps_refresh_roster()
    local now = os.clock();
    if (now - deeps.roster_at < 1) then
        return;
    end
    deeps.roster_at = now;
    deeps.roster = {};
    local party = AshitaCore:GetMemoryManager():GetParty();
    for i = 0, 17 do
        if (party:GetMemberIsActive(i) == 1) then
            local id = party:GetMemberServerId(i);
            local name = party:GetMemberName(i);
            if (id ~= nil and id ~= 0 and name ~= nil and name ~= '') then
                deeps.roster[id] = name;
            end
        end
    end
end

-- Called for every action packet (melee swings, weapon skills, spells, abilities...).
local function deeps_action(act)
    deeps_refresh_roster();
    local name = deeps.roster[act.actor_id];
    if (name == nil) then
        return;
    end

    local entry = deeps.actors[name];
    local counted = false;
    local function ensure()
        if (entry == nil) then
            entry = { name = name, total = 0, hits = 0, misses = 0, best = 0 };
            deeps.actors[name] = entry;
        end
        counted = true;
    end

    for _, target in ipairs(act.targets) do
        for _, a in ipairs(target.actions) do
            local kind = action.classify(a.message);
            if (kind == 'miss') then
                ensure();
                entry.misses = entry.misses + 1;
            elseif (kind ~= nil) then
                ensure();
                entry.total = entry.total + a.param;
                if (kind == 'melee' or kind == 'ranged') then
                    entry.hits = entry.hits + 1;
                end
                if (a.param > entry.best) then
                    entry.best = a.param;
                end
            end
            -- Skillchain and added-effect damage ride along on the same hit.
            if (a.add ~= nil and action.classify_add(a.add.message) ~= nil) then
                ensure();
                entry.total = entry.total + a.add.param;
            end
        end
    end

    if (counted) then
        local now = os.time();
        if (deeps.last ~= nil) then
            local gap = now - deeps.last;
            if (gap > 0 and gap <= DEEPS_IDLE) then
                deeps.active = deeps.active + gap;
            end
        end
        deeps.last = now;
    end
end

-- Damage dealers sorted highest first, plus the group total.
local function deeps_sorted()
    local rows, total = {}, 0;
    for _, entry in pairs(deeps.actors) do
        rows[#rows + 1] = entry;
        total = total + entry.total;
    end
    table.sort(rows, function (a, b)
        if (a.total ~= b.total) then
            return a.total > b.total;
        end
        return a.name < b.name;
    end);
    return rows, total;
end

-- Lines waiting to go to party chat. They are sent one at a time with a gap,
-- because the game drops chat lines that arrive too quickly.
local DEEPS_SAY_GAP = 1.5;
local deeps_say = { lines = {}, next_at = 0 };

local function deeps_report(count)
    local rows, total = deeps_sorted();
    if (#rows == 0) then
        print('[omni] No damage recorded yet.');
        return;
    end
    deeps_say.lines = {};
    for i, e in ipairs(rows) do
        if (i > count) then
            break;
        end
        local share = (total > 0) and (e.total / total * 100) or 0;
        local swings = e.hits + e.misses;
        local acc = (swings > 0) and string.format('%d%%', math.floor(e.hits / swings * 100 + 0.5)) or 'n/a';
        deeps_say.lines[#deeps_say.lines + 1] = string.format('/p %d. %s %s (%.1f%%) Acc %s High %s',
            i, e.name, commas(e.total), share, acc, commas(e.best));
    end
    deeps_say.next_at = 0;
end

local function deeps_say_tick()
    if (#deeps_say.lines == 0 or os.clock() < deeps_say.next_at) then
        return;
    end
    AshitaCore:GetChatManager():QueueCommand(1, table.remove(deeps_say.lines, 1));
    deeps_say.next_at = os.clock() + DEEPS_SAY_GAP;
end

local deeps_top_input = { 5 };   -- holder for the "Show top" number box
local deeps_tab = nil;   -- the tab entry, so its height can follow the number of rows

local function draw_deeps()
    local s = omni.settings;
    local limit = s.deeps_top or 5;

    -- "Show top" counter: click - / + to change it by one, or type a number (1 to 18).
    imgui.Text('Show top');
    imgui.SameLine();
    deeps_top_input[1] = limit;
    local sized = (imgui.PushItemWidth ~= nil and imgui.PopItemWidth ~= nil);
    if (sized) then imgui.PushItemWidth(100); end
    imgui.PushStyleColor(ImGuiCol_FrameBg, s.colors.button);
    if (imgui.InputInt('##deeps_top', deeps_top_input)) then
        limit = math.max(1, math.min(18, math.floor(tonumber(deeps_top_input[1]) or limit)));
        if (limit ~= s.deeps_top) then
            s.deeps_top = limit;
            settings.save('omni');
        end
    end
    imgui.PopStyleColor(1);
    if (sized) then imgui.PopItemWidth(); end

    local rows, total = {}, 0;
    for _, entry in pairs(deeps.actors) do
        rows[#rows + 1] = entry;
        total = total + entry.total;
    end
    table.sort(rows, function (a, b)
        if (a.total ~= b.total) then
            return a.total > b.total;
        end
        return a.name < b.name;
    end);

    local seconds = math.max(deeps.active, 1);
    imgui.Text(string.format('Total %s    Time %d:%02d    %s dps',
        commas(total), math.floor(deeps.active / 60), deeps.active % 60, commas(total / seconds)));
    imgui.SameLine();
    if (imgui.Button('Reset##deeps', { 60, 20 })) then
        deeps_reset();
    end
    imgui.Separator();

    if (#rows == 0) then
        imgui.TextWrapped('No damage recorded yet. It starts counting when you or your party hit something.');
        return;
    end

    -- Columns: the name starts at the left edge, the numbers are right-aligned to these x positions.
    local COL = { name = 8, damage = 250, share = 320, dps = 400, acc = 480, best = 580 };
    local dl = imgui.GetWindowDrawList();
    local white = imgui.GetColorU32({ 1.0, 1.0, 1.0, 1.0 });
    local dim = imgui.GetColorU32({ 0.70, 0.70, 0.75, 1.0 });

    local function right(x0, y, x, color, text)
        dl:AddText({ x0 + x - imgui.CalcTextSize(text), y }, color, text);
    end

    -- Column headings.
    local hx, hy = imgui.GetCursorScreenPos();
    dl:AddText({ hx + COL.name, hy }, dim, 'Name');
    right(hx, hy, COL.damage, dim, 'Damage');
    right(hx, hy, COL.share, dim, 'Share');
    right(hx, hy, COL.dps, dim, 'DPS');
    right(hx, hy, COL.acc, dim, 'Acc');
    right(hx, hy, COL.best, dim, 'Best hit');
    imgui.Dummy({ 1, 16 });

    local top = math.max(rows[1].total, 1);
    for i, e in ipairs(rows) do
        if (i > limit) then
            break;
        end
        local share = (total > 0) and (e.total / total * 100) or 0;
        local swings = e.hits + e.misses;
        local acc = (swings > 0) and string.format('%d%%', math.floor(e.hits / swings * 100 + 0.5)) or '-';

        -- The bar itself carries no text; the text is drawn over it in fixed columns.
        local x0, y0 = imgui.GetCursorScreenPos();
        imgui.PushStyleColor(ImGuiCol_PlotHistogram, deeps_colors[((i - 1) % #deeps_colors) + 1]);
        imgui.ProgressBar(e.total / top, { -1, 20 }, '');
        imgui.PopStyleColor(1);

        local y = y0 + 3;
        dl:AddText({ x0 + COL.name, y }, white, string.format('%d. %s', i, e.name));
        right(x0, y, COL.damage, white, commas(e.total));
        right(x0, y, COL.share, white, string.format('%.1f%%', share));
        right(x0, y, COL.dps, white, commas(e.total / seconds));
        right(x0, y, COL.acc, white, acc);
        right(x0, y, COL.best, white, commas(e.best));
    end
end

-- Sparks and unity accolades are listed in the Points tab, alongside the server's points.
-- So are the balances from the game's own Status > Currencies menu (the ones you have any of).
local currency = require('omni_currency');

trove.set_points_extras(function ()
    currency.request();     -- keeps the numbers fresh while the tab is showing
    local rows = {
        { group = 'Eminence & Unity', label = 'Sparks',          value = wallet.sparks },
        { group = 'Eminence & Unity', label = 'Unity Accolades', value = wallet.accolades },
    };
    for _, row in ipairs(currency.rows()) do
        rows[#rows + 1] = row;
    end
    return rows;
end);

----------------------------------------------------------------------------------------------------
-- Tabs shown in the drop-down panel. To add a tab, add an entry here.
--   label  : text on the tab
--   width  : the panel is at least this wide while the tab is showing
--   height : height of the tab's content area
--   render : draws the tab
----------------------------------------------------------------------------------------------------
local PANEL_HEADING = 'Omni';

local tabs = {};

for _, section in ipairs(trove.sections) do
  if (not section.hidden) then
    tabs[#tabs + 1] = {
        label   = section.label,
        width   = section.width,
        height  = section.height,
        section = section,
        render  = function () trove.render(section); end,
    };
    if (section.label == 'Currency') then
        -- Two tabs inside: Currency and Points (Trove's Points screen).
        local tab = tabs[#tabs];
        local points = nil;
        for _, x in ipairs(trove.sections) do if (x.label == 'Points') then points = x; end end
        tab.render = function ()
            if (imgui.BeginTabBar('##omni_cur_sub')) then
                if (imgui.BeginTabItem('Currency##omni_cursub')) then
                    trove.render(section);
                    tab.height = 620;
                    imgui.EndTabItem();
                end
                if (points ~= nil and imgui.BeginTabItem('Points##omni_cursub')) then
                    trove.render(points);
                    -- Grows to fit however many groups and rows Points has (up to a limit).
                    local layout = points.plugin and points.plugin.getLayout and points.plugin.getLayout();
                    if (layout ~= nil and layout.rows > 0) then
                        tab.height = math.max(200, math.min(900, 94 + layout.groups * 40 + layout.rows * 27));
                    end
                    imgui.EndTabItem();
                end
                imgui.EndTabBar();
            end
        end;
    end
    if (section.label == 'Character') then
        -- Character = Trove's Profile screen plus a Magic page (Trove's Magic screen).
        -- It grows to fit what is open (job armour lists can be long), so it never scrolls;
        -- the Magic page fills a fixed height because its lists scroll inside.
        local tab = tabs[#tabs];
        local magic = nil;
        for _, x in ipairs(trove.sections) do if (x.label == 'Magic') then magic = x; end end
        local hooked = false;
        local craftbook = nil;
        tab.render = function ()
            if (not hooked and magic ~= nil and section.plugin ~= nil and section.plugin.addTab ~= nil) then
                hooked = true;
                section.plugin.addTab('Magic', function ()
                    imgui.BeginChild('##omni_char_magic', { 0, 560 }, false);
                    trove.render(magic);
                    imgui.EndChild();
                end);
                -- Craftbook (omni_craftbook.lua) as the second page of Crafts.
                local ok, mod = pcall(require, 'omni_craftbook');
                if (ok and section.plugin.setCraftbook ~= nil) then
                    craftbook = mod;
                    section.plugin.setCraftbook(function () craftbook.render(540); end);
                elseif (not ok) then
                    print('[omni] Craftbook could not load: ' .. tostring(mod));
                end
            end
            trove.render(section);
            -- The Craftbook needs a wider panel than the other Character pages.
            local wide = section.plugin ~= nil and section.plugin.takeWide ~= nil and section.plugin.takeWide();
            tab.width = wide and 900 or section.width;
            tab.height = math.max(300, math.min(2400, math.floor(imgui.GetCursorPosY()) + 12));
        end;
    end
    if (section.label == 'Sea') then
        -- Three tabs inside: Sea (Trove's Lumoria screen), Jailers (omni_jailers.lua) and AV (the Absolute Virtue helper).
        -- Each is exactly as tall as what is in it.
        local tab = tabs[#tabs];
        tab.bg = 'bg_sea.png';   -- painted background (Crystal look)
        local av = require('omni_av');
        omni.av = av;
        pcall(av.set_mode, omni.settings.av_mode or 'zone');
        tab.render = function ()
            if (imgui.BeginTabBar('##omni_sea_sub')) then
                if (imgui.BeginTabItem('Sea##omni_seasub')) then
                    trove.render(section);
                    local h = section.plugin and section.plugin.getContentHeight and section.plugin.getContentHeight();
                    if (type(h) == 'number' and h > 0) then
                        tab.height = math.max(160, math.min(900, math.floor(h)));
                    end
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('Jailers##omni_seasub')) then
                    local ok, jl = pcall(require, 'omni_jailers');
                    if (ok) then jl.render(trove); else imgui.TextColored({ 1, 0.45, 0.45, 1 }, 'Jailers page could not load: ' .. tostring(jl)); end
                    tab.height = math.max(160, math.min(900, math.floor(imgui.GetCursorPosY()) + 10));
                    imgui.EndTabItem();
                end
                if (imgui.BeginTabItem('AV##omni_seasub')) then
                    -- Happy Virtue pop-out and when the helper listens (moved here from Options).
                    local av_on = { av.float_shown ~= nil and av.float_shown() };
                    if (imgui.Checkbox('Happy Virtue pop-out##sea_avpop', av_on) and av.set_float ~= nil) then av.set_float(av_on[1]); end
                    if (imgui.IsItemHovered()) then imgui.SetTooltip('The floating Absolute Virtue window: 2-hour locks and timers.\nSame as /av show and /av hide.'); end
                    if (av.auto_open ~= nil) then
                        imgui.SameLine(0, 14);
                        local ao = { av.auto_open() };
                        if (imgui.Checkbox('Open by itself when AV pops##sea_avauto', ao)) then av.auto_open(ao[1]); end
                        if (imgui.IsItemHovered()) then imgui.SetTooltip('When Absolute Virtue pops, Happy Virtue opens and its fight timer starts.'); end
                    end
                    imgui.TextColored({ 0.62, 0.66, 0.80, 1.0 }, 'Listens:');
                    for _, m in ipairs({ { 'zone', "In Al'Taieu" }, { 'always', 'Everywhere' }, { 'off', 'Off' } }) do
                        imgui.SameLine(0, 10);
                        if (imgui.RadioButton(m[2] .. '##sea_avmode', (omni.settings.av_mode or 'zone') == m[1])) then
                            omni.settings.av_mode = m[1];
                            pcall(av.set_mode, m[1]);
                            settings.save('omni');
                        end
                    end
                    imgui.Separator();
                    av.draw_tab(trove);
                    tab.height = math.max(160, math.min(900, math.floor(imgui.GetCursorPosY()) + 10));
                    imgui.EndTabItem();
                end
                imgui.EndTabBar();
            end
        end;
    end
  end
end

-- Sky god pops, placed next to the Sea tab.
do
    local sky = require('omni_sky');
    -- Three tabs inside: classic Sky, Sky 2.0, and the server's !pops list.
    local sky_tab = { label = 'Sky', width = 680, height = 500, bg = 'bg_sky.png' };
    sky_tab.render = function ()
        if (imgui.BeginTabBar('##omni_sky_sub')) then
            if (imgui.BeginTabItem('Sky##omni_skysub')) then sky.render(trove); imgui.EndTabItem(); end
            if (imgui.BeginTabItem('Sky 2.0##omni_skysub')) then sky.render_sky2(trove); imgui.EndTabItem(); end
            if (imgui.BeginTabItem('Pops##omni_skysub')) then sky.render_pops(trove); imgui.EndTabItem(); end
            if (imgui.BeginTabItem('Map##omni_skysub')) then
                -- Ru'Aun Gardens: where each god's ??? is (images/sky_map.png, a drawn guide map).
                local h = (trove.fileHandle ~= nil) and trove.fileHandle('sky_map.png') or nil;
                local avail = imgui.GetContentRegionAvail();
                local size = math.min(avail, 410);
                if (h ~= nil) then
                    imgui.SetCursorPosX(imgui.GetCursorPosX() + math.max(0, (avail - size) / 2));
                    imgui.Image(h, { size, size });
                else
                    imgui.TextColored({ 1, 0.45, 0.45, 1 }, 'Map picture missing (images/sky_map.png).');
                end
                imgui.TextColored({ 0.62, 0.66, 0.80, 1.0 }, "Trade the god's gem and stone to its ???. Kirin: all four seals to the ??? in the Shrine of Ru'Avitau (F-8).");
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end
    end;
    omni.sky = sky;
    local at = #tabs + 1;
    for i, tab in ipairs(tabs) do
        if (tab.label == 'Sea') then
            at = i;
            break;
        end
    end
    table.insert(tabs, at, sky_tab);
end

-- Goblin Ventures: EXP areas, HELM and fishing (omni_ventures.lua).
local ventures = require('omni_ventures');
do
    local vnm_section = nil;
    for _, section in ipairs(trove.sections) do
        if (section.label == 'VNM Armor') then vnm_section = section; end
    end

    -- Two tabs inside: the venture lists, and the VNM armour collection (Trove's VNM Armor screen).
    local tab = { label = 'Ventures', width = 930, height = 300 };
    tab.render = function ()
        if (imgui.BeginTabBar('##omni_ventures_sub')) then
            if (imgui.BeginTabItem('Ventures##omni_vsub')) then
                ventures.render(trove);
                tab.height = math.max(160, math.min(900, math.floor(ventures.height) + 6));
                imgui.EndTabItem();
            end
            if (vnm_section ~= nil and imgui.BeginTabItem('VNM Armor##omni_vsub')) then
                trove.render(vnm_section);
                tab.height = math.max(160, math.min(900, math.floor(imgui.GetCursorPosY()) + 12));
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end
    end;
    tabs[#tabs + 1] = tab;
end

-- Sparks shop (omni_sparks.lua).
local sparks = require('omni_sparks');
do
    local tab = { label = 'Sparks', width = 560, height = 300 };
    tab.render = function ()
        sparks.render(trove);
        tab.height = math.max(160, math.min(900, math.floor(sparks.height)));
    end;
    tabs[#tabs + 1] = tab;
end

-- Ultimates: every ultimate weapon / weapon skill as a quest with a % bar (omni_ultimates.lua).
do
    local ok, ultm = pcall(require, 'omni_ultimates');
    if (not ok) then print('[omni] Ultimates could not load: ' .. tostring(ultm)); end
    local tab = { label = 'Ultimates', width = 780, height = 400 };
    tab.render = function ()
        if (not ok) then imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'Ultimates could not load: ' .. tostring(ultm)); return; end
        ultm.render({});
        tab.height = math.max(160, math.min(900, math.floor(ultm.height)));
    end;
    tabs[#tabs + 1] = tab;
end

-- Multisend: Follow Me, sim-cast and quick commands for your other characters (omni_multisend.lua).
do
    local ok, msend = pcall(require, 'omni_multisend');
    if (ok) then omni.msend = msend; end
    local tab = { label = 'Multisend', width = 680, height = 360 };
    tab.render = function ()
        if (not ok) then
            imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'Multisend could not start: ' .. tostring(msend));
            return;
        end
        msend.render();
        tab.height = math.max(200, math.min(900, math.floor(msend.height)));
    end;
    tabs[#tabs + 1] = tab;
end

-- Quests: journey overview, quests by region and mission storylines (omni_quests.lua).
do
    local ok, quests = pcall(require, 'omni_quests');
    local tab = { label = 'Quests', width = 780, height = 600 };
    tab.render = function ()
        if (not ok) then
            imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'Quests could not start: ' .. tostring(quests));
            return;
        end
        quests.render(trove.image);
        tab.height = math.max(200, math.min(900, math.floor(quests.height)));
    end;
    tabs[#tabs + 1] = tab;
end

-- Abyssea: Procs (with a pop-out) and NM Pops; Abyssites / Atmas to follow (omni_abyssea.lua, omni_abypops.lua).
do
    local okp, abypops = pcall(require, 'omni_abypops');
    local abypops_err = nil;
    if (not okp) then abypops_err = abypops; abypops = nil; print('[omni] NM Pops could not load: ' .. tostring(abypops_err)); end
    -- Weapons: Empyrean weapon Magian trials, kill and trophy tracker (omni_abyweapons.lua).
    local okw, abyweapons = pcall(require, 'omni_abyweapons');
    local abyweapons_err = nil;
    if (not okw) then abyweapons_err = abyweapons; abyweapons = nil; print('[omni] Abyssea Weapons could not load: ' .. tostring(abyweapons_err)); end
    local tab = { label = 'Abyssea', width = 900, height = 600 };
    local opts = { settings = nil, save = function () settings.save('omni'); end };
    tab.render = function ()
        if (abyssea == nil) then
            imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'Abyssea could not load.');
            return;
        end
        opts.settings = omni.settings;
        if (imgui.BeginTabBar('##omni_aby_sub')) then
            if (imgui.BeginTabItem('Procs##omni_abysub')) then
                abyssea.render_procs(opts);
                imgui.EndTabItem();
            end
            if (imgui.BeginTabItem('Weapons##omni_abysub')) then
                if (abyweapons ~= nil) then
                    abyweapons.render(opts);
                else
                    imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'Weapons could not load: ' .. tostring(abyweapons_err));
                end
                imgui.EndTabItem();
            end
            if (imgui.BeginTabItem('NM Pops##omni_abysub')) then
                if (abypops ~= nil) then
                    abypops.render(opts);
                else
                    imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'NM Pops could not load: ' .. tostring(abypops_err));
                end
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end
        tab.height = math.max(200, math.min(900, math.floor(imgui.GetCursorPosY()) + 10));
    end;
    tabs[#tabs + 1] = tab;
    omni.abyssea_popout = function ()
        if (abyssea == nil) then return; end
        opts.settings = omni.settings;
        pcall(abyssea.render_popout, opts);
    end;
end

-- TH: Treasure Hunter on each monster, with a party announcement when it goes up (omni_th.lua).
do
    local ok, thmod = pcall(require, 'omni_th');
    if (ok) then omni.th = thmod; thmod.settings = omni.settings; else print('[omni] TH helper could not load: ' .. tostring(thmod)); end
    local tab = { label = 'TH', width = 430, height = 300 };
    local opts = { settings = nil, save = function () settings.save('omni'); end };
    tab.render = function ()
        if (not ok) then imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'TH helper could not load.'); return; end
        opts.settings = omni.settings;
        thmod.render(opts);
        tab.height = math.max(120, math.min(900, math.floor(thmod.height)));
    end;
    tabs[#tabs + 1] = tab;
    if (ok) then thmod.settings = omni.settings; end
end

-- Brighter chat colours (omni_chatcolors.lua).
do
    local ok, mod = pcall(require, 'omni_chatcolors');
    if (ok) then omni.chatcolors = mod; mod.settings = omni.settings; end
end

-- Happy Talks: spoken alerts (omni_talks.lua; Options > Happy Talks).
do
    local ok, mod = pcall(require, 'omni_talks');
    if (ok) then omni.talks = mod; mod.settings = omni.settings; else print('[omni] Happy Talks could not load: ' .. tostring(mod)); end
end

-- Roll Tracker: the /random order for NM pops (omni_rolls.lua; Options > Roll Tracker).
do
    local ok, mod = pcall(require, 'omni_rolls');
    if (ok) then omni.rolls = mod; else print('[omni] Roll Tracker could not load: ' .. tostring(mod)); end
end

-- Happy Pops: HNM pop timers with window warnings (omni_pops.lua; /pops).
do
    local ok, mod = pcall(require, 'omni_pops');
    if (ok) then omni.pops = mod; else print('[omni] Happy Pops could not load: ' .. tostring(mod)); end
end

-- Happy Translate: Japanese chat lines get an English line underneath (omni_translate.lua).
do
    local ok, mod = pcall(require, 'omni_translate');
    if (ok) then omni.translate = mod; else print('[omni] Happy Translate could not load: ' .. tostring(mod)); end
end

-- Spell lines: targetlines-style lines with an animation per element (omni_fx.lua).
do
    local ok, mod = pcall(require, 'omni_fx');
    if (ok) then omni.fx = mod; mod.settings = omni.settings; else print('[omni] Spell lines could not load: ' .. tostring(mod)); end
end

-- Job pictures for the party (omni_party.lua), drawn every frame from the main loop.
do
    local ok, mod = pcall(require, 'omni_party');
    if (ok) then
        omni.party = mod;
        omni.party_opts = { status = status, save = function () settings.save('omni'); end };
    else
        print('[omni] Party list could not load: ' .. tostring(mod));
    end
end

-- Options: switch parts of omni on or off.
do
    local tab = { label = 'Options', width = 560, height = 300, bg = 'bg_sea.png' };
    local GOLD, DIM = { 0.90, 0.78, 0.40, 1.0 }, { 0.62, 0.66, 0.80, 1.0 };
    local function save() settings.save('omni'); end
    local function toggle(label, key, default_on, tip)
        local s = omni.settings;
        local v = { (s[key] == nil) and default_on or (s[key] == true) };
        if (imgui.Checkbox(label .. '##opt_' .. key, v)) then s[key] = v[1]; save(); end
        if (tip and imgui.IsItemHovered()) then imgui.SetTooltip(tip); end
    end
    -- A section heading like the Sea tab's: a deep-blue bar with a bright stripe on the left.
    -- Click it to fold the section away; the fold is remembered.
    local SEA = { 0.15, 0.18, 0.28 };
    local function section(title)
        local s = omni.settings;
        local key = 'optfold_' .. title:gsub('[^%w]', '');
        local folded = s[key] == true;
        imgui.Dummy({ 1, 2 });
        imgui.PushStyleColor(ImGuiCol_ChildBg, { SEA[1], SEA[2], SEA[3], 0.85 });
        imgui.BeginChild('##opt_hdr_' .. key, { -1, 22 }, false, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse));
        local dl = imgui.GetWindowDrawList();
        local wx, wy = imgui.GetWindowPos();
        dl:AddRectFilled({ wx, wy }, { wx + 3, wy + 22 }, imgui.GetColorU32({ SEA[1] * 2.5, SEA[2] * 2.5, SEA[3] * 2.5, 1.0 }));
        imgui.SetCursorPos({ 0, 0 });
        if (imgui.Selectable('##opt_fold_' .. key, false, 0, { 0, 22 })) then s[key] = not folded or nil; save(); end
        imgui.SetCursorPos({ 10, 3 });
        imgui.TextColored(GOLD, (folded and '+ ' or '- ') .. title);
        imgui.EndChild();
        imgui.PopStyleColor(1);
        imgui.Dummy({ 1, 2 });
        return not folded;
    end
    -- A row of choice buttons that wraps inside the column; the chosen one is gold.
    local function choices(id, list, cur, on_pick)
        local availw = imgui.GetContentRegionAvail();
        local used = 0;
        for i, m in ipairs(list) do
            local bw = imgui.CalcTextSize(m[2]) + 16;
            if (i > 1) then
                if (used + 4 + bw > availw) then used = 0; else imgui.SameLine(0, 4); used = used + 4; end
            end
            used = used + bw;
            local on = (cur == m[1]);
            imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
            if (imgui.Button(m[2] .. '##' .. id .. i, { bw, 0 })) then on_pick(m[1]); end
            imgui.PopStyleColor(1);
            if (m[3] and imgui.IsItemHovered()) then imgui.SetTooltip(m[3]); end
        end
    end
    local function render_general()
        local s = omni.settings;
        local flags = bit.bor(ImGuiTableFlags_SizingStretchSame or 0, ImGuiTableFlags_NoPadOuterX or 0);
        if (imgui.BeginTable('##opt_gen', 2, flags)) then
            imgui.TableNextRow();

            ------------------------------------------------------------------ left column
            imgui.TableNextColumn();
            if (section('Look')) then
                local looks = {};
                for _, id in ipairs(LOOK_ORDER) do looks[#looks + 1] = { id, LOOK_LABEL[id] }; end
                choices('opt_look', looks, s.look or 'crystal', function (id) s.look = id; save(); end);
            end

            if (section('Bars')) then
            toggle('Abyssea time and lights', 'aby_bar', true, 'In Abyssea zones the bar shows Visitant time and lights instead of XP.');
            toggle('Dynamis time and time extensions', 'dyna_bar', true, 'In Dynamis the bar shows the time left and which of the five\ntime extensions (granules of time) you have, instead of XP.');
            toggle('Nyzul Isle floor, objective and time', 'nyzul_bar', true, 'On Nyzul Isle the bar shows the floor, the floor\'s objective (hover it for a tip)\nand the time left, instead of XP.');
            toggle('Sneak / Invisible buttons', 'stealth_bar', true, 'Magic, ninjutsu, Spectral Jig or oils and powders.');
            local hide = { not s.show_native };
            if (imgui.Checkbox("Hide the game's buff icons##opt_native", hide)) then
                s.show_native = not hide[1];
                omni.native_check = 0;   -- apply now
                save();
            end
            if (imgui.IsItemHovered()) then imgui.SetTooltip('omni shows your buffs under the bar instead.'); end
            end

            if (section('Chat')) then
                toggle('Brighter chat colours', 'chat_bright', true, 'Party, linkshells and tells.');
            end

            if (section('Multisend')) then
            local fm = { omni.msend ~= nil and omni.msend.following() };
            if (imgui.Checkbox('Follow Me##opt_follow', fm) and omni.msend ~= nil) then omni.msend.toggle_follow(); end
            if (imgui.IsItemHovered()) then imgui.SetTooltip('Same as the Follow button on the bar.'); end
            end

            ------------------------------------------------------------------ right column
            imgui.TableNextColumn();
            if (section('Spell lines')) then
            toggle('Animations', 'fx_on', true, 'Lightning, fireballs, cures and more.');
            toggle('Only my party and alliance', 'fx_party', true);
            toggle('Lines', 'fx_lines', true, 'Target lines between fighters and spell lines. Off = animations only.');
            toggle('AI art', 'fx_art', false, 'Painted fireballs, lightning, halos. Off = the drawn look.');
            end

            imgui.EndTable();
        end

        ---------------------------------------------------------------------- full width
        if (section('Party job pictures')) then
        toggle('Show beside the party lists', 'party_icons', true, 'Job pictures beside your party and alliance lists.');
        imgui.SameLine(0, 16);
        toggle('Move them', 'party_icons_unlocked', false, 'Tick, drag each next to its party list, then untick.');
        imgui.SameLine(0, 16);
        toggle('Show when solo', 'party_solo', false);
        -- Size and row spacing for each party (the game draws them at different sizes).
        local function slider(label, key, default, lo, hi)
            local v = { s[key] or default };
            imgui.PushItemWidth(110);
            if (imgui.SliderInt(label .. '##opt_' .. key, v, lo, hi)) then s[key] = v[1]; save(); end
            imgui.PopItemWidth();
        end
        local names = { 'Your party', 'Alliance 2', 'Alliance 3' };
        local x0 = imgui.GetCursorPosX();
        for n = 1, 3 do
            local pre = (n == 1) and 'party_' or ('party' .. n .. '_');
            imgui.SetCursorPosX(x0);
            imgui.TextColored(DIM, names[n]);
            imgui.SameLine(x0 + 90);
            slider('Size##p' .. n, pre .. 'icon_size', s.party_icon_size or 20, 12, 40);
            imgui.SameLine(x0 + 260);
            slider('Rows##p' .. n, pre .. 'icon_gap', s.party_icon_gap or 22, 12, 60);
        end
        end

        tab.height = math.max(160, math.floor(imgui.GetCursorPosY()) + 10);
    end
    -- Three pages: General, Happy Talks (spoken alerts, omni_talks.lua) and Roll Tracker (omni_rolls.lua).
    local talks_opts = { settings = nil, save = save };
    tab.render = function ()
        if (imgui.BeginTabBar('##omni_opt_sub')) then
            if (imgui.BeginTabItem('General##omni_optsub')) then render_general(); imgui.EndTabItem(); end
            if (imgui.BeginTabItem('Happy Talks##omni_optsub')) then
                if (omni.talks ~= nil) then
                    talks_opts.settings = omni.settings;
                    omni.talks.render(talks_opts);
                else
                    imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'Happy Talks could not load.');
                end
                tab.height = math.max(160, math.floor(imgui.GetCursorPosY()) + 10);
                imgui.EndTabItem();
            end
            if (imgui.BeginTabItem('Roll Tracker##omni_optsub')) then
                if (omni.rolls ~= nil) then
                    omni.rolls.render();
                else
                    imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, 'Roll Tracker could not load.');
                end
                tab.height = math.max(160, math.floor(imgui.GetCursorPosY()) + 10);
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end
    end;
    tabs[#tabs + 1] = tab;
end

-- Two tabs inside Damage: Simple (the list) and Advanced (everyone's full breakdown).
deeps_tab = { label = 'Damage', width = 620, height = 86 + 5 * 24 };
deeps_tab.render = function ()
    if (imgui.BeginTabBar('##omni_dmg_sub')) then
        if (imgui.BeginTabItem('Simple##omni_dmgsub')) then
            deeps_tab.width = 620;
            draw_deeps();
            deeps_tab.height = 104 + (omni.settings.deeps_top or 5) * 24 + 30;
            imgui.EndTabItem();
        end
        if (imgui.BeginTabItem('Advanced##omni_dmgsub')) then
            deeps_tab.width = 820;
            damage_adv.render(omni.settings.colors);
            deeps_tab.height = math.max(160, math.min(900, math.floor(damage_adv.height) + 30));
            imgui.EndTabItem();
        end
        imgui.EndTabBar();
    end
end;
tabs[#tabs + 1] = deeps_tab;

-- Happy Pops: HNM time of death and window timers (omni_pops.lua), as its own tab.
if (omni.pops ~= nil) then
    local pops_tab = { label = 'Happy Pops', width = 980, height = 460 };
    pops_tab.render = function ()
        omni.pops.render();
        pops_tab.height = math.max(160, math.min(900, math.floor(imgui.GetCursorPosY()) + 10));
    end;
    omni.pops.open_panel = function () omni.expanded = true; omni.sel = 'Happy Pops'; end;
    tabs[#tabs + 1] = pops_tab;
end

-- Happy Translate: translated chat and a reply box (omni_translate.lua), as its own tab.
if (omni.translate ~= nil and omni.translate.render ~= nil) then
    local tr_tab = { label = 'Happy Translate', width = 640, height = 380 };
    tr_tab.render = function ()
        omni.translate.render();
        tr_tab.height = math.max(160, math.min(900, math.floor(imgui.GetCursorPosY()) + 10));
    end;
    tabs[#tabs + 1] = tr_tab;
end

----------------------------------------------------------------------------------------------------
-- The drop-down panel (hangs under the bar, same width)
----------------------------------------------------------------------------------------------------
-- How tall the buff strip / target bar need to be (0 = nothing to show).
local function exp_need(player)
    local limit_mode = (xp.curr == 55999 or player:GetIsLimitModeEnabled() or player:GetIsExperiencePointsLocked());
    local ok, buffs = pcall(status.player_buffs);
    local n = (ok and type(buffs) == 'table') and #buffs or 0;
    if (n == 0 and not limit_mode) then return 0; end
    return (n > 0) and EXP_HEIGHT_BUFFS or EXP_HEIGHT;
end

local function target_need()
    local need = 0;
    pcall(function ()
        local target = AshitaCore:GetMemoryManager():GetTarget();
        local index = target:GetTargetIndex((target:GetIsSubTargetActive() == 1) and 1 or 0);
        if (index == nil or index == 0) then return; end
        local entity = GetEntity(index);
        if (entity == nil or entity.Name == nil or entity.Name == '') then return; end
        need = TARGET_HEIGHT;
    end);
    return need;
end

-- Tab layout: two rows. Anything not named here goes on the second row, before TH.
local TAB_ROWS = {
    { 'Abyssea', 'Happy Pops', 'Happy Translate', 'Quests', 'Multisend', 'Damage' },
    { 'Character', 'Ultimates', 'Currency', 'Dailies', 'Codex', 'Sky', 'Sea', 'Ventures', 'Sparks', 'Options', 'TH' },
};
local TAB_PAD, TAB_GAP = 8, 4;

local function tab_rows()
    local by = {};
    for _, t in ipairs(tabs) do by[t.label] = t; end
    if (omni.side_tab ~= nil) then by[omni.side_tab.label] = omni.side_tab; end
    local used, rows = {}, { {}, {} };
    for r, names in ipairs(TAB_ROWS) do
        for _, n in ipairs(names) do
            if (by[n] ~= nil) then rows[r][#rows[r] + 1] = by[n]; used[n] = true; end
        end
    end
    -- Extras: second row, just before TH.
    local last = rows[2][#rows[2]];
    local th_last = last ~= nil and last.label == 'TH';
    if (th_last) then rows[2][#rows[2]] = nil; end
    for _, t in ipairs(tabs) do
        if (not used[t.label]) then rows[2][#rows[2] + 1] = t; end
    end
    if (th_last) then rows[2][#rows[2] + 1] = last; end
    -- How wide the panel must be for the longest row (window padding 10 each side).
    local _, sh = imgui.CalcTextSize('Ag');
    local wmax = 0;
    for _, row in ipairs(rows) do
        local w = 0;
        for i, t in ipairs(row) do
            w = w + imgui.CalcTextSize(t.label) + TAB_PAD * 2 + ((i > 1) and TAB_GAP or 0);
            if (t == omni.side_tab) then w = w + 4 + math.floor(sh or 14) * 2; end
        end
        if (_ == 1 and crystal()) then w = w + imgui.CalcTextSize('O M N I') * 1.15 + 22; end
        wmax = math.max(wmax, w);
    end
    omni.tab_rows_width = math.floor(wmax + 22);
    return rows;
end

-- Crystal look for everything drawn inside the panel and the pop-outs: square corners, thin gold
-- frames, see-through buttons with a gold tint, gold ticks / sliders / tabs. Each page keeps its own
-- layout; while the scope is open, any rounding a page asks for becomes 0 and any plain dark button
-- or border colour it pushes is swapped for the Crystal one, so every tab looks the same.
local function gconst(n) local ok, v = pcall(function () return _G[n]; end); return ok and v or nil; end
local ROUND_VARS = {};
for _, n in ipairs({ 'WindowRounding', 'ChildRounding', 'FrameRounding', 'GrabRounding', 'TabRounding', 'PopupRounding', 'ScrollbarRounding' }) do
    local v = gconst('ImGuiStyleVar_' .. n);
    if (v ~= nil) then ROUND_VARS[v] = true; end
end
local BTN_COLS = {};
for _, n in ipairs({ 'Button', 'Tab', 'TabUnfocused', 'FrameBg' }) do
    local v = gconst('ImGuiCol_' .. n);
    if (v ~= nil) then BTN_COLS[v] = n; end
end
local function dull(c)
    if (type(c) ~= 'table' or #c < 3) then return false; end
    local hi = math.max(c[1], c[2], c[3]);
    local lo = math.min(c[1], c[2], c[3]);
    return hi < 0.40 and (hi - lo) < 0.20 and (c[4] == nil or c[4] > 0.2);
end
local cscope = { on = false, vars = 0, cols = 0, real_var = nil, real_col = nil };
-- Themed pages: the theme's pills, its accent when chosen, its dark boxes.
local BG_PILL, BG_HOVER, BG_GOLD, BG_LINE, BG_TINT, BG_INNER = nil, nil, nil, nil, { 1, 1, 1.03 }, nil;
-- Navy / blue-grey shades a page picks for itself become the same shade in the theme's colour.
local function unnavy(c)
    if (type(c) ~= 'table' or #c < 3) then return c; end
    local r, g, b = c[1], c[2], c[3];
    if (math.max(r, g, b) < 0.50 and b - r > 0.025 and b >= g) then
        local v = (r + g + b) / 3 * 0.80;
        return { math.min(1, v * BG_TINT[1]), math.min(1, v * BG_TINT[2]), math.min(1, v * BG_TINT[3]), c[4] or 1.0 };
    end
    return c;
end
local function goldish(c)
    return type(c) == 'table' and #c >= 3 and c[1] > 0.40 and c[1] - c[3] > 0.20 and (c[4] == nil or c[4] > 0.5);
end
local function black_begin()
    local t = theme();
    BG_PILL, BG_HOVER, BG_GOLD, BG_LINE, BG_TINT, BG_INNER = t.pill, t.hover, t.btn, t.line, t.tint, t.inner;
    local rr = (t.style == 'flat') and 0 or 1;
    local vars = {
        { 'ImGuiStyleVar_FrameRounding', 6 * rr }, { 'ImGuiStyleVar_ChildRounding', 8 * rr }, { 'ImGuiStyleVar_GrabRounding', 4 * rr },
        { 'ImGuiStyleVar_TabRounding', 6 * rr }, { 'ImGuiStyleVar_PopupRounding', 6 * rr }, { 'ImGuiStyleVar_ScrollbarRounding', 6 * rr },
        { 'ImGuiStyleVar_FrameBorderSize', 0 }, { 'ImGuiStyleVar_ChildBorderSize', 1 },
    };
    cscope.vars = 0;
    for _, v in ipairs(vars) do
        local id = gconst(v[1]);
        if (id ~= nil and pcall(imgui.PushStyleVar, id, v[2])) then cscope.vars = cscope.vars + 1; end
    end
    local cols = {
        { 'ImGuiCol_Button', BG_PILL }, { 'ImGuiCol_ButtonHovered', BG_HOVER }, { 'ImGuiCol_ButtonActive', BG_GOLD },
        { 'ImGuiCol_Border', BG_LINE }, { 'ImGuiCol_BorderShadow', { 0, 0, 0, 0 } },
        { 'ImGuiCol_FrameBg', BG_PILL }, { 'ImGuiCol_FrameBgHovered', BG_HOVER }, { 'ImGuiCol_FrameBgActive', BG_HOVER },
        { 'ImGuiCol_CheckMark', GOLD }, { 'ImGuiCol_SliderGrab', BG_GOLD }, { 'ImGuiCol_SliderGrabActive', GOLD },
        { 'ImGuiCol_Header', BG_PILL }, { 'ImGuiCol_HeaderHovered', BG_HOVER }, { 'ImGuiCol_HeaderActive', BG_GOLD },
        { 'ImGuiCol_Separator', BG_LINE }, { 'ImGuiCol_SeparatorHovered', BG_HOVER }, { 'ImGuiCol_SeparatorActive', GOLD },
        { 'ImGuiCol_Tab', BG_PILL }, { 'ImGuiCol_TabHovered', BG_HOVER }, { 'ImGuiCol_TabActive', BG_GOLD },
        { 'ImGuiCol_TabUnfocused', BG_PILL }, { 'ImGuiCol_TabUnfocusedActive', BG_GOLD },
        { 'ImGuiCol_ChildBg', BG_INNER }, { 'ImGuiCol_PopupBg', { t.bg[1], t.bg[2], t.bg[3], 0.98 } },
        { 'ImGuiCol_ScrollbarBg', { 0, 0, 0, 0 } }, { 'ImGuiCol_ScrollbarGrab', BG_HOVER },
        { 'ImGuiCol_ScrollbarGrabHovered', BG_LINE }, { 'ImGuiCol_ScrollbarGrabActive', GOLD },
        { 'ImGuiCol_PlotHistogram', BG_GOLD }, { 'ImGuiCol_TextSelectedBg', { t.accent[1], t.accent[2], t.accent[3], 0.35 } },
    };
    cscope.cols = 0;
    for _, c in ipairs(cols) do
        local id = gconst(c[1]);
        if (id ~= nil and pcall(imgui.PushStyleColor, id, c[2])) then cscope.cols = cscope.cols + 1; end
    end
    -- While open: pages' plain dark buttons become grey pills, their "chosen" gold-ish ones bright gold.
    cscope.real_var, cscope.real_col = imgui.PushStyleVar, imgui.PushStyleColor;
    cscope.real_u32 = imgui.GetColorU32;
    local rc, ru = cscope.real_col, cscope.real_u32;
    imgui.PushStyleColor = function (id, col, ...)
        local kind = BTN_COLS[id];
        if (kind ~= nil and dull(col)) then return rc(id, BG_PILL); end
        if ((kind == 'Button' or kind == 'Tab') and goldish(col)) then return rc(id, BG_GOLD); end
        if (id == ImGuiCol_Border and type(col) == 'table' and (col[4] or 1) > 0.05) then return rc(id, BG_LINE); end
        return rc(id, unnavy(col), ...);
    end;
    -- Colours pages draw straight onto the screen (bar tracks, boxes, headers) lose their navy too.
    imgui.GetColorU32 = function (c, ...)
        if (type(c) == 'table') then return ru(unnavy(c), ...); end
        return ru(c, ...);
    end;
end
local function crystal_begin()
    if (cscope.on or not crystal()) then return; end
    cscope.on = true;
    if (black_tab()) then return black_begin(); end
    local vars = {
        { 'ImGuiStyleVar_WindowRounding', 0 }, { 'ImGuiStyleVar_ChildRounding', 0 }, { 'ImGuiStyleVar_FrameRounding', 0 },
        { 'ImGuiStyleVar_GrabRounding', 0 }, { 'ImGuiStyleVar_TabRounding', 0 }, { 'ImGuiStyleVar_PopupRounding', 0 },
        { 'ImGuiStyleVar_ScrollbarRounding', 0 }, { 'ImGuiStyleVar_FrameBorderSize', 1 }, { 'ImGuiStyleVar_ChildBorderSize', 1 },
    };
    cscope.vars = 0;
    for _, v in ipairs(vars) do
        local id = gconst(v[1]);
        if (id ~= nil and pcall(imgui.PushStyleVar, id, v[2])) then cscope.vars = cscope.vars + 1; end
    end
    local G = function (a) return { 0.90, 0.77, 0.42, a }; end
    local cols = {
        { 'ImGuiCol_Button', G(0.07) }, { 'ImGuiCol_ButtonHovered', G(0.18) }, { 'ImGuiCol_ButtonActive', G(0.30) },
        { 'ImGuiCol_Border', G(0.32) }, { 'ImGuiCol_BorderShadow', { 0, 0, 0, 0 } },
        { 'ImGuiCol_FrameBg', { 0.06, 0.08, 0.15, 1.0 } }, { 'ImGuiCol_FrameBgHovered', { 0.10, 0.12, 0.22, 1.0 } },
        { 'ImGuiCol_FrameBgActive', { 0.13, 0.15, 0.27, 1.0 } },
        { 'ImGuiCol_CheckMark', GOLD }, { 'ImGuiCol_SliderGrab', G(0.80) }, { 'ImGuiCol_SliderGrabActive', GOLD },
        { 'ImGuiCol_Header', G(0.12) }, { 'ImGuiCol_HeaderHovered', G(0.20) }, { 'ImGuiCol_HeaderActive', G(0.30) },
        { 'ImGuiCol_Separator', G(0.30) }, { 'ImGuiCol_SeparatorHovered', G(0.50) }, { 'ImGuiCol_SeparatorActive', GOLD },
        { 'ImGuiCol_Tab', { 0, 0, 0, 0 } }, { 'ImGuiCol_TabHovered', G(0.16) }, { 'ImGuiCol_TabActive', G(0.28) },
        { 'ImGuiCol_TabUnfocused', { 0, 0, 0, 0 } }, { 'ImGuiCol_TabUnfocusedActive', G(0.22) },
        { 'ImGuiCol_ChildBg', { 0.05, 0.07, 0.13, 0.55 } }, { 'ImGuiCol_PopupBg', { 0.05, 0.06, 0.12, 0.98 } },
        { 'ImGuiCol_ScrollbarBg', { 0, 0, 0, 0 } }, { 'ImGuiCol_ScrollbarGrab', G(0.35) },
        { 'ImGuiCol_ScrollbarGrabHovered', G(0.55) }, { 'ImGuiCol_ScrollbarGrabActive', GOLD },
        { 'ImGuiCol_PlotHistogram', GOLD }, { 'ImGuiCol_TextSelectedBg', G(0.30) },
    };
    cscope.cols = 0;
    for _, c in ipairs(cols) do
        local id = gconst(c[1]);
        if (id ~= nil and pcall(imgui.PushStyleColor, id, c[2])) then cscope.cols = cscope.cols + 1; end
    end
    -- While open: pages' own rounding becomes square, their plain dark buttons / borders turn Crystal.
    cscope.real_var, cscope.real_col = imgui.PushStyleVar, imgui.PushStyleColor;
    local rv, rc = cscope.real_var, cscope.real_col;
    imgui.PushStyleVar = function (id, val, ...)
        if (ROUND_VARS[id]) then return rv(id, 0); end
        return rv(id, val, ...);
    end;
    imgui.PushStyleColor = function (id, col, ...)
        local kind = BTN_COLS[id];
        if (kind == 'Button' and dull(col)) then return rc(id, G(0.07)); end
        if ((kind == 'Tab' or kind == 'TabUnfocused') and dull(col)) then return rc(id, { 0, 0, 0, 0 }); end
        if (id == ImGuiCol_Border and type(col) == 'table' and (col[4] or 1) > 0.05) then return rc(id, G(0.32)); end
        return rc(id, col, ...);
    end;
end
local function crystal_end()
    if (not cscope.on) then return; end
    imgui.PushStyleVar, imgui.PushStyleColor = cscope.real_var, cscope.real_col;
    if (cscope.real_u32 ~= nil) then imgui.GetColorU32 = cscope.real_u32; cscope.real_u32 = nil; end
    if (cscope.cols > 0) then imgui.PopStyleColor(cscope.cols); end
    if (cscope.vars > 0) then imgui.PopStyleVar(cscope.vars); end
    cscope.on = false;
end
omni.crystal = crystal;

-- One look for every omni pop-out window (AV tracker, Abyssea procs, Happy Healer button):
-- the same background, outline, title bar, buttons and tables as omni's own panel.
-- Modules use it with: local st = package.loaded['omni_style']; local n = st and st.begin(); ... st.finish(n)
local function popout_begin()
    local t = theme();
    local cr = crystal();
    local bg = t and t.bg or (cr and { 0.05, 0.06, 0.12, 0.95 } or { 0.07, 0.08, 0.14, 0.94 });
    local ac = t and t.accent or { 0.90, 0.77, 0.42, 1.0 };
    local rr = (t == nil and cr) and 0 or ((t and t.style == 'flat') and 0 or 8);
    local mix = function (a, k) return { bg[1] + (ac[1] - bg[1]) * k, bg[2] + (ac[2] - bg[2]) * k, bg[3] + (ac[3] - bg[3]) * k, 1.0 }; end
    local n = { cols = 0, vars = 0 };
    local function col(name, c)
        local id = gconst(name);
        if (id ~= nil and pcall(imgui.PushStyleColor, id, c)) then n.cols = n.cols + 1; end
    end
    local function var(name, v)
        local id = gconst(name);
        if (id ~= nil and pcall(imgui.PushStyleVar, id, v)) then n.vars = n.vars + 1; end
    end
    col('ImGuiCol_WindowBg', { bg[1], bg[2], bg[3], 0.96 });
    col('ImGuiCol_Border', { ac[1], ac[2], ac[3], 0.55 });
    col('ImGuiCol_TitleBg', mix(nil, 0.10));
    col('ImGuiCol_TitleBgActive', mix(nil, 0.22));
    col('ImGuiCol_TitleBgCollapsed', mix(nil, 0.10));
    col('ImGuiCol_Text', { 0.92, 0.92, 0.95, 1.0 });
    col('ImGuiCol_TextDisabled', { 0.55, 0.57, 0.63, 1.0 });
    col('ImGuiCol_ResizeGrip', { 0, 0, 0, 0 });
    col('ImGuiCol_TableHeaderBg', mix(nil, 0.14));
    col('ImGuiCol_TableBorderStrong', { ac[1], ac[2], ac[3], 0.30 });
    col('ImGuiCol_TableBorderLight', { ac[1], ac[2], ac[3], 0.15 });
    col('ImGuiCol_TableRowBg', { 0, 0, 0, 0 });
    col('ImGuiCol_TableRowBgAlt', { 1, 1, 1, 0.03 });
    var('ImGuiStyleVar_WindowRounding', rr);
    var('ImGuiStyleVar_WindowBorderSize', 1);
    -- Buttons, boxes, tabs and the rest: the same as the panel's.
    if (not cscope.on and cr) then
        if (t ~= nil) then
            cscope.on = true;
            black_begin();
        else
            crystal_begin();
        end
        n.scope = cscope.on;
    end
    return n;
end
local function popout_end(n)
    if (n == nil) then return; end
    if (n.scope) then crystal_end(); end
    if (n.cols > 0) then imgui.PopStyleColor(n.cols); end
    if (n.vars > 0) then imgui.PopStyleVar(n.vars); end
end
-- A small On / Off slider (the Happy Healer one): green pill with a white knob. Returns true if clicked.
local function pill_switch(id, on, tip)
    local x, y = imgui.GetCursorScreenPos();
    local _, th = imgui.CalcTextSize('Ag');
    local h = math.floor(th or 14);
    local w = h * 2;
    local bh = h + 6;                      -- same height as the tab buttons
    y = y + math.floor((bh - h) / 2);
    local clicked = imgui.InvisibleButton(id, { w, bh });
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, imgui.GetColorU32(on and { 0.24, 0.62, 0.30, 1.0 } or { 0.22, 0.23, 0.32, 1.0 }), h / 2);
    local cx = on and (x + w - h / 2) or (x + h / 2);
    dl:AddCircleFilled({ cx, y + h / 2 }, h / 2 - 2, imgui.GetColorU32({ 0.95, 0.95, 0.97, 1.0 }), 16);
    if (tip ~= nil and imgui.IsItemHovered()) then imgui.SetTooltip(tip); end
    return clicked;
end
omni.pill_switch = pill_switch;

-- Happy Translate's On / Off switch, right after its tab.
local function tr_switch()
    local on = omni.translate.enabled();
    if (pill_switch('##tr_switch', on, on and 'Happy Translate is on - click to turn it off.' or 'Happy Translate is off - click to turn it on.')) then
        omni.translate.set(not on);
    end
end

package.loaded['omni_style'] = { begin = popout_begin, finish = popout_end, theme = theme, switch = pill_switch };

local function draw_panel()
    local s = omni.settings;

    imgui.SetNextWindowPos({ s.bar_x, s.bar_y + BAR_HEIGHT - 1 + omni.exp_h + omni.target_h }, ImGuiCond_Always);
    -- As wide as the bar, or wider if the tab showing needs more room. Height fits the content.
    local width = omni.bar_width;
    if (omni.active ~= nil and omni.active.width ~= nil and omni.active.width > width) then
        width = omni.active.width;
    end
    width = math.max(width, omni.tab_rows_width or 0);
    imgui.SetNextWindowSize({ width, 0 }, ImGuiCond_Always);
    local orn = crystal();
    imgui.PushStyleColor(ImGuiCol_WindowBg, orn and { 0, 0, 0, 0 } or s.colors.panel);
    imgui.PushStyleColor(ImGuiCol_Border, orn and { 0, 0, 0, 0 } or s.colors.border);
    imgui.PushStyleColor(ImGuiCol_Text, s.colors.text);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, orn and { 16, 12 } or { 10, 8 });
    local square = crystal();
    if (square) then imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 0); end

    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoSavedSettings);

    if (imgui.Begin('OmniPanel' .. omni.suffix, omni.bar_open, flags)) then
        local cr = crystal();
        if (cr) then
            local pwx, pwy = imgui.GetWindowPos();
            local pww, pwh = imgui.GetWindowWidth(), imgui.GetWindowHeight();
            if (type(pwh) == 'number' and pwh > 30) then
                if (black_tab()) then
                    pcall(theme_frame, imgui.GetWindowDrawList(), pwx + 1, pwy + 2, pwx + pww - 1, pwy + pwh - 1, theme().bg);
                else
                    pcall(ornate, imgui.GetWindowDrawList(), pwx + 1, pwy + 2, pwx + pww - 1, pwy + pwh - 1, 'bevel', { 0.035, 0.050, 0.12, 0.95 }, 12);
                end
            end
        end
        -- Heading (Crystal: "OMNI" in gold capitals on the same line as the top row of tabs).
        if (cr) then
            imgui.SetWindowFontScale(1.15);
            imgui.TextColored(GOLD, 'O M N I');
            imgui.SetWindowFontScale(1.0);
            imgui.SameLine(0, 22);
        else
            imgui.TextColored(s.colors.heading, PANEL_HEADING);
            imgui.PushStyleColor(ImGuiCol_Separator, { 0.79, 0.69, 0.42, 0.55 });
            imgui.Separator();
            imgui.PopStyleColor(1);
        end

        imgui.PushStyleColor(ImGuiCol_Button, s.colors.button);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, s.colors.hover);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, s.colors.hover);
        imgui.PushStyleColor(ImGuiCol_Tab, s.colors.tab);
        imgui.PushStyleColor(ImGuiCol_TabHovered, s.colors.hover);
        imgui.PushStyleColor(ImGuiCol_TabActive, s.colors.tab_active);

        -- Tabs in two rows of buttons (see TAB_ROWS), then the chosen tab's page.
        local rows = tab_rows();
        local sel = nil;
        for _, row in ipairs(rows) do for _, t in ipairs(row) do if (t.label == omni.sel) then sel = t; end end end
        if (sel == nil) then sel = rows[2][1] or rows[1][1]; omni.sel = sel and sel.label; end
        imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { TAB_PAD, 3 });
        imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { TAB_GAP, 4 });
        for r, row in ipairs(rows) do
            if (cr and r == 2) then
                -- thin gold line between the two rows
                local lx, ly = imgui.GetCursorScreenPos();
                imgui.GetWindowDrawList():AddLine({ lx, ly }, { lx + imgui.GetContentRegionAvail(), ly }, imgui.GetColorU32({ 0.90, 0.77, 0.42, 0.18 }), 1);
                imgui.Dummy({ 1, 2 });
            end
            for i, t in ipairs(row) do
                if (i > 1) then imgui.SameLine(0, TAB_GAP); end
                local on = (t == sel);
                if (cr) then
                    -- Text tabs: gold and underlined when chosen, top row brighter than the second.
                    imgui.PushStyleColor(ImGuiCol_Button, { 0, 0, 0, 0 });
                    imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.90, 0.77, 0.42, 0.10 });
                    imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.90, 0.77, 0.42, 0.18 });
                    imgui.PushStyleColor(ImGuiCol_Text, on and GOLD or (r == 1 and { 0.85, 0.85, 0.90, 1.0 } or s.colors.dim));
                else
                    imgui.PushStyleColor(ImGuiCol_Button, on and s.colors.tab_active or s.colors.tab);
                end
                if (imgui.Button(t.label .. '##omni_tab', { imgui.CalcTextSize(t.label) + TAB_PAD * 2, 0 })) then omni.sel = t.label; end
                if (cr and on) then
                    local a1x, _ = imgui.GetItemRectMin();
                    local a2x, a2y = imgui.GetItemRectMax();
                    if (type(a1x) == 'number' and type(a2y) == 'number') then
                        local tdl = imgui.GetWindowDrawList();
                        -- glowing underline: soft wide glow, then the bright line, then a gem in the middle
                        tdl:AddRectFilled({ a1x + 2, a2y - 5 }, { a2x - 2, a2y }, imgui.GetColorU32({ 0.90, 0.77, 0.42, 0.10 }));
                        tdl:AddLine({ a1x + TAB_PAD - 2, a2y - 1 }, { a2x - TAB_PAD + 2, a2y - 1 }, imgui.GetColorU32(GOLD), 2);
                        diamond(tdl, (a1x + a2x) / 2, a2y - 1, 3, { 0.98, 0.92, 0.75, 1.0 });
                    end
                end
                imgui.PopStyleColor(cr and 4 or 1);
                -- Happy Translate's On / Off switch sits right after its tab.
                if (t.label == 'Happy Translate' and omni.translate ~= nil) then
                    imgui.SameLine(0, 4);
                    tr_switch();
                end
            end
        end
        imgui.PopStyleVar(2);
        imgui.PushStyleColor(ImGuiCol_Separator, { 0.79, 0.69, 0.42, cr and 0.45 or 0.35 });
        imgui.Separator();
        imgui.PopStyleColor(1);
        if (sel ~= nil) then
            omni.active = sel;
            -- Black & Gold: no grey behind the page, the black panel shows through.
            local bt = cr and theme() ~= nil and sel.bg == nil;
            if (bt) then imgui.PushStyleColor(ImGuiCol_ChildBg, { 0, 0, 0, 0 }); end
            imgui.BeginChild('##omni_tab_' .. sel.label, { 0, sel.height or 300 }, false);
            if (bt) then imgui.PopStyleColor(1); end
            -- A painted background behind some tabs (Crystal look), dimmed so the text stays easy to read.
            if (cr and sel.bg ~= nil and trove.fileHandle ~= nil) then
                local h = trove.fileHandle(sel.bg);
                if (h ~= nil) then
                    local bdl = imgui.GetWindowDrawList();
                    local bx, by = imgui.GetWindowPos();
                    local bw, bh = imgui.GetWindowWidth(), imgui.GetWindowHeight();
                    -- cover the area, keeping the picture's shape (16:9), centred
                    local iw, ih = bw, bw * 9 / 16;
                    if (ih < bh) then ih = bh; iw = bh * 16 / 9; end
                    local ox, oy = bx + (bw - iw) / 2, by + (bh - ih) / 2;
                    pcall(function () bdl:AddImage(h, { ox, oy }, { ox + iw, oy + ih }); end);
                    bdl:AddRectFilled({ bx, by }, { bx + bw, by + bh }, imgui.GetColorU32({ 0.02, 0.03, 0.08, 0.62 }));
                end
            end
            crystal_begin();
            local okr, err = pcall(sel.render);
            crystal_end();
            if (not okr) then imgui.TextColored({ 1, 0.45, 0.45, 1 }, tostring(err)); end
            imgui.EndChild();
        end

        imgui.PopStyleColor(6);
    end
    imgui.End();

    imgui.PopStyleVar(square and 2 or 1);
    imgui.PopStyleColor(3);
end

----------------------------------------------------------------------------------------------------
-- Events
----------------------------------------------------------------------------------------------------
ashita.events.register('load', 'omni_load', function ()
    omni.icons = load_icons();
    -- 2.05: switch Black & Gold on once so it can be tried (Options > Look puts it back).
    if (omni.settings.bg_trial ~= true) then
        omni.settings.bg_trial = true;
        omni.settings.look_before = omni.settings.look;
        omni.settings.look = 'blackgold';
        pcall(settings.save, 'omni');
    end
    -- 2.18: spell lines back to the drawn look (AI art off) once; Options > AI art turns it on again.
    if (omni.settings.fx_art_reset ~= true) then
        omni.settings.fx_art_reset = true;
        omni.settings.fx_art = false;
        pcall(settings.save, 'omni');
    end
    omni.started = true;   -- the game is up
end);

ashita.events.register('unload', 'omni_unload', function ()
    settings.save('omni');
    trove.unload();
    status.unload();
end);

ashita.events.register('command', 'omni_command', function (e)
    local args = e.command:args();
    if (#args == 0) then
        return;
    end
    local cmd = args[1]:lower();

    -- /ddr : reset the damage meter.
    if (cmd == '/ddr') then
        e.blocked = true;
        deeps_reset();
        print('[omni] Damage meter reset.');
        return;
    end

    -- /ddp [number] : put the top damage dealers in party chat, 1st place first.
    -- Without a number it uses the "Show top" choice from the Damage tab.
    if (cmd == '/ddp') then
        e.blocked = true;
        local count = tonumber(args[2] or '') or omni.settings.deeps_top or 5;
        count = math.max(1, math.min(18, math.floor(count)));
        deeps_report(count);
        return;
    end

    if (cmd ~= '/omni') then
        return;
    end
    e.blocked = true;
    -- /omni fx [kind] : play a spell-line effect from you to your target (no kind: list them).
    if (args[2] ~= nil and args[2]:lower() == 'fx') then
        if (omni.fx == nil) then print('[omni] Spell lines are not loaded.'); return; end
        local k = (args[3] or ''):lower();
        if (k ~= '' and omni.fx.test(k, args[4])) then return; end
        local names = {};
        for n in pairs(omni.fx.kinds) do names[#names + 1] = n; end
        table.sort(names);
        print('[omni] /omni fx <kind>: ' .. table.concat(names, ', '));
        return;
    end
    -- /omni sea prints what the Sea tab's gear scan read off each Homam and Nashira piece.
    if (args[2] ~= nil and args[2]:lower() == 'sea') then
        for _, section in ipairs(trove.sections) do
            if (section.label == 'Sea' and section.plugin ~= nil and section.plugin.omniReport ~= nil) then
                local ok, lines = pcall(section.plugin.omniReport);
                if (ok and type(lines) == 'table') then
                    for _, line in ipairs(lines) do
                        print('[omni] ' .. line);
                    end
                else
                    print('[omni] Could not scan: ' .. tostring(lines));
                end
            end
        end
        return;
    end
    -- /omni version says which version is running (handy after an update).
    if (args[2] ~= nil and args[2]:lower() == 'version') then
        print('[omni] Running version ' .. addon.version);
        return;
    end
    -- /omni reset clears the Deeps damage meter.
    if (args[2] ~= nil and args[2]:lower() == 'reset') then
        deeps_reset();
        print('[omni] Damage meter reset.');
        return;
    end
    -- /omni opens or closes the drop-down panel.
    omni.expanded = not omni.expanded;
end);

ashita.events.register('packet_in', 'omni_packet_in', function (e)
    -- The Sparks tab's purchase: hides the shop menu while omni buys.
    local ok, hide = pcall(sparks.on_packet, e);
    if (ok and hide) then
        e.blocked = true;
        return;
    end

    trove.packet_in(e);

    if (e.id == 0x028) then
        -- Action packet: feeds the Deeps damage meter.
        local ok, act = pcall(action.parse, e.data);
        if (ok and act ~= nil) then
            pcall(deeps_action, act);
            pcall(damage_adv.on_action, act);   -- the Advanced damage page
            pcall(status.on_action, act);     -- debuffs landing on monsters
        end
        return;
    elseif (e.id == 0x029) then
        pcall(status.on_message, e.data);     -- effects wearing off, monsters dying
        return;
    elseif (e.id == 0x00A) then
        pcall(status.on_zone);
    elseif (e.id == 0x076) then
        pcall(status.on_party_buffs, e);
        return;
    end

    if (e.id == 0x02D) then
        -- Kill message: XP or limit points gained, with the chain number.
        local entity = GetPlayerEntity();
        if (entity == nil) then
            return;
        end
        local who    = struct.unpack('I', e.data_modified, 0x05);
        local amount = struct.unpack('I', e.data_modified, 0x11);
        local chain  = struct.unpack('I', e.data_modified, 0x15);
        local msg    = struct.unpack('H', e.data_modified, 0x19) % 1024;
        if (who == entity.ServerId and (msg == 8 or msg == 105 or msg == 253 or msg == 371 or msg == 372)) then
            xp_gained(amount, chain, AshitaCore:GetMemoryManager():GetPlayer():GetMainJobLevel());
        end
    elseif (e.id == 0x061) then
        -- Character stats: the exact XP numbers (also sent on level and job change).
        xp.curr = struct.unpack('H', e.data_modified, 0x11);
        xp.max  = struct.unpack('H', e.data_modified, 0x13);
        wallet.accolades = math.floor(e.data_modified:byte(0x5A) / 4) + e.data_modified:byte(0x5B) * 2 ^ 6 + e.data_modified:byte(0x5C) * 2 ^ 14;
    elseif (e.id == 0x063 and e.data_modified:byte(5) == 2) then
        -- Merit information: the exact limit points.
        xp.limit = struct.unpack('H', e.data_modified, 9);
    elseif (e.id == 0x1A3) then
        pcall(ventures.on_packet, e.data);
    elseif (e.id == 0x110) then
        -- Sparks changed.
        wallet.sparks = struct.unpack('I', e.data, 0x05);
    elseif (e.id == 0x113) then
        -- Currency list: sparks and accolades.
        wallet.sparks    = struct.unpack('I', e.data, 0x75);
        wallet.accolades = struct.unpack('I', e.data, 0xE5);
        pcall(currency.on_packet, e.data);
    end
end);

-- Chat lines: the Ventures tab catches the server's !ventures answer.
ashita.events.register('text_in', 'omni_text_in', function (e)
    if (e.injected) then
        return;
    end
    local ok, hide = pcall(ventures.on_text, e);
    if (ok and hide) then
        e.blocked = true;
    end
    if (omni.sky ~= nil) then
        local ok2, hide2 = pcall(omni.sky.on_text, e);
        if (ok2 and hide2) then
            e.blocked = true;
        end
    end
end);

ashita.events.register('d3d_present', 'omni_present', function ()
    if (omni.chatcolors ~= nil) then omni.chatcolors.settings = omni.settings; end
    pcall(apply_accent);
    pcall(sparks.tick);
    pcall(sparks.sell.tick);
    local entity = GetPlayerEntity();
    if (entity == nil) then
        return;
    end
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local job = player:GetMainJob();
    if (player.isZoning or job == 0) then
        return;
    end
    omni.suffix = '_' .. entity.Name;

    if (not xp.ready) then
        xp_init(player);
    end
    if (not wallet.ready) then
        wallet_init(player);
    end
    xp_tick();

    trove.load();   -- does its work once, on the first frame
    if (trove.setLook ~= nil) then pcall(trove.setLook, crystal() and (black_tab() and omni.settings.look or 'crystal') or 'omni'); end

    -- Keep the game's own buff icons (top-left) hidden; omni shows them on the XP bar instead.
    -- Checked every few seconds so it also takes over if another addon stops hiding them.
    if (os.clock() >= (omni.native_check or 0)) then
        omni.native_check = os.clock() + 5;
        if (omni.settings.show_native) then
            pcall(status.restore_native);
        else
            pcall(status.hide_native);
        end
    end
    deeps_say_tick();

    draw_bar(player, job);
    -- Hidden mode: only the main bar stays on screen.
    if (omni.settings.minimal) then
        omni.expanded = false;
        trove.frame(nil);
        return;
    end
    -- One row under the main bar: your buffs on the left, the target bar on the right.
    -- Either one takes the whole width when the other has nothing to show.
    omni.buff_times = false;
    local eh = exp_need(player);
    local th = target_need();
    local W = omni.bar_width;
    local row = 0;
    if (eh > 0 and th > 0) then
        local lw = math.floor(W * 0.42);
        row = math.max(eh, th);
        draw_exp(player, job, 0, lw, row);
        draw_target(lw - 1, W - lw + 1, row);
    elseif (eh > 0) then
        row = draw_exp(player, job, 0, W, eh);
    elseif (th > 0) then
        row = draw_target(0, W, th);
    end
    omni.exp_h = math.max(0, row - 1);
    -- Buff times hang under the row: keep the panel clear of them.
    if (omni.buff_times and eh > 0) then omni.exp_h = omni.exp_h + BUFF_TIME_H; end
    omni.target_h = 0;
    if (omni.expanded) then
        draw_panel();
    end
    if (omni.abyssea_popout ~= nil) then
        crystal_begin(); pcall(omni.abyssea_popout); crystal_end();
    end
    -- Job pictures beside the game's party list (omni_party.lua).
    if (omni.party ~= nil) then
        omni.party_opts.settings = omni.settings;
        omni.party_opts.icons = omni.icons;
        pcall(omni.party.render, omni.party_opts);
    end
    -- Tell the Trove screens which one is showing (none while the panel is closed).
    trove.frame((omni.expanded and omni.active ~= nil) and omni.active.section or nil);
end);
