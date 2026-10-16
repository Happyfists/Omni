--[[
    omni_stealth.lua - Sneak / Invisible buttons on the main bar.

    Picks whatever you can use right now, best first:
      * Magic (WHM or RDM, main or sub): Sneak (20), Invisible (25) - if you have learned them.
      * Ninjutsu (NIN, main or sub): Monomi: Ichi for sneak, Tonko: Ni / Tonko: Ichi for invisible.
      * Dancer (DNC 25, main or sub): Spectral Jig - sneak and invisible in one.
      * Items in your bag: Silent Oil (sneak), Prism Powder (invisible).
    Nothing usable: no buttons. A button turns green while that effect is on you.
]]

local imgui = require('imgui');

local stealth = {};

local BUFF_SNEAK, BUFF_INVIS = 71, 69;
local WHM, RDM, NIN, DNC = 3, 5, 13, 19;

-- Spell ids by name (looked up once; the numbers are the usual ones if the lookup fails).
local SPELLS = {
    ['Sneak'] = { id = 137, lv = 20, jobs = { WHM, RDM } },
    ['Invisible'] = { id = 136, lv = 25, jobs = { WHM, RDM } },
    ['Monomi: Ichi'] = { id = 318, lv = 88, jobs = { NIN } },
    ['Tonko: Ni'] = { id = 354, lv = 34, jobs = { NIN } },
    ['Tonko: Ichi'] = { id = 353, lv = 9, jobs = { NIN } },
};
local looked_up = false;
local function lookup()
    if looked_up then return; end
    looked_up = true;
    local res = AshitaCore:GetResourceManager();
    for name, sp in pairs(SPELLS) do
        pcall(function ()
            local r = res:GetSpellByName(name, 0);
            if r ~= nil and r.Index ~= nil then sp.id = r.Index; end
            -- Level needed for each job, when the resource has it.
            if r ~= nil and r.LevelRequired ~= nil then
                for _, j in ipairs(sp.jobs) do
                    local need = r.LevelRequired[j + 1] or r.LevelRequired[j];
                    if type(need) == 'number' and need > 0 and need < 100 then sp.lv = need; end
                end
            end
        end);
    end
end

local function job_level(player, job)
    local lv = 0;
    pcall(function ()
        if player:GetMainJob() == job then lv = player:GetMainJobLevel(); end
        if player:GetSubJob() == job then lv = math.max(lv, player:GetSubJobLevel()); end
    end);
    return lv;
end

local function can_cast(player, name)
    local sp = SPELLS[name];
    if sp == nil then return false; end
    local known = false;
    pcall(function () known = player:HasSpell(sp.id); end);
    if not known then return false; end
    for _, j in ipairs(sp.jobs) do
        if job_level(player, j) >= sp.lv then return true; end
    end
    return false;
end

-- How many of an item are in your main bag (by name).
local function item_count(name)
    local n = 0;
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();
        for i = 1, inv:GetContainerCountMax(0) do
            local it = inv:GetContainerItem(0, i);
            if it ~= nil and it.Id ~= 0 and it.Id ~= 65535 then
                local r = res:GetItemById(it.Id);
                if r ~= nil and r.Name[1] == name then n = n + it.Count; end
            end
        end
    end);
    return n;
end

-- What each button does right now (worked out every second or so).
local plan, plan_at = nil, 0;
local function make_plan()
    lookup();
    local p = { };
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local jig = job_level(player, DNC) >= 25;

    -- Sneak
    if can_cast(player, 'Sneak') then p.sneak = { cmd = '/ma "Sneak" <me>', tip = 'Sneak (magic)' };
    elseif can_cast(player, 'Monomi: Ichi') then p.sneak = { cmd = '/ma "Monomi: Ichi" <me>', tip = 'Monomi: Ichi (ninjutsu)' };
    elseif jig then p.sneak = { cmd = '/ja "Spectral Jig" <me>', tip = 'Spectral Jig (sneak + invisible)', jig = true };
    else
        local n = item_count('Silent Oil');
        if n > 0 then p.sneak = { cmd = '/item "Silent Oil" <me>', tip = 'Silent Oil x' .. n }; end
    end
    -- Invisible
    if can_cast(player, 'Invisible') then p.invis = { cmd = '/ma "Invisible" <me>', tip = 'Invisible (magic)' };
    elseif can_cast(player, 'Tonko: Ni') then p.invis = { cmd = '/ma "Tonko: Ni" <me>', tip = 'Tonko: Ni (ninjutsu)' };
    elseif can_cast(player, 'Tonko: Ichi') then p.invis = { cmd = '/ma "Tonko: Ichi" <me>', tip = 'Tonko: Ichi (ninjutsu)' };
    elseif jig then p.invis = { cmd = '/ja "Spectral Jig" <me>', tip = 'Spectral Jig (sneak + invisible)', jig = true };
    else
        local n = item_count('Prism Powder');
        if n > 0 then p.invis = { cmd = '/item "Prism Powder" <me>', tip = 'Prism Powder x' .. n }; end
    end
    -- Both from the jig: one button.
    if p.sneak and p.invis and p.sneak.jig and p.invis.jig then
        p.both = p.sneak; p.sneak, p.invis = nil, nil;
    end
    return p;
end

local function has_buff(id)
    local on = false;
    pcall(function ()
        local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();
        for i = 0, 31 do
            local b = buffs[i] or buffs[i + 1];
            if b == id then on = true; return; end
        end
    end);
    return on;
end

local function run(cmd)
    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, cmd); end);
end

-- Draw the buttons on the bar (inside its window, after the last item). Returns true if any drawn.
stealth.draw = function (style)
    local now = os.clock();
    if plan == nil or now - plan_at > 1.0 then
        local ok, p = pcall(make_plan);
        plan = ok and p or {};
        plan_at = now;
    end
    local buttons = {};
    if plan.both then
        buttons[#buttons + 1] = { label = 'S+I', b = plan.both, on = has_buff(BUFF_SNEAK) and has_buff(BUFF_INVIS) };
    end
    if plan.sneak then buttons[#buttons + 1] = { label = 'SNK', b = plan.sneak, on = has_buff(BUFF_SNEAK) }; end
    if plan.invis then buttons[#buttons + 1] = { label = 'INV', b = plan.invis, on = has_buff(BUFF_INVIS) }; end
    if #buttons == 0 then return false; end

    for i, bt in ipairs(buttons) do
        imgui.SameLine(0, (i == 1) and 6 or 2);
        imgui.SetCursorPosY(5);
        imgui.PushStyleColor(ImGuiCol_Button, bt.on and { 0.20, 0.55, 0.22, 1.0 } or style.idle);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, bt.on and { 0.26, 0.64, 0.28, 1.0 } or style.hover);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, style.hover);
        imgui.SetWindowFontScale(0.85);
        local w = imgui.CalcTextSize(bt.label) + 10;
        if imgui.Button(bt.label .. '##omni_stealth' .. i, { w, 22 }) then run(bt.b.cmd); end
        imgui.SetWindowFontScale(1.0);
        imgui.PopStyleColor(3);
        if imgui.IsItemHovered() then
            imgui.SetTooltip(bt.b.tip .. (bt.on and '  -  on you now' or '') .. '\nClick to use it on yourself');
        end
    end
    return true;
end

return stealth;
