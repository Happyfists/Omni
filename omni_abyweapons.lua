--[[
    omni_abyweapons.lua - "Weapons" page of omni's Abyssea tab: the Empyrean weapon Magian
    trials on CatsEyeXI (Vision of Abyssea), from bg-wiki "CatsEyeXI Systems/Empyrean Weapon".

    Pick a weapon to see its 10 trials, where you are, what to kill or trade next, and how to pop
    each NM (from the NM Pops data). Kill counters go up on their own when the NM is defeated
    (chat: "... defeats the X" / "X falls to the ground") and can be nudged with - / +.
    Trophy counts are read from your bags (all of them).

    Trials start from the Splintery Chest next to the Magian Moogle (Ru'Lude Gardens): take the
    quest weapon, trade it to the moogle. "Defeat" trials need the weapon equipped when the NM
    dies; "Trophy" trials are traded with the weapon to the Delivery Crate by the moogle.
]]

local imgui = require('imgui');

local weapons = {};
weapons.height = 400;

-- D = defeat, T = trade trophies.  { trial, trade in, kind, target, count, where/source, receive }
local function D(n, inp, who, cnt, out, where) return { n = n, inp = inp, kind = 'D', who = who, cnt = cnt, out = out, where = where }; end
local function T(n, inp, item, cnt, nm, zone, out) return { n = n, inp = inp, kind = 'T', item = item, cnt = cnt, who = nm, where = zone, out = out }; end

weapons.LIST = {
    { name = 'Verethragna', type = 'Hand-to-Hand', base = 'Pugilists', trials = {
        D(68, 'Pugilists', 'Tumbling Truffle', 3, 'Simian Fists'),
        D(69, 'Simian Fists', 'Helldiver', 3, 'Simian Fists (Attack+3)'),
        D(70, 'Simian Fists (Attack+3)', 'Orctrap', 3, 'Simian Fists (Attack+5)'),
        D(71, 'Simian Fists (Attack+5)', 'Intulo', 4, 'Mantis'),
        D(72, 'Mantis', 'Ramponneau', 4, 'Mantis (Attack+3)'),
        D(73, 'Mantis (Attack+3)', 'Keeper of Halidom', 4, 'Mantis (Attack+5)'),
        T(74, 'Mantis (Attack+5)', "Manananggal's Necklet", 10, 'Manananggal', 'Tahrongi', 'Mantis (Attack+7)'),
        T(75, 'Mantis (Attack+7)', "Mictlantecuhtli's Habit", 20, 'Mictlantecuhtli', 'Tahrongi', 'Mantis (DMG:+7)'),
        D(1138, 'Mantis (DMG:+7)', 'Irrlicht', 30, 'Mantis (DMG:+8)', 'La Theine'),
        T(1139, 'Mantis (DMG:+8)', 'Two-Leaf Chloris Bud', 50, 'Chloris', 'Tahrongi', 'Verethragna') } },
    { name = 'Twashtar', type = 'Dagger', base = 'Peeler', trials = {
        D(2, 'Peeler', 'Nocuous Weapon', 3, 'Renegade'),
        D(3, 'Renegade', 'Black Triple Stars', 3, 'Renegade (Attack+3)'),
        D(4, 'Renegade (Attack+3)', 'Serra', 3, 'Renegade (Attack+5)'),
        D(5, 'Renegade (Attack+5)', 'Bugbear Strongman', 4, 'Kartika'),
        D(6, 'Kartika', 'La Velue', 4, 'Kartika (Attack+3)'),
        D(7, 'Kartika (Attack+3)', 'Hovering Hotpot', 4, 'Kartika (Attack+5)'),
        T(8, 'Kartika (Attack+5)', "Chukwa's Egg", 10, 'Chukwa', 'Tahrongi', 'Kartika (Attack+7)'),
        T(9, 'Kartika (Attack+7)', "Cuelebre's Horn", 20, 'Cuelebre', 'Tahrongi', 'Kartika (DMG:+5)'),
        D(1092, 'Kartika (DMG:+5)', 'Adze', 30, 'Kartika (DMG:+6)', 'Tahrongi'),
        T(1093, 'Kartika (DMG:+6)', 'Glavoid Shell', 50, 'Glavoid', 'Tahrongi', 'Twashtar') } },
    { name = 'Almace', type = 'Sword', base = 'Side-sword', trials = {
        D(150, 'Side-sword', 'Serpopard Ishtar', 3, 'Schiavona'),
        D(151, 'Schiavona', 'Tottering Toby', 3, 'Schiavona (Attack+3)'),
        D(152, 'Schiavona (Attack+3)', 'Drooling Daisy', 3, 'Schiavona (Attack+5)'),
        D(153, 'Schiavona (Attack+5)', 'Gargantua', 4, 'Nobilis'),
        D(154, 'Nobilis', 'Megalobugard', 4, 'Nobilis (Attack+3)'),
        D(155, 'Nobilis (Attack+3)', 'Ratatoskr', 4, 'Nobilis (Attack+5)'),
        T(156, 'Nobilis (Attack+5)', "Keesha's Pamama", 10, 'Keesha Poppo', 'La Theine', 'Nobilis (Attack+7)'),
        T(157, 'Nobilis (Attack+7)', "Marvin's Pelage", 20, 'Mangy-tailed Marvin', 'La Theine', 'Nobilis (DMG:+7)'),
        D(1200, 'Nobilis (DMG:+7)', 'Khalamari', 30, 'Nobilis (DMG:+8)', 'Konschtat'),
        T(1201, 'Nobilis (DMG:+8)', 'Helm of Briareus', 50, 'Briareus', 'La Theine', 'Almace') } },
    { name = 'Caladbolg', type = 'Great Sword', base = 'Break Blade', trials = {
        D(216, 'Break Blade', 'Bloodpool Vorax', 3, 'Sunblade'),
        D(217, 'Sunblade', 'Golden Bat', 3, 'Sunblade (Attack+3)'),
        D(218, 'Sunblade (Attack+3)', 'Slippery Sucker', 3, 'Sunblade (Attack+5)'),
        D(219, 'Sunblade (Attack+5)', 'Seww the Squidlimbed', 4, 'Albion'),
        D(220, 'Albion', 'Ankabut', 4, 'Albion (Attack+3)'),
        D(221, 'Albion (Attack+3)', 'Okyupete', 4, 'Albion (Attack+5)'),
        T(222, 'Albion (Attack+5)', 'Chasmic Stinger', 10, 'Chasmic Hornet', 'La Theine', 'Albion (Attack+7)'),
        T(223, 'Albion (Attack+7)', "Mikey's Nugget", 20, 'Megamaw Mikey', 'La Theine', 'Albion (DMG:+10)'),
        D(1246, 'Albion (DMG:+10)', 'Quetzalli', 30, 'Albion (DMG:+12)', 'Tahrongi'),
        T(1247, 'Albion (DMG:+12)', "Carabosse's Gem", 50, 'Carabosse', 'La Theine', 'Caladbolg') } },
    { name = 'Farsha', type = 'Axe', base = 'Chopper', trials = {
        D(282, 'Chopper', 'Panzer Percival', 3, 'Splinter'),
        D(283, 'Splinter', "Ge'Dha Evileye", 3, 'Splinter (Attack+3)'),
        D(284, 'Splinter (Attack+3)', 'Bashe', 3, 'Splinter (Attack+5)'),
        D(285, 'Splinter (Attack+5)', 'Intulo', 4, 'Bonebiter'),
        D(286, 'Bonebiter', 'Ramponneau', 4, 'Bonebiter (Attack+3)'),
        D(287, 'Bonebiter (Attack+3)', 'Keeper of Halidom', 4, 'Bonebiter (Attack+5)'),
        T(288, 'Bonebiter (Attack+5)', 'Raskovnik Vine', 10, 'Raskovnik', 'Konschtat', 'Bonebiter (Attack+7)'),
        T(289, 'Bonebiter (Attack+7)', 'Balaur Skull', 20, 'Balaur', 'Konschtat', 'Bonebiter (DMG:+6)'),
        D(1292, 'Bonebiter (DMG:+6)', 'Piasa', 30, 'Bonebiter (DMG:+8)', 'La Theine'),
        T(1293, 'Bonebiter (DMG:+8)', 'Fistule Discharge', 50, 'Fistule', 'Konschtat', 'Farsha') } },
    { name = 'Ukonvasara', type = 'Great Axe', base = 'Lumberjack', trials = {
        D(364, 'Lumberjack', 'Hoo Mjuu the Torrent', 3, 'Sagaris'),
        D(365, 'Sagaris', 'Daggerclaw Dracos', 3, 'Sagaris (Attack+3)'),
        D(366, 'Sagaris (Attack+3)', 'Namtar', 3, 'Sagaris (Attack+5)'),
        D(367, 'Sagaris (Attack+5)', 'Gargantua', 4, 'Bonesplitter'),
        D(368, 'Bonesplitter', 'Megalobugard', 4, 'Bonesplitter (Attack+3)'),
        D(369, 'Bonesplitter (Attack+3)', 'Ratatoskr', 4, 'Bonesplitter (Attack+5)'),
        T(370, 'Bonesplitter (Attack+5)', "Cuelebre's Horn", 10, 'Cuelebre', 'Tahrongi', 'Bonesplitter (Attack+7)'),
        T(371, 'Bonesplitter (Attack+7)', "Chukwa's Egg", 20, 'Chukwa', 'Tahrongi', 'Bonesplitter (DMG:+11)'),
        D(1354, 'Bonesplitter (DMG:+11)', 'Adze', 30, 'Bonesplitter (DMG:+13)', 'Tahrongi'),
        T(1355, 'Bonesplitter (DMG:+13)', 'Glavoid Shell', 50, 'Glavoid', 'Tahrongi', 'Ukonvasara') } },
    { name = 'Redemption', type = 'Scythe', base = 'Farmhand', trials = {
        D(512, 'Farmhand', 'Barbastelle', 3, 'Stigma'),
        D(513, 'Stigma', 'Ah Puch', 3, 'Stigma (Attack+3)'),
        D(514, 'Stigma (Attack+3)', 'Donggu', 3, 'Stigma (Attack+5)'),
        D(515, 'Stigma (Attack+5)', 'Bugbear Strongman', 4, 'Ultimatum'),
        D(516, 'Ultimatum', 'La Velue', 4, 'Ultimatum (Attack+3)'),
        D(517, 'Ultimatum (Attack+3)', 'Hovering Hotpot', 4, 'Ultimatum (Attack+5)'),
        T(518, 'Ultimatum (Attack+5)', "Mictlantecuhtli's Habit", 10, 'Mictlantecuhtli', 'Tahrongi', 'Ultimatum (Attack+7)'),
        T(519, 'Ultimatum (Attack+7)', "Manananggal's Necklet", 20, 'Manananggal', 'Tahrongi', 'Ultimatum (DMG:+12)'),
        D(1462, 'Ultimatum (DMG:+12)', 'Irrlicht', 30, 'Ultimatum (DMG:+14)', 'La Theine'),
        T(1463, 'Ultimatum (DMG:+14)', 'Two-Leaf Chloris Bud', 50, 'Chloris', 'Tahrongi', 'Redemption') } },
    { name = 'Rhongomiant', type = 'Polearm', base = 'Ranseur', trials = {
        D(430, 'Ranseur', 'Slendlix Spindlethumb', 3, 'Copperhead'),
        D(431, 'Copperhead', 'Herbage Hunter', 3, 'Copperhead (Attack+3)'),
        D(432, 'Copperhead (Attack+3)', 'Kirata', 3, 'Copperhead (Attack+5)'),
        D(433, 'Copperhead (Attack+5)', 'Intulo', 4, 'Oathkeeper'),
        D(434, 'Oathkeeper', 'Ramponneau', 4, 'Oathkeeper (Attack+3)'),
        D(435, 'Oathkeeper (Attack+3)', 'Keeper of Halidom', 4, 'Oathkeeper (Attack+5)'),
        T(436, 'Oathkeeper (Attack+5)', "Bakka's Wing", 10, 'Bakka', 'Konschtat', 'Oathkeeper (Attack+7)'),
        T(437, 'Oathkeeper (Attack+7)', 'Lieje Lantern', 20, 'Tonberry Lieje', 'Konschtat', 'Oathkeeper (DMG:+12)'),
        D(1400, 'Oathkeeper (DMG:+12)', 'Guimauve', 30, 'Oathkeeper (DMG:+14)', 'Konschtat'),
        T(1401, 'Oathkeeper (DMG:+14)', "Kukulkan's Fang", 50, 'Kukulkan', 'Konschtat', 'Rhongomiant') },
      note = "CatsEyeXI changed trial 1401 from Chloris Buds to Kukulkan's Fangs to spread out demand." },
    { name = 'Kannagi', type = 'Katana', base = 'Kibashiri', trials = {
        D(578, 'Kibashiri', "Zi'Ghi Boneeater", 3, 'Koruri'),
        D(579, 'Koruri', 'Lumbering Lambert', 3, 'Koruri (Attack+3)'),
        D(580, 'Koruri (Attack+3)', 'Deadly Dodo', 3, 'Koruri (Attack+5)'),
        D(581, 'Koruri (Attack+5)', 'Gargantua', 4, 'Mozu'),
        D(582, 'Mozu', 'Megalobugard', 4, 'Mozu (Attack+3)'),
        D(583, 'Mozu (Attack+3)', 'Ratatoskr', 4, 'Mozu (Attack+5)'),
        T(584, 'Mozu (Attack+5)', "Marvin's Pelage", 10, 'Mangy-tailed Marvin', 'La Theine', 'Mozu (Attack+7)'),
        T(585, 'Mozu (Attack+7)', "Keesha's Pamama", 20, 'Keesha Poppo', 'La Theine', 'Mozu (DMG:+7)'),
        D(1508, 'Mozu (DMG:+7)', 'Khalamari', 30, 'Mozu (DMG:+8)', 'Konschtat'),
        T(1509, 'Mozu (DMG:+8)', 'Helm of Briareus', 50, 'Briareus', 'La Theine', 'Kannagi') } },
    { name = 'Masamune', type = 'Great Katana', base = 'Donto', trials = {
        D(644, 'Donto', 'Vuu Puqu the Beguiler', 3, 'Shirodachi'),
        D(645, 'Shirodachi', 'Buburimboo', 3, 'Shirodachi (Attack+3)'),
        D(646, 'Shirodachi (Attack+3)', "Zo'Khu Blackcloud", 3, 'Shirodachi (Attack+5)'),
        D(647, 'Shirodachi (Attack+5)', 'Seww the Squidlimbed', 4, 'Radennotachi'),
        D(648, 'Radennotachi', 'Ankabut', 4, 'Radennotachi (Attack+3)'),
        D(649, 'Radennotachi (Attack+3)', 'Okyupete', 4, 'Radennotachi (Attack+5)'),
        T(650, 'Radennotachi (Attack+5)', 'Chasmic Stinger', 10, 'Chasmic Hornet', 'La Theine', 'Radennotachi (Attack+7)'),
        T(651, 'Radennotachi (Attack+7)', "Mikey's Nugget", 20, 'Megamaw Mikey', 'La Theine', 'Radennotachi (DMG:+10)'),
        D(1554, 'Radennotachi (DMG:+10)', 'Quetzalli', 30, 'Radennotachi (DMG:+12)', 'Tahrongi'),
        T(1555, 'Radennotachi (DMG:+12)', "Carabosse's Gem", 50, 'Carabosse', 'La Theine', 'Masamune') } },
    { name = 'Gambanteinn', type = 'Club', base = 'Stenz', trials = {
        D(710, 'Stenz', 'Stray Mary', 3, 'Rageblow'),
        D(711, 'Rageblow', 'Hawkeyed Dnatbat', 3, 'Rageblow (Attack+3)'),
        D(712, 'Rageblow (Attack+3)', 'Dune Widow', 3, 'Rageblow (Attack+5)'),
        D(713, 'Rageblow (Attack+5)', 'Seww the Squidlimbed', 4, 'Culacula'),
        D(714, 'Culacula', 'Ankabut', 4, 'Culacula (Attack+3)'),
        D(715, 'Culacula (Attack+3)', 'Okyupete', 4, 'Culacula (Attack+5)'),
        T(716, 'Culacula (Attack+5)', 'Raskovnik Vine', 10, 'Raskovnik', 'Konschtat', 'Culacula (Attack+7)'),
        T(717, 'Culacula (Attack+7)', 'Balaur Skull', 20, 'Balaur', 'Konschtat', 'Culacula (DMG:+15)'),
        D(1600, 'Culacula (DMG:+15)', 'Piasa', 30, 'Culacula (DMG:+16)', 'La Theine'),
        T(1601, 'Culacula (DMG:+16)', 'Fistule Discharge', 50, 'Fistule', 'Konschtat', 'Gambanteinn') } },
    { name = 'Hvergelmir', type = 'Staff', base = 'Crook', trials = {
        D(776, 'Crook', 'Teporingo', 3, 'Shillelagh'),
        D(777, 'Shillelagh', 'Valkurm Emperor', 3, 'Shillelagh (Attack+3)'),
        D(778, 'Shillelagh (Attack+3)', 'Hyakume', 3, 'Shillelagh (Attack+5)'),
        D(779, 'Shillelagh (Attack+5)', 'Gloomanita', 4, 'Slaine'),
        D(780, 'Slaine', 'Mischievous Micholas', 4, 'Slaine (Attack+3)'),
        D(781, 'Slaine (Attack+3)', 'Cactuar Cantautor', 4, 'Slaine (Attack+5)'),
        T(782, 'Slaine (Attack+5)', 'Lieje Lantern', 10, 'Tonberry Lieje', 'Konschtat', 'Slaine (Attack+7)'),
        T(783, 'Slaine (Attack+7)', "Bakka's Wing", 20, 'Bakka', 'Konschtat', 'Slaine (DMG:+13)'),
        D(1646, 'Slaine (DMG:+13)', 'Guimauve', 30, 'Slaine (DMG:+15)', 'Konschtat'),
        T(1647, 'Slaine (DMG:+15)', "Kukulkan's Fang", 50, 'Kukulkan', 'Konschtat', 'Hvergelmir') } },
    { name = 'Gandiva', type = 'Bow', base = 'Sparrow', trials = {
        D(941, 'Sparrow', "Be'Hya Hundredwall", 3, 'Kestrel'),
        D(942, 'Kestrel', 'Jolly Green', 3, 'Kestrel (Rng.Atk.+3)'),
        D(943, 'Kestrel (Rng.Atk.+3)', 'Trembler Tabitha', 3, 'Kestrel (Rng.Atk.+5)'),
        D(944, 'Kestrel (Rng.Atk.+5)', 'Seww the Squidlimbed', 4, 'Astrild'),
        D(945, 'Astrild', 'Ankabut', 4, 'Astrild (Rng.Atk.+3)'),
        D(946, 'Astrild (Rng.Atk.+3)', 'Okyupete', 4, 'Astrild (Rng.Atk.+5)'),
        T(947, 'Astrild (Rng.Atk.+5)', 'Balaur Skull', 10, 'Balaur', 'Konschtat', 'Astrild (Rng.Atk.+7)'),
        T(948, 'Astrild (Rng.Atk.+7)', 'Raskovnik Vine', 20, 'Raskovnik', 'Konschtat', 'Astrild (DMG:+10)'),
        D(1788, 'Astrild (DMG:+10)', 'Piasa', 30, 'Astrild (DMG:+11)', 'La Theine'),
        T(1789, 'Astrild (DMG:+11)', 'Fistule Discharge', 50, 'Fistule', 'Konschtat', 'Gandiva') } },
    { name = 'Armageddon', type = 'Gun', base = 'Thunderstick', trials = {
        D(891, 'Thunderstick', 'Desmodont', 3, 'Blue Steel'),
        D(892, 'Blue Steel', 'Moo Ouzi the Swiftblade', 3, 'Blue Steel (Rng.Atk.+3)'),
        D(893, 'Blue Steel (Rng.Atk.+3)', "Ni'Zho Bladebender", 3, 'Blue Steel (Rng.Atk.+5)'),
        D(894, 'Blue Steel (Rng.Atk.+5)', 'Bugbear Strongman', 4, 'Magnatus'),
        D(895, 'Magnatus', 'La Velue', 4, 'Magnatus (Rng.Atk.+3)'),
        D(896, 'Magnatus (Rng.Atk.+3)', 'Hovering Hotpot', 4, 'Magnatus (Rng.Atk.+5)'),
        T(897, 'Magnatus (Rng.Atk.+5)', "Mikey's Nugget", 10, 'Megamaw Mikey', 'La Theine', 'Magnatus (Rng.Atk.+7)'),
        T(898, 'Magnatus (Rng.Atk.+7)', 'Chasmic Stinger', 20, 'Chasmic Hornet', 'La Theine', 'Magnatus (DMG:+7)'),
        D(1758, 'Magnatus (DMG:+7)', 'Quetzalli', 30, 'Magnatus (DMG:+8)', 'Tahrongi'),
        T(1759, 'Magnatus (DMG:+8)', "Carabosse's Gem", 50, 'Carabosse', 'La Theine', 'Armageddon') } },
};

----------------------------------------------------------------------------------------------------
-- NM details from the NM Pops data (zone, map position, how to pop).
----------------------------------------------------------------------------------------------------
local okd, abydata = pcall(require, 'abydata.abyssea_data');
local function norm(s) return (tostring(s or ''):lower():gsub('[^%w]', '')); end
local NM_INFO = {};
if okd and type(abydata) == 'table' then
    for _, z in ipairs(abydata.zones or {}) do
        for _, nm in ipairs(z.nms or {}) do NM_INFO[norm(nm.name)] = { zone = z.short_name, nm = nm }; end
    end
end

----------------------------------------------------------------------------------------------------
-- Saved per character: chosen weapon, trial you are on, kill counts.
----------------------------------------------------------------------------------------------------
local st = { owner = nil, weapon = nil, step = {}, kills = {} };
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
    return dir .. 'abyweapons_' .. name .. '.txt';
end
local function save()
    if st.owner == nil then return; end
    pcall(function ()
        local f = io.open(save_path(st.owner), 'w');
        if f == nil then return; end
        f:write('weapon ', tostring(st.weapon or ''), '\n');
        for w, n in pairs(st.step) do f:write('step ', w, '=', n, '\n'); end
        for k, n in pairs(st.kills) do f:write('kill ', k, '=', n, '\n'); end
        f:close();
    end);
end
local function load()
    local name = my_name();
    if name == nil or name == st.owner then return; end
    st.owner, st.weapon, st.step, st.kills = name, nil, {}, {};
    pcall(function ()
        local f = io.open(save_path(name), 'r');
        if f == nil then return; end
        for line in f:lines() do
            local w = line:match('^weapon (.*)$');
            if w and w ~= '' then st.weapon = w; end
            local a, b = line:match('^step ([^=]+)=(%d+)$');
            if a then st.step[a] = tonumber(b); end
            local c, d = line:match('^kill ([^=]+)=(%d+)$');
            if c then st.kills[c] = tonumber(d); end
        end
        f:close();
    end);
end

-- Every NM any trial asks you to defeat (for the kill counter).
local WATCH = {};
for _, w in ipairs(weapons.LIST) do
    for _, t in ipairs(w.trials) do if t.kind == 'D' then WATCH[t.who:lower()] = t.who; end end
end

-- Kill counter: "X defeats the Y." / "Y falls to the ground." / "Y was defeated".
local last_kill = {};
local function on_text(e)
    local msg = (e.message_modified or e.message or ''):gsub('[\30\31].', ''):lower();
    if msg == '' then return; end
    for low, nm in pairs(WATCH) do
        if msg:find(low, 1, true) and (msg:find('defeats', 1, true) or msg:find('falls to the ground', 1, true) or msg:find('was defeated', 1, true)) then
            -- one count per kill (the same kill can print more than one line)
            local now = os.clock();
            if (last_kill[nm] == nil or now - last_kill[nm] > 3) then
                last_kill[nm] = now;
                load();
                st.kills[nm] = (st.kills[nm] or 0) + 1;
                save();
            end
            return;
        end
    end
end
ashita.events.register('text_in', 'omni_abyweapons_text', function (e) if not e.injected then pcall(on_text, e); end end);

----------------------------------------------------------------------------------------------------
-- Bags: trophy counts and which stage weapons you own.
----------------------------------------------------------------------------------------------------
local bag = { at = -100, count = {}, names = {} };
local function scan()
    if os.clock() - bag.at < 2 then return; end
    bag.at = os.clock();
    local count, names = {}, {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();
        for b = 0, 16 do
            for slot = 1, (inv:GetContainerCountMax(b) or 0) do
                local it = inv:GetContainerItem(b, slot);
                if it ~= nil and it.Id ~= nil and it.Id ~= 0 and it.Id ~= 65535 then
                    local r = res:GetItemById(it.Id);
                    if r and r.Name and r.Name[1] then
                        local k = norm(r.Name[1]);
                        count[k] = (count[k] or 0) + (it.Count or 1);
                        names[k] = true;
                        if r.LogNameSingular and r.LogNameSingular[1] then
                            local k2 = norm(r.LogNameSingular[1]);
                            if k2 ~= k then count[k2] = (count[k2] or 0) + (it.Count or 1); names[k2] = true; end
                        end
                    end
                end
            end
        end
    end);
    bag.count, bag.names = count, names;
end
local function have(item) return bag.count[norm(item)] or 0; end

-- Best guess at the trial you are on: the furthest stage weapon you own.
local function guess_step(w)
    local best = nil;
    for i, t in ipairs(w.trials) do
        local base = t.inp:gsub('%s*%b()', '');
        if bag.names[norm(base)] then best = best or i; best = i; end
    end
    return best;
end

----------------------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------------------
local C = {
    gold = { 0.90, 0.78, 0.40, 1.0 }, text = { 0.92, 0.92, 0.95, 1.0 }, dim = { 0.62, 0.66, 0.80, 1.0 },
    faint = { 0.42, 0.44, 0.52, 1.0 }, green = { 0.45, 0.88, 0.45, 1.0 }, red = { 1.00, 0.50, 0.50, 1.0 },
    blue = { 0.55, 0.75, 1.00, 1.0 }, yellow = { 1.00, 0.88, 0.35, 1.0 },
};

local function find_weapon(name)
    for _, w in ipairs(weapons.LIST) do if w.name == name then return w; end end
    return nil;
end

local function pop_lines(nmname)
    local info = NM_INFO[norm(nmname)];
    if info == nil then return nil; end
    local nm, out = info.nm, {};
    local where = 'Abyssea - ' .. info.zone .. (nm.location and (' ' .. nm.location) or '');
    out[#out + 1] = { C.dim, where .. '  -  ' .. tostring(nm.spawn_type or '') .. (nm.respawn and ('  -  ' .. nm.respawn) or '') };
    for _, r in ipairs(nm.requirements or {}) do
        local n = (r.type == 'item') and have(r.name) or nil;
        local label = string.format('%s%s%s', (r.type == 'ki') and 'Key item: ' or 'Pop: ', r.name, r.source and ('  (from ' .. r.source .. ')') or '');
        local col = C.text;
        if n ~= nil then label = label .. string.format('  - you have %d', n); col = (n > 0) and C.green or C.red; end
        out[#out + 1] = { col, label };
    end
    return out;
end

weapons.render = function (opts)
    load();
    scan();
    local W = math.floor(imgui.GetContentRegionAvail());

    imgui.PushTextWrapPos(0);
    imgui.TextColored(C.dim, "Empyrean weapons (Trial of the Magians). Start at the Splintery Chest by the Magian Moogle in Ru'Lude Gardens. Defeat trials: have the weapon equipped. Trophy trials: trade the items and weapon to the Delivery Crate.");
    imgui.PopTextWrapPos();
    imgui.Dummy({ 1, 2 });

    -- Weapon picker: one button each, wrapping to fit.
    local x = 0;
    for i, w in ipairs(weapons.LIST) do
        local label = w.name;
        local bw = imgui.CalcTextSize(label) + 18;
        if i > 1 then
            if x + 6 + bw <= W then imgui.SameLine(0, 6); x = x + 6; else x = 0; end
        end
        local on = (st.weapon == w.name);
        imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
        if imgui.Button(label .. '##abyw' .. i, { bw, 0 }) then st.weapon = w.name; save(); end
        imgui.PopStyleColor(1);
        if imgui.IsItemHovered() then imgui.SetTooltip(w.type .. '  -  starts from ' .. w.base); end
        x = x + bw;
    end
    imgui.Dummy({ 1, 4 });

    local w = find_weapon(st.weapon);
    if w == nil then
        imgui.TextColored(C.dim, 'Pick a weapon to see its trials.');
        weapons.height = imgui.GetCursorPosY() + 8;
        return;
    end

    -- Where you are: saved, else guessed from your bags, else trial 1.
    local cur = st.step[w.name] or guess_step(w) or 1;
    local t = w.trials[cur];

    imgui.SetWindowFontScale(1.15);
    imgui.TextColored(C.gold, w.name);
    imgui.SetWindowFontScale(1.0);
    imgui.SameLine(0, 10);
    imgui.TextColored(C.dim, string.format('%s  -  trial %d of 10', w.type, cur));
    imgui.SameLine(0, 14);
    if imgui.SmallButton('<##abyw_prev') and cur > 1 then st.step[w.name] = cur - 1; save(); end
    imgui.SameLine(0, 4);
    if imgui.SmallButton('Done - next >##abyw_next') and cur < 10 then st.step[w.name] = cur + 1; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Move on to the next trial once the moogle has upgraded your weapon.'); end
    if w.note then imgui.TextColored(C.yellow, w.note); end
    imgui.Dummy({ 1, 2 });

    -- The 10 trials: number, trade in, what to do, progress, what you get.
    local cx = { 8, 62, 250, 0, 0 };
    cx[4] = math.max(520, W - 260);
    cx[5] = math.max(cx[4] + 90, W - 170);
    local y0 = imgui.GetCursorPosY();
    imgui.SetCursorPos({ cx[1], y0 }); imgui.TextColored(C.faint, 'Trial');
    imgui.SetCursorPos({ cx[2], y0 }); imgui.TextColored(C.faint, 'Trade in');
    imgui.SetCursorPos({ cx[3], y0 }); imgui.TextColored(C.faint, 'Objective');
    imgui.SetCursorPos({ cx[4], y0 }); imgui.TextColored(C.faint, 'Progress');
    imgui.SetCursorPos({ cx[5], y0 }); imgui.TextColored(C.faint, 'Receive');
    for i, tr in ipairs(w.trials) do
        local y = imgui.GetCursorPosY() + 2;
        local done, now = i < cur, i == cur;
        local col = done and C.faint or (now and C.text or C.dim);
        if now then
            local dl = imgui.GetWindowDrawList();
            local wx, wy = imgui.GetWindowPos();
            local sy = imgui.GetScrollY and imgui.GetScrollY() or 0;
            local _, lh = imgui.CalcTextSize('Ag');
            dl:AddRectFilled({ wx + 2, wy + y - 2 - sy }, { wx + W - 2, wy + y + lh + 2 - sy }, imgui.GetColorU32({ 0.90, 0.78, 0.40, 0.12 }), 4);
        end
        imgui.SetCursorPos({ cx[1], y }); imgui.TextColored(done and C.green or (now and C.gold or C.dim), (done and '+ ' or (now and '> ' or '  ')) .. tostring(tr.n));
        imgui.SetCursorPos({ cx[2], y }); imgui.TextColored(col, tr.inp);
        imgui.SetCursorPos({ cx[3], y });
        local obj;
        if tr.kind == 'D' then obj = string.format('Defeat %s x%d', tr.who, tr.cnt) .. (tr.where and ('  (' .. tr.where .. ')') or '');
        else obj = string.format('Trade %s x%d', tr.item, tr.cnt); end
        imgui.TextColored(col, obj);
        if imgui.IsItemHovered() then
            imgui.BeginTooltip();
            imgui.TextColored(C.gold, (tr.kind == 'D') and tr.who or (tr.item .. '  -  from ' .. tr.who));
            if tr.kind == 'T' then imgui.TextColored(C.dim, 'Drops from ' .. tr.who .. ', Abyssea - ' .. tr.where); end
            local lines = pop_lines(tr.who);
            if lines then for _, l in ipairs(lines) do imgui.TextColored(l[1], l[2]); end
            else imgui.TextColored(C.faint, 'Not in the NM Pops list (a normal or field NM).'); end
            imgui.EndTooltip();
        end
        imgui.SetCursorPos({ cx[4], y });
        if tr.kind == 'D' then
            local k = st.kills[tr.who] or 0;
            imgui.TextColored(k >= tr.cnt and C.green or (now and C.yellow or C.dim), string.format('%d / %d', math.min(k, 999), tr.cnt));
            if now then
                imgui.SameLine(0, 6);
                if imgui.SmallButton('-##abyw_m' .. i) then st.kills[tr.who] = math.max(0, k - 1); save(); end
                imgui.SameLine(0, 2);
                if imgui.SmallButton('+##abyw_p' .. i) then st.kills[tr.who] = k + 1; save(); end
            end
        else
            local n = have(tr.item);
            imgui.TextColored(n >= tr.cnt and C.green or (now and C.yellow or C.dim), string.format('%d / %d', n, tr.cnt));
            if imgui.IsItemHovered() then imgui.SetTooltip('In your bags (all of them).'); end
        end
        imgui.SetCursorPos({ cx[5], y }); imgui.TextColored(i == 10 and C.gold or col, tr.out);
        if now and imgui.IsItemHovered() then imgui.SetTooltip('Click "Done - next" when you have this.'); end
    end
    imgui.Dummy({ 1, 6 });

    -- Next up: the current trial in detail.
    imgui.TextColored(C.gold, 'Next up');
    imgui.SameLine(0, 8);
    if t.kind == 'D' then
        local k = st.kills[t.who] or 0;
        imgui.TextColored(C.text, string.format('Defeat %s  -  %d of %d (weapon equipped)', t.who, math.min(k, t.cnt), t.cnt));
        if k > 0 then
            imgui.SameLine(0, 10);
            if imgui.SmallButton('Reset count##abyw_rs') then st.kills[t.who] = 0; save(); end
        end
    else
        local n = have(t.item);
        imgui.TextColored(C.text, string.format('Collect %s  -  %d of %d, from %s (Abyssea - %s)', t.item, n, t.cnt, t.who, t.where));
    end
    local lines = pop_lines(t.who);
    if lines then
        for _, l in ipairs(lines) do imgui.SetCursorPosX(18); imgui.TextColored(l[1], l[2]); end
    elseif t.kind == 'D' and t.where then
        imgui.SetCursorPosX(18); imgui.TextColored(C.dim, 'Abyssea - ' .. t.where .. '.');
    end

    -- Still to get for the rest of this weapon.
    local left = {};
    for i = cur, 10 do
        local tr = w.trials[i];
        if tr.kind == 'T' then
            local n = have(tr.item);
            if n < tr.cnt then left[#left + 1] = string.format('%s %d/%d', tr.item, n, tr.cnt); end
        else
            local k = st.kills[tr.who] or 0;
            if k < tr.cnt then left[#left + 1] = string.format('%s kills %d/%d', tr.who, k, tr.cnt); end
        end
    end
    imgui.Dummy({ 1, 4 });
    imgui.TextColored(C.gold, 'Still to do');
    imgui.SameLine(0, 8);
    imgui.PushTextWrapPos(0);
    imgui.TextColored(#left == 0 and C.green or C.dim, #left == 0 and 'Everything collected - finish the trials at the moogle.' or table.concat(left, '  -  '));
    imgui.PopTextWrapPos();

    weapons.height = imgui.GetCursorPosY() + 8;
end

return weapons;
