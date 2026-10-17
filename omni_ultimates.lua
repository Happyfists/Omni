--[[
    omni_ultimates.lua - "Ultimates" tab: every CatsEyeXI ultimate weapon and weapon skill as a
    quest with a progress bar - Oboro (JSE), Relic, Mythic, Ergon, Empyrean, Mythic WS, Aeonic WS.

    From bg-wiki "CatsEyeXI Systems/..." pages (Oboro Weapons, Relic Weapon, Mythic Weapon,
    Ergon Weapon, Empyrean Weapon, Mythic Weapon Skill, Aeonic Weapon Skill).

    Progress per quest = the average of its steps:
      * item steps are counted from your bags (all of them), e.g. 7 / 10 = 70% of that step,
      * other steps (ranks, titles, currencies, NPC trades) are tick boxes, saved per character,
      * owning the finished weapon in any bag makes the quest 100%,
      * Empyrean progress comes from the Abyssea > Weapons page (trial you are on).
]]

local imgui = require('imgui');

local ult = {};
ult.height = 400;

local function norm(s) return (tostring(s or ''):lower():gsub('[^%w]', '')); end

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------
local function I(name, need, note) return { item = name, need = need or 1, note = note }; end   -- counted from bags
local function M(label) return { manual = label }; end                                        -- tick box

local CATS = {};

-- Oboro: JSE weapons (Port Jeuno E-6). Rank 10 (+ The Warrior's Path on ACE/WEW); collect after JP midnight.
local OBORO = {
    { 'Minos', 'WAR', 'Gabbrath Horn', 'Toporok', 'Dark Amood' },
    { 'Nyepel', 'MNK', 'Rockfin Tooth', 'Koenigs Knuckles', 'Behemoth Cesti' },
    { 'Sindri', 'WHM', 'Bztavian Stinger', 'Brise-os', 'Sacred Wand' },
    { 'Kaladanda', 'BLM', 'Waktza Rostrum', 'Iridal Staff', 'Chatoyant Staff' },
    { 'Egeking', 'RDM', 'Yggdreant Bole', 'Anelace', 'Apaisante' },
    { 'Sandung', 'THF', 'Cehuetzi Claw', 'Odorous Knife', "Garuda's Dagger" },
    { 'Priwen', 'PLD', 'Gabbrath Horn', 'Januwiyah', 'Tariqah' },
    { 'Cronus', 'DRK', 'Rockfin Tooth', 'Orichalcum Scythe', 'Smiting Scythe' },
    { 'Arktoi', 'BST', 'Bztavian Stinger', 'Veldt Axe', 'Furnace Tabarzin' },
    { 'Terpander', 'BRD', 'Waktza Rostrum', 'Shofar +1', 'Cyt. Anglica +1' },
    { 'Lionsquall', 'RNG', 'Yggdreant Bole', 'Hellfire', 'Matchlock Gun +1' },
    { 'Kurikaranotachi', 'SAM', 'Cehuetzi Claw', 'Butachi', 'Shirogatana' },
    { 'Shigi', 'NIN', 'Gabbrath Horn', 'Hirenjaku', 'Izayoi' },
    { 'Areadbhar', 'DRG', 'Rockfin Tooth', 'Orichalcum Lance', 'Mezraq' },
    { 'Gridarvor', 'SMN', 'Bztavian Stinger', 'Flete Pole', 'Iridal Staff' },
    { 'Mimesis', 'BLU', 'Waktza Rostrum', 'Steel Kilij', "Killer's Kilij" },
    { 'Deathlocke', 'COR', 'Yggdreant Bole', 'Hexagun', 'Silver Cassandra' },
    { 'Ohtas', 'PUP', 'Cehuetzi Claw', 'Adaman Sainti', 'Buzbaz Sainti' },
    { 'Polyhymnia', 'DNC', 'Gabbrath Horn', 'Adder Jambiya', 'Behemoth Knife' },
    { 'Coeus', 'SCH', 'Rockfin Tooth', 'Iridal Staff', 'Chatoyant Staff' },
    { 'Dunna', 'GEO', 'Bztavian Stinger', 'Im. Wootz Ingot', 'Star Sapphire' },
    { 'Aettir', 'RUN', 'Waktza Rostrum', 'Pealing Nagan', 'Mythril Heart' },
};
do
    local list = {};
    for _, o in ipairs(OBORO) do
        list[#list + 1] = { name = o[1], sub = o[2], final = o[1], steps = {
            M('Rank 10 (and The Warrior\'s Path on ACE / WEW)'),
            I(o[3], 2), M('200 H-P Bayld'), I(o[4], 1), I(o[5], 1),
            M('Traded to Oboro - collect after JP midnight') } };
    end
    CATS[#CATS + 1] = { id = 'oboro', label = 'Oboro', list = list,
        info = "Oboro, Port Jeuno (E-6), bottom of the stairs. Rank 10 needed (ACE / WEW also need The Warrior's Path). Trade the items, then collect after Japanese midnight." };
end

-- Relic: Dynamis upgrades, or rewards (Lv75 + Rank 10 = a stage 4; any craft 100 = a finished one).
local RELICS = {
    { 'Spharai', 'Hand-to-Hand' }, { 'Mandau', 'Dagger' }, { 'Excalibur', 'Sword' }, { 'Ragnarok', 'Great Sword' },
    { 'Guttler', 'Axe' }, { 'Bravura', 'Great Axe' }, { 'Apocalypse', 'Scythe' }, { 'Gungnir', 'Polearm' },
    { 'Kikoku', 'Katana' }, { 'Amanomurakumo', 'Great Katana' }, { 'Mjollnir', 'Club' }, { 'Claustrum', 'Staff' },
    { 'Yoichinoyumi', 'Bow' }, { 'Annihilator', 'Gun' }, { 'Aegis', 'Shield' },
};
do
    local list = {};
    for _, r in ipairs(RELICS) do
        list[#list + 1] = { name = r[1], sub = r[2], final = r[1], steps = {
            M('Base relic (Dynamis drop) - or the Lv75 + Rank 10 reward (a stage 4)'),
            M('Stage 2 (Dynamis currency upgrade)'), M('Stage 3'), M('Stage 4'),
            M('Stage 5 - finished (or the craft 100 reward)') } };
    end
    CATS[#CATS + 1] = { id = 'relic', label = 'Relic', list = list,
        info = 'Rank 10 at Lv75 = a stage 4 relic as a one-time reward. Any craft at 100 = a finished relic. Or upgrade from a Dynamis drop. CatsEyeXI: DMG+ Magian augments also give Resist "Death"; Ragnarok adds RUN, Mjollnir adds GEO. Swap: old weapon + 5,000,000 gil to the final-stage spot.' };
end

-- Mythic (Nonoroon, Aht Urhgan Whitegate I-11 -> Seaprince's Tombstone, Caedarva Mire E-10).
local MYTHICS = {
    { 'Conqueror', 'WAR' }, { 'Glanzfaust', 'MNK' }, { 'Yagrush', 'WHM' }, { 'Laevateinn', 'BLM' }, { 'Murgleis', 'RDM' },
    { 'Vajra', 'THF' }, { 'Burtgang', 'PLD' }, { 'Liberator', 'DRK' }, { 'Aymur', 'BST' }, { 'Carnwenhan', 'BRD' },
    { 'Gastraphetes', 'RNG' }, { 'Kogarasumaru', 'SAM' }, { 'Nagi', 'NIN' }, { 'Ryunohige', 'DRG' }, { 'Nirvana', 'SMN' },
    { 'Tizona', 'BLU' }, { 'Death Penalty', 'COR' }, { 'Kenkonken', 'PUP' }, { 'Terpsichore', 'DNC' }, { 'Tupsimati', 'SCH' },
};
do
    local list = {};
    for _, m in ipairs(MYTHICS) do
        list[#list + 1] = { name = m[1], sub = m[2], final = m[1], steps = {
            M('6,000 Zeni + 5 Imperial Gold Pieces to Nonoroon (on ' .. m[2] .. ') - base weapon'),
            M('Mercenary Captain rank (60 Bronze, 60 Silver, 60 Mithril, 30 Gold)'),
            M('30,000 Alexandrite stored with Paparoon (Nashmau) - Cat\'s Eye'),
            I("Tinnin's Fang"), I("Sarameya's Hide"), I("Tyger's Tail"),
            I("Gurfurlur's Helmet"), I("Ja Ja's Chestplate"), I("Medusa's Armlet"),
            I("Cat's Eye"), I('Imp. Gold Piece', 99),
            M('Titles: Gurfurlur, Cerberus, Gulool Ja Ja, Hydra, Medusa, Khimaira'),
            M("Traded to the Seaprince's Tombstone (Caedarva Mire E-10) with the base weapon") } };
    end
    CATS[#CATS + 1] = { id = 'mythic', label = 'Mythic', list = list,
        info = "Start: Nonoroon, Aht Urhgan Whitegate (I-11), on the job you want it for. Zeni from Soul Plates (Sanraku). Alexandrite from Einherjar and Aht Urhgan beastmen, stored with Paparoon (Nashmau). HNM trophies can also be force-popped with ISNM drops (Fang of Stheno, Dawnservant Drum, Mubtakir Naphtha). A Mythos Token skips the helmet, chestplate, armlet and titles. Balrahn's Eyepatch can replace any one trophy." };
end

-- Ergon (Rune Fencer / Geomancer).
do
    local function ergon(name, sub, broken)
        return { name = name, sub = sub, final = name, steps = {
            I('Adoulin Letter', 1, 'from Domain Coffers'),
            I(broken, 1, 'Frozen Foot trail, Uleguerand Range D-8'),
            I('P. Yggrete Crystal', 1, 'Sylvie or Volgoi, Ru\'Lude Gardens'),
            I('Bayld Crystal', 1, 'store 3,000 H-P Bayld at the Domain Officer'),
            I('Amphisbaena Hide', 1, 'Domain NMs'), I('Battosai Fang', 1, 'Domain NMs'), I('Tortuga Shell', 1, 'Domain NMs'),
            M('Traded to Wildernix (Lost Trail, Misareaux Coast F-4) - collect after JP midnight') } };
    end
    CATS[#CATS + 1] = { id = 'ergon', label = 'Ergon', list = {
        ergon('Idris', 'GEO', 'Broken Wand'), ergon('Epeolatry', 'RUN', 'Broken Sword') },
        info = 'Sylvie wants: Bztavian Stinger, Rockfin Tooth, Gabbrath Horn, Yggdreant Root, Waktza Crest, Cehuetzi Pelt. Volgoi wants: Bztavian Wing, Rockfin Fin, Gabbrath Meat, Yggdreant Bole, Waktza Rostrum, Cehuetzi Claw. Either one gives the P. Yggrete Crystal.' };
end

-- Empyrean: from the Abyssea > Weapons page.
CATS[#CATS + 1] = { id = 'empyrean', label = 'Empyrean', list = nil,
    info = "10 Magian trials each (Abyssea > Weapons has the full list, kills and trophies). Start at the Splintery Chest by the Magian Moogle, Ru'Lude Gardens." };

-- Mythic weapon skills: the quest "Unlocking a Myth" - trade the Vigil weapon to Zalsuhm.
local MYTHIC_WS = {
    { "King's Justice", 'Conqueror' }, { "Ascetic's Fury", 'Glanzfaust' }, { 'Mystic Boon', 'Yagrush' },
    { 'Vidohunir', 'Laevateinn' }, { 'Death Blossom', 'Murgleis' }, { 'Mandalic Stab', 'Vajra' },
    { 'Atonement', 'Burtgang' }, { 'Insurgency', 'Liberator' }, { 'Primal Rend', 'Aymur' },
    { 'Mordant Rime', 'Carnwenhan' }, { 'Trueflight', 'Gastraphetes' }, { 'Tachi: Rana', 'Kogarasumaru' },
    { 'Blade: Kamu', 'Nagi' }, { 'Drakesbane', 'Ryunohige' }, { 'Garland of Bliss', 'Nirvana' },
    { 'Expiacion', 'Tizona' }, { 'Leaden Salute', 'Death Penalty' }, { 'Stringing Pummel', 'Kenkonken' },
    { 'Pyrrhic Kleos', 'Terpsichore' }, { 'Omniscience', 'Tupsimati' },
};
do
    local list = {};
    for _, m in ipairs(MYTHIC_WS) do
        list[#list + 1] = { name = m[1], sub = m[2], ws = m[1], steps = {
            I(m[2], 1, 'the mythic weapon'),
            M('Quest "Unlocking a Myth" started (Zalsuhm)'),
            M('Weapon skill points done (see the table above)'),
            M('Vigil weapon traded to Zalsuhm') } };
    end
    CATS[#CATS + 1] = { id = 'mythicws', label = 'Mythic WS', list = list,
        info = 'Quest "Unlocking a Myth". The WS does not unlock on its own: trade the Vigil weapon to Zalsuhm. Weapon skill points needed by Nyzul Isle progress: 0 = 16,000 / 1-19 = 14,080-8,000 / 20-39 = 7,040-4,000 / 40-59 = 3,520-2,000 / 60-79 = 1,760-1,000 / 80-99 = 880-500 / 100 (Runic Key) = 250.' };
end

-- Aeonic weapon skills: Domain Officer, Upper Jeuno (G-9).
local AEONIC = {
    { 'Shijin Spiral', 'Hand-to-Hand', 'Lancewood Log', 'Infinity Core' },
    { 'Exenterator', 'Dagger', 'Slime Juice', 'Infinity Core' },
    { 'Requiescat', 'Sword', 'Colossal Skull', 'Infinity Core' },
    { 'Resolution', 'Great Sword', 'Goblin Grease', 'Infinity Core' },
    { 'Ruinator', 'Axe', 'Griffon Hide', 'Infinity Core' },
    { 'Upheaval', 'Great Axe', 'Giant Frozen Head', 'Infinity Core' },
    { 'Entropy', 'Scythe', 'Relic Iron', 'Infinity Core' },
    { 'Stardiver', 'Polearm', 'Fresh Orc Liver', 'Infinity Core' },
    { 'Blade: Shun', 'Katana', 'Wootz Ore', 'Infinity Core' },
    { 'Tachi: Shoha', 'Great Katana', 'Sparkling Stone', 'Infinity Core' },
    { 'Realmrazer', 'Club', 'Giant Frozen Head', 'Colossal Skull' },
    { 'Shattersoul', 'Staff', 'Slime Juice', 'Fresh Orc Liver' },
    { 'Apex Arrow', 'Archery', 'Griffon Hide', 'Lancewood Log' },
    { 'Last Stand', 'Marksmanship', 'Goblin Grease', 'Relic Iron' },
};
do
    local list = {};
    for _, a in ipairs(AEONIC) do
        list[#list + 1] = { name = a[1], sub = a[2], ws = a[1], steps = {
            M('Conquest Points / Imperial Standing / Allied Notes paid (ACE 300k first, 200k after; CW / WEW 100k first, 75k after)'),
            I(a[3], 10, 'Dynamis'), I(a[4], 10, 'Dynamis'),
            M('50,000 Domain Shards (Domain Invasion)'),
            M('Bought from the Domain Officer') } };
    end
    CATS[#CATS + 1] = { id = 'aeonic', label = 'Aeonic WS', list = list,
        info = 'Domain Officer, Upper Jeuno (G-9): "Unlock Weaponskill". Pay one currency, then bring the Dynamis items, then 50,000 Domain Shards from Domain Invasion.' };
end

----------------------------------------------------------------------------------------------------
-- Saved per character: ticked steps.
----------------------------------------------------------------------------------------------------
local st = { owner = nil, ticks = {}, cat = 'oboro', open = {} };
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
    return dir .. 'ultimates_' .. name .. '.txt';
end
local function save()
    if st.owner == nil then return; end
    pcall(function ()
        local f = io.open(save_path(st.owner), 'w');
        if f == nil then return; end
        f:write('cat ', st.cat, '\n');
        for k, v in pairs(st.ticks) do if v then f:write('tick ', k, '\n'); end end
        f:close();
    end);
end
local function load()
    local name = my_name();
    if name == nil or name == st.owner then return; end
    st.owner, st.ticks = name, {};
    pcall(function ()
        local f = io.open(save_path(name), 'r');
        if f == nil then return; end
        for line in f:lines() do
            local c = line:match('^cat (.+)$'); if c then st.cat = c; end
            local t = line:match('^tick (.+)$'); if t then st.ticks[t] = true; end
        end
        f:close();
    end);
end

----------------------------------------------------------------------------------------------------
-- Bags (counts by item name, and by the long "log" name, so "Imp. Gold Piece" matches).
----------------------------------------------------------------------------------------------------
local bag = { at = -100, count = {} };
local function scan()
    if os.clock() - bag.at < 2 then return; end
    bag.at = os.clock();
    local count = {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();
        for b = 0, 16 do
            for slot = 1, (inv:GetContainerCountMax(b) or 0) do
                local it = inv:GetContainerItem(b, slot);
                if it ~= nil and it.Id ~= nil and it.Id ~= 0 and it.Id ~= 65535 then
                    local r = res:GetItemById(it.Id);
                    if r and r.Name and r.Name[1] then
                        local seen = {};
                        for _, nm in ipairs({ r.Name[1], r.LogNameSingular and r.LogNameSingular[1] or nil }) do
                            local k = nm and norm(nm);
                            if k and k ~= '' and not seen[k] then seen[k] = true; count[k] = (count[k] or 0) + (it.Count or 1); end
                        end
                    end
                end
            end
        end
    end);
    bag.count = count;
end
local function have(name) return bag.count[norm(name)] or 0; end

-- A quest's progress (0..1) and each step's own fraction.
local function progress(cat, q)
    if q.final and have(q.final) > 0 then return 1, true; end
    local sum, n = 0, 0;
    for i, s in ipairs(q.steps) do
        local f;
        if s.item then f = math.min(1, have(s.item) / s.need);
        else f = st.ticks[cat.id .. ':' .. q.name .. ':' .. i] and 1 or 0; end
        sum, n = sum + f, n + 1;
    end
    return (n > 0) and (sum / n) or 0, false;
end

----------------------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------------------
local C = {
    gold = { 0.90, 0.78, 0.40, 1.0 }, text = { 0.92, 0.92, 0.95, 1.0 }, dim = { 0.62, 0.66, 0.80, 1.0 },
    faint = { 0.42, 0.44, 0.52, 1.0 }, green = { 0.45, 0.88, 0.45, 1.0 }, red = { 1.00, 0.50, 0.50, 1.0 },
    track = { 0.10, 0.12, 0.20, 1.0 },
};

-- A % bar: track, fill (gold, green at 100%), the number on top.
local function bar(w, h, frac)
    local dl = imgui.GetWindowDrawList();
    local x, y = imgui.GetCursorScreenPos();
    local full = frac >= 0.999;
    dl:AddRectFilled({ x, y }, { x + w, y + h }, imgui.GetColorU32(C.track), h / 2);
    if frac > 0 then
        local fc = full and { 0.30, 0.72, 0.40, 1.0 } or { 0.80, 0.62, 0.22, 1.0 };
        dl:AddRectFilled({ x, y }, { x + math.max(h, w * frac), y + h }, imgui.GetColorU32(fc), h / 2);
    end
    local label = string.format('%d%%', math.floor(frac * 100 + 0.5));
    local tw = imgui.CalcTextSize(label);
    local _, th = imgui.CalcTextSize('Ag');
    dl:AddText({ x + (w - tw) / 2, y + (h - th) / 2 }, imgui.GetColorU32({ 1, 1, 1, 1 }), label);
    imgui.Dummy({ w, h });
end

local function render_steps(cat, q)
    for i, s in ipairs(q.steps) do
        imgui.SetCursorPosX(28);
        if s.item then
            local n = have(s.item);
            local ok = n >= s.need;
            imgui.TextColored(ok and C.green or C.red, ok and '[x]' or '[ ]');
            imgui.SameLine(0, 6);
            imgui.TextColored(ok and C.text or C.dim, string.format('%s  %d / %d', s.item, math.min(n, 9999), s.need) .. (s.note and ('   (' .. s.note .. ')') or ''));
        else
            local key = cat.id .. ':' .. q.name .. ':' .. i;
            local v = { st.ticks[key] == true };
            if imgui.Checkbox(s.manual .. '##ult_' .. key, v) then st.ticks[key] = v[1] or nil; save(); end
        end
    end
end

local function render_list(cat, W)
    local rows = {};
    for _, q in ipairs(cat.list) do
        local p, owned = progress(cat, q);
        rows[#rows + 1] = { q = q, p = p, owned = owned };
    end
    local done = 0;
    for _, r in ipairs(rows) do if r.p >= 0.999 then done = done + 1; end end
    imgui.TextColored(C.dim, string.format('%d of %d done. Click a name for its steps.', done, #rows));
    local barW = math.max(160, math.min(320, W - 300));
    for _, r in ipairs(rows) do
        local q = r.q;
        local key = cat.id .. ':' .. q.name;
        local y = imgui.GetCursorPosY();
        imgui.SetCursorPosX(8);
        local open = st.open[key] == true;
        imgui.PushStyleColor(ImGuiCol_Text, r.p >= 0.999 and C.green or C.gold);
        if imgui.Selectable((open and '- ' or '+ ') .. q.name .. '##ult_row_' .. key, open, 0, { 170, 0 }) then st.open[key] = not open; end
        imgui.PopStyleColor(1);
        imgui.SetCursorPos({ 186, y });
        imgui.TextColored(C.dim, q.sub or '');
        imgui.SetCursorPos({ W - barW - 8, y + 1 });
        bar(barW, 14, r.p);
        if open then
            if r.owned then imgui.SetCursorPosX(28); imgui.TextColored(C.green, 'You have it!'); end
            render_steps(cat, q);
            imgui.Dummy({ 1, 4 });
        end
    end
end

local function render_empyrean(cat, W)
    local aw = nil;
    pcall(function () aw = require('omni_abyweapons'); end);
    if aw == nil or aw.LIST == nil then imgui.TextColored(C.red, 'The Abyssea Weapons page did not load.'); return; end
    local barW = math.max(160, math.min(320, W - 300));
    local done = 0;
    local rows = {};
    for _, w in ipairs(aw.LIST) do
        local step = (aw.step_of and aw.step_of(w.name)) or 0;
        local owned = have(w.name) > 0;
        local p = owned and 1 or (math.max(0, step - 1) / 10);
        rows[#rows + 1] = { w = w, p = p, step = step, owned = owned };
        if p >= 0.999 then done = done + 1; end
    end
    imgui.TextColored(C.dim, string.format('%d of %d done. Trial you are on comes from Abyssea > Weapons.', done, #rows));
    for _, r in ipairs(rows) do
        local y = imgui.GetCursorPosY();
        imgui.SetCursorPosX(8);
        imgui.TextColored(r.p >= 0.999 and C.green or C.gold, r.w.name);
        imgui.SetCursorPos({ 186, y });
        imgui.TextColored(C.dim, r.w.type .. (r.owned and '' or (r.step > 0 and string.format('  -  trial %d of 10', r.step) or '')));
        imgui.SetCursorPos({ W - barW - 8, y + 1 });
        bar(barW, 14, r.p);
    end
end

ult.render = function (opts)
    load();
    scan();
    local W = math.floor(imgui.GetContentRegionAvail());

    -- Category buttons, each with how many are done.
    local x = 0;
    for i, cat in ipairs(CATS) do
        local label = cat.label;
        local bw = imgui.CalcTextSize(label) + 22;
        if i > 1 then if x + 6 + bw <= W then imgui.SameLine(0, 6); x = x + 6; else x = 0; end end
        local on = (st.cat == cat.id);
        imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
        if imgui.Button(label .. '##ult_cat' .. i, { bw, 0 }) then st.cat = cat.id; save(); end
        imgui.PopStyleColor(1);
        x = x + bw;
    end
    imgui.Dummy({ 1, 4 });

    local cat = CATS[1];
    for _, c in ipairs(CATS) do if c.id == st.cat then cat = c; end end
    imgui.PushTextWrapPos(0);
    imgui.TextColored(C.dim, cat.info);
    imgui.PopTextWrapPos();
    imgui.Dummy({ 1, 4 });

    if cat.list then render_list(cat, W); else render_empyrean(cat, W); end
    ult.height = imgui.GetCursorPosY() + 8;
end

return ult;
