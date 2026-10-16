--[[
* trove/plugins/scrolls.lua — Scroll Ledger
* (omni copy: the counters also count learned spells; see "omni change" notes)
*
* Displays all storable magic scrolls with owned/missing status.
* Data fetched as packed bitmasks via generic tab protocol.
* Crystal Warrior only.
*
* Command: /trove scrolls
]]--

local imgui = require('imgui');

------------------------------------------------------------
-- Shared (injected via init)
------------------------------------------------------------
local renderIcon = nil;
local getItemRes = nil;
local ui = nil;
local renderTooltip = nil;

------------------------------------------------------------
-- Scroll Data (loaded from data/scroll_data.lua)
-- Order MUST match the server's page layout.
------------------------------------------------------------
local CATEGORIES = require('plugins/data/scroll_data');

------------------------------------------------------------
-- Protocol
------------------------------------------------------------
local PACKET_ID          = 0x1A4;
local C2S_TAB_SUMMARY   = 13;
local S2C_TAB_SUMMARY   = 12;
local TAB_SOURCE_SCROLLS = 2;

local function makePacket()
    local p = {};
    for i = 1, 64 do p[i] = 0; end
    return p;
end

local function sendScrollRequest()
    local p = makePacket();
    p[5] = C2S_TAB_SUMMARY;
    p[7] = TAB_SOURCE_SCROLLS;
    AshitaCore:GetPacketManager():AddOutgoingPacket(PACKET_ID, p);
end

------------------------------------------------------------
-- State
------------------------------------------------------------
local isOpen      = { false };
local dataLoaded  = false;
local bitmasks    = {};
local selectedCat = nil;
local ROW_HEIGHT  = 26;

-- Representative icon per category
local CAT_ICONS = {
    ['White Magic'] = 4609,  -- Cure
    ['Black Magic'] = 4752,  -- Fire
    ['Summoning']   = 4896,  -- Fire Spirit
    ['Ninjutsu']    = 4928,  -- Katon: Ichi
    ['Songs']       = 4976,  -- Foe Requiem
    ['Dice']        = 5477,  -- Warrior Die
    ['Geomancy']    = 6073,  -- Indi-Regen
    ['Blue Magic']  = 11465, -- Magus Keffiyeh (omni addition)
};

-- Spell name -> spell ID lookup (built on init, for "learned" detection)
local spellNameToId = {};
local spellMapBuilt = false;

local function normalize(name)
    return name:gsub("'", ''):lower();
end

local function buildSpellMap()
    if spellMapBuilt then return; end
    spellMapBuilt = true;
    local resMgr = AshitaCore:GetResourceManager();
    for i = 0, 1024 do
        local spell = resMgr:GetSpellById(i);
        if spell and spell.Name and spell.Name[1] and spell.Name[1] ~= '' then
            spellNameToId[normalize(spell.Name[1])] = i;
        end
    end
end

-- omni change: Corsair dice teach a Phantom Roll. A die counts as learned when
-- you know its roll. The game only lists a job's abilities while you are on that
-- job (main or support), so rolls seen are saved per character and still count
-- on other jobs.
local DIE_ROLL = {
    ['Warrior Die'] = "Fighter's Roll",      ['Monk Die'] = "Monk's Roll",
    ['White Mage Die'] = "Healer's Roll",    ['Black Mage Die'] = "Wizard's Roll",
    ['Red Mage Die'] = "Warlock's Roll",     ['Thief Die'] = "Rogue's Roll",
    ['Paladin Die'] = "Gallant's Roll",      ['Dark Knight Die'] = 'Chaos Roll',
    ['Beastmaster Die'] = 'Beast Roll',      ['Bard Die'] = 'Choral Roll',
    ['Ranger Die'] = "Hunter's Roll",        ['Samurai Die'] = 'Samurai Roll',
    ['Ninja Die'] = 'Ninja Roll',            ['Dragoon Die'] = 'Drachen Roll',
    ['Summoner Die'] = "Evoker's Roll",      ['Blue Mage Die'] = "Magus's Roll",
    ['Corsair Die'] = "Corsair's Roll",      ['Puppetmaster Die'] = 'Puppet Roll',
    ['Dancer Die'] = "Dancer's Roll",        ['Scholar Die'] = "Scholar's Roll",
    ['Bolters Die'] = "Bolter's Roll",       ['Casters Die'] = "Caster's Roll",
    ['Coursers Die'] = "Courser's Roll",     ['Blitzers Die'] = "Blitzer's Roll",
    ['Tacticians Die'] = "Tactician's Roll", ['Allies Die'] = "Allies' Roll",
    ['Misers Die'] = "Miser's Roll",         ['Companions Die'] = "Companion's Roll",
    ['Avengers Die'] = "Avenger's Roll",     ['Geomancer Die'] = "Naturalist's Roll",
    ['Rune Fencer Die'] = "Runeist's Roll",
};

local abilityNameToId = nil;   -- normalised job ability name -> resource id (512+)
local function rollId(rollName)
    if abilityNameToId == nil then
        abilityNameToId = {};
        local resMgr = AshitaCore:GetResourceManager();
        for i = 512, 1279 do
            local a = resMgr:GetAbilityById(i);
            if a and a.Name and a.Name[1] and a.Name[1] ~= '' then
                abilityNameToId[normalize(a.Name[1])] = abilityNameToId[normalize(a.Name[1])] or i;
            end
        end
    end
    return abilityNameToId[normalize(rollName)];
end

-- Rolls seen as known, saved per character: config\addons\omni\rolls_<Name>.txt
local rollsKnown, rollsOwner = {}, nil;
local function rollsPath(name)
    return string.format('%s\\config\\addons\\omni\\rolls_%s.txt', AshitaCore:GetInstallPath(), name);
end
local function rollsLoad()
    local name = nil;
    pcall(function () name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
    if name == nil or name == '' or name == rollsOwner then return; end
    rollsOwner, rollsKnown = name, {};
    pcall(function ()
        local f = io.open(rollsPath(name), 'r');
        if f == nil then return; end
        for line in f:lines() do if line ~= '' then rollsKnown[line] = true; end end
        f:close();
    end);
end
local function rollsSave()
    if rollsOwner == nil then return; end
    pcall(function ()
        local f = io.open(rollsPath(rollsOwner), 'w');
        if f == nil then return; end
        for roll in pairs(rollsKnown) do f:write(roll, '\n'); end
        f:close();
    end);
end

local function isRollKnown(dieName)
    local roll = DIE_ROLL[dieName];
    if roll == nil then return nil; end
    rollsLoad();
    local id = rollId(roll);
    if id ~= nil then
        local ok, has = pcall(function () return AshitaCore:GetMemoryManager():GetPlayer():HasAbility(id); end);
        if ok and has and not rollsKnown[roll] then
            rollsKnown[roll] = true;
            rollsSave();
        end
    end
    return rollsKnown[roll] == true;
end

-- omni change: answers are remembered for a couple of seconds, because the
-- counters now ask about every spell on every frame.
local learnedCache   = {};
local learnedCacheAt = 0;

local function isSpellLearned(spellName, knownSpellId)
    local now = os.clock();
    if now - learnedCacheAt > 2 then
        learnedCache   = {};
        learnedCacheAt = now;
    end
    local cached = learnedCache[spellName];
    if cached ~= nil then return cached; end

    local learned = false;
    local spellId = knownSpellId or spellNameToId[normalize(spellName)];
    local roll = isRollKnown(spellName);
    if roll ~= nil then
        learned = roll;
    elseif spellId ~= nil then
        learned = AshitaCore:GetMemoryManager():GetPlayer():HasSpell(spellId) and true or false;
    end
    learnedCache[spellName] = learned;
    return learned;
end

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
------------------------------------------------------------
-- omni addition: "where to learn" details, shown under a spell when it is clicked
------------------------------------------------------------
local bluHints = {};
do
    local ok, mod = pcall(require, 'plugins/data/blu_hints');
    if ok and type(mod) == 'table' and type(mod.hints) == 'table' then
        bluHints = mod.hints;
    end
end

-- CatsEyeXI-specific sources (from the CatsEyeXI wiki's level 75 blue magic table).
-- Where a spell is listed here, this replaces the retail location list.
local bluServerNotes = {
    [656] = 'Clionid, Escha - Ru\'Aun on Seiryu\'s island',  -- Acrid Stream
    [659] = 'Wivre',  -- Demoralizing Roar
    [677] = 'Craver',  -- Empty Thrash
    [688] = 'Golem',  -- Heavy Strike
    [657] = 'Limule, Escha - Ru\'Aun on Suzaku\'s island',  -- Blazing Bound
    [673] = 'Gorger',  -- Quad Continuum
    [699] = 'Fomor',  -- Barbed Crescent
    [658] = 'Gnole',  -- Plenilune Embrace
    [672] = 'Amoeban, Escha - Ru\'Aun on Genbu\'s Island',  -- Osmosis
    [679] = 'Seether',  -- Occultation
    [685] = 'Marid',  -- Barrier Tusk
    [668] = 'Ahriman',  -- Magic Barrier
    [696] = 'Any Orcs in the past [S] zones.',  -- O. Counterstance
    [737] = 'Pygmytoise in Gustav Tunnel lower level. Must be under the effect of Unbridled Learning to use.',  -- Harden Shell
    [741] = 'Tinnin hydra mobs. Must be under the effect of Unbridled Learning to use.',  -- Pyric Bulwark
    [745] = 'Tchakka in Domain Invasion.',  -- Carcharian Verve
    [661] = 'Qutrub',  -- Animating Wail
    [662] = 'Magic Pot',  -- Battery Charge
    [721] = 'Wild Ungeweder',  -- Anvil Lightning
    [725] = 'Wild Baelfyr',  -- Blinding Fulgor
    [727] = 'Wild Ungeweder',  -- Silent Storm
    [722] = 'Wild Byrgen',  -- Entomb
    [706] = 'Velkk Intruder',  -- Glutinous Dart
    [719] = 'Wild Baelfyr',  -- Searing Tempest
    [726] = 'Wild Gefyrst',  -- Scouring Spate
    [720] = 'Wild Gefyrst',  -- Spectral Floe
    [728] = 'Wild Byrgen',  -- Tenebral Crush
};

-- Vendors, BCNMs and mob drops for scrolls, dice and plates (generated data file).
local scrollSources = {};
do
    local ok, mod = pcall(require, 'plugins/data/scroll_sources');
    if ok and type(mod) == 'table' then
        scrollSources = mod;
    end
end

local expandedRow = nil;   -- id of the row whose details are open
local detailCache = {};    -- spell id -> list of ready-to-draw lines

-- Pre-Abyssea only: Abyssea zones, Walk of Echoes / Legion, and everything from Adoulin on are left out.
local LATE_ZONES = { [15]=true, [45]=true, [132]=true, [215]=true, [216]=true, [217]=true, [218]=true,
                     [253]=true, [254]=true, [255]=true, [182]=true, [183]=true };
local function isLateZone(zoneId)
    return zoneId >= 256 or LATE_ZONES[zoneId] == true;
end

local function getLearnLines(spellId)
    if detailCache[spellId] ~= nil then return detailCache[spellId]; end
    local lines = {};
    local zones = bluHints[spellId];
    if zones ~= nil then
        local resMgr = AshitaCore:GetResourceManager();
        for zoneId, mobs in pairs(zones) do
            if not isLateZone(zoneId) then
                local zoneName = resMgr:GetString('zones.names', zoneId);
                if zoneName == nil or zoneName == '' then zoneName = string.format('Zone %d', zoneId); end
                lines[#lines + 1] = { zone = zoneName, mobs = (table.concat(mobs, ', '):gsub('%%', '%%%%')) };
            end
        end
        table.sort(lines, function(a, b) return a.zone < b.zone; end);
    end
    detailCache[spellId] = lines;
    return lines;
end

local sourceCache = {};    -- item id -> sorted drop lines

local function getDropLines(itemId, drops)
    if sourceCache[itemId] ~= nil then return sourceCache[itemId]; end
    local lines = {};
    local resMgr = AshitaCore:GetResourceManager();
    for zoneId, mobs in pairs(drops) do
        local zoneName = resMgr:GetString('zones.names', zoneId);
        if zoneName == nil or zoneName == '' then zoneName = string.format('Zone %d', zoneId); end
        lines[#lines + 1] = { zone = zoneName, mobs = (mobs:gsub('%%', '%%%%')) };
    end
    table.sort(lines, function(a, b) return a.zone < b.zone; end);
    sourceCache[itemId] = lines;
    return lines;
end

local function renderPairList(title, list)
    ui.colored(title, 'header');
    imgui.Indent(12);
    imgui.PushTextWrapPos(0);
    for _, entry in ipairs(list) do
        imgui.TextColored(ui.color('yellow'), (entry[1]:gsub('%%', '%%%%')));
        imgui.SameLine();
        imgui.TextColored(ui.color('dimmed'), '- ' .. entry[2]);
    end
    imgui.PopTextWrapPos();
    imgui.Unindent(12);
end

-- Details for a scroll, die or plate: who sells it, which BCNMs and mobs drop it.
local function renderScrollSources(scroll)
    imgui.Indent(30);
    local src = scrollSources[scroll[2]];
    if src == nil then
        ui.dim('No pre-Abyssea vendor, BCNM or mob drop listed.');
    else
        if src.vendors then renderPairList('Sold by:', src.vendors); end
        if src.bcnm then renderPairList('BCNM:', src.bcnm); end
        if src.drops then
            ui.colored('Dropped by:', 'header');
            for _, line in ipairs(getDropLines(scroll[2], src.drops)) do
                imgui.Indent(12);
                imgui.TextColored(ui.color('yellow'), line.zone);
                imgui.Indent(12);
                imgui.PushTextWrapPos(0);
                imgui.TextColored(ui.color('dimmed'), line.mobs);
                imgui.PopTextWrapPos();
                imgui.Unindent(24);
            end
        end
    end
    ui.dim('(Public CatsEyeXI server data - live server can differ.)');
    imgui.Unindent(30);
    imgui.Spacing();
end

local function renderLearnDetails(scroll, cat)
    if scroll[2] == 0 and not cat.learnedOnly then
        -- omni: a quest-learned spell.
        imgui.Indent(30);
        ui.colored('Learn from:', 'header');
        imgui.PushTextWrapPos(0);
        imgui.TextColored(ui.color('yellow'), scroll[4] or 'A quest - see the wiki for this one.');
        imgui.PopTextWrapPos();
        imgui.Unindent(30);
        imgui.Spacing();
        return;
    end
    if not cat.learnedOnly then
        renderScrollSources(scroll);
        return;
    end
    imgui.Indent(30);
    local note  = scroll[3] and bluServerNotes[scroll[3]] or nil;
    local lines = scroll[3] and getLearnLines(scroll[3]) or {};
    if note ~= nil then
        ui.colored('Learn from (CatsEyeXI):', 'header');
        imgui.PushTextWrapPos(0);
        imgui.TextColored(ui.color('yellow'), note);
        imgui.PopTextWrapPos();
    elseif #lines > 0 then
        ui.colored('Learn from:', 'header');
        for _, line in ipairs(lines) do
            imgui.TextColored(ui.color('yellow'), line.zone);
            imgui.Indent(12);
            imgui.PushTextWrapPos(0);
            imgui.TextColored(ui.color('dimmed'), line.mobs);
            imgui.PopTextWrapPos();
            imgui.Unindent(12);
        end
        ui.dim('(Retail locations, pre-Abyssea zones only - CatsEyeXI can differ.)');
    else
        ui.dim('No pre-Abyssea location listed for this spell.');
    end
    imgui.Unindent(30);
    imgui.Spacing();
end

local function hasBit(mask, bitIndex)
    return bit.band(mask, bit.lshift(1, bitIndex)) ~= 0;
end

local function countOwned(catIdx)
    local cat = CATEGORIES[catIdx];
    local owned, total = 0, 0;
    local offset = 0;
    for i = 1, catIdx - 1 do
        offset = offset + #CATEGORIES[i].pages;
    end
    for pageIdx, page in ipairs(cat.pages) do
        local mask = (not cat.learnedOnly) and bitmasks[offset + pageIdx] or 0;
        for i = 0, #page - 1 do
            total = total + 1;
            -- omni change: a spell counts if its scroll is stored OR you have learned it.
            if hasBit(mask, i) or isSpellLearned(page[i + 1][1], page[i + 1][3]) then owned = owned + 1; end
        end
    end
    -- omni: spells learned by quest (no scroll), e.g. Summoner's avatars.
    for _, q in ipairs(cat.quested or {}) do
        total = total + 1;
        if isSpellLearned(q[1], q[3]) then owned = owned + 1; end
    end
    return owned, total;
end

local function getPageOffset(catIdx, pageIdx)
    local offset = 0;
    for i = 1, catIdx - 1 do
        offset = offset + #CATEGORIES[i].pages;
    end
    return offset + pageIdx;
end

------------------------------------------------------------
-- Render: Category list
------------------------------------------------------------
------------------------------------------------------------
-- omni addition: category banners
------------------------------------------------------------
local BANNER_HEIGHT = 58;
local BANNER_TINTS = {
    ['White Magic'] = { 0.86, 0.89, 0.97 },
    ['Black Magic'] = { 0.58, 0.38, 0.90 },
    ['Summoning']   = { 0.28, 0.80, 0.66 },
    ['Ninjutsu']    = { 0.88, 0.30, 0.32 },
    ['Songs']       = { 0.96, 0.80, 0.32 },
    ['Dice']        = { 0.96, 0.56, 0.22 },
    ['Geomancy']    = { 0.56, 0.78, 0.36 },
    ['Blue Magic']  = { 0.30, 0.58, 0.98 },
};

-- Returns true when the banner is clicked.
local function renderCategoryBanner(cat, catIdx, owned, total, pct)
    local tint = BANNER_TINTS[cat.name] or { 0.79, 0.69, 0.42 };
    local clicked = false;

    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.05, 0.07, 0.15, 0.95 });
    imgui.BeginChild(string.format('##magic_banner_%d', catIdx), { -1, BANNER_HEIGHT }, false,
        bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse));

    local dl = imgui.GetWindowDrawList();
    local wx, wy = imgui.GetWindowPos();
    local ww = imgui.GetWindowWidth();

    -- Colour wash fading out from the left, built from strips.
    local strips, washW = 24, ww * 0.7;
    for k = 0, strips - 1 do
        local alpha = 0.42 * (1 - k / strips) ^ 1.6;
        dl:AddRectFilled({ wx + washW * k / strips, wy }, { wx + washW * (k + 1) / strips + 1, wy + BANNER_HEIGHT },
            imgui.GetColorU32({ tint[1], tint[2], tint[3], alpha }));
    end
    -- Solid bar on the left edge and a thin line of the same colour along the top.
    dl:AddRectFilled({ wx, wy }, { wx + 4, wy + BANNER_HEIGHT }, imgui.GetColorU32({ tint[1], tint[2], tint[3], 1.0 }));
    dl:AddRectFilled({ wx, wy }, { wx + ww, wy + 1 }, imgui.GetColorU32({ tint[1], tint[2], tint[3], 0.55 }));

    -- The whole banner is the click target.
    imgui.SetCursorPos({ 0, 0 });
    if imgui.Selectable(string.format('##magic_banner_sel_%d', catIdx), false, 0, { 0, BANNER_HEIGHT }) then
        clicked = true;
    end

    -- Icon.
    local iconId = CAT_ICONS[cat.name];
    if iconId then
        imgui.SetCursorPos({ 14, 7 });
        renderIcon(iconId, 36);
    end

    -- Name, larger than normal text.
    imgui.SetWindowFontScale(1.35);
    imgui.SetCursorPos({ 60, 6 });
    imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, cat.name);
    imgui.SetWindowFontScale(1.0);

    -- Count and percentage on the right.
    local countText = string.format('%d / %d', owned, total);
    local pctText = string.format('%d%%', pct);
    dl:AddText({ wx + ww - imgui.CalcTextSize(countText) - 34, wy + 8 }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 1.0 }), countText);
    dl:AddText({ wx + ww - imgui.CalcTextSize(pctText) - 34, wy + 24 },
        imgui.GetColorU32((pct >= 100) and { 0.55, 0.90, 0.55, 1.0 } or { tint[1], tint[2], tint[3], 1.0 }), pctText);
    dl:AddText({ wx + ww - 18, wy + 16 }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.6 }), '>');

    -- Progress bar along the bottom.
    local bx1, bx2 = wx + 60, wx + ww - 34;
    local by1, by2 = wy + BANNER_HEIGHT - 14, wy + BANNER_HEIGHT - 8;
    dl:AddRectFilled({ bx1 - 1, by1 - 1 }, { bx2 + 1, by2 + 1 }, imgui.GetColorU32({ 0.0, 0.0, 0.0, 0.9 }), 4);
    dl:AddRectFilled({ bx1, by1 }, { bx2, by2 }, imgui.GetColorU32({ 0.02, 0.04, 0.11, 1.0 }), 3);
    if total > 0 and owned > 0 then
        local fill = math.max((bx2 - bx1) * math.min(1, owned / total), 6);
        dl:AddRectFilled({ bx1, by1 }, { bx1 + fill, by2 }, imgui.GetColorU32({ tint[1], tint[2], tint[3], 1.0 }), 3);
        dl:AddRectFilled({ bx1 + 1, by1 }, { bx1 + fill - 1, by1 + 2 }, imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.25 }), 3);
    end

    imgui.EndChild();
    imgui.PopStyleColor(1);
    return clicked;
end

local function renderCategoryList()
    if not dataLoaded then
        ui.dim('Loading...');
        return;
    end

    if ui.button('Refresh', 60, 22) then
        dataLoaded = false;
        sendScrollRequest();
    end
    -- omni change: one counter for every spell in every category.
    local allOwned, allTotal = 0, 0;
    for catIdx = 1, #CATEGORIES do
        local o, t = countOwned(catIdx);
        allOwned = allOwned + o;
        allTotal = allTotal + t;
    end
    imgui.SameLine();
    ui.colored('All spells', 'header');
    imgui.SameLine();
    ui.dim(string.format('%d / %d (%d%%)', allOwned, allTotal, allTotal > 0 and math.floor(allOwned / allTotal * 100) or 0));
    imgui.Separator();
    imgui.Spacing();

    imgui.BeginChild('##scroll_cats', { -1, -1 }, false);
    for catIdx, cat in ipairs(CATEGORIES) do
        local owned, total = countOwned(catIdx);
        local pct = total > 0 and math.floor(owned / total * 100) or 0;
        local subtitle = string.format('%d / %d (%d%%)', owned, total, pct);
        -- omni change: each category is a banner in its own colour, with a big icon,
        -- the name in larger text and a progress bar along the bottom.
        if renderCategoryBanner(cat, catIdx, owned, total, pct) then
            selectedCat = catIdx;
        end
        imgui.Spacing();
    end
    imgui.EndChild();
end

------------------------------------------------------------
-- Render: Scroll list for a category
------------------------------------------------------------
local function renderScrollList()
    local cat = CATEGORIES[selectedCat];

    if ui.button('< Back', 55, 22) then
        selectedCat = nil;
        return;
    end
    imgui.SameLine();
    local owned, total = countOwned(selectedCat);
    ui.colored(cat.name, 'header');
    imgui.SameLine();
    ui.dim(string.format('(%d/%d)', owned, total));
    imgui.Separator();
    imgui.Spacing();

    imgui.BeginChild('##scroll_list', { -1, -1 }, false);
    -- omni: quest-learned spells (no scroll) are listed after the scroll pages.
    local pageList = {};
    for pageIdx, page in ipairs(cat.pages) do pageList[#pageList + 1] = page; end
    if cat.quested then pageList[#pageList + 1] = cat.quested; end
    for pageIdx, page in ipairs(pageList) do
        local isQuested = (page == cat.quested);
        local maskIdx = getPageOffset(selectedCat, pageIdx);
        local mask = (not cat.learnedOnly and not isQuested) and bitmasks[maskIdx] or 0;
        local pageOwned = 0;
        for i = 0, #page - 1 do
            -- omni change: count learned spells as well as stored scrolls.
            if hasBit(mask, i) or isSpellLearned(page[i + 1][1], page[i + 1][3]) then pageOwned = pageOwned + 1; end
        end

        -- omni change: each page folds when its heading is clicked.
        local pageTitle = isQuested and 'Learned by quest' or string.format('Page %d', pageIdx);
        local pageOpen = ui.sectionHeader(pageTitle, pageOwned, string.format('magic:%s:%d', cat.name, pageIdx));
        imgui.Spacing();

        for i, scroll in ipairs(pageOpen and page or {}) do
            local spellName = scroll[1];
            local itemId    = scroll[2];
            local has       = hasBit(mask, i - 1);
            local learned   = isSpellLearned(spellName, scroll[3]);
            local isAlt     = (i % 2 == 0);

            local base = ui.color('childBg');
            local bgColor;
            if learned then
                bgColor = { 0.12, 0.25, 0.12, 0.50 };
            elseif isAlt then
                bgColor = { base[1], base[2], base[3], 0.35 };
            else
                bgColor = { base[1], base[2], base[3], 0.20 };
            end

            local rowId = string.format('##sr_%d_%d_%d', selectedCat, pageIdx, i);
            imgui.PushStyleColor(ImGuiCol_ChildBg, bgColor);
            imgui.BeginChild(rowId, { -1, ROW_HEIGHT }, false);

            imgui.SetCursorPos({ 4, 1 });
            if itemId ~= 0 then
                renderIcon(itemId, 22);
                imgui.SameLine(0, 6);
            end

            imgui.SetCursorPosY(0);
            -- omni change: clicking a row opens/closes its "where to get it" details.
            if imgui.Selectable(string.format('##ssel_%d_%d_%d', selectedCat, pageIdx, i), expandedRow == rowId,
                ImGuiSelectableFlags_SpanAllColumns, { 0, ROW_HEIGHT }) then
                expandedRow = (expandedRow ~= rowId) and rowId or nil;
            end
            local hovered = imgui.IsItemHovered();

            -- Draw name via drawlist
            local dl = imgui.GetWindowDrawList();
            local wx, wy = imgui.GetWindowPos();
            local nameColor = (has or (cat.learnedOnly and learned))
                and (ui.color('green') or { 0.4, 0.9, 0.4, 1.0 })
                or  (ui.color('dimmed') or { 0.4, 0.4, 0.4, 1.0 });
            local rollName = DIE_ROLL[spellName];
            if rollName then
                -- Dice: the roll it teaches, then the die in grey.
                local rollColor = learned and { 0.45, 0.88, 0.45, 1.0 } or nameColor;
                dl:AddText({ wx + 30, wy + 6 }, imgui.GetColorU32(rollColor), rollName);
                dl:AddText({ wx + 30 + imgui.CalcTextSize(rollName) + 8, wy + 6 }, imgui.GetColorU32({ 0.55, 0.57, 0.66, 1.0 }), '(' .. spellName .. ')');
            else
                dl:AddText({ wx + 30, wy + 6 }, imgui.GetColorU32(nameColor), spellName);
            end

            -- Status badges (right-aligned, drawn via drawlist)
            local ww = imgui.GetWindowWidth();
            local badgeX = wx + ww;
            local badgeY = wy + 4;
            local badgeH = 16;
            local badgePad = 4;

            local function drawBadge(text, fg, bg)
                local tw = imgui.CalcTextSize(text);
                local bw = tw + badgePad * 2;
                badgeX = badgeX - bw - 4;
                dl:AddRectFilled({ badgeX, badgeY }, { badgeX + bw, badgeY + badgeH }, imgui.GetColorU32(bg), 3);
                dl:AddText({ badgeX + badgePad, badgeY + 1 }, imgui.GetColorU32(fg), text);
            end

            if has then
                drawBadge('Stored', { 0.30, 0.85, 0.30, 1.0 }, { 0.15, 0.30, 0.15, 0.80 });
            end
            if learned then
                drawBadge('Learned', { 0.40, 0.75, 1.0, 1.0 }, { 0.12, 0.20, 0.35, 0.80 });
            end

            imgui.EndChild();

            if hovered then
                -- Use shared tooltip for full item details (description, jobs, level)
                if renderTooltip and itemId ~= 0 then
                    renderTooltip({ id = itemId, name = spellName });
                end
                -- Append status as a separate tooltip line
                -- (The shared tooltip handles BeginTooltip/EndTooltip,
                --  so we add status via the item row's right-side indicator instead)
            end

            imgui.PopStyleColor(1);

            if expandedRow == rowId then
                renderLearnDetails(scroll, cat);
            end
        end
        imgui.Spacing();
    end
    imgui.EndChild();
end

------------------------------------------------------------
-- Main render
------------------------------------------------------------
local function renderWindow()
    if not isOpen[1] then return; end

    if not dataLoaded and not bitmasks[1] then
        sendScrollRequest();
        bitmasks[1] = 0;
    end

    imgui.SetNextWindowSize({ 380, 500 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSizeConstraints({ 320, 400 }, { 500, 800 });

    local winColors = ui.pushWindowStyle();

    if imgui.Begin('Scrolls###trove_scrolls', isOpen, ImGuiWindowFlags_None) then
        local _bgPop = ui.renderBackground();
        if selectedCat then
            renderScrollList();
        else
            renderCategoryList();
        end
        if _bgPop > 0 then imgui.PopStyleColor(_bgPop); end
    end
    imgui.End();
    ui.popWindowStyle(winColors);
end

------------------------------------------------------------
-- Plugin export
------------------------------------------------------------
return {
    name        = 'Scrolls',
    author      = 'Loxley',
    version     = '1.0',
    description = 'Scroll collection tracker (Crystal Warrior)',

    init = function(sharedRenderIcon, sharedGetItemRes, sharedUi, sharedRenderTooltip)
        renderIcon = sharedRenderIcon;
        getItemRes = sharedGetItemRes;
        ui = sharedUi;
        renderTooltip = sharedRenderTooltip;
        buildSpellMap();
    end,

    commands = {
        scrolls = function(state, args)
            isOpen[1] = not isOpen[1];
        end,
    },

    window = {
        category = 'Storage',
        isOpen  = isOpen,
        render  = renderWindow,
        label   = 'Scrolls',
        icon    = 4609, -- Scroll of Cure
    },

    onPacketIn = function(e, state)
        if e.id ~= 0x1A4 then return; end

        local action = struct.unpack('B', e.data_modified, 0x04 + 1);
        if action ~= S2C_TAB_SUMMARY then return; end

        local source = struct.unpack('B', e.data_modified, 0x06 + 1);
        if source ~= TAB_SOURCE_SCROLLS then return; end

        local entryCount = struct.unpack('B', e.data_modified, 0x05 + 1);
        bitmasks = {};
        local offset = 0x08;
        for i = 1, entryCount do
            local b1 = struct.unpack('B', e.data_modified, offset + 1);
            local b2 = struct.unpack('B', e.data_modified, offset + 2);
            local b3 = struct.unpack('B', e.data_modified, offset + 3);
            local b4 = struct.unpack('B', e.data_modified, offset + 4);
            local mask = b1 + b2 * 256 + b3 * 65536 + b4 * 16777216;
            table.insert(bitmasks, mask);
            offset = offset + 4;
        end
        dataLoaded = true;
    end,
};
