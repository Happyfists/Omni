--[[
* trove/plugins/vnm.lua — VNM Armor plugin
*
* Floating window showing VNM armor collection progress.
* Monitors chat for Populox zone messages and Active Venture Seals.
* Highlights items dropping in announced zones.
]]--

local imgui = require('imgui');

------------------------------------------------------------
-- Shared functions (injected by trove.lua via plugin.init)
------------------------------------------------------------
local renderIcon = nil;
local getItemRes = nil;
local ui = nil;

------------------------------------------------------------
-- VNM Armor Data
------------------------------------------------------------
local SETS = {
    {
        name   = 'Ares',
        crest  = 'Mountain',
        color  = { 0.90, 0.55, 0.20, 1.0 },
        jobs   = 'WAR DRK PLD DRG RUN',
        final  = { head = 16084, body = 14546, hands = 14961, legs = 15625, feet = 15711 },
        tiers  = {
            { prefix = "Enyo's",   head = 16085, body = 14547, hands = 14962, legs = 15626, feet = 15712 },
            { prefix = "Phobos's", head = 16086, body = 14548, hands = 14963, legs = 15627, feet = 15713 },
            { prefix = "Deimos's", head = 16087, body = 14549, hands = 14964, legs = 15628, feet = 15714 },
        },
    },
    {
        name   = 'Skadi',
        crest  = 'Forest',
        color  = { 0.20, 0.75, 0.20, 1.0 },
        jobs   = 'THF RNG BST COR DNC',
        final  = { head = 16088, body = 14550, hands = 14965, legs = 15629, feet = 15715 },
        tiers  = {
            { prefix = "Njord's", head = 16089, body = 14551, hands = 14966, legs = 15630, feet = 15716 },
            { prefix = "Freyr's", head = 16090, body = 14552, hands = 14967, legs = 15631, feet = 15717 },
            { prefix = "Freya's", head = 16091, body = 14553, hands = 14968, legs = 15632, feet = 15718 },
        },
    },
    {
        name   = 'Usukane',
        crest  = 'Desert',
        color  = { 0.85, 0.75, 0.30, 1.0 },
        jobs   = 'MNK NIN SAM PUP',
        final  = { head = 16092, body = 14554, hands = 14969, legs = 15633, feet = 15719 },
        tiers  = {
            { prefix = 'Hoshikazu',  head = 16093, body = 14555, hands = 14970, legs = 15634, feet = 15720 },
            { prefix = 'Tsukikazu',  head = 16094, body = 14556, hands = 14971, legs = 15635, feet = 15721 },
            { prefix = 'Hikazu',     head = 16095, body = 14557, hands = 14972, legs = 15636, feet = 15722 },
        },
    },
    {
        name   = 'Marduk',
        crest  = 'Ocean',
        color  = { 0.30, 0.55, 0.90, 1.0 },
        jobs   = 'WHM BRD SMN SCH',
        final  = { head = 16096, body = 14558, hands = 14973, legs = 15637, feet = 15723 },
        tiers  = {
            { prefix = "Anu's",    head = 16097, body = 14559, hands = 14974, legs = 15638, feet = 15724 },
            { prefix = "Ea's",     head = 16098, body = 14560, hands = 14975, legs = 15639, feet = 15725 },
            { prefix = "Enlil's",  head = 16099, body = 14561, hands = 14976, legs = 15640, feet = 15726 },
        },
    },
    {
        name   = 'Morrigan',
        crest  = 'Tundra',
        color  = { 0.65, 0.45, 0.80, 1.0 },
        jobs   = 'BLM RDM BLU GEO',
        final  = { head = 16100, body = 14562, hands = 14977, legs = 15641, feet = 15727 },
        tiers  = {
            { prefix = "Nemain's", head = 16101, body = 14563, hands = 14978, legs = 15642, feet = 15728 },
            { prefix = "Bodb's",   head = 16102, body = 14564, hands = 14979, legs = 15643, feet = 15729 },
            { prefix = "Macha's",  head = 16103, body = 14565, hands = 14980, legs = 15644, feet = 15730 },
        },
    },
};

local SLOTS      = { 'head', 'body', 'hands', 'legs', 'feet' };
local SLOT_LABELS = { 'Head', 'Body', 'Hands', 'Legs', 'Feet' };
local TIER_LABELS = { 'T1', 'T2', 'T3', 'Done' };   -- omni change: 4th column is the finished piece

-- omni addition: the item in a column - tiers 1-3, then the completed piece.
local function columnItem(set, ti, slotKey)
    if ti <= 3 then return set.tiers[ti][slotKey]; end
    return set.final[slotKey];
end

-- omni addition: the three upgrades Irvina (Aht Urhgan Whitegate K-11) puts on a finished piece.
-- From the FFXI Wiki page "CatsEyeXI Systems/Salvage Augments". Used to tell which upgrade a piece is on.
local UPGRADES = {
    Ares = {
        head  = { 'Haste +1% Store TP +1', 'Haste +2% Store TP +2', 'Haste +3% Store TP +3' },
        body  = { 'Dual Wield +2 MDT -3%', 'Dual Wield +3 MDT -4%', 'Dual Wield +4 MDT -5%' },
        hands = { 'STR +2 Double Attack +1%', 'STR +3 Double Attack +2%', 'STR +4 Double Attack +3%' },
        legs  = { 'Acc +3 Atk +3', 'Acc +5 Atk +5', 'Acc +8 Atk +8' },
        feet  = { 'STR +2 Store TP +1', 'STR +3 Store TP +2', 'STR +4 Store TP +3' },
    },
    Skadi = {
        head  = { 'Acc +2 Ranged Acc +2', 'Acc +3 Ranged Acc +3', 'Acc +4 Ranged Acc +4' },
        body  = { 'Haste +1% Store TP +2', 'Haste +2% Store TP +3', 'Haste +3% Store TP +4' },
        hands = { 'Haste +1% Crit. Rate +1%', 'Haste +2% Crit. Rate +2%', 'Haste +3% Crit. Rate +3%' },
        legs  = { 'STR +1 Store TP +1', 'STR +2 Store TP +2', 'STR +3 Store TP +3' },
        feet  = { 'AGI +1 Haste +1%', 'AGI +2 Haste +2%', 'AGI +3 Haste +3%' },
    },
    Usukane = {
        head  = { 'Counter +2 DT -2%', 'Counter +3 DT -3%', 'Counter +4 DT -4%' },
        body  = { 'MDB +1 Double Attack +1%', 'MDB +2 Double Attack +2%', 'MDB +3 Double Attack +3%' },
        hands = { 'STR +2 Counter +1', 'STR +3 Counter +2', 'STR +4 Counter +3' },
        legs  = { 'Acc +3 Kick Attack +1', 'Acc +4 Kick Attack +2', 'Acc +5 Kick Attack +3' },
        feet  = { 'DEX +1 AGI +1', 'DEX +2 AGI +2', 'DEX +3 AGI +3' },
    },
    Marduk = {
        head  = { 'Acc +5 Magic Acc +1', 'Acc +6 Magic Acc +2', 'Acc +7 Magic Acc +3' },
        body  = { 'Acc +5 Magic Acc +1', 'Acc +8 Magic Acc +2', 'Acc +10 Magic Acc +3' },
        hands = { 'Atk +5 Haste +1%', 'Atk +8 Haste +2%', 'Atk +10 Haste +3%' },
        legs  = { 'Magic Acc +1 Song Duration +3%', 'Magic Acc +2 Song Duration +4%', 'Magic Acc +3 Song Duration +5%' },
        feet  = { 'CHR +3 Pet DT -2%', 'CHR +4 Pet DT -3%', 'CHR +5 Pet DT -4%' },
    },
    Morrigan = {
        head  = { 'Haste +2% Sword Skill +6', 'Haste +3% Sword Skill +7', 'Haste +4% Sword Skill +8' },
        body  = { 'Acc +3 M.Acc +3', 'Acc +4 M.Acc +4', 'Acc +5 M.Acc +5' },
        hands = { 'INT +1 MND +1', 'INT +2 MND +2', 'INT +3 MND +3' },
        legs  = { 'Atk +5 MDT -1%', 'Atk +8 MDT -2%', 'Atk +10 MDT -3%' },
        feet  = { 'Acc +3 M.Acc +1', 'Acc +4 M.Acc +2', 'Acc +5 M.Acc +3' },
    },
};

local CREST_ITEM_IDS = {
    Mountain = 3047, Forest = 3045, Desert = 3049, Ocean = 3046, Tundra = 3050,
};

-- What each upgrade costs, per piece: Artisan Seals for the slot, Crests for the set.
local UPGRADE_SEALS  = { 5, 10, 15 };
local UPGRADE_CRESTS = { 3, 5, 8 };

-- Turning the stored augment values on an item into the numbers shown in game.
local AUG_VALUES = {};
do
    local ok, mod = pcall(require, 'plugins/data/augment_values');
    if ok and type(mod) == 'table' then AUG_VALUES = mod; end
end

local function augmentNumbers(extra)
    local out = {};
    if extra == nil then return out; end
    pcall(function()
        local kind = struct.unpack('B', extra, 1);
        if kind ~= 2 and kind ~= 3 then return; end
        for slot = 0, 4 do
            local word = struct.unpack('B', extra, 3 + slot * 2) + struct.unpack('B', extra, 4 + slot * 2) * 256;
            local id = word % 2048;
            if id ~= 0 then
                local rule = AUG_VALUES[id] or { 1, 1 };
                out[#out + 1] = math.abs(rule[1] + math.floor(word / 2048) * rule[2]);
            end
        end
    end);
    return out;
end

-- 0 = not upgraded yet, 1-3 = upgrade tier, matched against the wiki's numbers.
local function upgradeTier(lines, numbers)
    if #numbers == 0 or lines == nil then return 0; end
    local best, bestScore = 0, 0;
    for t, text in ipairs(lines) do
        local pool, hits = {}, 0;
        for n in text:gmatch('[%+%-](%d+)') do n = tonumber(n); pool[n] = (pool[n] or 0) + 1; end
        for _, v in ipairs(numbers) do
            if (pool[v] or 0) > 0 then pool[v] = pool[v] - 1; hits = hits + 1; end
        end
        if hits > bestScore then best, bestScore = t, hits; end
    end
    return best;
end

-- Short and long slot names on Artisan Seals.
local SEAL_SLOT = {
    hd = 'head', head = 'head', bd = 'body', body = 'body', hn = 'hands', hands = 'hands',
    lg = 'legs', legs = 'legs', ft = 'feet', feet = 'feet',
};

local finalTiers  = {};   -- final item id -> upgrade tier 0-3 (highest copy you own)
local sealCounts  = {};   -- 'head'.. -> Artisan Seals you have for that slot
local crestCounts = {};   -- crest item id -> how many you have

local HNM_DROPS = {
    [1] = { head = 'Cerberus',  body = 'Tiamat',      hands = 'Nidhogg',       legs = 'Medusa',                feet = 'Escha Suzaku' },
    [2] = { head = 'Hydra',     body = 'Jormungand',   hands = 'Aspidochelone', legs = 'Gulool Ja Ja',         feet = 'Escha Seiryu' },
    [3] = { head = 'Khimaira',  body = 'Vrtra',        hands = 'Escha Genbu',   legs = 'Gurfurlur the Menacing', feet = 'Escha Byakko' },
};

------------------------------------------------------------
-- Zone drop data
------------------------------------------------------------
local ZONE_DROPS = {
    { zone = 'Valkurm Dunes',            tier = 1, slot = 'head',  crest = 'Ocean'    },
    { zone = 'Buburimu Peninsula',        tier = 1, slot = 'body',  crest = 'Mountain' },
    { zone = 'Maze of Shakhrami',         tier = 1, slot = 'hands', crest = 'Tundra'   },
    { zone = 'Jugner Forest',             tier = 1, slot = 'legs',  crest = 'Forest'   },
    { zone = 'Pashhow Marshlands',        tier = 1, slot = 'feet',  crest = 'Ocean'    },
    { zone = 'Meriphataud Mountains',     tier = 1, slot = 'hands', crest = 'Mountain' },
    { zone = 'Korroloka Tunnel',          tier = 2, slot = 'body',  crest = 'Mountain' },
    { zone = 'Batallia Downs',            tier = 1, slot = 'legs',  crest = 'Desert'   },
    { zone = 'Rolanberry Fields',         tier = 1, slot = 'feet',  crest = 'Ocean'    },
    { zone = 'Sauromugue Champaign',      tier = 1, slot = 'head',  crest = 'Desert'   },
    { zone = 'Qufim Island',              tier = 1, slot = 'legs',  crest = 'Tundra'   },
    { zone = 'Yuhtunga Jungle',           tier = 1, slot = 'body',  crest = 'Forest'   },
    { zone = 'Yhoator Jungle',            tier = 2, slot = 'hands', crest = 'Forest'   },
    { zone = 'Sea Serpent Grotto',         tier = 2, slot = 'legs',  crest = 'Ocean'    },
    { zone = 'The Sanctuary of Zi\'Tah',  tier = 2, slot = 'head',  crest = 'Forest'   },
    { zone = 'Eastern Altepa Desert',     tier = 2, slot = 'body',  crest = 'Desert'   },
    { zone = 'Garlaige Citadel',          tier = 2, slot = 'feet',  crest = 'Mountain' },
    { zone = 'Crawler\'s Nest',           tier = 2, slot = 'legs',  crest = 'Desert'   },
    { zone = 'Western Altepa Desert',     tier = 2, slot = 'hands', crest = 'Desert'   },
    { zone = 'Labyrinth of Onzozo',       tier = 2, slot = 'head',  crest = 'Tundra'   },
    { zone = 'Gustav Tunnel',             tier = 3, slot = 'hands', crest = 'Desert'   },
    { zone = 'Toraimarai Canal',          tier = 2, slot = 'body',  crest = 'Ocean'    },
    { zone = 'Misareaux Coast',           tier = 2, slot = 'feet',  crest = 'Tundra'   },
    { zone = 'Bostaunieux Oubliette',     tier = 3, slot = 'feet',  crest = 'Tundra'   },
    { zone = 'Uleguerand Range',          tier = 3, slot = 'head',  crest = 'Tundra'   },
    { zone = 'Kuftal Tunnel',             tier = 3, slot = 'legs',  crest = 'Mountain' },
    { zone = 'The Boyahda Tree',          tier = 3, slot = 'head',  crest = 'Mountain' },
    { zone = 'Cape Teriggan',             tier = 3, slot = 'body',  crest = 'Desert'   },
    { zone = 'Ro\'Maeve',                 tier = 3, slot = 'hands', crest = 'Forest'   },
    { zone = 'Bibiki Bay',                tier = 3, slot = 'body',  crest = 'Ocean'    },
    { zone = 'East Ronfaure [S]',         tier = 1, slot = 'head',  crest = 'Forest',   loc = '(G-9)' },
    { zone = 'West Sarutabaruta [S]',     tier = 1, slot = 'hands', crest = 'Forest'   },
    { zone = 'North Gustaberg [S]',       tier = 1, slot = 'feet',  crest = 'Mountain' },
    { zone = 'Wajaom Woodlands',          tier = 1, slot = 'body',  crest = 'Tundra',  loc = '(I-6)' },
    { zone = 'Bhaflau Thickets',          tier = 1, slot = 'hands', crest = 'Desert',  loc = '(H-9)' },
    { zone = 'Alzadaal Undersea Ruins',   tier = 1, slot = 'legs',  crest = 'Ocean',   loc = 'Map 3 (I-8)' },
    { zone = 'Grauberg [S]',              tier = 2, slot = 'head',  crest = 'Mountain' },
    { zone = 'Vunkerl Inlet [S]',         tier = 2, slot = 'hands', crest = 'Ocean'    },
    { zone = 'Fort Karugo-Narugo [S]',    tier = 2, slot = 'feet',  crest = 'Forest'   },
    { zone = 'East Ronfaure [S]',         tier = 2, slot = 'body',  crest = 'Forest',  loc = '(H-9)' },
    { zone = 'Garlaige Citadel [S]',      tier = 3, slot = 'legs',  crest = 'Forest'   },
    { zone = 'Rolanberry Fields [S]',     tier = 3, slot = 'hands', crest = 'Ocean'    },
    { zone = 'Bhaflau Thickets',          tier = 3, slot = 'feet',  crest = 'Desert',  loc = '(H-7)' },
    { zone = 'Wajaom Woodlands',          tier = 3, slot = 'body',  crest = 'Tundra',  loc = '(I-8)' },
    { zone = 'Aydeewa Subterrane',        tier = 3, slot = 'legs',  crest = 'Mountain' },
    { zone = 'Caedarva Mire',             tier = 3, slot = 'legs',  crest = 'Tundra'   },
    { zone = 'Mount Zhayolm',             tier = 3, slot = 'feet',  crest = 'Desert'   },
    { zone = 'Alzadaal Undersea Ruins',   tier = 3, slot = 'head',  crest = 'Ocean',   loc = 'Map 2 (I-8)' },
};

local CREST_ZONES = {};
local ZONE_LOOKUP = {};
local ZONE_LOC_LOOKUP = {};  -- key: "zone|loc" for zones with duplicate entries
local ZONE_HAS_LOC = {};     -- zones that need loc disambiguation
local ITEM_ZONES  = {};

local function buildLookups()
    CREST_ZONES = {};
    ZONE_LOOKUP = {};
    ZONE_LOC_LOOKUP = {};
    ZONE_HAS_LOC = {};
    ITEM_ZONES  = {};

    -- First pass: identify zones that appear more than once
    local zoneCounts = {};
    for _, drop in ipairs(ZONE_DROPS) do
        local key = string.lower(drop.zone);
        zoneCounts[key] = (zoneCounts[key] or 0) + 1;
    end

    for _, drop in ipairs(ZONE_DROPS) do
        if not CREST_ZONES[drop.crest] then CREST_ZONES[drop.crest] = {}; end
        local found = false;
        for _, z in ipairs(CREST_ZONES[drop.crest]) do if z == drop.zone then found = true; break; end end
        if not found then table.insert(CREST_ZONES[drop.crest], drop.zone); end

        local key = string.lower(drop.zone);
        local entry = { tier = drop.tier, slot = drop.slot, crest = drop.crest };

        -- For duplicate zones with loc, use loc-specific lookup
        if zoneCounts[key] > 1 and drop.loc then
            ZONE_HAS_LOC[key] = true;
            local locKey = key .. '|' .. string.lower(drop.loc);
            if not ZONE_LOC_LOOKUP[locKey] then ZONE_LOC_LOOKUP[locKey] = {}; end
            table.insert(ZONE_LOC_LOOKUP[locKey], entry);
        else
            if not ZONE_LOOKUP[key] then ZONE_LOOKUP[key] = {}; end
            table.insert(ZONE_LOOKUP[key], entry);
        end

        for _, set in ipairs(SETS) do
            local itemId = set.tiers[drop.tier][drop.slot];
            if itemId then
                if not ITEM_ZONES[itemId] then ITEM_ZONES[itemId] = {}; end
                local dup = false;
                for _, z in ipairs(ITEM_ZONES[itemId]) do if z == drop.zone then dup = true; break; end end
                if not dup then table.insert(ITEM_ZONES[itemId], drop.zone); end
            end
        end
    end
end
buildLookups();

------------------------------------------------------------
-- Storage Slip 01
------------------------------------------------------------
local SLIP_ID = 29312;
local SLIP_ITEMS = {
    16084, 14546, 14961, 15625, 15711, 16085, 14547, 14962, 15626, 15712,
    16086, 14548, 14963, 15627, 15713, 16087, 14549, 14964, 15628, 15714,
    16088, 14550, 14965, 15629, 15715, 16089, 14551, 14966, 15630, 15716,
    16090, 14552, 14967, 15631, 15717, 16091, 14553, 14968, 15632, 15718,
    16092, 14554, 14969, 15633, 15719, 16093, 14555, 14970, 15634, 15720,
    16094, 14556, 14971, 15635, 15721, 16095, 14557, 14972, 15636, 15722,
    16096, 14558, 14973, 15637, 15723, 16097, 14559, 14974, 15638, 15724,
    16098, 14560, 14975, 15639, 15725, 16099, 14561, 14976, 15640, 15726,
    16100, 14562, 14977, 15641, 15727, 16101, 14563, 14978, 15642, 15728,
    16102, 14564, 14979, 15643, 15729, 16103, 14565, 14980, 15644, 15730,
};

------------------------------------------------------------
-- Containers
------------------------------------------------------------
local CONTAINERS = {
    { id = 0,  name = 'Inventory' },  { id = 1,  name = 'Safe' },
    { id = 2,  name = 'Storage' },    { id = 4,  name = 'Locker' },
    { id = 5,  name = 'Satchel' },    { id = 6,  name = 'Sack' },
    { id = 7,  name = 'Case' },       { id = 8,  name = 'Wardrobe' },
    { id = 9,  name = 'Safe 2' },     { id = 10, name = 'Wardrobe 2' },
    { id = 11, name = 'Wardrobe 3' }, { id = 12, name = 'Wardrobe 4' },
    { id = 13, name = 'Wardrobe 5' }, { id = 14, name = 'Wardrobe 6' },
    { id = 15, name = 'Wardrobe 7' }, { id = 16, name = 'Wardrobe 8' },
};

------------------------------------------------------------
-- Ownership tracking
------------------------------------------------------------
local owned     = {};
local lastScan  = 0;
local SCAN_INTERVAL = 2;

local function bitPow(p) return 2 ^ (p - 1); end
local function hasBit(x, p) return x % (p + p) >= p; end

local function scanInventory()
    local now = os.clock();
    if now - lastScan < SCAN_INTERVAL then return; end
    lastScan = now;

    local newOwned = {};
    local inventory = AshitaCore:GetMemoryManager():GetInventory();

    local watchIds = {};
    local finalPiece = {};   -- omni: final item id -> { set, slot }
    local newTiers, newSeals, newCrests = {}, {}, {};
    local crestIds = {};
    for _, id in pairs(CREST_ITEM_IDS) do crestIds[id] = true; end
    for _, set in ipairs(SETS) do
        for _, slot in ipairs(SLOTS) do finalPiece[set.final[slot]] = { set = set, slot = slot }; end
    end
    for _, set in ipairs(SETS) do
        for t = 1, 3 do
            for _, slot in ipairs(SLOTS) do watchIds[set.tiers[t][slot]] = true; end
        end
        for _, slot in ipairs(SLOTS) do watchIds[set.final[slot]] = true; end
    end

    if inventory == nil then return; end
    for _, container in ipairs(CONTAINERS) do
        local max = inventory:GetContainerCountMax(container.id);
        if max ~= nil and max > 0 then
        for j = 0, max do
            local ok, item = pcall(function() return inventory:GetContainerItem(container.id, j); end);
            if not ok or item == nil then break; end
            if item.Id ~= 0 and item.Id ~= 65535 then
                if watchIds[item.Id] then newOwned[item.Id] = container.name; end
                -- omni: upgrade tier of finished pieces, and the upgrade materials you hold.
                local fp = finalPiece[item.Id];
                if fp then
                    local t = upgradeTier(UPGRADES[fp.set.name] and UPGRADES[fp.set.name][fp.slot], augmentNumbers(item.Extra));
                    if t > (newTiers[item.Id] or 0) then newTiers[item.Id] = t; end
                end
                if crestIds[item.Id] then
                    newCrests[item.Id] = (newCrests[item.Id] or 0) + (item.Count or 1);
                elseif not watchIds[item.Id] then
                    local res = getItemRes(item.Id);
                    local name = res and res.Name and res.Name[1];
                    if name and name:lower():find('artisan seal', 1, true) then
                        -- Names are short in game: "Artisan Seal: Hd", "Bd.", "Hn.", "Lg.", "Ft."
                        local part = (name:lower():match(':%s*(.-)%.?%s*$') or ''):gsub('%.', '');
                        local slot = SEAL_SLOT[part];
                        if slot then
                            newSeals[slot] = (newSeals[slot] or 0) + (item.Count or 1);
                        end
                    end
                end
                if item.Id == SLIP_ID then
                    local extra = item.Extra;
                    for idx, slipItemId in ipairs(SLIP_ITEMS) do
                        if watchIds[slipItemId] then
                            local byteIndex = math.floor((idx - 1) / 8) + 1;
                            local bitIndex  = (idx - 1) % 8 + 1;
                            local byte = struct.unpack('B', extra, byteIndex);
                            if byte < 0 then byte = byte + 256; end
                            if hasBit(byte, bitPow(bitIndex)) then
                                newOwned[slipItemId] = 'Storage Slip 01';
                            end
                        end
                    end
                end
            end
        end
        end -- max check
    end
    owned = newOwned;
    finalTiers, sealCounts, crestCounts = newTiers, newSeals, newCrests;
end

------------------------------------------------------------
-- Alert system
------------------------------------------------------------
local alertZones    = {};
local alertDisplay  = {};
local alertTime     = 0;
local ALERT_TIMEOUT = 300;
local alertItemIds  = {};
local alertCrests   = {};

local function clearAlerts()
    alertZones   = {};
    alertDisplay = {};
    alertItemIds = {};
    alertCrests  = {};
    alertTime    = 0;
end

local function processPopuloxMessage(msg)
    alertTime = os.clock();
    for zonePart in msg:gmatch('([^/]+)') do
        local trimmed = zonePart:gsub('^%s+',''):gsub('%s+$','');
        local locStr = trimmed:match('(%(?[Mm]ap%s*%d+%s*%)?%s*%([A-Z]%-[0-9]+%))') or trimmed:match('(%([A-Z]%-[0-9]+%))');
        local zoneName = trimmed:gsub('%s*%(?[Mm]ap%s*%d+%s*%)?%s*%([A-Z]%-[0-9]+%)',''):gsub('%s*%([A-Z]%-[0-9]+%)','');
        if #zoneName > 3 then
            local key = string.lower(zoneName);
            if not alertZones[trimmed] then
                alertZones[trimmed] = true;
                table.insert(alertDisplay, trimmed);
            end

            -- Use loc-specific lookup for zones with duplicates
            local drops = nil;
            if ZONE_HAS_LOC[key] and locStr then
                local locKey = key .. '|' .. string.lower(locStr);
                drops = ZONE_LOC_LOOKUP[locKey];
            end
            -- Fallback to general lookup
            if not drops then
                drops = ZONE_LOOKUP[key];
            end

            if drops then
                for _, drop in ipairs(drops) do
                    for _, set in ipairs(SETS) do
                        local itemId = set.tiers[drop.tier][drop.slot];
                        if itemId then alertItemIds[itemId] = true; end
                    end
                    alertCrests[drop.crest] = true;
                end
            end
        end
    end
end

local function hasAlertActive()
    return alertTime > 0;
end

------------------------------------------------------------
-- Layout constants
------------------------------------------------------------
local ICON_SIZE = 28;   -- omni change: smaller so all five sets fit with the Done column
local CELL_PAD  = 3;


-- Cell background colors (cached, rebuilt on theme change)
local cellColorCache = nil;
local cellColorVersion = -1;

local function getCellColors()
    local v = ui.getThemeVersion();
    if cellColorCache and cellColorVersion == v then return cellColorCache; end
    local base = ui.color('childBg');
    cellColorCache = {
        ownedBg    = { 0.16, 0.42, 0.16, 1.0  },   -- omni change: green = owned
        completeBg = { 0.18, 0.28, 0.48, 1.0  },
        cellBg     = { 0.45, 0.13, 0.13, 1.0  },   -- omni change: red = not owned
    };
    cellColorVersion = v;
    return cellColorCache;
end

------------------------------------------------------------
-- Render helpers
------------------------------------------------------------
local function renderTooltip(itemId, setData, tierIdx, slotKey)
    local res = getItemRes(itemId);
    local name = res and res.Name[1] or '???';

    ui.tooltip(function()
        ui.colored(name, 'white');

        local isComplete = slotKey and owned[setData.final[slotKey]] ~= nil;
        if isComplete then
            local finalRes = getItemRes(setData.final[slotKey]);
            local finalName = finalRes and finalRes.Name[1] or '???';
            imgui.TextColored({ 0.40, 0.60, 1.0, 1.0 }, string.format('  Completed: %s', finalName));
        elseif owned[itemId] then
            ui.colored(string.format('  Owned (%s)', tostring(owned[itemId])), 'ownedTick');
        end

        imgui.Separator();
        if tierIdx == 4 then
            -- omni addition: which upgrade the finished piece is on, and what the next one gives.
            local tier = finalTiers[itemId] or 0;
            local lines = UPGRADES[setData.name] and UPGRADES[setData.name][slotKey] or {};
            if owned[itemId] then
                imgui.TextColored({ 1.0, 0.82, 0.25, 1.0 }, string.format('Upgrade %d of 3', tier));
            end
            for t = 1, 3 do
                local col = (owned[itemId] and tier >= t) and { 0.45, 0.90, 0.45, 1.0 } or { 0.65, 0.65, 0.70, 1.0 };
                imgui.TextColored(col, string.format('Tier %d: %s  (%d seals, %d crests)', t, lines[t] or '?', UPGRADE_SEALS[t], UPGRADE_CRESTS[t]));
            end
            ui.colored('Upgraded by Irvina, Aht Urhgan Whitegate (K-11).', 'dimText');
            return;
        end
        ui.colored('Drop zones:', 'dimText');

        local zones = ITEM_ZONES[itemId];
        if zones then
            for _, z in ipairs(zones) do
                local key = string.lower(z);
                if alertZones[key] then
                    ui.colored('  >> ' .. z .. ' <<', 'alertGlow');
                else
                    imgui.Text('  ' .. z);
                end
            end
        else
            imgui.Text('  (unknown)');
        end

        if slotKey and tierIdx then
            local hnm = HNM_DROPS[tierIdx] and HNM_DROPS[tierIdx][slotKey];
            if hnm then
                imgui.Separator();
                ui.colored('Also drops from:', 'dimText');
                imgui.TextColored({ 0.90, 0.70, 0.50, 1.0 }, '  ' .. hnm);
            end
        end
    end);
end

local function renderCrestTooltip(setData)
    ui.tooltip(function()
        local crestId = CREST_ITEM_IDS[setData.crest];
        if crestId then renderIcon(crestId, 20); imgui.SameLine(0, 6); end
        imgui.TextColored(setData.color, setData.name .. ' (' .. setData.crest .. ' Crest)');
        ui.colored(setData.jobs, 'dimText');
        imgui.Separator();
        imgui.Text('Crest zones:');
        local zones = CREST_ZONES[setData.crest];
        if zones then
            for _, z in ipairs(zones) do
                local key = string.lower(z);
                if alertZones[key] then
                    ui.colored('  >> ' .. z .. ' <<', 'alertGlow');
                else
                    imgui.Text('  ' .. z);
                end
            end
        end
    end);
end

local function renderCell(itemId, setData, tierIdx, slotKey)
    local isOwned    = owned[itemId] ~= nil;
    local isAlert    = alertItemIds[itemId] ~= nil;
    local isComplete = owned[setData.final[slotKey]] ~= nil;

    local bgCol;
    local cc = getCellColors();
    -- omni change: green if you own it (or already own the finished piece), red if not.
    if isOwned or isComplete then bgCol = cc.ownedBg;
    else bgCol = cc.cellBg; end

    imgui.PushStyleColor(ImGuiCol_ChildBg, bgCol);
    local cellId = string.format('##vnm_cell_%d', itemId);
    imgui.BeginChild(cellId, { ICON_SIZE + CELL_PAD * 2, ICON_SIZE + CELL_PAD * 2 }, true, ImGuiWindowFlags_NoScrollbar);
    imgui.SetCursorPos({ CELL_PAD, CELL_PAD });
    if not renderIcon(itemId, ICON_SIZE) then
        imgui.PushStyleColor(ImGuiCol_Button, ui.color('notOwned'));
        imgui.Button('?', { ICON_SIZE, ICON_SIZE });
        imgui.PopStyleColor();
    end
    imgui.EndChild();
    imgui.PopStyleColor();

    -- omni addition: three stars along the bottom of a finished piece - gold for each upgrade it has.
    if tierIdx == 4 and isOwned then
        local rx, ry = imgui.GetItemRectMin();
        local rx2, ry2 = imgui.GetItemRectMax();
        local dl = imgui.GetWindowDrawList();
        local tier = finalTiers[itemId] or 0;
        local cx0 = (rx + rx2) / 2 - 9;
        local cy = ry2 - 5;
        for n = 1, 3 do
            local cx = cx0 + (n - 1) * 9;
            local col = (tier >= n) and { 1.0, 0.82, 0.25, 1.0 } or { 0.15, 0.15, 0.20, 0.85 };
            local r = 3.6;
            local pts = {};
            for k = 0, 9 do
                local a = -math.pi / 2 + k * math.pi / 5;
                local rr = (k % 2 == 0) and r or r * 0.45;
                pts[#pts + 1] = { cx + math.cos(a) * rr, cy + math.sin(a) * rr };
            end
            local ok = pcall(function()
                for k = 1, 10, 2 do
                    local p1, p2, p3 = pts[k], pts[(k % 10) + 1], pts[((k + 8) % 10) + 1];
                    dl:AddTriangleFilled(p1, p2, p3, imgui.GetColorU32(col));
                end
                dl:AddCircleFilled({ cx, cy }, r * 0.5, imgui.GetColorU32(col), 8);
            end);
            if not ok then dl:AddCircleFilled({ cx, cy }, 2.5, imgui.GetColorU32(col), 8); end
        end
    end

    if isAlert then
        local rx, ry = imgui.GetItemRectMin();
        local rx2, ry2 = imgui.GetItemRectMax();
        local drawList = imgui.GetWindowDrawList();
        local pulse = math.abs(math.sin(os.clock() * 3.0));
        local alertCol = { 1.0, 0.85 + pulse * 0.15, 0.20, 0.6 + pulse * 0.4 };
        drawList:AddRect({ rx, ry }, { rx2, ry2 }, imgui.GetColorU32(alertCol), 0, 0, 2);
    end

    if imgui.IsItemHovered() then
        renderTooltip(itemId, setData, tierIdx, slotKey);
    end
end

------------------------------------------------------------
-- Window state
------------------------------------------------------------
local isOpen = { false };

------------------------------------------------------------
-- Main render (floating window)
------------------------------------------------------------
local function renderWindow()
    if not isOpen[1] then return; end

    if alertTime > 0 and os.clock() - alertTime > ALERT_TIMEOUT then
        clearAlerts();
    end

    scanInventory();

    local totalOwned = 0;
    local totalItems = 0;
    for _, set in ipairs(SETS) do
        for t = 1, 4 do   -- omni change: the completed piece counts too
            for _, slot in ipairs(SLOTS) do
                totalItems = totalItems + 1;
                if owned[columnItem(set, t, slot)] then totalOwned = totalOwned + 1; end
            end
        end
    end

    local title;
    if alertTime > 0 and #alertDisplay > 0 then
        local zoneStr = table.concat(alertDisplay, ' / ');
        if #zoneStr > 60 then zoneStr = string.sub(zoneStr, 1, 57) .. '...'; end
        title = string.format('VNM [%d/%d] - %s###trove_vnm', totalOwned, totalItems, zoneStr);
    else
        title = string.format('VNM Armor [%d/%d]###trove_vnm', totalOwned, totalItems);
    end

    imgui.SetNextWindowSize({ 740, 300 }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSizeConstraints({ 700, 300 }, { 1000, 800 });

    local winColors = ui.pushWindowStyle();

    if imgui.Begin(title, isOpen, ImGuiWindowFlags_NoScrollbar) then
        local _bgPop = ui.renderBackground();
        local cellW  = ICON_SIZE + CELL_PAD * 2;
        local labelW = 56;
        local startX = labelW + 4;

        -- Clear button + set headers
        if alertTime > 0 then
            imgui.PushStyleColor(ImGuiCol_Button, { 0.35, 0.25, 0.10, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.50, 0.35, 0.15, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.25, 0.18, 0.08, 1.0 });
            ui.pushColor('alertGlow');
            if imgui.SmallButton('Clear') then clearAlerts(); end
            ui.popColor();
            imgui.PopStyleColor(3);
            imgui.SameLine(0, 0);
        end

        for si, set in ipairs(SETS) do
            local headerW = cellW * 4 + 10;
            local textW = imgui.CalcTextSize(set.name);
            local padX = (headerW - textW) / 2;
            if padX < 0 then padX = 0; end
            imgui.SetCursorPosX(startX + (si - 1) * (headerW + 8) + padX);
            imgui.TextColored(set.color, set.name);
            if imgui.IsItemHovered() then renderCrestTooltip(set); end
            imgui.SameLine(0, 0);
        end
        imgui.NewLine();
        imgui.Separator();

        -- Tier sub-headers
        imgui.SetCursorPosX(startX);
        for si = 1, #SETS do
            for ti = 1, 4 do
                if si > 1 or ti > 1 then imgui.SameLine(0, 0); end
                local x = startX + (si - 1) * (cellW * 4 + 10 + 8) + (ti - 1) * (cellW + 2);
                imgui.SetCursorPosX(x);
                ui.pushColor('accent');
                local tierTextW = imgui.CalcTextSize(TIER_LABELS[ti]);
                local tierPad = (cellW - tierTextW) / 2;
                if tierPad < 0 then tierPad = 0; end
                imgui.SetCursorPosX(x + tierPad);
                imgui.Text(TIER_LABELS[ti]);
                ui.popColor();
            end
        end

        -- omni addition: what is still needed to fully upgrade every finished piece.
        -- A piece not made yet counts as needing all three upgrades.
        local function stillNeeded(set, slotKey)
            local tier = owned[set.final[slotKey]] and (finalTiers[set.final[slotKey]] or 0) or 0;
            local seals, crests = 0, 0;
            for t = tier + 1, 3 do
                seals = seals + UPGRADE_SEALS[t];
                crests = crests + UPGRADE_CRESTS[t];
            end
            return seals, crests;
        end
        local GOOD, SHORT = { 0.45, 0.90, 0.45, 1.0 }, { 1.0, 0.45, 0.45, 1.0 };

        -- Grid
        for slotIdx, slotKey in ipairs(SLOTS) do
            ui.colored(SLOT_LABELS[slotIdx], 'slotText');
            -- omni: Artisan Seals for this slot, have / still needed, under the slot name.
            do
                local need = 0;
                for _, set in ipairs(SETS) do need = need + (stillNeeded(set, slotKey)); end
                local have = sealCounts[slotKey] or 0;
                local lx, ly = imgui.GetItemRectMin();
                local text = string.format('%d/%d', have, need);
                imgui.GetWindowDrawList():AddText({ lx, ly + 15 }, imgui.GetColorU32((have >= need) and GOOD or SHORT), text);
                if imgui.IsItemHovered() then
                    ui.tooltip(function()
                        ui.colored(string.format('Artisan Seal: %s', SLOT_LABELS[slotIdx]), 'white');
                        imgui.Text(string.format('You have %d, and %d are still needed to fully upgrade every %s piece.', have, need, SLOT_LABELS[slotIdx]:lower()));
                    end);
                end
            end
            for si, set in ipairs(SETS) do
                for ti = 1, 4 do
                    imgui.SameLine(0, 0);
                    local x = startX + (si - 1) * (cellW * 4 + 10 + 8) + (ti - 1) * (cellW + 2);
                    imgui.SetCursorPosX(x);
                    renderCell(columnItem(set, ti, slotKey), set, ti, slotKey);
                end
            end
        end

        -- omni addition: under each set, its crests - have / still needed for every upgrade.
        imgui.Spacing();
        local rowY = imgui.GetCursorPosY();
        imgui.SetCursorPos({ 4, rowY + 8 });
        ui.colored('Crests', 'slotText');
        if imgui.IsItemHovered() then
            ui.tooltip(function()
                imgui.Text('Under each set: its crests you have / still needed.');
                imgui.Text('Under each slot name: Artisan Seals you have / still needed.');
            end);
        end
        for si, set in ipairs(SETS) do
            local need = 0;
            for _, slotKey in ipairs(SLOTS) do
                local _, crests = stillNeeded(set, slotKey);
                need = need + crests;
            end
            local have = crestCounts[CREST_ITEM_IDS[set.crest]] or 0;
            local groupX = startX + (si - 1) * (cellW * 4 + 10 + 8);
            local groupW = cellW * 4 + 3 * 2;
            -- Two short centred lines: the crest name in the set's colour, then have / needed.
            local name = set.crest .. ' Crest';
            local count = string.format('%d / %d', have, need);
            imgui.SetCursorPos({ groupX + math.max(0, (groupW - imgui.CalcTextSize(name)) / 2), rowY });
            imgui.TextColored(set.color, name);
            imgui.SetCursorPos({ groupX + math.max(0, (groupW - imgui.CalcTextSize(count)) / 2), rowY + 16 });
            imgui.TextColored((have >= need) and GOOD or SHORT, count);
        end
        if _bgPop > 0 then imgui.PopStyleColor(_bgPop); end
    end
    imgui.End();
    ui.popWindowStyle(winColors);
end

------------------------------------------------------------
-- Plugin interface
------------------------------------------------------------
return {
    name        = 'VNM Armor',
    author      = 'Loxley',
    version     = '1.0',
    description = 'VNM armor collection tracker with zone alerts',

    -- Expose init for trove.lua to inject shared functions
    init = function(sharedRenderIcon, sharedGetItemRes, sharedUi)
        renderIcon = sharedRenderIcon;
        getItemRes = sharedGetItemRes;
        ui = sharedUi;
    end,

    -- Expose hasAlert for the burger button indicator
    hasAlert = hasAlertActive,

    commands = {
        vnm = function(state, args)
            isOpen[1] = not isOpen[1];
        end,
    },

    window = {
        category = 'Collections',
        isOpen  = isOpen,
        render  = renderWindow,
        -- Menu entry config for the hamburger popup
        label   = 'VNM Armor',
        icon    = 3045,
    },

    onPacketIn = function(e, state)
        -- Zone change: clear alerts
        if e.id == 0x0A or e.id == 0x0B then
            clearAlerts();
            return;
        end

        -- Chat monitoring for Populox and Active Venture Seals
        if e.id ~= 0x17 then return; end

        local chatType = struct.unpack('B', e.data_modified, 0x04 + 1);

        local sender = '';
        for i = 0x08, 0x16 do
            local b = struct.unpack('B', e.data_modified, i + 1);
            if b == 0 then break; end
            sender = sender .. string.char(b);
        end

        local msg = '';
        for i = 0x17, #e.data_modified - 1 do
            local b = struct.unpack('B', e.data_modified, i + 1);
            if b == 0 then break; end
            msg = msg .. string.char(b);
        end

        if sender == 'Populox' and chatType == 0x21 and msg:find('/') then
            processPopuloxMessage(msg);
            return;
        end

        local sealsMsg = msg:match('Active Venture Seals:%s*(.+)');
        if sealsMsg and sealsMsg:find('/') then
            processPopuloxMessage(sealsMsg);
        end
    end,
};
