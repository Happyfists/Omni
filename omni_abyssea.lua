--[[
    omni_abyssea.lua - Abyssea: Visitant time and lights.

    While you are in one of the nine Abyssea field zones, omni's points bar shows your
    Visitant time left and all seven lights instead of XP and the wallet.

    Read passively from what the game already sends (no packets sent, nothing polled):
      * the Abyssea status messages (packet 0x02A) - lights and time,
      * the matching chat lines ("visitant status will wear off in ...", "Pearlescent: 10 / Ebon: 2",
        "body emits a faint azure light!") as a back-up.

    Message numbers and light gains from the Abyssea Tracker addon by IntegReady (CatsEyeXI edition),
    which follows the Ashita Points addon.
]]

local imgui = require('imgui');

local aby = {};

-- Abyssea zone id -> base message id of its status messages.
local ZONES = {
    [15]  = 7315, -- Konschtat
    [132] = 7315, -- La Theine
    [45]  = 7315, -- Tahrongi
    [215] = 7215, -- Attohwa
    [216] = 7315, -- Misareaux
    [217] = 7315, -- Vunkerl
    [218] = 7315, -- Altepa
    [253] = 7215, -- Uleguerand
    [254] = 7315, -- Grauberg
};

-- The seven lights: key, short label, colour, cap.
aby.LIGHTS = {
    { key = 'pearlescent', label = 'Pearl',  col = { 0.92, 0.92, 0.98, 1.0 }, max = 230 },
    { key = 'azure',       label = 'Azure',  col = { 0.30, 0.65, 1.00, 1.0 }, max = 255 },
    { key = 'ruby',        label = 'Ruby',   col = { 1.00, 0.35, 0.35, 1.0 }, max = 255 },
    { key = 'amber',       label = 'Amber',  col = { 1.00, 0.68, 0.25, 1.0 }, max = 255 },
    { key = 'golden',      label = 'Gold',   col = { 1.00, 0.84, 0.30, 1.0 }, max = 200 },
    { key = 'silvery',     label = 'Silver', col = { 0.78, 0.84, 0.94, 1.0 }, max = 200 },
    { key = 'ebon',        label = 'Ebon',   col = { 0.66, 0.52, 0.86, 1.0 }, max = 200 },
};

-- Light gained per message strength.
local GAINS = {
    pearlescent = { feeble = 0, faint = 5,  mild = 10, strong = 15, intense = 0 },
    golden      = { feeble = 0, faint = 5,  mild = 10, strong = 15, intense = 0 },
    silvery     = { feeble = 0, faint = 5,  mild = 10, strong = 15, intense = 0 },
    ebon        = { feeble = 0, faint = 1,  mild = 2,  strong = 3,  intense = 0 },
    azure       = { feeble = 8, faint = 16, mild = 24, strong = 32, intense = 64 },
    ruby        = { feeble = 8, faint = 16, mild = 24, strong = 32, intense = 64 },
    amber       = { feeble = 8, faint = 16, mild = 24, strong = 32, intense = 64 },
};
local CAP = {};
for _, l in ipairs(aby.LIGHTS) do CAP[l.key] = l.max; end

local st = {
    zone = 0,
    inside = false,
    lights = {},
    minutes = nil,     -- Visitant minutes left when last told
    anchor = 0,        -- os.clock() when last told
};

local function reset_lights()
    for _, l in ipairs(aby.LIGHTS) do st.lights[l.key] = 0; end
end
reset_lights();

local function zone_now()
    local z = 0;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    return tonumber(z) or 0;
end

local function check_zone()
    local z = zone_now();
    if z ~= st.zone then
        st.zone = z;
        st.inside = ZONES[z] ~= nil;
        reset_lights();
        st.minutes, st.anchor = nil, 0;
    end
end

local function set_minutes(m)
    m = tonumber(m);
    if m == nil then return; end
    st.minutes, st.anchor = math.max(0, m), os.clock();
end

local function minutes_left()
    if st.minutes == nil then return nil; end
    return math.max(0, st.minutes - (os.clock() - st.anchor) / 60);
end

local function add_light(key, n)
    st.lights[key] = math.min((st.lights[key] or 0) + n, CAP[key] or 255);
end

----------------------------------------------------------------------------------------------------
-- Reading what the game sends
----------------------------------------------------------------------------------------------------
local function u16(d, o) local a, b = d:byte(o + 1, o + 2); if not b then return nil; end return a + b * 256; end
local function u32(d, o)
    local a, b, c, e = d:byte(o + 1, o + 4);
    if not e then return 0; end
    return a + b * 0x100 + c * 0x10000 + e * 0x1000000;
end

local function on_status(d)
    if not st.inside or #d < 0x1C then return; end
    local base = ZONES[st.zone];
    local msg = u16(d, 0x1A);
    if base == nil or msg == nil then return; end
    local rel = (msg % 0x4000) - base;
    local p1, p2, p3, p4 = u32(d, 0x08), u32(d, 0x0C), u32(d, 0x10), u32(d, 0x14);
    local L = st.lights;
    if rel == 0 then
        L.pearlescent, L.ebon, L.golden, L.silvery = p1, p2, p3, p4;
    elseif rel == 1 then
        L.azure, L.ruby, L.amber = p1, p2, p3;
    elseif rel == 9 or rel == 10 or rel == 45 then
        set_minutes(p1);
    elseif rel == 12 then
        set_minutes((minutes_left() or 0) + p1);
    elseif rel == 183 then add_light('pearlescent', 5);
    elseif rel == 184 then add_light('golden', 5 * (p1 + 1));
    elseif rel == 185 then add_light('silvery', 5 * (p1 + 1));
    elseif rel == 186 then add_light('ebon', p1 + 1);
    elseif rel == 187 then add_light('azure', 8);
    elseif rel == 188 then add_light('ruby', 8);
    elseif rel == 189 then add_light('amber', 8);
    end
end

local function on_text(msg)
    if not st.inside or type(msg) ~= 'string' then return; end
    local t = msg:gsub('[\30\31].', ''):lower();
    local n, unit = t:match('visitant status will wear off in (%d+) (%a+)');
    if n then
        set_minutes(unit:sub(1, 3) == 'min' and tonumber(n) or tonumber(n) / 60);
        return;
    end
    local a, b = t:match('pearlescent: (%d+) / ebon: (%d+)');
    if a then st.lights.pearlescent, st.lights.ebon = tonumber(a), tonumber(b); end
    a, b = t:match('golden: (%d+) / silvery: (%d+)');
    if a then st.lights.golden, st.lights.silvery = tonumber(a), tonumber(b); end
    local c;
    a, b, c = t:match('azure: (%d+) / ruby: (%d+) / amber: (%d+)');
    if a then st.lights.azure, st.lights.ruby, st.lights.amber = tonumber(a), tonumber(b), tonumber(c); end
    local strength, light = t:match('body emits an? (%a+) (%a+) light!');
    if strength and GAINS[light] and GAINS[light][strength] then
        add_light(light, GAINS[light][strength]);
    end
end

ashita.events.register('packet_in', 'omni_abyssea_in', function (e)
    if e.id == 0x00A then
        st.zone = -1;                -- zoning: look again next frame
    elseif e.id == 0x02A and e.data then
        pcall(on_status, e.data);
    end
end);

ashita.events.register('text_in', 'omni_abyssea_text', function (e)
    pcall(on_text, e.message);
end);

----------------------------------------------------------------------------------------------------
-- For omni
----------------------------------------------------------------------------------------------------
-- In an Abyssea field zone right now?
aby.inside = function ()
    check_zone();
    return st.inside;
end

aby.lights = function () return st.lights; end
aby.minutes_left = minutes_left;

-- Time left as text: "1:02:05", "45:12", or "--:--" until the game says.
aby.time_text = function ()
    local m = minutes_left();
    if m == nil then return '--:--'; end
    local s = math.floor(m * 60);
    local h = math.floor(s / 3600);
    if h > 0 then return string.format('%d:%02d:%02d', h, math.floor((s % 3600) / 60), s % 60); end
    return string.format('%02d:%02d', math.floor(s / 60), s % 60);
end

-- Drawn on the points bar in place of XP and the wallet (c = omni colours).
local PURPLE = { 0.78, 0.58, 1.00, 1.0 };
aby.draw_bar = function (c)
    imgui.TextColored(PURPLE, 'Abyssea');
    imgui.SameLine(0, 12);
    imgui.TextColored(c.label, 'Time');
    imgui.SameLine(0, 5);
    local m = minutes_left();
    local tcol = (m == nil) and c.dim or ((m <= 5) and { 1.0, 0.40, 0.40, 1.0 } or ((m <= 15) and { 1.0, 0.80, 0.30, 1.0 } or { 0.50, 0.92, 0.50, 1.0 }));
    imgui.TextColored(tcol, aby.time_text());
    if imgui.IsItemHovered() then
        imgui.SetTooltip((m == nil) and 'Visitant time shows once the game tells you it (on entering, or when it changes).'
            or 'Visitant time left. Turns yellow at 15 minutes and red at 5.');
    end
    for _, l in ipairs(aby.LIGHTS) do
        imgui.SameLine(0, 14);
        imgui.TextColored(l.col, l.label);
        imgui.SameLine(0, 5);
        local v = st.lights[l.key] or 0;
        -- Capped lights show in gold.
        imgui.TextColored((v >= l.max) and { 1.0, 0.84, 0.30, 1.0 } or c.text, tostring(v));
        if imgui.IsItemHovered() then
            imgui.SetTooltip(string.format('%s light: %d / %d%s', l.label, v, l.max, (v >= l.max) and '  (capped)' or ''));
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Vana'diel clock (read from the game, same signature as Abystagger / LuAshitacast)
----------------------------------------------------------------------------------------------------
local DAYS = { 'Firesday', 'Earthsday', 'Watersday', 'Windsday', 'Iceday', 'Lightningday', 'Lightsday', 'Darksday' };
local clock_sig = nil;
local function vana()
    if clock_sig == nil then
        clock_sig = 0;
        pcall(function ()
            clock_sig = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0x34, 0) or 0;
        end);
    end
    if clock_sig == 0 then return nil; end
    local ok, t = pcall(function ()
        local p = ashita.memory.read_uint32(clock_sig);
        if p == nil or p == 0 then return nil; end
        local raw = ashita.memory.read_uint32(p + 0x0C);
        if raw == nil then return nil; end
        local ts = (raw + 92514960) * 25;
        return { hour = math.floor(ts / 3600) % 24, minute = math.floor(ts / 60) % 60, weekday = math.floor(ts / 86400) % 8 };
    end);
    if ok then return t; end
    return nil;
end
aby.vana = vana;

-- Game minutes -> real time text (one game day is 57.6 real minutes).
local function real_in(game_minutes)
    local secs = math.floor(game_minutes * 60 / 25);
    if secs >= 60 then return string.format('%d min', math.floor(secs / 60 + 0.5)); end
    return string.format('%d s', secs);
end

----------------------------------------------------------------------------------------------------
-- Procs: what triggers each colour (from Abyssea Tracker and Abystagger; skill levels from omni's
-- weapon skill data, which comes from the CatsEyeXI server files)
----------------------------------------------------------------------------------------------------
local RED = {
    'Cyclone', 'Energy Drain', 'Red Lotus Blade', 'Seraph Blade', 'Freezebite', 'Shadow of Death',
    'Raiden Thrust', 'Blade: Ei', 'Tachi: Jinpu', 'Tachi: Koki', 'Seraph Strike', 'Earth Crusher', 'Sunburst',
};
local BLUE = {
    { key = 'piercing', name = 'Piercing', from = 6 * 60,  to = 14 * 60, ws = {
        'Shadowstitch', 'Dancing Edge', 'Shark Bite', 'Evisceration', 'Skewer', 'Wheeling Thrust', 'Impulse Drive',
        'Sidewinder', 'Blast Arrow', 'Arching Arrow', 'Empyreal Arrow', 'Slug Shot', 'Blast Shot', 'Heavy Shot', 'Detonator' } },
    { key = 'slashing', name = 'Slashing', from = 14 * 60, to = 22 * 60, ws = {
        'Vorpal Blade', 'Swift Blade', 'Savage Blade', 'Spinning Slash', 'Ground Strike', 'Mistral Axe', 'Decimation',
        'Full Break', 'Steel Cyclone', 'Cross Reaper', 'Spiral Hell', 'Blade: Ten', 'Blade: Ku', 'Tachi: Gekko', 'Tachi: Kasha' } },
    { key = 'blunt', name = 'Blunt', from = 22 * 60, to = 6 * 60, ws = {
        'Raging Fists', 'Spinning Attack', 'Howling Fist', 'Dragon Kick', 'Asuran Fists', 'Skullbreaker', 'True Strike',
        'Judgment', 'Hexa Strike', 'Black Halo', 'Heavy Swing', 'Shell Crusher', 'Full Swing', 'Spirit Taker', 'Retribution' } },
};
local YELLOW = {
    Firesday     = { 'Fire III', 'Fire IV', 'Firaga III', 'Flare', 'Katon: Ni', 'Ice Threnody', 'Heat Breath' },
    Earthsday    = { 'Stone III', 'Stone IV', 'Stonega III', 'Quake', 'Doton: Ni', 'Lightning Threnody', 'Magnetite Cloud' },
    Watersday    = { 'Water III', 'Water IV', 'Waterga III', 'Flood', 'Suiton: Ni', 'Fire Threnody', 'Maelstrom' },
    Windsday     = { 'Aero III', 'Aero IV', 'Aeroga III', 'Tornado', 'Huton: Ni', 'Earth Threnody', 'Mysterious Light' },
    Iceday       = { 'Blizzard III', 'Blizzard IV', 'Blizzaga III', 'Freeze', 'Hyoton: Ni', 'Wind Threnody', 'Ice Break' },
    Lightningday = { 'Thunder III', 'Thunder IV', 'Thundaga III', 'Burst', 'Raiton: Ni', 'Water Threnody', 'Mind Blast' },
    Lightsday    = { 'Banish II', 'Banish III', 'Banishga II', 'Holy', 'Flash', 'Dark Threnody', 'Radiant Breath' },
    Darksday     = { 'Drain', 'Aspir', 'Dispel', 'Bio II', 'Kurayami: Ni', 'Light Threnody', 'Eyes On Me' },
};

local SKILL = { [1] = 'Hand-to-Hand', [2] = 'Dagger', [3] = 'Sword', [4] = 'Great Sword', [5] = 'Axe', [6] = 'Great Axe',
    [7] = 'Scythe', [8] = 'Polearm', [9] = 'Katana', [10] = 'Great Katana', [11] = 'Club', [12] = 'Staff',
    [25] = 'Archery', [26] = 'Marksmanship' };
local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM',
    'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };

local WS = nil;   -- name -> { id, skill, level, quest, jobs }
local function ws_info(name)
    if WS == nil then
        WS = {};
        local ok, data = pcall(require, 'plugins/data/ws_data');
        if ok and type(data) == 'table' then
            for _, w in ipairs(data) do WS[w.name:lower()] = w; end
        end
    end
    return WS[name:lower()];
end

-- Can you use this weapon skill right now (your main job)?
local use_cache, use_at = {}, -10;
local function can_ws(name)
    if os.clock() - use_at > 2 then use_cache, use_at = {}, os.clock(); end
    if use_cache[name] ~= nil then return use_cache[name]; end
    local w = ws_info(name);
    local ok = false;
    if w then
        pcall(function ()
            local p = AshitaCore:GetMemoryManager():GetPlayer();
            if p:HasWeaponSkill(w.id) then ok = true; return; end
            local job = JOBS[p:GetMainJob()] or '';
            local jobOk = (' ' .. w.jobs .. ' '):find(' ' .. job .. ' ', 1, true) ~= nil;
            local skill = p:GetCombatSkill(w.skill):GetSkill() or 0;
            ok = (not w.quest) and jobOk and skill >= w.level;
        end);
    end
    use_cache[name] = ok;
    return ok;
end

-- Can you cast this spell right now (learned, and your main or support job has it at its level)?
local spell_ids = nil;
local function can_cast(name)
    if os.clock() - use_at > 2 then use_cache, use_at = {}, os.clock(); end
    local key = 'spell:' .. name;
    if use_cache[key] ~= nil then return use_cache[key]; end
    if spell_ids == nil then
        spell_ids = {};
        pcall(function ()
            local res = AshitaCore:GetResourceManager();
            for i = 1, 1024 do
                local sp = res:GetSpellById(i);
                if sp and sp.Name and sp.Name[1] and sp.Name[1] ~= '' then spell_ids[sp.Name[1]:lower()] = spell_ids[sp.Name[1]:lower()] or i; end
            end
        end);
    end
    local ok = false;
    local id = spell_ids[name:lower()];
    if id then
        pcall(function ()
            local p = AshitaCore:GetMemoryManager():GetPlayer();
            if not p:HasSpell(id) then return; end
            local sp = AshitaCore:GetResourceManager():GetSpellById(id);
            local mj, ml, sj, sl = p:GetMainJob(), p:GetMainJobLevel(), p:GetSubJob(), p:GetSubJobLevel();
            local need_m = sp.LevelRequired and sp.LevelRequired[mj + 1];
            local need_s = sp.LevelRequired and sp.LevelRequired[sj + 1];
            ok = (need_m ~= nil and need_m > 0 and need_m ~= 255 and need_m <= ml)
              or (need_s ~= nil and need_s > 0 and need_s ~= 255 and need_s <= sl);
        end);
    end
    use_cache[key] = ok;
    return ok;
end

local function target_name()
    local n = nil;
    pcall(function ()
        local idx = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
        local e = GetEntity(idx);
        if e and e.Name and e.Name ~= '' then n = e.Name; end
    end);
    return n;
end

-- Where the clock is now: blue window, its end, weekday, next weekday.
local function now_info()
    local t = vana();
    if t == nil then return nil; end
    local mins = t.hour * 60 + t.minute;
    local win = BLUE[3];
    if mins >= 360 and mins < 840 then win = BLUE[1]; elseif mins >= 840 and mins < 1320 then win = BLUE[2]; end
    local left = (win.to - mins) % 1440;
    return {
        t = t, win = win, win_left = left,
        day = DAYS[t.weekday + 1], next_day = DAYS[(t.weekday + 1) % 8 + 1], day_left = 1440 - mins,
    };
end
aby.now_info = now_info;

----------------------------------------------------------------------------------------------------
-- Ticks: what you've tried on this target (cleared when you change target)
----------------------------------------------------------------------------------------------------
local ticks, tick_target = {}, nil;
local function check_target(st_)
    local tn = target_name();
    if st_.aby_autoclear ~= false and tn ~= nil and tn ~= tick_target then
        if tick_target ~= nil then ticks = {}; end
        tick_target = tn;
    end
    return tn;
end

----------------------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------------------
local C = {
    gold = { 0.90, 0.78, 0.40, 1.0 }, text = { 0.92, 0.92, 0.95, 1.0 }, dim = { 0.60, 0.63, 0.74, 1.0 },
    faint = { 0.40, 0.42, 0.50, 1.0 }, green = { 0.45, 0.88, 0.45, 1.0 }, panel = { 0.07, 0.08, 0.13, 0.70 },
    red = { 1.00, 0.40, 0.38, 1.0 }, blue = { 0.38, 0.68, 1.00, 1.0 }, yellow = { 1.00, 0.84, 0.30, 1.0 },
};

local function u32c(c) return imgui.GetColorU32(c); end

-- One proc row: tick, name (green = you can use it), and dim detail on the right.
local function proc_row(id, name, usable, detail, width, compact)
    local x0, y0 = imgui.GetCursorPos();
    local done = ticks[name] == true;
    local h = compact and 18 or 20;
    if imgui.Selectable('##' .. id, false, 0, { width, h }) then ticks[name] = not done or nil; end
    local hovered = imgui.IsItemHovered();
    if hovered then imgui.SetTooltip(done and 'Click to un-tick' or 'Click to tick it off once you have tried it'); end
    -- Tick box drawn by hand so the row stays one click target.
    local sx, sy = imgui.GetCursorScreenPos();
    local wx, wy = imgui.GetWindowPos();
    local bx, by = wx + x0 + 4 - imgui.GetScrollX(), wy + y0 + 3 - imgui.GetScrollY();
    local dl = imgui.GetWindowDrawList();
    dl:AddRect({ bx, by }, { bx + 12, by + 12 }, u32c(done and C.green or C.faint), 2, 0, 1.5);
    if done then
        dl:AddLine({ bx + 2, by + 6 }, { bx + 5, by + 10 }, u32c(C.green), 2);
        dl:AddLine({ bx + 5, by + 10 }, { bx + 11, by + 2 }, u32c(C.green), 2);
    end
    imgui.SetCursorPos({ x0 + 22, y0 + 1 });
    local col = done and C.faint or (usable and C.green or C.dim);
    imgui.TextColored(col, name);
    if detail and detail ~= '' then
        local dw = imgui.CalcTextSize(detail);
        imgui.SetCursorPos({ x0 + width - dw - 6, y0 + 1 });
        imgui.TextColored(done and C.faint or C.faint, detail);
    end
    imgui.SetCursorPos({ x0, y0 + h });
end

local function ws_detail(name)
    local w = ws_info(name);
    if w == nil then return ''; end
    local sk = SKILL[w.skill] or '';
    return (w.level and w.level > 0) and string.format('%s %d', sk, w.level) or sk;
end

local function card_begin(id, w, h, title, col, right)
    imgui.PushStyleColor(ImGuiCol_ChildBg, C.panel);
    imgui.PushStyleColor(ImGuiCol_Border, { col[1], col[2], col[3], 0.45 });
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, 6);
    imgui.BeginChild(id, { w, h }, true);
    local inner = math.floor(imgui.GetContentRegionAvail());
    local x0 = imgui.GetCursorPosX();
    imgui.TextColored(col, title);
    if right then
        imgui.SameLine(x0 + inner - imgui.CalcTextSize(right));
        imgui.TextColored(C.dim, right);
    end
    local sx, sy = imgui.GetCursorScreenPos();
    imgui.GetWindowDrawList():AddLine({ sx, sy }, { sx + inner, sy }, u32c({ col[1], col[2], col[3], 0.35 }), 1);
    imgui.Dummy({ 1, 3 });
    return inner;
end
local function card_end()
    imgui.EndChild();
    imgui.PopStyleVar(1);
    imgui.PopStyleColor(2);
end

local function sorted_usable_first(list, check)
    local a, b = {}, {};
    for _, n in ipairs(list) do if check(n) then a[#a + 1] = n; else b[#b + 1] = n; end end
    for _, n in ipairs(b) do a[#a + 1] = n; end
    return a;
end

local function head_button(label, on, w)
    imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Text, on and { 1, 0.96, 0.85, 1 } or C.dim);
    -- Sized to the text (plus padding), so nothing is ever cut off.
    local text = label:gsub('##.*$', '');
    local clicked = imgui.Button(label, { imgui.CalcTextSize(text) + 22, 0 });
    imgui.PopStyleColor(2);
    return clicked;
end

-- Cut text to fit a width, ending in "...".
local function fit_text(text, width)
    text = tostring(text or '');
    if imgui.CalcTextSize(text) <= width then return text; end
    local n = #text;
    while n > 1 and imgui.CalcTextSize(text:sub(1, n) .. '...') > width do n = n - 1; end
    return text:sub(1, n) .. '...';
end

-- The Procs page. opts = { settings = omni settings table, save = function }
local open_other = {};
aby.render_procs = function (opts)
    local S = opts.settings or {};
    local info = now_info();
    local tn = check_target(S);
    local W = math.floor(imgui.GetContentRegionAvail());

    -- Info strip: four small blocks side by side, each a dim label over its value.
    imgui.PushStyleColor(ImGuiCol_ChildBg, C.panel);
    imgui.PushStyleColor(ImGuiCol_Border, { 0.90, 0.78, 0.40, 0.25 });
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, 6);
    imgui.BeginChild('##aby_clock', { W, 50 }, true, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse));
    local inner = math.floor(imgui.GetContentRegionAvail());
    local x0, y0 = imgui.GetCursorPosX(), imgui.GetCursorPosY();
    local bw = math.floor(inner / 4);
    local function block(i, label, value, vcol, note)
        local bx = x0 + (i - 1) * bw;
        imgui.SetCursorPos({ bx, y0 });
        imgui.TextColored(C.dim, label);
        if note then
            imgui.SameLine(0, 6);
            imgui.TextColored(C.faint, note);
        end
        imgui.SetCursorPos({ bx, y0 + 17 });
        imgui.TextColored(vcol, fit_text(value, bw - 10));
    end
    if info then
        block(1, "Vana'diel", string.format('%02d:%02d  %s', info.t.hour, info.t.minute, info.day), C.gold);
        block(2, 'Blue window', info.win.name, C.blue, 'next in ' .. real_in(info.win_left));
        block(3, 'Yellow day', info.day, C.yellow, info.next_day:sub(1, 3) .. ' in ' .. real_in(info.day_left));
    else
        block(1, "Vana'diel", 'clock not readable', C.red);
    end
    block(4, 'Target', tn or 'none', tn and C.text or C.faint);
    imgui.EndChild();
    imgui.PopStyleVar(1);
    imgui.PopStyleColor(2);
    imgui.Dummy({ 1, 2 });

    -- Buttons: all the same style; the two settings light up gold when on.
    if head_button((S.aby_pop and 'Close pop-out' or 'Pop out') .. '##aby_pop', S.aby_pop, 120) then
        S.aby_pop = not S.aby_pop;
        if opts.save then pcall(opts.save); end
    end
    imgui.SameLine(0, 6);
    if head_button('Clear ticks##aby_clear', false, 110) then ticks = {}; end
    imgui.SameLine(0, 6);
    if head_button('Only what I can use##aby_only', S.aby_only_usable == true, 170) then
        S.aby_only_usable = not (S.aby_only_usable == true);
        if opts.save then pcall(opts.save); end
    end
    imgui.SameLine(0, 6);
    if head_button('Clear on new target##aby_ac', S.aby_autoclear ~= false, 170) then
        S.aby_autoclear = (S.aby_autoclear == false);
        if opts.save then pcall(opts.save); end
    end
    local legend = 'Green = you can use it.  Click a row to tick it.';
    local lw = imgui.CalcTextSize(legend);
    imgui.SameLine(0, 12);
    local room = W - imgui.GetCursorPosX();
    if lw <= room then
        imgui.SameLine(W - lw);
        imgui.SetCursorPosY(imgui.GetCursorPosY() + 3);
        imgui.TextColored(C.faint, legend);
    else
        imgui.NewLine();
        imgui.TextColored(C.faint, legend);
    end
    imgui.Dummy({ 1, 2 });

    local colW = math.floor((W - 16) / 3);
    local H = 470;
    local onlyU = S.aby_only_usable == true;

    -- Red: elemental weapon skills, any time.
    local inner = card_begin('##aby_red', colW, H, 'Red  -  elemental WS', C.red, 'any time');
    local n = 0;
    for _, ws in ipairs(sorted_usable_first(RED, can_ws)) do
        if not onlyU or can_ws(ws) then n = n + 1; proc_row('ar_' .. ws, ws, can_ws(ws), ws_detail(ws), inner); end
    end
    if n == 0 then imgui.TextColored(C.faint, 'None you can use on this job.'); end
    card_end();

    imgui.SameLine(0, 8);

    -- Blue: physical weapon skills of the current damage type; the other two folded.
    local cur = info and info.win or nil;
    inner = card_begin('##aby_blue', colW, H, 'Blue  -  ' .. (cur and cur.name or 'all'), C.blue, cur and ('next in ' .. real_in(info.win_left)) or nil);
    for _, win in ipairs(BLUE) do
        local is_now = (cur == nil) or (win == cur);
        if not is_now then
            imgui.Dummy({ 1, 2 });
            local o = open_other[win.key] == true;
            if imgui.Selectable((o and 'v ' or '> ') .. win.name .. ' (later)##aby_bo_' .. win.key, false, 0, { inner, 0 }) then open_other[win.key] = not o; end
        end
        if is_now or open_other[win.key] then
            local m = 0;
            for _, ws in ipairs(sorted_usable_first(win.ws, can_ws)) do
                if not onlyU or can_ws(ws) then
                    m = m + 1;
                    if is_now then proc_row('ab_' .. ws, ws, can_ws(ws), ws_detail(ws), inner);
                    else imgui.TextColored(can_ws(ws) and C.green or C.faint, '    ' .. ws); end
                end
            end
            if m == 0 and is_now then imgui.TextColored(C.faint, 'None you can use on this job.'); end
        end
    end
    card_end();

    imgui.SameLine(0, 8);

    -- Yellow: today's spells; tomorrow folded.
    local day = info and info.day or nil;
    inner = card_begin('##aby_yellow', colW, H, 'Yellow  -  ' .. (day or 'all days'), C.yellow, info and ('next in ' .. real_in(info.day_left)) or nil);
    local days = day and { day, info.next_day } or DAYS;
    for i, d in ipairs(days) do
        local is_now = (day == nil) or (i == 1);
        if not is_now then
            imgui.Dummy({ 1, 2 });
            local o = open_other['y' .. d] == true;
            if imgui.Selectable((o and 'v ' or '> ') .. d .. ' (next)##aby_yo_' .. d, false, 0, { inner, 0 }) then open_other['y' .. d] = not o; end
        elseif day == nil then
            imgui.TextColored(C.yellow, d);
        end
        if is_now or open_other['y' .. d] then
            local m = 0;
            for _, sp in ipairs(sorted_usable_first(YELLOW[d], can_cast)) do
                if not onlyU or can_cast(sp) then
                    m = m + 1;
                    if is_now then proc_row('ay_' .. d .. sp, sp, can_cast(sp), nil, inner);
                    else imgui.TextColored(can_cast(sp) and C.green or C.faint, '    ' .. sp); end
                end
            end
            if m == 0 and is_now then imgui.TextColored(C.faint, 'None you can cast on this job.'); end
        end
    end
    imgui.Dummy({ 1, 6 });
    imgui.PushTextWrapPos(0);
    imgui.TextColored(C.faint, 'Green = learned and your main or support job can cast it. Blue Magic counts only if it is learned.');
    imgui.PopTextWrapPos();
    card_end();
end

----------------------------------------------------------------------------------------------------
-- Pop-out: a small window (like Cure Please's) with just what works right now.
----------------------------------------------------------------------------------------------------
local pop_saved = 0;
aby.render_popout = function (opts)
    local S = opts.settings or {};
    if not S.aby_pop then return; end
    local info = now_info();
    check_target(S);
    local W = 290;
    imgui.SetNextWindowPos({ S.aby_pop_x or 400, S.aby_pop_y or 200 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSizeConstraints({ W, 60 }, { W, 900 });
    imgui.PushStyleColor(ImGuiCol_WindowBg, { 0.05, 0.06, 0.11, 0.94 });
    imgui.PushStyleColor(ImGuiCol_Border, { 0.90, 0.78, 0.40, 0.55 });
    imgui.PushStyleColor(ImGuiCol_Header, { 0.90, 0.78, 0.40, 0.0 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.90, 0.78, 0.40, 0.12 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.90, 0.78, 0.40, 0.22 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 8);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8, 6 });
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_AlwaysAutoResize);
    if imgui.Begin('Procs##aby_popout', true, flags) then
        local inner = W - 16;
        -- Title line: clock and a close button.
        imgui.TextColored(C.gold, 'Procs');
        if info then
            imgui.SameLine(0, 8);
            imgui.TextColored(C.dim, string.format('%02d:%02d %s', info.t.hour, info.t.minute, info.day));
        end
        imgui.SameLine(W - 28);
        if imgui.SmallButton('x##aby_pop_x') then S.aby_pop = false; if opts.save then pcall(opts.save); end end

        local function section(title, col, right)
            imgui.Dummy({ 1, 2 });
            local x0 = imgui.GetCursorPosX();
            imgui.TextColored(col, title);
            if right then imgui.SameLine(x0 + inner - imgui.CalcTextSize(right)); imgui.TextColored(C.faint, right); end
        end
        -- Everything that procs right now; the ones you can use are green and listed first.
        local function weapon(nme) local w = ws_info(nme); return w and SKILL[w.skill] or nil; end
        local function list(prefix, names, check, detail)
            for _, nme in ipairs(sorted_usable_first(names, check)) do
                proc_row(prefix .. nme, nme, check(nme), detail and detail(nme) or nil, inner, true);
            end
        end

        section('Red', C.red, 'any time');
        list('pr_', RED, can_ws, weapon);
        if info then
            section('Blue  ' .. info.win.name, C.blue, real_in(info.win_left) .. ' left');
            list('pb_', info.win.ws, can_ws, weapon);
            section('Yellow  ' .. info.day, C.yellow, real_in(info.day_left) .. ' left');
            list('py_', YELLOW[info.day], can_cast);
        else
            imgui.TextColored(C.red, 'Clock not readable.');
        end

        local x, y = imgui.GetWindowPos();
        if type(x) == 'number' and (math.floor(x) ~= S.aby_pop_x or math.floor(y) ~= S.aby_pop_y)
            and not imgui.IsMouseDown(0) and os.clock() - pop_saved > 1 then
            S.aby_pop_x, S.aby_pop_y = math.floor(x), math.floor(y);
            pop_saved = os.clock();
            if opts.save then pcall(opts.save); end
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
    imgui.PopStyleColor(5);
end

return aby;
