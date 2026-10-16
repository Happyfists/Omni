--[[
    omni_healer_ui.lua - the Happy Healer tab, laid out like Cure Please's main window:
    buttons along the top, Character Selection (you and the monitored player), a big
    Pause / Start button, the three party boxes with everyone's HP and MP, and
    "current action". Cards are drawn by hand (rounded, with a header line) so it looks
    tidy rather than like plain Windows boxes.

    The healing itself is done by the engine in omni_sidekick.lua; this file only draws
    and sends its /hh commands.
]]

local imgui = require('imgui');
local ffi = require('ffi');

local ui = {};
ui.height = 420;

local C = {
    page     = { 0.82, 0.84, 0.88, 1.0 },   -- tab background
    card     = { 0.95, 0.96, 0.97, 1.0 },   -- card background
    edge     = { 0.64, 0.68, 0.76, 1.0 },   -- card outline
    head     = { 0.16, 0.27, 0.48, 1.0 },   -- card titles
    rule     = { 0.78, 0.81, 0.87, 1.0 },   -- line under a card title
    text     = { 0.10, 0.11, 0.14, 1.0 },
    dim      = { 0.55, 0.57, 0.62, 1.0 },
    blue     = { 0.10, 0.38, 0.80, 1.0 },
    button   = { 1.00, 1.00, 1.00, 1.0 },
    hover    = { 0.86, 0.91, 0.98, 1.0 },
    press    = { 0.74, 0.83, 0.95, 1.0 },
    track    = { 0.83, 0.85, 0.89, 1.0 },   -- empty part of a bar
    mp       = { 0.30, 0.55, 0.95, 1.0 },
    go       = { 0.24, 0.62, 0.30, 1.0 },   -- Start
    go_h     = { 0.30, 0.70, 0.36, 1.0 },
    stop     = { 0.86, 0.55, 0.16, 1.0 },   -- Pause
    stop_h   = { 0.92, 0.62, 0.22, 1.0 },
};

-- omni's Crystal look: the same page in navy and gold, square corners (ui.dark set by omni).
local LIGHT = {};
for k, v in pairs(C) do LIGHT[k] = v; end
LIGHT.popbg   = { 0.93, 0.95, 0.98, 0.94 };
LIGHT.popedge = { 0.24, 0.42, 0.75, 0.90 };
local DARK = {
    page     = { 0.045, 0.060, 0.12, 1.0 },
    card     = { 0.065, 0.085, 0.165, 1.0 },
    edge     = { 0.90, 0.77, 0.42, 0.35 },
    head     = { 0.90, 0.77, 0.42, 1.0 },
    rule     = { 0.90, 0.77, 0.42, 0.22 },
    text     = { 0.93, 0.93, 0.96, 1.0 },
    dim      = { 0.60, 0.64, 0.76, 1.0 },
    blue     = { 0.62, 0.50, 0.22, 1.0 },     -- selected things: deep gold
    button   = { 0.08, 0.10, 0.19, 1.0 },
    hover    = { 0.14, 0.16, 0.28, 1.0 },
    press    = { 0.20, 0.22, 0.36, 1.0 },
    track    = { 0.14, 0.16, 0.25, 1.0 },
    mp       = { 0.24, 0.48, 0.92, 1.0 },
    go       = { 0.22, 0.58, 0.30, 1.0 },
    go_h     = { 0.28, 0.66, 0.36, 1.0 },
    stop     = { 0.80, 0.52, 0.16, 1.0 },
    stop_h   = { 0.88, 0.60, 0.22, 1.0 },
    popbg    = { 0.045, 0.060, 0.13, 0.94 },
    popedge  = { 0.90, 0.77, 0.42, 0.60 },
};
ui.dark = false;
ui.R = 6;
local function apply_look()
    local src = ui.dark and DARK or LIGHT;
    for k, v in pairs(src) do C[k] = v; end
    ui.R = ui.dark and 0 or 6;
end

local function u32(c) return imgui.GetColorU32(c); end

local function cmd(c)
    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, c); end);
end

local function hp_colour(p)
    if p >= 75 then return { 0.22, 0.68, 0.30, 1.0 }; end
    if p >= 50 then return { 0.86, 0.74, 0.16, 1.0 }; end
    if p >= 25 then return { 0.90, 0.50, 0.12, 1.0 }; end
    return { 0.85, 0.18, 0.18, 1.0 };
end

local function party_member(i)
    local party = AshitaCore:GetMemoryManager():GetParty();
    if party:GetMemberIsActive(i) ~= 1 then return nil; end
    local name = party:GetMemberName(i);
    if name == nil or name == '' then return nil; end
    return {
        name = name,
        hpp = party:GetMemberHPPercent(i) or 0,
        mpp = party:GetMemberMPPercent(i) or 0,
        same_zone = party:GetMemberZone(i) == party:GetMemberZone(0),
        job = party:GetMemberMainJob(i) or 0,
    };
end

-- A rounded card with a title and a thin line under it. x, y are inside the root child.
local function card(dl, wx, wy, x, y, w, h, title, right_text)
    dl:AddRectFilled({ wx + x, wy + y }, { wx + x + w, wy + y + h }, u32(C.card), ui.R);
    dl:AddRect({ wx + x, wy + y }, { wx + x + w, wy + y + h }, u32(C.edge), ui.R);
    if title then
        dl:AddText({ wx + x + 10, wy + y + 6 }, u32(C.head), title);
        if right_text then
            dl:AddText({ wx + x + w - 10 - imgui.CalcTextSize(right_text), wy + y + 6 }, u32(C.dim), right_text);
        end
        dl:AddLine({ wx + x + 8, wy + y + 24 }, { wx + x + w - 8, wy + y + 24 }, u32(C.rule), 1);
    end
end

-- Select button: green "Selected" once what's in the dropdown is what's in use.
local function select_button(id, w, is_set)
    if is_set then
        imgui.PushStyleColor(ImGuiCol_Button, C.go);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, C.go_h);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, C.go_h);
        imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
    end
    local clicked = imgui.Button((is_set and 'Selected' or 'Select') .. id, { w, 0 });
    if is_set then imgui.PopStyleColor(4); end
    return clicked;
end

-- Small job picture from omni's job icon sheet (6 x 4 sprites, picture on the left half).
-- ui.icons is set by omni.lua. Returns the width used (0 when there's no picture).
local JOB_ABBR = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM',
    'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };
local function job_icon(job, x, y, size, faded)
    if ui.icons == nil or job == nil or job < 1 or job > 22 then return 0; end
    local u1 = (1.0 / 6.0) * math.fmod(job - 1.0, 6.0);
    local v1 = 0.25 * math.floor((job - 1) / 6.0);
    imgui.SetCursorPos({ x, y });
    local ok = pcall(function ()
        imgui.Image(tonumber(ffi.cast('uint32_t', ui.icons)), { size, size }, { u1, v1 }, { u1 + (1.0 / 12.0), v1 + 0.25 },
            { 1, 1, 1, faded and 0.45 or 1 }, { 1, 1, 1, 0 });
    end);
    if not ok then return 0; end
    if imgui.IsItemHovered() then imgui.SetTooltip(JOB_ABBR[job]); end
    return size + 4;
end

local function bar(dl, x1, y1, x2, h, frac, col)
    local r = h / 2;
    dl:AddRectFilled({ x1, y1 }, { x2, y1 + h }, u32(C.track), r);
    if frac > 0 then
        dl:AddRectFilled({ x1, y1 }, { x1 + math.max(h, (x2 - x1) * frac), y1 + h }, u32(col), r);
    end
end

-- ===================================================================================
-- Healing page: Cure Please's "Healing" tab. Every box here is a real Happy Healer
-- setting, saved per job like the rest.
-- ===================================================================================
local CURES   = { 'Cure', 'Cure II', 'Cure III', 'Cure IV', 'Cure V', 'Cure VI', 'Full Cure' };
local CURAGAS = { 'Curaga', 'Curaga II', 'Curaga III', 'Curaga IV', 'Curaga V' };
local TARGET_MODES = { { 'most', 'Most hurt in range' }, { 'lowest', 'Lowest HP' }, { 'name', 'Specified target' } };
local curaga_name_buf = { '' };
local buf_loaded = false;

local function key_of(name) return (name:gsub(' ', '_')); end

-- Save once a slider or box is let go of, not on every frame it moves.
local function save_when_done(sk, changed)
    if imgui.IsItemDeactivatedAfterEdit ~= nil then
        if imgui.IsItemDeactivatedAfterEdit() then sk.save(); end
    elseif changed then
        sk.save();
    end
end

-- One spell row: tick box, name, amount. Spells this job can't cast are greyed out.
local function spell_row(sk, s, spells, name, x, y, amountX, amountW, lineH)
    local base = spells[name];
    local key = key_of(name);
    if base == nil then
        imgui.SetCursorPos({ x, y + 2 });
        imgui.TextColored(C.edge, '[ ]');
        imgui.SetCursorPos({ x + 28, y + 2 });
        imgui.TextColored(C.dim, name);
        imgui.SetCursorPos({ amountX + 6, y + 2 });
        imgui.TextColored(C.dim, '-');
        return;
    end
    imgui.SetCursorPos({ x, y });
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 3, 3 });
    local on = { s['disabled_' .. key] ~= true };
    if imgui.Checkbox(name .. '##hh_use_' .. key, on) then
        s['disabled_' .. key] = not on[1];
        sk.save();
    end
    imgui.PopStyleVar(1);
    if imgui.IsItemHovered() then
        imgui.SetTooltip(on[1] and ('Untick so Happy Healer never casts ' .. name) or ('Tick so Happy Healer can cast ' .. name));
    end
    imgui.SetCursorPos({ amountX, y });
    imgui.PushItemWidth(amountW);
    local amt = { math.floor(tonumber(s['hh_amount_' .. key]) or base) };
    local changed = imgui.InputInt('##hh_amt_' .. key, amt, 0, 0);
    if changed then s['hh_amount_' .. key] = math.max(0, amt[1]); end
    save_when_done(sk, changed);
    imgui.PopItemWidth();
    if imgui.IsItemHovered() then
        imgui.SetTooltip(name .. ' is cast when someone is missing at least this much HP.');
    end
end

-- A labelled 0-100 slider for one setting.
local function threshold_slider(sk, s, id, label, keyname, fallback, x, y, w, tip)
    local v = { math.floor(tonumber(s[keyname]) or fallback) };
    imgui.SetCursorPos({ x, y });
    imgui.TextColored(C.text, label);
    local val = string.format('%d%%%%', v[1]);
    imgui.SetCursorPos({ x + w - imgui.CalcTextSize(string.format('%d%%', v[1])), y });
    imgui.TextColored(C.blue, val);
    imgui.SetCursorPos({ x, y + 22 });
    imgui.PushItemWidth(w);
    imgui.PushStyleVar(ImGuiStyleVar_GrabMinSize, 14);
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 4, 2 });
    local changed = imgui.SliderInt('##hh_sl_' .. id, v, 1, 100, '');
    imgui.PopStyleVar(2);
    if changed then s[keyname] = v[1]; end
    save_when_done(sk, changed);
    imgui.PopItemWidth();
    if tip and imgui.IsItemHovered() then imgui.SetTooltip(tip); end
end

local function render_healing(sk, dl, wx, wy, W, pad, top, lineH)
    local s = sk.settings();
    if s == nil then
        imgui.SetCursorPos({ pad + 10, top + 10 });
        imgui.TextColored(C.dim, 'Change to WHM, RDM, BRD, COR, SCH or GEO to set up healing.');
        return top + 40;
    end
    local spells = sk.heal_spells();
    if not buf_loaded then
        buf_loaded = true;
        curaga_name_buf[1] = s.hh_curaga_name or '';
    end

    local cw = W - pad * 2;
    local x0 = pad + 14;
    local amountX = x0 + 120;
    local amountW = 80;
    local rightX = pad + math.floor(cw * 0.5) + 10;
    local sliderW = cw - (rightX - pad) - 24;
    local rowH = lineH + 12;

    -- Healing Options card.
    local hy = top;
    local hh = 34 + lineH + 12 + #CURES * rowH + 8;
    card(dl, wx, wy, pad, hy, cw, hh, 'Healing Options');

    -- Column headings.
    local by = hy + 34;
    dl:AddText({ wx + x0, wy + by }, u32(C.dim), 'Spell');
    dl:AddText({ wx + amountX, wy + by }, u32(C.dim), 'Cast when HP missing');
    dl:AddLine({ wx + x0, wy + by + lineH + 4 }, { wx + amountX + amountW + 120, wy + by + lineH + 4 }, u32(C.rule), 1);
    local bh = lineH + 2;

    local ry = by + bh + 10;
    for i, n in ipairs(CURES) do
        spell_row(sk, s, spells, n, x0, ry + (i - 1) * rowH, amountX, amountW, lineH);
    end

    local heal_thr = math.floor(tonumber(s.heal_threshold) or 75);
    threshold_slider(sk, s, 'cure', 'Cure Threshold', 'heal_threshold', 75, rightX, hy + 36, sliderW,
        'Cure anyone whose HP drops below this %.');
    threshold_slider(sk, s, 'high', 'High Priority Threshold', 'focus_threshold', 85, rightX, hy + 96, sliderW,
        'Your focus target (click a name on the Main page) is cured below this %, before anyone else.');
    threshold_slider(sk, s, 'mon', 'Monitored Priority Threshold', 'hh_monitored_threshold', heal_thr, rightX, hy + 156, sliderW,
        'The monitored player is cured below this %.');

    -- Area of Effect Healing card.
    local ay = hy + hh + pad;
    local ah = 38 + math.max(#CURAGAS * rowH, 4 * 52) + 8;
    card(dl, wx, wy, pad, ay, cw, ah, 'Area of Effect Healing');
    for i, n in ipairs(CURAGAS) do
        spell_row(sk, s, spells, n, x0, ay + 36 + (i - 1) * rowH, amountX, amountW, lineH);
    end

    threshold_slider(sk, s, 'curaga', 'Curaga Threshold', 'heal_aoe_threshold', 70, rightX, ay + 36, sliderW,
        'Curaga when party members are below this %.');

    local labelW = imgui.CalcTextSize('Total members required for Curaga') + 12;
    imgui.SetCursorPos({ rightX, ay + 98 });
    imgui.TextColored(C.text, 'Total members required for Curaga');
    imgui.SetCursorPos({ rightX + labelW, ay + 94 });
    imgui.PushItemWidth(90);
    local need = { math.floor(tonumber(s.hh_curaga_min) or 2) };
    if imgui.InputInt('##hh_cmin', need, 1, 1) then
        s.hh_curaga_min = math.max(1, math.min(6, need[1]));
        sk.save();
    end
    imgui.PopItemWidth();

    local tlabelW = imgui.CalcTextSize('Specified target name') + 12;
    imgui.SetCursorPos({ rightX, ay + 134 });
    imgui.TextColored(C.text, 'Curaga Targeting type');
    imgui.SetCursorPos({ rightX + tlabelW, ay + 130 });
    imgui.PushItemWidth(sliderW - tlabelW);
    local cur = 0;
    local labels = {};
    for i, m in ipairs(TARGET_MODES) do
        labels[i] = m[2];
        if m[1] == (s.hh_curaga_target or 'most') then cur = i - 1; end
    end
    local pick = { cur };
    if imgui.Combo('##hh_ctype', pick, table.concat(labels, '\0') .. '\0') then
        s.hh_curaga_target = TARGET_MODES[pick[1] + 1][1];
        sk.save();
    end
    imgui.PopItemWidth();

    imgui.SetCursorPos({ rightX, ay + 170 });
    imgui.TextColored((s.hh_curaga_target == 'name') and C.text or C.dim, 'Specified target name');
    imgui.SetCursorPos({ rightX + tlabelW, ay + 166 });
    imgui.PushItemWidth(sliderW - tlabelW);
    if imgui.InputText('##hh_cname', curaga_name_buf, 32) then
        s.hh_curaga_name = curaga_name_buf[1];
    end
    save_when_done(sk, false);
    imgui.PopItemWidth();

    return ay + ah;
end

-- ===================================================================================
-- Debuff Removal page: Cure Please's "Debuff Removal" tab.
-- ===================================================================================
local NA_SPELLS = { 'Blindna', 'Cursna', 'Viruna', 'Paralyna', 'Stona', 'Poisona', 'Silena', 'Esuna', 'Erase' };
local WHO = { { 'pl', 'Me' }, { 'mon', 'Monitored' }, { 'party', 'Party' } };

local function small_check(id, value)
    imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 2, 1 });
    local v = { value };
    local clicked = imgui.Checkbox(id, v);
    imgui.PopStyleVar(1);
    return clicked, v[1];
end

local function render_debuffs(sk, dl, wx, wy, W, pad, top, lineH)
    local s = sk.settings();
    if s == nil then
        imgui.SetCursorPos({ pad + 10, top + 10 });
        imgui.TextColored(C.dim, 'Change to WHM, RDM, BRD, COR, SCH or GEO to set up debuff removal.');
        return top + 40;
    end
    local cw = W - pad * 2;
    local x0 = pad + 14;
    local rowH = lineH + 10;

    -- On / off, and who to clean.
    local h1 = 34 + rowH * 2 + 4;
    card(dl, wx, wy, pad, top, cw, h1, 'Debuff Removal');
    imgui.SetCursorPos({ x0, top + 32 });
    local c, v = small_check('Remove debuffs##hh_dr_on', s.debuff_removal_enabled ~= false);
    if c then s.debuff_removal_enabled = v; sk.save(); end
    imgui.SameLine(0, 40);
    c, v = small_check('Wake up anyone asleep##hh_wake_on', s.wake_enabled ~= false);
    if c then s.wake_enabled = v; sk.save(); end
    imgui.SetCursorPos({ x0, top + 32 + rowH + 1 });
    imgui.TextColored(C.dim, 'Remove from');
    for j, w in ipairs(WHO) do
        imgui.SameLine(0, j == 1 and 14 or 24);
        imgui.SetCursorPosY(top + 32 + rowH);
        local cc, vv = small_check(w[2] .. '##hh_who_' .. w[1], s['hh_rm_' .. w[1]] ~= false);
        if cc then s['hh_rm_' .. w[1]] = vv; sk.save(); end
    end

    -- Party Debuffs: which removal spells to use.
    local have = sk.debuff_spells();
    local list = {};
    for _, n in ipairs(NA_SPELLS) do list[#list + 1] = n; end
    for n in pairs(have) do
        local known = false;
        for _, m in ipairs(NA_SPELLS) do if m == n then known = true; end end
        if not known then list[#list + 1] = n; end
    end
    local cols = 5;
    local colW = math.floor((cw - 28) / cols);
    local sy = top + h1 + pad;
    local h2 = 34 + rowH + math.ceil(#list / cols) * rowH + 4;
    card(dl, wx, wy, pad, sy, cw, h2, 'Party Debuffs', 'spells to use');
    imgui.SetCursorPos({ x0, sy + 32 });
    if imgui.Button('Tick all##hh_na_all') then
        for _, n in ipairs(list) do if have[n] then s['disabled_' .. n:gsub(' ', '_')] = false; end end
        sk.save();
    end
    imgui.SameLine(0, 6);
    if imgui.Button('Untick all##hh_na_none') then
        for _, n in ipairs(list) do if have[n] then s['disabled_' .. n:gsub(' ', '_')] = true; end end
        sk.save();
    end
    imgui.SameLine(0, 14);
    imgui.TextColored(C.dim, 'Happy Healer uses the ticked spells.');
    for i, n in ipairs(list) do
        local cx = x0 + ((i - 1) % cols) * colW;
        local cy = sy + 32 + rowH + math.floor((i - 1) / cols) * rowH;
        if have[n] then
            imgui.SetCursorPos({ cx, cy });
            local key = 'disabled_' .. n:gsub(' ', '_');
            local cc, vv = small_check(n .. '##hh_na_' .. i, s[key] ~= true);
            if cc then s[key] = not vv; sk.save(); end
        else
            imgui.SetCursorPos({ cx, cy + 1 });
            imgui.TextColored(C.edge, '[ ]');
            imgui.SetCursorPos({ cx + 26, cy + 1 });
            imgui.TextColored(C.dim, n);
        end
    end

    -- Erase Debuffs: what Erase is allowed to remove.
    local names = sk.debuff_names();
    local ids = {};
    for _, id in ipairs(sk.erase_ids()) do if names[id] then ids[#ids + 1] = id; end end
    table.sort(ids, function (a, b) return names[a] < names[b]; end);
    local ecols = 4;
    local ecolW = math.floor((cw - 28) / ecols);
    local ey = sy + h2 + pad;
    local erows = math.ceil(#ids / ecols);
    local h3 = 34 + rowH + erows * rowH + 6;
    card(dl, wx, wy, pad, ey, cw, h3, 'Erase Debuffs');
    local can_erase = have['Erase'] == true;
    imgui.SetCursorPos({ x0, ey + 32 });
    if can_erase then
        if imgui.Button('Tick all##hh_er_all') then
            for _, id in ipairs(ids) do s['skip_debuff_Erase_' .. id] = nil; end
            sk.save();
        end
        imgui.SameLine(0, 6);
        if imgui.Button('Untick all##hh_er_none') then
            for _, id in ipairs(ids) do s['skip_debuff_Erase_' .. id] = true; end
            sk.save();
        end
        imgui.SameLine(0, 14);
        imgui.TextColored(C.dim, 'Erase removes the ticked ones.');
    else
        imgui.TextColored(C.dim, 'Your job can\'t cast Erase.');
    end
    for i, id in ipairs(ids) do
        local col = math.floor((i - 1) / erows);       -- fill down each column
        local row = (i - 1) % erows;
        local cx = x0 + col * ecolW;
        local cy = ey + 32 + rowH + row * rowH;
        local key = 'skip_debuff_Erase_' .. id;
        if can_erase then
            imgui.SetCursorPos({ cx, cy });
            local cc, vv = small_check(names[id] .. '##hh_er_' .. id, s[key] ~= true);
            if cc then
                if vv then s[key] = nil; else s[key] = true; end
                sk.save();
            end
        else
            imgui.SetCursorPos({ cx + 26, cy + 1 });
            imgui.TextColored(C.dim, names[id]);
        end
    end

    -- Item Debuff Removal: use items on yourself (Antidote, Echo Drops, ...).
    local items = sk.item_removals();
    local icols = 3;
    local icolW = math.floor((cw - 28) / icols);
    local iy = ey + h3 + pad;
    local irows = math.ceil(#items / icols);
    local h4 = 34 + rowH + irows * (rowH + lineH + 2) + 6;
    card(dl, wx, wy, pad, iy, cw, h4, 'Item Debuff Removal', 'on yourself');
    imgui.SetCursorPos({ x0, iy + 32 });
    local ic, iv = small_check('Use items to remove my debuffs##hh_items_on', s.item_removal_enabled == true);
    if ic then s.item_removal_enabled = iv; sk.save(); end
    local items_on = s.item_removal_enabled == true;
    for i, e in ipairs(items) do
        local col = (i - 1) % icols;
        local row = math.floor((i - 1) / icols);
        local cx = x0 + col * icolW;
        local cy = iy + 32 + rowH + row * (rowH + lineH + 2);
        local have = e.count == nil and '?' or tostring(e.count);
        if items_on then
            imgui.SetCursorPos({ cx, cy });
            local cc, vv = small_check(e.item .. '##hh_item_' .. i, s[e.key] == true);
            if cc then s[e.key] = vv; sk.save(); end
        else
            imgui.SetCursorPos({ cx + 26, cy + 1 });
            imgui.TextColored(C.dim, e.item);
        end
        -- What it removes, and how many you have (red when you have none).
        imgui.SetCursorPos({ cx + 26, cy + rowH - 4 });
        imgui.TextColored(C.dim, e.debuff);
        imgui.SameLine(0, 6);
        imgui.TextColored((e.count or 0) > 0 and C.go or { 0.80, 0.25, 0.25, 1.0 }, 'x' .. have);
    end
    return iy + h4;
end

-- ===================================================================================
-- Enhancing page: Cure Please's "Enhancing" tab. Buffs on you (PL Buffs), area buffs
-- (Group PL Buffs) and who in the party gets which buff (Cast Auto).
-- ===================================================================================
local function tier_combo(sk, row, id, w)
    if #row.names < 2 then return; end
    local items = { 'Best I can cast' };
    local cur = 0;
    local pick = sk.buff_pick(row.key);
    for i, n in ipairs(row.names) do
        items[#items + 1] = n;
        if n == pick then cur = i; end
    end
    imgui.PushItemWidth(w);
    local v = { cur };
    if imgui.Combo('##hh_tier_' .. id, v, table.concat(items, '\0') .. '\0') then
        sk.buff_pick_set(row.key, v[1] > 0 and row.names[v[1]] or nil);
    end
    imgui.PopItemWidth();
end

local function render_enhancing(sk, dl, wx, wy, W, pad, top, lineH)
    local s = sk.settings();
    if s == nil then
        imgui.SetCursorPos({ pad + 10, top + 10 });
        imgui.TextColored(C.dim, 'Change to WHM, RDM, BRD, COR, SCH or GEO to set up buffs.');
        return top + 40;
    end
    local cw = W - pad * 2;
    local x0 = pad + 14;
    local rowH = lineH + 12;
    local rows = sk.buff_rows();
    local selfs, targets = {}, {};
    for _, r in ipairs(rows) do
        if r.target then targets[#targets + 1] = r; else selfs[#selfs + 1] = r; end
    end

    -- On / off for all buffing.
    local y = top;
    local h0 = 34 + rowH;
    card(dl, wx, wy, pad, y, cw, h0, 'Enhancing');
    imgui.SetCursorPos({ x0, y + 32 });
    local c, v = small_check('Cast buffs##hh_buff_on', s.buff_enabled ~= false);
    if c then s.buff_enabled = v; sk.save(); end
    imgui.SameLine(0, 24);
    imgui.TextColored(C.dim, 'Buffs are recast when they wear off.');
    y = y + h0 + pad;

    -- Buffs on people: who gets which buff (Me and party slots 1-5).
    if #targets > 0 then
        local party = AshitaCore:GetMemoryManager():GetParty();
        local heads = { 'Me' };
        for i = 1, 5 do
            local n = nil;
            pcall(function () if party:GetMemberIsActive(i) == 1 then n = party:GetMemberName(i); end end);
            heads[#heads + 1] = (n and n ~= '') and n:sub(1, 7) or ('P' .. i);
        end
        local colW = 62;
        local tickX = pad + cw - 14 - colW * 6;
        local labelW = 120;
        local comboW = tickX - (x0 + labelW) - 14;
        local h1 = 34 + lineH + 10 + #targets * rowH + 6;
        card(dl, wx, wy, pad, y, cw, h1, 'Buffs on people', 'tick who gets each one');
        for j, hd in ipairs(heads) do
            local hx = tickX + (j - 1) * colW;
            imgui.SetCursorPos({ hx + (colW - imgui.CalcTextSize(hd)) / 2 - 6, y + 32 });
            imgui.TextColored(j == 1 and C.blue or C.head, hd);
        end
        dl:AddLine({ wx + x0, wy + y + 32 + lineH + 4 }, { wx + pad + cw - 14, wy + y + 32 + lineH + 4 }, u32(C.rule), 1);
        for i, r in ipairs(targets) do
            local ry = y + 34 + lineH + 10 + (i - 1) * rowH;
            if i % 2 == 0 then
                dl:AddRectFilled({ wx + x0 - 6, wy + ry - 3 }, { wx + pad + cw - 8, wy + ry + rowH - 3 }, u32(C.page), ui.R / 2);
            end
            imgui.SetCursorPos({ x0, ry + 2 });
            imgui.TextColored(C.text, r.label);
            imgui.SetCursorPos({ x0 + labelW, ry - 1 });
            if #r.names > 1 then tier_combo(sk, r, 't' .. i, comboW); end
            for j = 0, 5 do
                imgui.SetCursorPos({ tickX + j * colW + colW / 2 - 16, ry - 1 });
                local cc, vv = small_check('##hh_bt_' .. i .. '_' .. j, sk.buff_on(r.key, j));
                if cc then sk.buff_set(r.key, r.group, j, vv); end
            end
        end
        y = y + h1 + pad;
    end

    -- Buffs on you, and area buffs: two columns of tick + tier/element.
    if #selfs > 0 then
        local half = math.ceil(#selfs / 2);
        local h2 = 34 + half * rowH + 6;
        card(dl, wx, wy, pad, y, cw, h2, 'Buffs on me and area buffs');
        local colW = math.floor((cw - 28) / 2);
        for i, r in ipairs(selfs) do
            local col = (i <= half) and 0 or 1;
            local row = (i <= half) and (i - 1) or (i - 1 - half);
            local cx = x0 + col * (colW + 6);
            local cy = y + 32 + row * rowH;
            imgui.SetCursorPos({ cx, cy });
            local cc, vv = small_check(r.label .. '##hh_bs_' .. i, sk.self_on(r.key, r.group));
            if cc then sk.self_set(r.key, r.group, vv); end
            if #r.names > 1 then
                imgui.SetCursorPos({ cx + 130, cy - 1 });
                tier_combo(sk, r, 's' .. i, colW - 140);
            end
        end
        y = y + h2;
    end
    return y;
end

-- ===================================================================================
-- Shared bits for the last Cure Please pages.
-- ===================================================================================
local function no_job(pad, top, what)
    imgui.SetCursorPos({ pad + 10, top + 10 });
    imgui.TextColored(C.dim, 'Change to WHM, RDM, BRD, COR, SCH or GEO to set up ' .. what .. '.');
    return top + 40;
end

-- A dropdown of names; first item is `none_label` (nil). Returns the new pick or false.
local function name_combo(id, names, current, none_label, w)
    local items = { none_label };
    local cur = 0;
    for i, n in ipairs(names) do
        items[#items + 1] = n;
        if n == current then cur = i; end
    end
    imgui.PushItemWidth(w);
    local v = { cur };
    local changed = imgui.Combo(id, v, table.concat(items, '\0') .. '\0');
    imgui.PopItemWidth();
    if changed then return v[1] > 0 and names[v[1]] or nil; end
    return false;
end

-- A tick box bound to one setting. `default_on` = what an unset setting means.
local function setting_check(sk, s, label, key, default_on, tip)
    local on;
    if default_on then on = s[key] ~= false; else on = s[key] == true; end
    local c, v = small_check(label, on);
    if c then s[key] = v; sk.save(); end
    if tip and imgui.IsItemHovered() then imgui.SetTooltip(tip); end
end

-- ===================================================================================
-- Geomancy page: Cure Please's "Geomancy" tab.
-- ===================================================================================
local function render_geomancy(sk, dl, wx, wy, W, pad, top, lineH)
    local s = sk.settings();
    if s == nil then return no_job(pad, top, 'Geomancy'); end
    local cw = W - pad * 2;
    local x0 = pad + 14;
    local rowH = lineH + 14;
    local colW = math.floor((cw - 28) / 3);
    local indi = sk.group_names('buff', 'Indi');
    local geo = sk.group_names('buff', 'Geo');
    local geobt = sk.group_names('geo', 'Geo-bt');
    if #indi == 0 and #geo == 0 then
        local h = 34 + rowH;
        card(dl, wx, wy, pad, top, cw, h, 'Geomancy');
        imgui.SetCursorPos({ x0, top + 34 });
        imgui.TextColored(C.dim, 'Your job can\'t cast Geomancy spells.');
        return top + h;
    end

    local h = 34 + rowH * 5 + 8;
    card(dl, wx, wy, pad, top, cw, h, 'Geomancy');
    local y = top + 32;

    -- Column 1: Indi (on you).
    imgui.SetCursorPos({ x0, y });
    local c, v = small_check('Indi spells##hh_indi_on', sk.self_on('Indi', true));
    if c then sk.self_set('Indi', true, v); end
    imgui.SetCursorPos({ x0, y + rowH });
    local p = name_combo('##hh_indi', indi, sk.buff_pick('Indi'), 'Best I can cast', colW - 16);
    if p ~= false then sk.buff_pick_set('Indi', p); end

    -- Column 2: Geo (on a party member, or you).
    local gx = x0 + colW;
    local geo_target = nil;
    for i = 0, 5 do if sk.buff_on('Geo', i) then geo_target = i; break; end end
    imgui.SetCursorPos({ gx, y });
    c, v = small_check('Geo spells##hh_geo_on', geo_target ~= nil);
    if c then
        for i = 0, 5 do sk.buff_set('Geo', true, i, v and i == 0); end
        geo_target = v and 0 or nil;
    end
    imgui.SetCursorPos({ gx, y + rowH });
    p = name_combo('##hh_geo', geo, sk.buff_pick('Geo'), 'Best I can cast', colW - 16);
    if p ~= false then sk.buff_pick_set('Geo', p); end
    imgui.SetCursorPos({ gx, y + rowH * 2 + 3 });
    imgui.TextColored(C.dim, 'Bubble on');
    imgui.SetCursorPos({ gx + 80, y + rowH * 2 });
    local party = sk.party_names();
    local targets = { 'Me' };
    for _, n in ipairs(party) do targets[#targets + 1] = n; end
    local cur = geo_target and targets[geo_target + 1] or nil;
    p = name_combo('##hh_geo_tgt', targets, cur, 'Nobody', colW - 96);
    if p ~= false then
        local pick = nil;
        for i, n in ipairs(targets) do if n == p then pick = i - 1; end end
        for i = 0, 5 do sk.buff_set('Geo', true, i, pick ~= nil and i == pick); end
    end

    -- Column 3: Entrust (an Indi spell on someone else).
    local ex = x0 + colW * 2;
    imgui.SetCursorPos({ ex, y });
    c, v = small_check('Entrust##hh_entrust_on', s.disabled_Entrust ~= true);
    if c then s.disabled_Entrust = not v; sk.save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Use Entrust to put an Indi spell on a party member.'); end
    imgui.SetCursorPos({ ex, y + rowH });
    p = name_combo('##hh_entrust_spell', indi, s.entrust_spell, 'No spell', colW - 16);
    if p ~= false then s.entrust_spell = p; sk.save(); end
    imgui.SetCursorPos({ ex, y + rowH * 2 + 3 });
    imgui.TextColored(C.dim, 'On');
    imgui.SetCursorPos({ ex + 30, y + rowH * 2 });
    p = name_combo('##hh_entrust_tgt', party, s.entrust_target, 'Nobody', colW - 46);
    if p ~= false then s.entrust_target = p; sk.save(); end

    -- Bottom row: the enemy debuff bubble and luopan handling.
    local by = y + rowH * 3 + 6;
    dl:AddLine({ wx + x0, wy + by - 6 }, { wx + pad + cw - 14, wy + by - 6 }, u32(C.rule), 1);
    imgui.SetCursorPos({ x0, by });
    setting_check(sk, s, 'Luopan care (Full Circle, Radial Arcana)##hh_geo_en', 'geo_enabled', false,
        'Let Happy Healer look after your luopan: Full Circle when it\'s far away, Radial Arcana for MP.');
    if #geobt > 0 then
        imgui.SetCursorPos({ x0, by + rowH });
        c, v = small_check('Enemy debuff bubble in battle##hh_geobt_on', sk.self_on('Geo-bt', true));
        if c then sk.self_set('Geo-bt', true, v); end
        imgui.SameLine(0, 12);
        imgui.SetCursorPosY(by + rowH - 1);
        p = name_combo('##hh_geobt', geobt, sk.buff_pick('Geo-bt'), 'Best I can cast', colW);
        if p ~= false then sk.buff_pick_set('Geo-bt', p); end
    end
    return top + h;
end

-- ===================================================================================
-- Singing page: Cure Please's "Singing" tab.
-- ===================================================================================
local function render_singing(sk, dl, wx, wy, W, pad, top, lineH)
    local s = sk.settings();
    if s == nil then return no_job(pad, top, 'songs'); end
    local cw = W - pad * 2;
    local x0 = pad + 14;
    local rowH = lineH + 16;
    local songs = sk.song_names();
    if #songs == 0 then
        local h = 34 + rowH;
        card(dl, wx, wy, pad, top, cw, h, 'Bard Songs');
        imgui.SetCursorPos({ x0, top + 34 });
        imgui.TextColored(C.dim, 'Your job can\'t sing. Change to Bard.');
        return top + h;
    end
    local plan = sk.songs_plan();
    local function pick(id, current, w)
        local p = name_combo(id, songs, current, 'No song', w);
        if p ~= false then return true, p; end
        return false, nil;
    end

    -- Party songs: sung to everyone.
    local h0 = 34 + rowH * 2 + 4;
    card(dl, wx, wy, pad, top, cw, h0, 'Party songs', 'sung to everyone');
    local half = math.floor((cw - 28) / 2);
    local lab = imgui.CalcTextSize('Song 2') + 12;
    for k = 1, 2 do
        local cx = x0 + (k - 1) * (half + 8);
        imgui.SetCursorPos({ cx, top + 35 });
        imgui.TextColored(C.text, 'Song ' .. k);
        imgui.SetCursorPos({ cx + lab, top + 32 });
        local ch, v = pick('##hh_ps' .. k, plan.party['s' .. k], half - lab - 8);
        if ch then plan.party['s' .. k] = v; sk.songs_apply(); end
    end
    imgui.SetCursorPos({ x0, top + 32 + rowH });
    setting_check(sk, s, 'Wait until the party is in range before singing##hh_holdaoe', 'hold_aoe_for_group', false);

    -- Each member: Pianissimo gives them their own two songs.
    local y = top + h0 + pad;
    local party = AshitaCore:GetMemoryManager():GetParty();
    local h1 = 34 + lineH + 10 + 6 * rowH + lineH * 2 + 14;
    card(dl, wx, wy, pad, y, cw, h1, 'Party members', 'tick Pianissimo to single them out');
    local nameW = 150;
    local pianX = x0 + nameW;
    local pianW = imgui.CalcTextSize('Pianissimo') + 34;
    local s1X = pianX + pianW;
    local songW = math.floor((pad + cw - 14 - s1X - 8) / 2);
    local s2X = s1X + songW + 8;
    imgui.SetCursorPos({ x0, y + 32 }); imgui.TextColored(C.dim, 'Member');
    imgui.SetCursorPos({ pianX, y + 32 }); imgui.TextColored(C.dim, 'Pianissimo');
    imgui.SetCursorPos({ s1X, y + 32 }); imgui.TextColored(C.dim, 'Song 1');
    imgui.SetCursorPos({ s2X, y + 32 }); imgui.TextColored(C.dim, 'Song 2');
    dl:AddLine({ wx + x0, wy + y + 32 + lineH + 4 }, { wx + pad + cw - 14, wy + y + 32 + lineH + 4 }, u32(C.rule), 1);
    for i = 0, 5 do
        local ry = y + 34 + lineH + 10 + i * rowH;
        if i % 2 == 1 then
            dl:AddRectFilled({ wx + x0 - 6, wy + ry - 4 }, { wx + pad + cw - 8, wy + ry + rowH - 4 }, u32(C.page), ui.R / 2);
        end
        local name, job = nil, 0;
        pcall(function ()
            if party:GetMemberIsActive(i) == 1 then name = party:GetMemberName(i); job = party:GetMemberMainJob(i) or 0; end
        end);
        local m = plan['m' .. i];
        if name == nil or name == '' then
            imgui.SetCursorPos({ x0, ry + 2 });
            imgui.TextColored(C.dim, 'Empty');
        else
            local iw = job_icon(job, x0, ry, lineH, false);
            imgui.SetCursorPos({ x0 + iw, ry + 2 });
            imgui.TextColored(i == 0 and C.blue or C.text, name);
            imgui.SetCursorPos({ pianX + 10, ry });
            local c, v = small_check('##hh_pian' .. i, m.pian == true);
            if c then m.pian = v; sk.songs_apply(); end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(i == 0 and 'Give yourself your own two songs.' or ('Use Pianissimo to give ' .. name .. ' their own two songs.'));
            end
            if m.pian then
                imgui.SetCursorPos({ s1X, ry - 1 });
                local ch, sv = pick('##hh_m' .. i .. 's1', m.s1, songW);
                if ch then m.s1 = sv; sk.songs_apply(); end
                imgui.SetCursorPos({ s2X, ry - 1 });
                ch, sv = pick('##hh_m' .. i .. 's2', m.s2, songW);
                if ch then m.s2 = sv; sk.songs_apply(); end
            else
                imgui.SetCursorPos({ s1X, ry + 2 });
                imgui.TextColored(C.dim, 'Gets the party songs');
            end
        end
    end
    imgui.SetCursorPos({ x0, y + h1 - lineH * 2 - 12 });
    imgui.PushTextWrapPos(pad + cw - 14);
    imgui.TextColored(C.dim, 'Party songs reach everyone in range, Pianissimo members too. A Bard holds 2 songs on each person (more with an extra-song instrument).');
    imgui.PopTextWrapPos();
    return y + h1;
end

-- ===================================================================================
-- Job Abilities page: Cure Please's "Job Abilities" tab.
-- ===================================================================================
local function render_abilities(sk, dl, wx, wy, W, pad, top, lineH)
    local s = sk.settings();
    if s == nil then return no_job(pad, top, 'job abilities'); end
    local cw = W - pad * 2;
    local x0 = pad + 14;
    local rowH = lineH + 12;
    local rows = sk.ja_rows();
    local mainj, subj = sk.main_sub();
    local main, sub = {}, {};
    for _, r in ipairs(rows) do if r.main then main[#main + 1] = r; else sub[#sub + 1] = r; end end
    local y = top;
    for _, part in ipairs({ { mainj, main, 'm' }, { subj, sub, 's' } }) do
        if #part[2] > 0 then
            local cols = 3;
            local colW = math.floor((cw - 28) / cols);
            local nrows = math.ceil(#part[2] / cols);
            local h = 34 + nrows * rowH + 4;
            card(dl, wx, wy, pad, y, cw, h, part[1] .. ' abilities', 'tick to let Happy Healer use them');
            for i, r in ipairs(part[2]) do
                local cx = x0 + ((i - 1) % cols) * colW;
                local cy = y + 32 + math.floor((i - 1) / cols) * rowH;
                imgui.SetCursorPos({ cx, cy });
                local cc, vv = small_check(r.label .. '##hh_ja_' .. part[3] .. i, sk.self_on(r.key, r.group));
                if cc then sk.self_set(r.key, r.group, vv); end
            end
            y = y + h + pad;
        end
    end
    if y == top then
        local h = 34 + rowH;
        card(dl, wx, wy, pad, top, cw, h, 'Job Abilities');
        imgui.SetCursorPos({ x0, top + 34 });
        imgui.TextColored(C.dim, 'No job abilities for this job.');
        return top + h;
    end
    return y - pad;
end

-- ===================================================================================
-- Other Options page: Cure Please's "Other Options" tab.
-- ===================================================================================
local function render_options(sk, dl, wx, wy, W, pad, top, lineH)
    local s = sk.settings();
    if s == nil then return no_job(pad, top, 'options'); end
    local cw = W - pad * 2;
    local x0 = pad + 14;
    local rowH = lineH + 12;

    local h1 = 34 + rowH * 4 + 4;
    card(dl, wx, wy, pad, top, cw, h1, 'Cure Settings');
    imgui.SetCursorPos({ x0, top + 32 });
    setting_check(sk, s, 'Enable OVERCURE##hh_over', 'hh_overcure', true,
        'Allow a cure that heals more than the HP missing.');
    imgui.SetCursorPos({ x0, top + 32 + rowH });
    setting_check(sk, s, 'Enable UNDERCURE##hh_under', 'hh_undercure', true,
        'Allow a cure that heals less than the HP missing.');
    imgui.SetCursorPos({ x0, top + 32 + rowH * 2 });
    setting_check(sk, s, 'Enable Monitored Priority##hh_monpri', 'hh_monitored_priority', true,
        'Use the Monitored Priority Threshold (Healing page) for the monitored player.');
    imgui.SetCursorPos({ x0, top + 32 + rowH * 3 });
    setting_check(sk, s, 'Enable Out Of Party curing##hh_oop', 'hh_out_of_party', true,
        'Heal the monitored player\'s party even when you\'re not in it.');

    local y = top + h1 + pad;
    local h2 = 34 + rowH * 3 + 4;
    card(dl, wx, wy, pad, y, cw, h2, 'Raise, Rest and MP');
    imgui.SetCursorPos({ x0, y + 32 });
    setting_check(sk, s, 'Raise KO\'d party members##hh_raise', 'revive_enabled', true);
    imgui.SetCursorPos({ x0, y + 32 + rowH });
    setting_check(sk, s, 'Rest (/heal) when MP is low and nothing needs doing##hh_rest', 'rest_enabled', false);
    imgui.SetCursorPos({ x0, y + 32 + rowH * 2 });
    setting_check(sk, s, 'Use MP recovery (Convert, Sublimation, Radial Arcana...)##hh_recover', 'recover_enabled', true);
    return y + h2;
end

-- ===================================================================================
-- Program Options page: Cure Please's "Program Options" tab.
-- ===================================================================================
local follow_buf = { '' };
local follow_loaded = false;

local function render_program(sk, dl, wx, wy, W, pad, top, lineH)
    local s = sk.settings();
    if s == nil then return no_job(pad, top, 'program options'); end
    local cw = W - pad * 2;
    local x0 = pad + 14;
    local rowH = lineH + 12;
    local half = math.floor((cw - 8) / 2);

    local h = 34 + rowH * 5 + 4;
    card(dl, wx, wy, pad, top, half, h, 'Program Options');
    imgui.SetCursorPos({ x0, top + 32 });
    setting_check(sk, s, 'Pause when character zones##hh_pzone', 'stop_after_zone', false);
    imgui.SetCursorPos({ x0, top + 32 + rowH });
    setting_check(sk, s, 'Pause on startup##hh_pstart', 'load_stopped', false,
        'Always load paused, whatever it was doing last time.');
    imgui.SetCursorPos({ x0, top + 32 + rowH * 2 });
    setting_check(sk, s, 'Pause on KO##hh_pko', 'hh_pause_on_ko', false);

    local fx = pad + half + 8;
    local fx0 = fx + 14;
    card(dl, wx, wy, fx, top, cw - half - 8, h, 'PL Follow Options');
    if not follow_loaded then follow_loaded = true; follow_buf[1] = s.follow_target or ''; end
    imgui.SetCursorPos({ fx0, top + 32 });
    setting_check(sk, s, 'Auto Follow##hh_follow', 'follow_enabled', false);
    -- Labels in one column, boxes lined up after the longest one.
    local fw = cw - half - 8;
    local labW = math.max(imgui.CalcTextSize('Follow'), imgui.CalcTextSize('Keep distance')) + 14;
    local inX = fx0 + labW;
    imgui.SetCursorPos({ fx0, top + 32 + rowH + 3 });
    imgui.TextColored(C.text, 'Follow');
    imgui.SetCursorPos({ inX, top + 32 + rowH });
    imgui.PushItemWidth(fx + fw - 14 - inX);
    if imgui.InputText('##hh_follow_name', follow_buf, 32) then
        local n = tostring(follow_buf[1] or ''):gsub('^%s+', ''):gsub('%s+$', '');
        s.follow_target = (n ~= '') and n or nil;
        sk.save();
    end
    imgui.PopItemWidth();
    if imgui.IsItemHovered() then imgui.SetTooltip('Who to follow (leave empty for the party leader).'); end
    imgui.SetCursorPos({ fx0, top + 32 + rowH * 2 + 3 });
    imgui.TextColored(C.text, 'Keep distance');
    imgui.SetCursorPos({ inX, top + 32 + rowH * 2 });
    imgui.PushItemWidth(60);
    local d = { math.floor(tonumber(s.follow_distance) or 5) };
    if imgui.InputInt('##hh_follow_dist', d, 0, 0) then
        s.follow_distance = math.max(1, math.min(20, d[1]));
        sk.save();
    end
    imgui.PopItemWidth();
    imgui.SameLine(0, 8);
    imgui.TextColored(C.dim, 'yalms');
    imgui.SetCursorPos({ fx0, top + 32 + rowH * 3 });
    local c, v = small_check('Use FFXI default auto follow##hh_native', s.multisend_follow ~= true);
    if c then s.multisend_follow = not v; sk.save(); end
    return top + h;
end

-- ===================================================================================
-- Save page: name and keep your settings (like Cure Please's saved setups).
-- ===================================================================================
local save_name = { '' };
local save_pick = nil;
local delete_armed_at = 0;
local save_msg, save_msg_col = nil, nil;

local function render_save(sk, dl, wx, wy, W, pad, top, lineH)
    local s = sk.settings();
    if s == nil then
        imgui.SetCursorPos({ pad + 10, top + 10 });
        imgui.TextColored(C.dim, 'Change to WHM, RDM, BRD, COR, SCH or GEO to save settings.');
        return top + 40;
    end
    local cw = W - pad * 2;
    local x0 = pad + 14;
    local combo = sk.combo();
    local names = sk.profile('names') or {};
    local active = sk.profile('active');
    local rowH = lineH + 8;
    local listH = math.max(5, #names + 1) * rowH;
    local h = 34 + lineH * 2 + 14 + listH + 16 + (lineH + 14) + 30;
    card(dl, wx, wy, pad, top, cw, h, 'Saved settings', combo);

    imgui.SetCursorPos({ x0, top + 32 });
    imgui.PushTextWrapPos(pad + cw - 14);
    imgui.TextColored(C.dim, 'Saves all your Happy Healer settings under a name. Each job pair (like WHM/SCH) has its own list.');
    imgui.PopTextWrapPos();

    -- The list.
    local lx, ly, lw = x0, top + 32 + lineH * 2 + 14, math.floor(cw * 0.55);
    dl:AddRectFilled({ wx + lx, wy + ly }, { wx + lx + lw, wy + ly + listH + 8 }, u32(C.button), ui.R * 0.66);
    dl:AddRect({ wx + lx, wy + ly }, { wx + lx + lw, wy + ly + listH + 8 }, u32(C.edge), ui.R * 0.66);
    local rows = { { nil, 'Default (always saved as you go)' } };
    for _, n in ipairs(names) do rows[#rows + 1] = { n, n }; end
    for i, r in ipairs(rows) do
        local ry = ly + 4 + (i - 1) * rowH;
        local is_active = (r[1] == active);
        local is_pick = (r[1] == save_pick);
        if is_pick then
            dl:AddRectFilled({ wx + lx + 3, wy + ry }, { wx + lx + lw - 3, wy + ry + rowH }, u32(C.hover), ui.R / 2);
        end
        imgui.SetCursorPos({ lx + 3, ry });
        if imgui.InvisibleButton('##hh_prof_' .. i, { lw - 6, rowH }) then
            save_pick = r[1];
            if r[1] then save_name[1] = r[1]; end
        end
        dl:AddText({ wx + lx + 10, wy + ry + 4 }, u32(is_active and C.blue or (r[1] and C.text or C.dim)), r[2]);
        if is_active then
            local tag = 'in use';
            dl:AddText({ wx + lx + lw - 12 - imgui.CalcTextSize(tag), wy + ry + 4 }, u32(C.go), tag);
        end
    end

    -- Buttons beside the list.
    local bx = lx + lw + 14;
    local bw = cw - (bx - pad) - 14;
    imgui.SetCursorPos({ bx, ly });
    if imgui.Button('Load##hh_prof_load', { bw, 0 }) then
        if save_pick then
            sk.profile('load', save_pick);
            save_msg, save_msg_col = 'Loaded ' .. save_pick .. '.', C.go;
        else
            sk.profile('default');
            save_msg, save_msg_col = 'Back to Default.', C.go;
        end
    end
    if imgui.IsItemHovered() then imgui.SetTooltip('Use the save picked in the list.'); end
    imgui.SetCursorPos({ bx, ly + 34 });
    local armed = os.clock() - delete_armed_at < 3;
    if save_pick == nil then
        imgui.TextColored(C.dim, 'Pick a save to delete it.');
    elseif imgui.Button((armed and 'Click again to delete' or 'Delete') .. '##hh_prof_del', { bw, 0 }) then
        if armed then
            sk.profile('delete', save_pick);
            save_msg, save_msg_col = 'Deleted ' .. save_pick .. '.', C.stop;
            save_pick = nil;
            delete_armed_at = 0;
        else
            delete_armed_at = os.clock();
        end
    end
    imgui.SetCursorPos({ bx, ly + 68 });
    if imgui.Button('Reset to job defaults##hh_prof_new', { bw, 0 }) then
        sk.profile('new');
        save_msg, save_msg_col = 'Settings reset to the job defaults. Your saves are untouched.', C.go;
    end

    -- Save under a name.
    local ny = ly + listH + 20;
    imgui.SetCursorPos({ x0, ny + 3 });
    imgui.TextColored(C.text, 'Name');
    imgui.SetCursorPos({ x0 + 50, ny });
    imgui.PushItemWidth(lw - 50);
    imgui.InputText('##hh_prof_name', save_name, 40);
    imgui.PopItemWidth();
    imgui.SetCursorPos({ bx, ny });
    imgui.PushStyleColor(ImGuiCol_Button, C.go);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, C.go_h);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, C.go_h);
    imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
    local clicked = imgui.Button('Save##hh_prof_save', { bw, 0 });
    imgui.PopStyleColor(4);
    if clicked then
        local n = tostring(save_name[1] or ''):gsub('^%s+', ''):gsub('%s+$', '');
        if n == '' or n:lower() == 'default' then
            save_msg, save_msg_col = 'Type a name first (not "Default").', C.stop;
        else
            sk.profile('save', n);
            save_pick = n;
            save_msg, save_msg_col = 'Saved as ' .. n .. '.', C.go;
        end
    end
    if imgui.IsItemHovered() then imgui.SetTooltip('Save your current settings under this name (replaces a save with the same name).'); end

    imgui.SetCursorPos({ x0, ny + lineH + 16 });
    if save_msg then
        imgui.TextColored(save_msg_col, save_msg);
    elseif active then
        imgui.TextColored(C.dim, 'Changed something? Press Save with the name ' .. active .. ' to keep it in that save.');
    end
    return top + h;
end

local mon_pick, pl_pick, last_mon = { 0 }, { 0 }, nil;
local page = 'main';

ui.render = function (sk)
    apply_look();
    ui.used = true;   -- the pop-out button shows once Happy Healer has been opened
    local W = imgui.GetContentRegionAvail();
    local job = sk.job_name();
    local running = sk.is_running();
    local focus = sk.focus_target();

    imgui.PushStyleColor(ImGuiCol_ChildBg, C.page);
    imgui.PushStyleColor(ImGuiCol_Text, C.text);
    imgui.PushStyleColor(ImGuiCol_Button, C.button);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, C.hover);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, C.press);
    imgui.PushStyleColor(ImGuiCol_FrameBg, C.button);
    imgui.PushStyleColor(ImGuiCol_FrameBgHovered, C.hover);
    imgui.PushStyleColor(ImGuiCol_FrameBgActive, C.hover);
    imgui.PushStyleColor(ImGuiCol_PopupBg, C.button);
    imgui.PushStyleColor(ImGuiCol_Header, C.press);
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, C.hover);
    imgui.PushStyleColor(ImGuiCol_Border, C.edge);
    imgui.PushStyleColor(ImGuiCol_CheckMark, C.blue);
    imgui.PushStyleColor(ImGuiCol_SliderGrab, C.blue);
    imgui.PushStyleColor(ImGuiCol_SliderGrabActive, C.blue);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 4);
    imgui.PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1);

    imgui.BeginChild('##hh_root', { W, 0 }, false, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse));
    local dl = imgui.GetWindowDrawList();
    local wx, wy = imgui.GetWindowPos();
    local pad = 8;

    -- Title on the left, buttons on the right.
    imgui.SetCursorPos({ pad + 2, 8 });
    imgui.SetWindowFontScale(1.25);
    imgui.TextColored(C.head, 'Happy Healer');
    imgui.SetWindowFontScale(1.0);
    imgui.SameLine(0, 14);
    if sk.sharing() then
        imgui.TextColored(C.go, 'Sharing party');
        if imgui.IsItemHovered() then imgui.SetTooltip('Your other characters on this PC can pick you as their Monitored Player.'); end
    else
        imgui.TextColored(C.dim, 'Not sharing yet');
    end
    local buttons = {
        { 'Party Info', '/hh panel' },
        { 'Widget', '/hh widget' },
    };
    local bx = W - pad;
    for i = #buttons, 1, -1 do bx = bx - (imgui.CalcTextSize(buttons[i][1]) + 18) - ((i < #buttons) and 6 or 0); end
    imgui.SetCursorPos({ bx, 8 });
    for i, b in ipairs(buttons) do
        if i > 1 then imgui.SameLine(0, 6); end
        if imgui.Button(b[1] .. '##hh_top' .. i) then cmd(b[2]); end
    end

    -- Page tabs along the top, like Cure Please's.
    local mj, sj = sk.main_sub();
    local tabs = { { 'main', 'Main' }, { 'healing', 'Healing' }, { 'debuff', 'Debuff Removal' }, { 'enhancing', 'Enhancing' } };
    -- Job pages only show when your main or sub job can use them.
    if mj == 'GEO' or sj == 'GEO' then tabs[#tabs + 1] = { 'geomancy', 'Geomancy' }; end
    if mj == 'BRD' or sj == 'BRD' then tabs[#tabs + 1] = { 'singing', 'Bard Songs' }; end
    tabs[#tabs + 1] = { 'abilities', 'Job Abilities' };
    tabs[#tabs + 1] = { 'options', 'Other Options' };
    tabs[#tabs + 1] = { 'program', 'Program Options' };
    tabs[#tabs + 1] = { 'save', 'Save' };
    local valid = false;
    for _, pg in ipairs(tabs) do if pg[1] == page then valid = true; end end
    if not valid then page = 'main'; end
    local tx, ty = pad, 38;
    local tabH = (select(2, imgui.CalcTextSize('Ag')) or 14) + 8;
    for i, pg in ipairs(tabs) do
        local tw = imgui.CalcTextSize(pg[2]) + 18;
        if tx + tw > W - pad then tx = pad; ty = ty + tabH + 4; end   -- wrap to a second row
        imgui.SetCursorPos({ tx, ty });
        tx = tx + tw + 4;
        local sel = (page == pg[1]);
        if sel then
            imgui.PushStyleColor(ImGuiCol_Button, C.blue);
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, C.blue);
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
        end
        if imgui.Button(pg[2] .. '##hh_page_' .. pg[1], { tw, 0 }) then page = pg[1]; end
        if sel then imgui.PopStyleColor(3); end
    end
    local lineH = select(2, imgui.CalcTextSize('Ag')) or 14;
    local top0 = ty + lineH + 14;
    dl:AddLine({ wx + pad, wy + top0 - 5 }, { wx + W - pad, wy + top0 - 5 }, u32(C.blue), 2);

    if page == 'healing' then
        ui.height = render_healing(sk, dl, wx, wy, W, pad, top0, lineH) + pad;
    elseif page == 'debuff' then
        ui.height = render_debuffs(sk, dl, wx, wy, W, pad, top0, lineH) + pad;
    elseif page == 'enhancing' then
        ui.height = render_enhancing(sk, dl, wx, wy, W, pad, top0, lineH) + pad;
    elseif page == 'geomancy' then
        ui.height = render_geomancy(sk, dl, wx, wy, W, pad, top0, lineH) + pad;
    elseif page == 'singing' then
        ui.height = render_singing(sk, dl, wx, wy, W, pad, top0, lineH) + pad;
    elseif page == 'abilities' then
        ui.height = render_abilities(sk, dl, wx, wy, W, pad, top0, lineH) + pad;
    elseif page == 'options' then
        ui.height = render_options(sk, dl, wx, wy, W, pad, top0, lineH) + pad;
    elseif page == 'program' then
        ui.height = render_program(sk, dl, wx, wy, W, pad, top0, lineH) + pad;
    elseif page == 'save' then
        ui.height = render_save(sk, dl, wx, wy, W, pad, top0, lineH) + pad;
    else
    -- Character Selection card.
    local top = top0;
    local leftW = math.floor((W - pad * 3) * 0.62);
    local comboH = lineH + 8;
    local cardH = 32 + comboH * 2 + 10 + 12;
    card(dl, wx, wy, pad, top, leftW, cardH, 'Character Selection');
    local me = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or '?';

    -- Like Cure Please: Selected PL is the character doing the healing (always the
    -- game this tab is open in), and Monitored Player is whose party it looks after.
    -- Both lists hold every character running omni on this PC, you first.
    local others = sk.others();
    local everyone = { me };
    for _, n in ipairs(others) do everyone[#everyone + 1] = n; end
    local mon = sk.monitored() or me;

    -- Keep the Monitored dropdown showing the real choice until you pick another.
    if mon ~= last_mon then
        last_mon = mon;
        mon_pick[1] = 0;
        for i, n in ipairs(everyone) do if n == mon then mon_pick[1] = i - 1; end end
    end
    mon_pick[1] = math.min(mon_pick[1], #everyone - 1);

    local labelW = imgui.CalcTextSize('Monitored Player') + 16;
    local selW = imgui.CalcTextSize('Selected') + 20;
    local comboW = leftW - 20 - labelW - selW - 6;
    local row1 = top + 32;
    local row2 = row1 + comboH + 6;
    local tx = (comboH - lineH) / 2 - 1;

    imgui.SetCursorPos({ pad + 10, row1 + tx });
    imgui.TextColored(C.go, 'Selected PL');
    imgui.SetCursorPos({ pad + 10 + labelW, row1 });
    imgui.PushItemWidth(comboW);
    imgui.Combo('##hh_pl', pl_pick, me .. (job and ('  (' .. job .. ')') or '') .. '\0');
    imgui.PopItemWidth();
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Happy Healer heals from the game this tab is open in.\nTo heal with another character, use the tab in that game.');
    end
    imgui.SameLine(0, 6);
    select_button('##hh_plsel', selW, true);

    imgui.SetCursorPos({ pad + 10, row2 + tx });
    imgui.TextColored(C.go, 'Monitored Player');
    imgui.SetCursorPos({ pad + 10 + labelW, row2 });
    imgui.PushItemWidth(comboW);
    imgui.Combo('##hh_mon', mon_pick, table.concat(everyone, '\0') .. '\0');
    imgui.PopItemWidth();
    if imgui.IsItemHovered() then
        imgui.SetTooltip(#others == 0
            and 'Only you so far. Load omni on your other characters on this PC and they show up here.'
            or 'Whose party to heal, buff and cleanse. Pick, then press Select.');
    end
    imgui.SameLine(0, 6);
    if select_button('##hh_monsel', selW, everyone[mon_pick[1] + 1] == mon) then
        local pick = everyone[mon_pick[1] + 1];
        sk.set_monitored((pick ~= me) and pick or nil);
    end

    -- Big Pause / Start card.
    local rx = pad * 2 + leftW;
    local rw = W - rx - pad;
    card(dl, wx, wy, rx, top, rw, cardH, nil);
    imgui.SetCursorPos({ rx + 10, top + 10 });
    local btn, btn_h, label;
    if job == nil then
        btn, btn_h, label = C.track, C.track, 'Not a healing job';
    elseif running then
        btn, btn_h, label = C.stop, C.stop_h, 'Pause';
    else
        btn, btn_h, label = C.go, C.go_h, 'Start';
    end
    imgui.PushStyleColor(ImGuiCol_Button, btn);
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, btn_h);
    imgui.PushStyleColor(ImGuiCol_ButtonActive, btn_h);
    imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 8);
    imgui.SetWindowFontScale(1.7);
    if imgui.Button(label .. '##hh_go', { rw - 20, cardH - lineH - 28 }) and job ~= nil then
        cmd(running and '/hh stop' or '/hh start');
    end
    imgui.SetWindowFontScale(1.0);
    imgui.PopStyleVar(1);
    imgui.PopStyleColor(4);
    local state = (job == nil) and 'Use WHM RDM BRD COR SCH GEO'
        or (running and (sk.is_sleeping() and 'Sleeping (AFK) - move to wake it' or 'Healing') or 'Paused');
    imgui.SetCursorPos({ rx + (rw - imgui.CalcTextSize(state)) / 2, top + cardH - lineH - 8 });
    imgui.TextColored(running and C.go or C.dim, state);

    -- Party 1 (yours), then 2 and 3. With no alliance, Party 2 shows the
    -- monitored player's party instead (read from their game on this PC).
    local py = top + cardH + pad;
    local colW = math.floor((W - pad * 4) / 3);
    local rowH = 46;                                -- tall rows for the big job pictures
    local ICON = 36;
    local partyH = 30 + rowH * 6 + 4;
    local my_zone = 0;
    pcall(function () my_zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0); end);

    -- Party 1 is the monitored player's party (yours when you monitor yourself).
    -- When you monitor someone else, Party 2 shows your own party if you're not in theirs.
    local mine = {};
    for r = 0, 5 do mine[r + 1] = party_member(r) or false; end
    local groups = {};
    local roster = (mon ~= me) and sk.roster(mon) or nil;
    if roster then
        local live = {};
        for _, m in ipairs(mine) do if m then live[m.name] = m; end end
        local rows, with_me = {}, false;
        for r = 1, 6 do
            local e = roster[r];
            if e and live[e.name] then
                rows[r] = live[e.name];             -- in your party too: use your own fresher numbers
                if e.name == me then with_me = true; end
            else
                rows[r] = e and { name = e.name, hpp = e.hpp or 0, mpp = e.mpp or 0, same_zone = (e.zone or 0) == my_zone, is_trust = e.is_trust, job = e.main_job or 0 } or false;
            end
        end
        groups[1] = { title = mon .. "'s party", rows = rows };
        groups[2] = with_me and { title = 'Party 2', rows = {} } or { title = 'Your party', rows = mine };
        groups[3] = { title = 'Party 3', rows = {} };
    else
        groups[1] = { title = 'Party 1', rows = mine };
        for p = 1, 2 do
            local rows = {};
            for r = 0, 5 do rows[r + 1] = party_member(p * 6 + r) or false; end
            groups[p + 1] = { title = 'Party ' .. (p + 1), rows = rows };
        end
    end

    local boxH = lineH + 4;
    for p = 1, 3 do
        local g = groups[p];
        local px = pad + (p - 1) * (colW + pad);
        local count = 0;
        for _, m in ipairs(g.rows) do if m then count = count + 1; end end
        card(dl, wx, wy, px, py, colW, partyH, g.title, string.format('%d / 6', count));
        for r = 1, 6 do
            local m = g.rows[r];
            local ry = py + 30 + (r - 1) * rowH;
            local cx = px + 8;                         -- tick box
            -- Row: tick box, big job picture, then name / HP% over the HP and MP bars.
            local x1, x2 = wx + px + 14 + boxH, wx + px + colW - 10;
            local xt = x1 + ICON + 6;                  -- text and bars start after the picture
            local ty = ry + 3;                         -- name line
            if not m then
                dl:AddRectFilled({ x1, wy + ry + 2 }, { x1 + ICON, wy + ry + 2 + ICON }, u32(C.track), ui.R * 0.66);
                dl:AddText({ xt, wy + ty }, u32(C.dim), 'Inactive');
                bar(dl, xt, wy + ry + 22, x2, 7, 0, C.track);
            elseif m.is_trust then
                -- Someone else's Trust: shown like Cure Please, but only its owner's
                -- party can cast on it, so there's nothing to tick or focus.
                job_icon(m.job, x1 - wx, ry + 2, ICON, true);
                local pct = string.format('%d%%', m.hpp);
                local nm = m.name .. '  (trust)';
                dl:AddText({ xt, wy + ty }, u32(C.dim), nm);
                dl:AddText({ x2 - imgui.CalcTextSize(pct), wy + ty }, u32(C.dim), pct);
                bar(dl, xt, wy + ry + 22, x2, 7, m.hpp / 100, hp_colour(m.hpp));
                bar(dl, xt, wy + ry + 32, x2, 4, m.mpp / 100, C.mp);
            else
                local skipped = sk.is_skipped(m.name);
                -- Tick box: ticked = Happy Healer looks after this person.
                imgui.SetCursorPos({ cx, ry + math.floor((rowH - 4 - boxH) / 2) });
                imgui.PushStyleVar(ImGuiStyleVar_FramePadding, { 2, 2 });
                local on = { not skipped };
                if imgui.Checkbox('##hh_on_' .. p .. '_' .. r, on) then sk.toggle_skip(m.name); end
                imgui.PopStyleVar(1);
                if imgui.IsItemHovered() then
                    imgui.SetTooltip(skipped and ('Tick to let Happy Healer heal and buff ' .. m.name)
                        or ('Untick to stop Happy Healer healing or buffing ' .. m.name));
                end

                -- Click the name to make them the focus (healed first).
                local is_focus = focus ~= nil and focus == m.name;
                local pct = skipped and 'off' or string.format('%d%%', m.hpp);
                imgui.SetCursorPos({ x1 - wx, ry });
                if imgui.InvisibleButton('##hh_focus_' .. p .. '_' .. r, { math.max(10, x2 - x1 - imgui.CalcTextSize(pct) - 6), rowH - 6 }) then
                    cmd(is_focus and '/hh focus clear' or ('/hh focus name ' .. m.name));
                end
                if imgui.IsItemHovered() then
                    imgui.SetTooltip(is_focus and 'Click to clear the focus'
                        or ('Click to make ' .. m.name .. ' the focus (healed first)'));
                end

                local namecol = skipped and C.dim or (is_focus and C.blue or (m.same_zone and C.text or C.dim));
                job_icon(m.job, x1 - wx, ry + 2, ICON, skipped);
                if is_focus then
                    dl:AddRect({ x1 - 1, wy + ry + 1 }, { x1 + ICON + 1, wy + ry + 3 + ICON }, u32(C.blue), 4, 0, 2);
                end
                dl:AddText({ xt, wy + ty }, u32(namecol), m.name .. (is_focus and '  (focus)' or ''));
                dl:AddText({ x2 - imgui.CalcTextSize(pct), wy + ty }, u32(skipped and C.dim or C.text), pct);
                bar(dl, xt, wy + ry + 22, x2, 7, m.hpp / 100, skipped and C.edge or hp_colour(m.hpp));
                bar(dl, xt, wy + ry + 32, x2, 4, m.mpp / 100, skipped and C.edge or C.mp);
            end
        end
    end

    -- Current action card.
    local ay = py + partyH + pad;
    local ah = 50;
    card(dl, wx, wy, pad, ay, W - pad * 2, ah, 'Current action');
    local what, at = sk.last_action();
    local text, col;
    if not running then
        text, col = (job == nil) and 'Nothing - this job is not a healer.' or 'Paused.', C.dim;
    elseif what == nil then
        text, col = 'Watching the party...', C.dim;
    else
        text, col = string.format('%s   (%ds ago)', what, os.time() - (at or os.time())), C.text;
    end
    dl:AddText({ wx + pad + 10, wy + ay + 29 }, u32(col), text);

    ui.height = ay + ah + pad;
    end
    imgui.SetCursorPos({ 0, ui.height });
    imgui.Dummy({ 1, 1 });
    imgui.EndChild();
    imgui.PopStyleVar(2);
    imgui.PopStyleColor(15);
end

----------------------------------------------------------------------------------------------------
-- Pop-out: a small button you can drag anywhere, shown while the Happy Healer page is closed.
-- opts = { settings = table holding pop_x / pop_y, save = function, open = function }
----------------------------------------------------------------------------------------------------
local pop_saved_at = 0;
ui.render_popout = function (sk, opts)
    local job = sk.job_name();
    if job == nil then return; end           -- not on a healing job
    local running = sk.is_running();
    if not (ui.used or running) then return; end

    local st = opts.settings or {};
    local W, H = 150, 78;
    imgui.SetNextWindowPos({ st.hh_pop_x or 300, st.hh_pop_y or 300 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSize({ W, H }, ImGuiCond_Always);
    apply_look();
    imgui.PushStyleColor(ImGuiCol_WindowBg, C.popbg);
    imgui.PushStyleColor(ImGuiCol_Border, C.popedge);
    imgui.PushStyleColor(ImGuiCol_Text, C.text);
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 8);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 8, 6 });
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoSavedSettings);
    if imgui.Begin('Happy Healer##hh_popout', true, flags) then
        -- Title (drag the window by it) and a button that opens the full page.
        imgui.TextColored(C.head or { 0.20, 0.36, 0.66, 1.0 }, 'Happy Healer');
        imgui.SameLine(W - 30);
        imgui.PushStyleColor(ImGuiCol_Button, C.button);
        if imgui.SmallButton('^##hh_pop_open') and opts.open then opts.open(); end
        imgui.PopStyleColor(1);
        if imgui.IsItemHovered() then imgui.SetTooltip('Open Happy Healer'); end

        local btn, btn_h, label;
        if running then btn, btn_h, label = C.stop, C.stop_h, 'Pause';
        else btn, btn_h, label = C.go, C.go_h, 'Start'; end
        imgui.PushStyleColor(ImGuiCol_Button, btn);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, btn_h);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, btn_h);
        imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
        imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 6);
        imgui.SetWindowFontScale(1.25);
        if imgui.Button(label .. '##hh_pop_go', { W - 16, 0 }) then
            cmd(running and '/hh stop' or '/hh start');
        end
        imgui.SetWindowFontScale(1.0);
        imgui.PopStyleVar(1);
        imgui.PopStyleColor(4);
        local state = running and (sk.is_sleeping() and 'Sleeping (AFK)' or 'Healing') or 'Paused';
        imgui.SetCursorPosX((W - imgui.CalcTextSize(state)) / 2);
        imgui.TextColored(running and C.go or C.dim, state);

        -- Remember where it was dragged to (saved once the mouse lets go).
        local x, y = imgui.GetWindowPos();
        if type(x) == 'number' and (math.floor(x) ~= st.hh_pop_x or math.floor(y) ~= st.hh_pop_y)
            and not imgui.IsMouseDown(0) and os.clock() - pop_saved_at > 1 then
            st.hh_pop_x, st.hh_pop_y = math.floor(x), math.floor(y);
            pop_saved_at = os.clock();
            if opts.save then pcall(opts.save); end
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
    imgui.PopStyleColor(3);
end

return ui;
