--[[
* trove/plugins/profile.lua — Job levels, prestige, and crafting skills
*
* Shows all 22 jobs with levels, EXP bar for current job, prestige stars,
* and a separate Crafts tab with all 9 crafting skills.
*
* Uses the generic plugin data protocol (pluginId 1).
*
* Command: /trove profile
]]--

local imgui = require('imgui');

------------------------------------------------------------
-- Shared (injected via init)
------------------------------------------------------------
local renderIcon     = nil;
local getItemRes     = nil;
local ui             = nil;
local renderTooltip  = nil;
local renderFileIcon = nil;

------------------------------------------------------------
-- State
------------------------------------------------------------
local isOpen  = { false };
local wasOpen = false;
local loaded  = false;
local loading = false;

-- Parsed data from server
local data = {
    prestige = {},    -- [1..22] = tier (0-5)
    crafts   = {},    -- [1..9] = skill level (0-110 with decimal)
    isCW     = false,
    exp      = {},    -- [1..22] = current EXP per job
};

-- EXP to next level (static, from exp_base table, levels 1-75)
-- Index = current level, value = EXP needed to reach next level
local TNL = {
    [1]  =   500, [2]  =   750, [3]  =  1000, [4]  =  1250, [5]  =  1500,
    [6]  =  1750, [7]  =  2000, [8]  =  2200, [9]  =  2400, [10] =  2600,
    [11] =  2800, [12] =  3000, [13] =  3200, [14] =  3400, [15] =  3600,
    [16] =  3800, [17] =  4000, [18] =  4200, [19] =  4400, [20] =  4600,
    [21] =  4800, [22] =  5000, [23] =  5100, [24] =  5200, [25] =  5300,
    [26] =  5400, [27] =  5500, [28] =  5600, [29] =  5700, [30] =  5800,
    [31] =  5900, [32] =  6000, [33] =  6100, [34] =  6200, [35] =  6300,
    [36] =  6400, [37] =  6500, [38] =  6600, [39] =  6700, [40] =  6800,
    [41] =  6900, [42] =  7000, [43] =  7100, [44] =  7200, [45] =  7300,
    [46] =  7400, [47] =  7500, [48] =  7600, [49] =  7700, [50] =  7800,
    [51] =  8000, [52] =  9200, [53] = 10400, [54] = 11600, [55] = 12800,
    [56] = 14000, [57] = 15200, [58] = 16400, [59] = 17600, [60] = 18800,
    [61] = 20000, [62] = 21500, [63] = 23000, [64] = 24500, [65] = 26000,
    [66] = 27500, [67] = 29000, [68] = 30500, [69] = 32000, [70] = 34000,
    [71] = 36000, [72] = 38000, [73] = 40000, [74] = 42000,
};

------------------------------------------------------------
-- Protocol
------------------------------------------------------------
local PACKET_ID       = 0x1A4;
local C2S_PLUGIN_DATA = 17;
local PLUGIN_ID       = 1;

local requestTime = 0;

local function requestData()
    if loading then return; end
    loading = true;
    requestTime = os.clock();
    local p = {};
    for i = 1, 64 do p[i] = 0; end
    p[5] = C2S_PLUGIN_DATA;
    p[7] = PLUGIN_ID;
    AshitaCore:GetPacketManager():AddOutgoingPacket(PACKET_ID, p);
end

------------------------------------------------------------
-- Constants
------------------------------------------------------------
local JOB_ABBR = {
    [1]  = 'WAR', [2]  = 'MNK', [3]  = 'WHM', [4]  = 'BLM', [5]  = 'RDM',
    [6]  = 'THF', [7]  = 'PLD', [8]  = 'DRK', [9]  = 'BST', [10] = 'BRD',
    [11] = 'RNG', [12] = 'SAM', [13] = 'NIN', [14] = 'DRG', [15] = 'SMN',
    [16] = 'BLU', [17] = 'COR', [18] = 'PUP', [19] = 'DNC', [20] = 'SCH',
    [21] = 'GEO', [22] = 'RUN',
};

local JOB_ICON_ITEMS = {
    [1]  = 12511, [2]  = 12512, [3]  = 13855, [4]  = 13856,
    [5]  = 12513, [6]  = 12514, [7]  = 12515, [8]  = 12516,
    [9]  = 12517, [10] = 13857, [11] = 12518, [12] = 13868,
    [13] = 13869, [14] = 12519, [15] = 12520, [16] = 11465,
    [17] = 15266, [18] = 11471, [19] = 11478, [20] = 16140,
    [21] = 27786, [22] = 27787,
};

-- Prestige bonus descriptions per job (matches server enum)
-- Format string: {} is replaced by the tier value
local PRESTIGE_DESC = {
    [1]  = { 'STR+{}',                    { 1, 2, 4, 6, 8 } },
    [2]  = { 'HP +{}%',                   { 3, 5, 8, 10, 12 } },
    [3]  = { 'Waltz / Cure Pot. II +{}%', { 1, 2, 4, 6, 8 } },
    [4]  = { 'Magic Atk. Bonus +{}',      { 1, 2, 4, 6, 8 } },
    [5]  = { 'Fast Cast +{}%',            { 1, 2, 3, 4, 5 } },
    [6]  = { 'TH+{} / Evasion+{}',        { {0,0}, {1,5}, {2,8}, {1,10}, {2,12} } },
    [7]  = { 'Phys. dmg. taken II -{}%',  { 1, 2, 3, 4, 5 } },
    [8]  = { 'Attack+{}',                 { 5, 10, 15, 20, 25 } },
    [9]  = { 'Killer Effects +{}',        { 3, 5, 8, 10, 12 } },
    [10] = { 'Enh/Song Duration +{}%',    { 3, 5, 8, 10, 12 } },
    [11] = { 'Ranged Attack+{}',          { 5, 10, 15, 20, 25 } },
    [12] = { 'Store TP +{}',              { 1, 2, 3, 4, 5 } },
    [13] = { 'Ranged Accuracy+{}',        { 5, 8, 10, 12, 15 } },
    [14] = { 'Accuracy+{}',              { 5, 8, 10, 12, 15 } },
    [15] = { 'MP +{}%',                   { 3, 5, 8, 10, 12 } },
    [16] = { 'Magic Accuracy +{}',        { 5, 8, 10, 12, 15 } },
    [17] = { 'EXP to Gil +{}%',           { 10, 20, 30, 40, 50 } },
    [18] = { 'DEX+{}',                    { 1, 2, 4, 6, 8 } },
    [19] = { 'AGI+{}',                    { 1, 2, 4, 6, 8 } },
    [20] = { 'INT+{}',                    { 1, 2, 4, 6, 8 } },
    [21] = { 'Conserve MP +{}',           { 1, 2, 3, 4, 5 } },
    [22] = { 'Magic dmg. taken II -{}%',  { 1, 2, 3, 4, 5 } },
};

-- Jobs required per prestige tier
local TIER_REQS = { 3, 5, 10, 15, 22 };

local CRAFT_NAMES = {
    'Fishing', 'Woodworking', 'Smithing', 'Goldsmithing',
    'Clothcraft', 'Leathercraft', 'Bonecraft', 'Alchemy', 'Cooking',
};

-- Craft rank thresholds
local CRAFT_RANKS = {
    { 0,   'Amateur' },
    { 10,  'Recruit' },
    { 20,  'Initiate' },
    { 30,  'Novice' },
    { 40,  'Apprentice' },
    { 50,  'Journeyman' },
    { 60,  'Craftsman' },
    { 70,  'Artisan' },
    { 80,  'Adept' },
    { 90,  'Veteran' },
    { 100, 'Expert' },
    { 110, 'Master' },
};

------------------------------------------------------------
-- Helpers
------------------------------------------------------------
local function getPrestigeDesc(jobId, tier)
    local desc = PRESTIGE_DESC[jobId];
    if not desc or tier <= 0 then return nil; end
    local fmt = desc[1];
    local vals = desc[2];
    local v = vals[tier];
    if type(v) == 'table' then
        local idx = 0;
        return (string.gsub(fmt, '{}', function()
            idx = idx + 1;
            return tostring(v[idx] or 0);
        end));
    end
    return (string.gsub(fmt, '{}', tostring(v)));
end

local function getCraftRank(level)
    local rank = 'Amateur';
    for _, entry in ipairs(CRAFT_RANKS) do
        if level >= entry[1] then rank = entry[2]; end
    end
    return rank;
end

local function getPlayerData()
    local ok, result = pcall(function()
        local p = AshitaCore:GetMemoryManager():GetPlayer();
        local d = {
            mainJob     = p:GetMainJob(),
            mainLvl     = p:GetMainJobLevel(),
            subJob      = p:GetSubJob(),
            subLvl      = p:GetSubJobLevel(),
            currentExp  = 0,
            expNeeded   = 0,
            limitPoints = 0,
            meritPoints = 0,
            meritMax    = 0,
            isLimitMode = false,
            jobs        = {},
        };
        -- These may not exist in all Ashita builds
        pcall(function()
            d.currentExp  = p:GetExpCurrent();
            d.expNeeded   = p:GetExpNeeded();
            d.limitPoints = p:GetLimitPoints();
            d.meritPoints = p:GetMeritPoints();
            d.meritMax    = p:GetMeritPointsMax();
            d.isLimitMode = p:GetIsLimitModeEnabled() ~= 0;
        end);
        for id = 1, 22 do d.jobs[id] = p:GetJobLevel(id); end
        return d;
    end);
    return ok and result or nil;
end

------------------------------------------------------------
-- Render helpers
------------------------------------------------------------
local STAR_SIZE  = 12;
local ICON_SIZE  = 24;
local ROW_HEIGHT = 44;
local BAR_HEIGHT = 14;

local function renderExpBar(current, needed, width, barY, barColor, label)
    local pct = needed > 0 and math.min(current / needed, 1.0) or 1.0;
    local dl = imgui.GetWindowDrawList();
    local bx, by = imgui.GetCursorScreenPos();
    by = barY;

    -- Background
    dl:AddRectFilled({ bx, by }, { bx + width, by + BAR_HEIGHT },
        imgui.GetColorU32({ 0.06, 0.06, 0.09, 0.90 }), 3);

    -- Fill
    if pct > 0 then
        dl:AddRectFilled({ bx, by }, { bx + width * pct, by + BAR_HEIGHT },
            imgui.GetColorU32(barColor), 3);
    end

    -- Border
    dl:AddRect({ bx, by }, { bx + width, by + BAR_HEIGHT },
        imgui.GetColorU32({ 1, 1, 1, 0.06 }), 3);

    -- Text
    local fracStr = label or string.format('%d / %d', current, needed);
    local fracW = imgui.CalcTextSize(fracStr);
    local tx = bx + (width - fracW) / 2;
    dl:AddText({ tx + 1, by + 1 }, imgui.GetColorU32({ 0, 0, 0, 0.80 }), fracStr);
    dl:AddText({ tx, by },         imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.90 }), fracStr);
end

local function renderCraftBar(level, maxLevel, width)
    local pct = maxLevel > 0 and math.min(level / maxLevel, 1.0) or 0;
    local dl = imgui.GetWindowDrawList();
    local bx, by = imgui.GetCursorScreenPos();

    -- Background
    dl:AddRectFilled({ bx, by }, { bx + width, by + BAR_HEIGHT },
        imgui.GetColorU32({ 0.06, 0.06, 0.09, 0.90 }), 3);

    -- Fill (amber/gold for crafts)
    if pct > 0 then
        dl:AddRectFilled({ bx, by }, { bx + width * pct, by + BAR_HEIGHT },
            imgui.GetColorU32({ 0.65, 0.50, 0.15, 0.70 }), 3);
    end

    -- Border
    dl:AddRect({ bx, by }, { bx + width, by + BAR_HEIGHT },
        imgui.GetColorU32({ 1, 1, 1, 0.06 }), 3);

    -- Show decimal if fractional, integer if whole
    local fracStr;
    if level == math.floor(level) then
        fracStr = tostring(math.floor(level));
    else
        fracStr = string.format('%.1f', level);
    end
    local fracW = imgui.CalcTextSize(fracStr);
    local tx = bx + (width - fracW) / 2;
    dl:AddText({ tx + 1, by + 1 }, imgui.GetColorU32({ 0, 0, 0, 0.80 }), fracStr);
    dl:AddText({ tx, by },         imgui.GetColorU32({ 1.0, 1.0, 1.0, 0.90 }), fracStr);

    imgui.Dummy({ width, BAR_HEIGHT + 2 });
end

------------------------------------------------------------
-- Render: Jobs tab
------------------------------------------------------------
------------------------------------------------------------
-- omni addition: Artifact and Relic armour for each job (click a job to open it).
--   Artifact: plain piece -> +1 at Sagheera (Port Jeuno) -> augment tiers 1-3 at Vision (Port Jeuno)
--   Relic:    plain piece -> +1 at Sagheera (Port Jeuno) -> augment ranks 1-10 at Franz (Tavnazian Safehold)
-- Data in plugins/data/af_relic.lua (CatsEyeXI server scripts and CatsEyeXI wiki pages).
------------------------------------------------------------
local AF_DATA = nil;
local openJob = nil;          -- job id whose armour is showing
local afHeights = {};         -- job id -> height of its armour box
local bagCounts, bagExtra, bagAt = {}, {}, -100;

local AUG_RULES = nil;
local function afData()
    if AF_DATA == nil then
        local ok, d = pcall(require, 'plugins/data/af_relic');
        AF_DATA = (ok and type(d) == 'table') and d or { jobs = {} };
        local ok2, a = pcall(require, 'plugins/data/augment_values');
        AUG_RULES = (ok2 and type(a) == 'table') and a or {};
    end
    return AF_DATA;
end

-- Numbers shown on an item's augments (same reading as the VNM Armor page).
local function augNumbers(extra)
    local out = {};
    if extra == nil then return out; end
    pcall(function()
        local kind = struct.unpack('B', extra, 1);
        if kind ~= 2 and kind ~= 3 then return; end
        for slot = 0, 4 do
            local word = struct.unpack('B', extra, 3 + slot * 2) + struct.unpack('B', extra, 4 + slot * 2) * 256;
            local id = word % 2048;
            if id ~= 0 then
                local rule = AUG_RULES[id] or { 1, 1 };
                out[#out + 1] = math.abs(rule[1] + math.floor(word / 2048) * rule[2]);
            end
        end
    end);
    return out;
end

-- Which tier / rank (1..n) the augment numbers match best; 0 = no augments.
local function matchStage(texts, numbers)
    if #numbers == 0 or texts == nil then return 0; end
    local best, bestScore = 0, -1e9;
    for t, text in ipairs(texts) do
        local pool, size, hits = {}, 0, 0;
        for m in text:gmatch('[%+%-](%d+)') do local n = tonumber(m); pool[n] = (pool[n] or 0) + 1; size = size + 1; end
        for _, v in ipairs(numbers) do
            if (pool[v] or 0) > 0 then pool[v] = pool[v] - 1; hits = hits + 1; end
        end
        local score = hits * 10 - math.abs(size - #numbers);
        if score > bestScore then best, bestScore = t, score; end
    end
    return best;
end

-- Item counts in every bag, and the augment data of each piece (refreshed every 2 s).
local function scanBags()
    if os.clock() - bagAt < 2 then return; end
    bagAt = os.clock();
    local c, x = {}, {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for bag = 0, 16 do
            local max = inv:GetContainerCountMax(bag) or 0;
            for slot = 1, max do
                local e = inv:GetContainerItem(bag, slot);
                if e ~= nil and e.Id ~= nil and e.Id ~= 0 and e.Id ~= 65535 then
                    c[e.Id] = (c[e.Id] or 0) + (e.Count or 1);
                    if e.Extra ~= nil then
                        x[e.Id] = x[e.Id] or {};
                        x[e.Id][#x[e.Id] + 1] = e.Extra;
                    end
                end
            end
        end
    end);
    bagCounts, bagExtra = c, x;
end

-- Highest tier / rank among the copies you own of an item.
local function stageOf(id, texts)
    local best = 0;
    for _, extra in ipairs(bagExtra[id] or {}) do
        local s = matchStage(texts, augNumbers(extra));
        if s > best then best = s; end
    end
    return best;
end

------------------------------------------------------------
-- Materials stored with Vision. Type !vision in game: the server lists what you have
-- stored, and we read those lines and remember them (saved per character).
------------------------------------------------------------
local vision = { counts = {}, at = nil, loaded = nil, sea = nil, limbus = nil };   -- sea / limbus: when each list was last read
local visionList = nil;        -- which Vision list is being read right now
local visionUntil = -100;      -- reading Vision's list until this clock time
local visionNames = nil;       -- normalised item name -> id, for the items the armour data uses

local function normName(s) return (s or ''):lower():gsub('[^%w]', ''); end

local function myName()
    local n = nil;
    pcall(function () n = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
    if n == nil or n == '' then return nil; end
    return n;
end

local function visionPath(name)
    local dir = string.format('%s\\config\\addons\\omni\\', AshitaCore:GetInstallPath());
    for _, fn in ipairs({ 'create_dir', 'create_directory' }) do
        if ashita and ashita.fs and ashita.fs[fn] then pcall(ashita.fs[fn], dir); end
    end
    return dir .. 'vision_' .. name .. '.txt';
end

local function visionSave()
    local name = myName();
    if name == nil then return; end
    pcall(function ()
        local f = io.open(visionPath(name), 'w');
        if f == nil then return; end
        f:write('#at ', tostring(vision.at or os.time()), '\n');
        if vision.sea then f:write('#sea ', tostring(vision.sea), '\n'); end
        if vision.limbus then f:write('#limbus ', tostring(vision.limbus), '\n'); end
        for id, n in pairs(vision.counts) do f:write(id, ' ', n, '\n'); end
        f:close();
    end);
end

-- Load once per character (switching characters loads theirs).
local function visionLoad()
    local name = myName();
    if name == nil or vision.loaded == name then return; end
    vision.loaded, vision.counts, vision.at, vision.sea, vision.limbus = name, {}, nil, nil, nil;
    pcall(function ()
        local f = io.open(visionPath(name), 'r');
        if f == nil then return; end
        for line in f:lines() do
            local key, t = line:match('^#(%a+) (%d+)');
            if key == 'at' then vision.at = tonumber(t);
            elseif key == 'sea' then vision.sea = tonumber(t);
            elseif key == 'limbus' then vision.limbus = tonumber(t);
            else
                local id, n = line:match('^(%d+) (%d+)');
                if id then vision.counts[tonumber(id)] = tonumber(n); end
            end
        end
        f:close();
    end);
end

-- Every item id in the armour data, with its name, so Vision's wording can be matched.
local function buildVisionNames(D)
    visionNames = {};
    local ids = {};
    local add = function (id) if id then ids[id] = true; end end
    for _, pair in pairs(D.AF_HQ or {}) do for _, id in ipairs(pair) do add(id); end end
    for _, id in ipairs(D.AF_ORGANS or {}) do add(id); end
    add(D.AF_TISSUE); add(D.ABC);
    for _, set in pairs(D.jobs or {}) do
        for _, list in ipairs({ set.af or {}, set.relic or {} }) do
            for _, p in ipairs(list) do
                for _, m in ipairs(p.make or {}) do add(m[1]); end
            end
        end
    end
    local res = AshitaCore:GetResourceManager();
    for id in pairs(ids) do
        pcall(function ()
            local r = res:GetItemById(id);
            if r and r.Name and r.Name[1] and r.Name[1] ~= '' then visionNames[normName(r.Name[1])] = id; end
            if r and r.LogNameSingular and r.LogNameSingular[1] and r.LogNameSingular[1] ~= '' then
                visionNames[normName(r.LogNameSingular[1])] = visionNames[normName(r.LogNameSingular[1])] or id;
            end
        end);
    end
end

-- "H.Q. Hpemde Organ" in chat vs "H.Q. Hpemde Org." in the item list: exact match first,
-- otherwise the longest item name the chat name starts with.
local function visionId(chatName)
    local key = normName(chatName);
    if key == '' then return nil; end
    if visionNames[key] then return visionNames[key]; end
    local best, bestLen = nil, 0;
    for k, id in pairs(visionNames) do
        if #k >= 6 and #k > bestLen and key:sub(1, #k) == k then best, bestLen = id, #k; end
    end
    return best;
end

-- Which Vision list an item is on: organs / tissue / chips are 'sea', everything else 'limbus'.
local seaIds = nil;
local function visionKind(id)
    if seaIds == nil then
        seaIds = {};
        local D = afData();
        for _, pair in pairs(D.AF_HQ or {}) do for _, i in ipairs(pair) do seaIds[i] = true; end end
        for _, i in ipairs(D.AF_ORGANS or {}) do seaIds[i] = true; end
        if D.AF_TISSUE then seaIds[D.AF_TISSUE] = true; end
        if D.ABC then seaIds[D.ABC] = true; end
    end
    return seaIds[id] and 'sea' or 'limbus';
end
local visionFresh = false;     -- a new list header was just read: its old counts go on the first line

local function onVisionText(msg)
    if type(msg) ~= 'string' then return; end
    -- Drop colour codes and anything that is not plain text.
    -- (Japanese-style characters such as the bullet are two bytes; drop both.)
    local line = msg:gsub('[\30\31].', ''):gsub('[\129-\159\224-\239].', ' '):gsub('[\127-\255]', ' '):gsub('[%c]', ' ');
    if line:find('=== Vision:', 1, true) then
        visionUntil = os.clock() + 4;
        local low = line:lower();
        if low:find('sea', 1, true) or low:find('organ', 1, true) then visionList = 'sea';
        elseif low:find('limbus', 1, true) or low:find('af+1', 1, true) or low:find('apollyon', 1, true) or low:find('material', 1, true) then visionList = 'limbus';
        else visionList = nil; end
        visionFresh = (visionList ~= nil);
        bagAt = -100;           -- and look through your bags / Mog House again straight away
        return;
    end
    if os.clock() > visionUntil then return; end
    local found = false;
    for name, n in line:gmatch('(%a[%a%.\' %-]-) x(%d+)') do
        if visionNames == nil then buildVisionNames(afData()); end
        local id = visionId(name);
        if id == nil then id = visionId(name:match('^%S+%s+(.+)$')); end   -- stray leading word
        if id then
            if visionFresh then
                -- A new list: forget everything from the old one, so items you have used up
                -- (and Vision no longer lists) drop to 0 instead of keeping their old count.
                visionFresh = false;
                for old in pairs(vision.counts) do
                    if visionKind(old) == visionList then vision.counts[old] = nil; end
                end
            end
            vision.counts[id] = tonumber(n);
            found = true;
        end
    end
    if found then
        visionUntil = os.clock() + 2;
        vision.at = os.time();
        if visionList then vision[visionList] = vision.at; end
        visionSave();
    end
end

ashita.events.register('text_in', 'omni_profile_vision', function (e)
    pcall(function () visionLoad(); onVisionText(e.message); end);
end);

-- Ask Vision for your stored counts (the same as typing !vision).
local visionQueue = {};
local function visionAsk()
    bagAt = -100;   -- rescan bags and Mog House too
    visionQueue = { { at = os.clock(), cmd = '/say !vision sea organs' }, { at = os.clock() + 3, cmd = '/say !vision limbus mats' } };
end
ashita.events.register('d3d_present', 'omni_profile_vision_ask', function ()
    if #visionQueue > 0 and os.clock() >= visionQueue[1].at then
        local q = table.remove(visionQueue, 1);
        pcall(function () AshitaCore:GetChatManager():QueueCommand(1, q.cmd); end);
    end
end);

-- What you have: in your bags plus stored with Vision.
local function haveCount(id)
    return (bagCounts[id] or 0) + (vision.counts[id] or 0);
end

local nameCache = {};
local function itemName(id)
    if id == nil then return '?'; end
    if nameCache[id] then return nameCache[id]; end
    local n = 'Item #' .. id;
    pcall(function ()
        local r = AshitaCore:GetResourceManager():GetItemById(id);
        if r and r.Name and r.Name[1] and r.Name[1] ~= '' then n = r.Name[1]; end
    end);
    nameCache[id] = n;
    return n;
end

local GREEN_T = { 0.45, 0.88, 0.45, 1.0 };
local RED_T   = { 0.95, 0.45, 0.45, 1.0 };
local GOLD_T  = { 0.90, 0.80, 0.30, 1.0 };
local DIM_T   = { 0.62, 0.66, 0.80, 1.0 };
local BLUE_T  = { 0.55, 0.75, 1.00, 1.0 };

-- A wrapped line of "Item have/need" chips, green when you have enough.
local function needLine(x0, width, list)
    local lineW = 0;
    imgui.SetCursorPosX(x0);
    for i, n in ipairs(list) do
        local h = haveCount(n[1]);
        local text = string.format('%s %d/%d', itemName(n[1]), math.min(h, 9999), n[2]);
        local tw = imgui.CalcTextSize(text) + 12;
        if i > 1 then
            if lineW + tw > width then lineW = 0; imgui.SetCursorPosX(x0);
            else imgui.SameLine(0, 10); end
        end
        imgui.TextColored(h >= n[2] and GREEN_T or RED_T, text);
        lineW = lineW + tw;
    end
end

local function wrapped(x0, width, col, text)
    imgui.SetCursorPosX(x0);
    imgui.PushTextWrapPos(x0 + width);
    imgui.TextColored(col, text);
    imgui.PopTextWrapPos();
end

-- What Vision needs for AF tier n on this slot.
local function afTierNeeds(D, slot, n)
    local hq = D.AF_HQ[slot] or {};
    local list = {};
    for _, id in ipairs(hq) do list[#list + 1] = { id, n }; end
    list[#list + 1] = { D.ABC, 10 * n };
    for _, id in ipairs(D.AF_ORGANS) do list[#list + 1] = { id, n }; end
    list[#list + 1] = { D.AF_TISSUE, 2 * n };
    return list;
end

-- Where a piece is up to: owns the augmentable piece?, owns the plain piece?, tier/rank reached.
local function pieceState(p, kind)
    local own = function (id) return id ~= nil and (bagCounts[id] or 0) > 0; end
    local texts = (kind == 'af') and p.tiers or p.ranks;
    local hasAug  = own(p.aug) or (p.plus2 ~= nil and own(p.plus2));
    local hasBase = own(p.base) or (p.base2 ~= nil and own(p.base2));
    local stage = 0;
    if hasAug then
        stage = stageOf(p.aug, texts);
        if p.plus2 then stage = math.max(stage, stageOf(p.plus2, texts)); end
    end
    return hasAug, hasBase, stage;
end

-- Everything still needed to cap every piece of a job (from where each piece is now).
local function capTotals(D, set)
    local function bucket()
        local b = { items = {}, order = {} };
        b.add = function (id, n)
            if id == nil or n == nil or n <= 0 then return; end
            if b.items[id] == nil then b.items[id] = 0; b.order[#b.order + 1] = id; end
            b.items[id] = b.items[id] + n;
        end
        b.list = function ()
            local out = {};
            for _, id in ipairs(b.order) do out[#out + 1] = { id, b.items[id] }; end
            return out;
        end
        return b;
    end
    local make, vision = bucket(), bucket();
    local rp, forgotten, cur, missing = 0, 0, 0, 0;
    for _, p in ipairs(set.af or {}) do
        local hasAug, hasBase, stage = pieceState(p, 'af');
        if not hasAug and not hasBase then missing = missing + 1; end
        if not hasAug and p.make then for _, m in ipairs(p.make) do make.add(m[1], m[2]); end end
        for n = stage + 1, 3 do
            for _, m in ipairs(afTierNeeds(D, p.slot, n)) do vision.add(m[1], m[2]); end
        end
    end
    for _, p in ipairs(set.relic or {}) do
        local hasAug, hasBase, stage = pieceState(p, 'relic');
        if not hasAug and not hasBase then missing = missing + 1; end
        if not hasAug and p.make then for _, m in ipairs(p.make) do make.add(m[1], m[2]); end end
        if p.ranks then
            for n = stage + 1, 10 do
                local c = D.RELIC_RANK_COST[n];
                if c then rp, forgotten, cur = rp + c[1], forgotten + c[2], cur + c[3]; end
            end
        end
    end
    return make.list(), vision.list(), rp, forgotten, cur, missing;
end

-- A tidy list in two columns: item name on the left, have / need on the right.
-- Rows still short are red with how many more; finished rows are green with a tick.
local function capList(x0, width, rows)
    local colW = math.floor((width - 20) / 2);
    local numW = 110;
    for i, r in ipairs(rows) do
        local col = (i - 1) % 2;
        local cx = x0 + col * (colW + 20);
        if col == 1 then imgui.SameLine(cx); else imgui.SetCursorPosX(cx); end
        local done = r.have ~= nil and r.have >= r.need;
        imgui.TextColored(done and GREEN_T or { 0.90, 0.90, 0.90, 1.0 }, r.name);
        imgui.SameLine(cx + colW - numW);
        if r.have == nil then
            imgui.TextColored(BLUE_T, string.format('%d needed', r.need));
        elseif done then
            imgui.TextColored(GREEN_T, string.format('%d / %d  done', math.min(r.have, 99999), r.need));
        else
            imgui.TextColored(RED_T, string.format('%d / %d', math.min(r.have, 99999), r.need));
        end
        if r.stored ~= nil and imgui.IsItemHovered() then
            imgui.SetTooltip(string.format('%d in your bags\n%d stored with Vision', r.bag or 0, r.stored));
        end
    end
end

local function capHeader(x0, title, note)
    imgui.Dummy({ 1, 3 });
    imgui.SetCursorPosX(x0);
    imgui.TextColored(BLUE_T, title);
    if note then imgui.SameLine(0, 8); imgui.TextColored(DIM_T, note); end
end

local function itemRows(list)
    local rows = {};
    for _, n in ipairs(list) do
        rows[#rows + 1] = { name = itemName(n[1]), have = haveCount(n[1]), bag = bagCounts[n[1]] or 0, stored = vision.counts[n[1]] or 0, need = n[2] };
    end
    return rows;
end

-- The counter along the bottom of a job's drop-down.
local function renderCapTotals(D, set, abbr, width)
    visionLoad();
    local make, vupg, rp, forgotten, cur, missing = capTotals(D, set);
    imgui.Dummy({ 1, 4 });
    imgui.PushStyleColor(ImGuiCol_Separator, { 0.79, 0.69, 0.42, 0.35 });
    imgui.Separator();
    imgui.PopStyleColor(1);
    local x0 = imgui.GetCursorPosX();
    imgui.TextColored(GOLD_T, 'To cap every ' .. abbr .. ' piece');
    imgui.SameLine(0, 10);
    imgui.TextColored(DIM_T, '+1 made, Artifact tier 3, Relic rank 10');
    if #make == 0 and #vupg == 0 and rp == 0 then
        imgui.TextColored(GREEN_T, 'Everything is capped.');
        return;
    end
    if #make > 0 then
        capHeader(x0, 'Making the +1 pieces');
        capList(x0, width, itemRows(make));
    end
    if #vupg > 0 then
        capHeader(x0, 'Artifact upgrades', 'Vision, Port Jeuno');
        capList(x0, width, itemRows(vupg));
    end
    imgui.Dummy({ 1, 3 });
    imgui.SetCursorPosX(x0);
    if imgui.SmallButton('Update from Vision##vis_ask') then visionAsk(); end
    if vision.at then
        wrapped(x0, width, DIM_T, 'Counts include what you have stored with Vision (read ' .. os.date('%d %b %H:%M', vision.at) .. '). Press Update from Vision to refresh. Hover a count for the split.');
    else
        wrapped(x0, width, GOLD_T, 'Press Update from Vision (or type !vision sea organs and !vision limbus mats) to add what Vision holds to these counts.');
    end
    if rp > 0 then
        capHeader(x0, 'Relic upgrades', 'Franz, Tavnazian Safehold - Freya keeps these, so only the totals');
        capList(x0, width, {
            { name = 'Rank Points', need = rp },
            { name = 'Forgotten items', need = forgotten },
            { name = 'Currency', need = cur },
        });
    end
    if missing > 0 then
        imgui.Dummy({ 1, 3 });
        imgui.SetCursorPosX(x0);
        imgui.TextColored(RED_T, string.format('You still need to get %d piece%s first.', missing, missing == 1 and '' or 's'));
    end
end

-- One piece: picture and name, where it's up to, and what the next step needs.
local function renderPiece(D, p, kind, x0, width)
    local own = function (id) return id ~= nil and (bagCounts[id] or 0) > 0; end
    local texts = (kind == 'af') and p.tiers or p.ranks;
    local maxStage = (kind == 'af') and 3 or 10;
    local hasAug, hasBase, stage = pieceState(p, kind);

    local showId = hasAug and (own(p.aug) and p.aug or p.plus2) or (hasBase and (own(p.base) and p.base or p.base2)) or (p.base or p.aug);
    local label = showId and itemName(showId) or (p.name or '?');

    imgui.SetCursorPosX(x0);
    if not (showId and renderIcon(showId, 20)) then imgui.Dummy({ 20, 20 }); end
    imgui.SameLine(0, 6);
    imgui.SetCursorPosY(imgui.GetCursorPosY() + 2);
    imgui.TextColored(hasAug and GOLD_T or (hasBase and GREEN_T or RED_T), label);
    local hovered = imgui.IsItemHovered();
    imgui.SameLine(0, 8);
    local word = (kind == 'af') and 'Tier' or 'Rank';
    if hasAug then
        imgui.TextColored(stage >= maxStage and GOLD_T or BLUE_T, string.format('%s %d/%d', word, stage, maxStage));
    elseif hasBase then
        imgui.TextColored(GREEN_T, p.make and 'needs +1' or 'owned');
    else
        imgui.TextColored(RED_T, 'not owned');
    end

    -- Tooltip: every tier / rank, yours highlighted.
    if hovered and texts then
        imgui.BeginTooltip();
        imgui.TextColored(GOLD_T, label .. ((kind == 'af') and '  -  Vision, Port Jeuno' or '  -  Franz, Tavnazian Safehold'));
        if p.summary then imgui.TextColored(DIM_T, 'At rank 10: ' .. p.summary); end
        for i, t in ipairs(texts) do
            local col = (i == stage) and GOLD_T or ((i < stage) and DIM_T or { 0.9, 0.9, 0.9, 1 });
            imgui.TextColored(col, string.format('%s %d: %s%s', word, i, t, (i == stage) and '   < yours' or ''));
        end
        imgui.EndTooltip();
    end

    local ix = x0 + 26;
    local iw = width - 26;
    if hasAug then
        if stage > 0 and texts[stage] then wrapped(ix, iw, DIM_T, texts[stage]); end
        if stage < maxStage then
            local n = stage + 1;
            if kind == 'af' then
                wrapped(ix, iw, BLUE_T, string.format('Tier %d: %s', n, texts[n] or ''));
                needLine(ix, iw, afTierNeeds(D, p.slot, n));
            else
                local c = D.RELIC_RANK_COST[n];
                wrapped(ix, iw, BLUE_T, string.format('Rank %d: %s', n, texts[n] or ''));
                if c then wrapped(ix, iw, DIM_T, string.format('Needs %d RP, %d Forgotten items, %d currency (kept by Freya)', c[1], c[2], c[3])); end
            end
        end
    elseif hasBase and p.make then
        wrapped(ix, iw, BLUE_T, 'Make +1 at Sagheera (Port Jeuno):');
        needLine(ix, iw, p.make);
    end
    imgui.Dummy({ 1, 3 });
end

local function renderSet(D, title, list, kind, width)
    imgui.TextColored(GOLD_T, title);
    local done = 0;
    for _, p in ipairs(list) do
        local hasAug = (bagCounts[p.aug or -1] or 0) > 0 or (p.plus2 and (bagCounts[p.plus2] or 0) > 0);
        if hasAug then done = done + 1; end
    end
    imgui.SameLine(0, 10);
    imgui.TextColored(DIM_T, string.format('%d / %d %s', done, #list, (kind == 'af') and 'at +1' or 'at +1'));
    imgui.Separator();
    local x0 = imgui.GetCursorPosX();
    for _, p in ipairs(list) do renderPiece(D, p, kind, x0, width); end
end

-- The drop-down under a job: Artifact on the left, Relic on the right.
local function renderJobArmour(id, fullW)
    local abbr = JOB_ABBR[id];
    local D = afData();
    local set = D.jobs and D.jobs[abbr];
    imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.10, 0.12, 0.20, 0.85 });
    local h = afHeights[id] or 400;
    imgui.BeginChild('##af_' .. id, { fullW, set and h or 40 }, true, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse));
    if set == nil then
        imgui.TextColored(DIM_T, 'No Artifact or Relic data for ' .. abbr .. '.');
    else
        scanBags();
        local half = math.floor((fullW - 34) / 2);
        imgui.BeginGroup();
        renderSet(D, 'Artifact armour', set.af, 'af', half);
        imgui.EndGroup();
        imgui.SameLine(half + 24);
        imgui.BeginGroup();
        renderSet(D, 'Relic armour', set.relic, 'relic', half);
        imgui.EndGroup();
        renderCapTotals(D, set, abbr, fullW - 24);
        afHeights[id] = math.floor(imgui.GetCursorPosY() + 10);
    end
    imgui.EndChild();
    imgui.PopStyleColor(1);
    if set ~= nil then
        if imgui.SmallButton('Hide armour##af_hide_' .. id) then openJob = nil; end
        imgui.SameLine(0, 10);
        imgui.PushTextWrapPos(fullW);
        imgui.TextColored(DIM_T, 'Hover a piece for every tier / rank.');
        imgui.PopTextWrapPos();
    end
end

-- Reminder at the top of Jobs until both Vision lists have been read.
local function visionStatus(x, label, at)
    imgui.SameLine(x);
    if at then
        imgui.TextColored(GREEN_T, 'Done');
    else
        imgui.TextColored(RED_T, 'To do');
    end
    imgui.SameLine(x + 46);
    imgui.TextColored(at and DIM_T or { 0.95, 0.92, 0.85, 1.0 }, label);
end

local function renderVisionWarning()
    visionLoad();
    local avail = imgui.GetContentRegionAvail();
    if vision.sea == nil or vision.limbus == nil then
        imgui.PushStyleColor(ImGuiCol_ChildBg, { 0.24, 0.17, 0.06, 0.90 });
        imgui.PushStyleColor(ImGuiCol_Border, { 0.90, 0.80, 0.30, 0.60 });
        imgui.BeginChild('##vis_warn', { avail, 58 }, true, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse));
        imgui.TextColored(GOLD_T, 'Read your Vision storage');
        imgui.SameLine(0, 10);
        imgui.TextColored(DIM_T, 'so the armour upgrade counts are right');
        imgui.SameLine(avail - 130);
        if imgui.SmallButton('Update now##vis_warn_ask') then visionAsk(); end
        imgui.Dummy({ 0, 0 });
        visionStatus(8, '!vision sea organs', vision.sea);
        visionStatus(math.floor(avail / 2), '!vision limbus mats', vision.limbus);
        imgui.EndChild();
        imgui.PopStyleColor(2);
    else
        local oldest = math.min(vision.sea, vision.limbus);
        imgui.TextColored(DIM_T, 'Vision storage read ' .. os.date('%d %b, %H:%M', oldest));
        imgui.SameLine(0, 10);
        if imgui.SmallButton('Update##vis_ok_ask') then visionAsk(); end
    end
end

local function renderJobsTab(player)
    renderVisionWarning();
    local mainJob = player.mainJob;
    local mainLvl = player.mainLvl;
    local avail = imgui.GetContentRegionAvail();
    local colW = math.floor((avail - 12) / 2);

    -- Count 75s for tier requirements display
    local count75 = 0;
    for id = 1, 22 do
        if player.jobs[id] >= 75 then count75 = count75 + 1; end
    end

    -- Merit/Limit row (from Ashita memory, always available)
    imgui.Spacing();
    local meritStr = string.format('Merits: %d / %d', player.meritPoints, player.meritMax);
    local limitStr = string.format('Limit Points: %d / 10000', player.limitPoints);
    imgui.TextColored(ui.color('dimmed'), meritStr);
    imgui.SameLine(0, 20);
    imgui.TextColored(ui.color('dimmed'), limitStr);
    imgui.SameLine(0, 20);
    imgui.TextColored(ui.color('dimmed'), string.format('Jobs at 75: %d/22', count75));
    imgui.Spacing();
    imgui.Separator();
    imgui.Spacing();

    -- 2-column job grid
    for id = 1, 22 do
        local level = player.jobs[id];
        local abbr = JOB_ABBR[id];
        local tier = (loaded and data.prestige[id]) or 0;
        local isMain = (id == mainJob);
        local isMax = (level >= 75);

        -- Column layout
        if (id - 1) % 2 == 1 then
            imgui.SameLine(colW + 16);
        end

        -- Job row child
        local childId = string.format('##job_%d', id);
        imgui.BeginChild(childId, { colW, ROW_HEIGHT + 4 }, false);

        -- Job icon
        local iconId = JOB_ICON_ITEMS[id];
        if iconId then renderIcon(iconId, ICON_SIZE); end
        imgui.SameLine(0, 6);

        -- Job name + level
        local levelStr = string.format('%s %d', abbr, level);
        local nameColor;
        if isMain then
            nameColor = { 0.90, 0.90, 0.95, 1.0 };
        elseif isMax or tier > 0 then
            nameColor = { 0.90, 0.80, 0.30, 1.0 }; -- gold
        elseif level >= 37 then
            nameColor = { 0.40, 0.60, 0.90, 1.0 }; -- blue
        elseif level > 0 then
            nameColor = { 0.40, 0.80, 0.40, 1.0 }; -- green
        else
            nameColor = { 0.40, 0.40, 0.45, 0.60 }; -- gray
        end

        imgui.SetCursorPosY(imgui.GetCursorPosY() + 2);
        imgui.TextColored(nameColor, levelStr);

        -- Prestige stars
        if tier > 0 then
            imgui.SameLine(0, 4);
            for s = 1, tier do
                renderFileIcon('star.png', STAR_SIZE);
                if s < tier then imgui.SameLine(0, 1); end
            end
        end

        -- omni: "Armor" button at the right of the job name: opens / closes the armour list.
        do
            local isOpenJob = (openJob == id);
            local lbl = isOpenJob and 'Armor  ^' or 'Armor  v';
            local bw = imgui.CalcTextSize('Armor  v') + 14;
            local y = imgui.GetCursorPosY();
            imgui.SameLine(colW - bw - 6);
            imgui.SetCursorPosY(2);
            if isOpenJob then
                imgui.PushStyleColor(ImGuiCol_Button, { 0.65, 0.55, 0.15, 0.9 });
                imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 });
            end
            if imgui.SmallButton(lbl .. '##armor_' .. id) then
                if isOpenJob then openJob = nil; else openJob = id; end
            end
            if isOpenJob then imgui.PopStyleColor(2); end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(isOpenJob and 'Hide the Artifact / Relic armour' or 'Show Artifact / Relic armour for ' .. abbr);
            end
            imgui.SetCursorPosY(y);
        end

        -- EXP bar (all leveled jobs, full gold bar at 75)
        if loaded and level > 0 then
            local barX = ICON_SIZE + 6;
            imgui.SetCursorPosX(barX);
            local barW = colW - barX - 4;
            if barW > 40 then
                local sx, sy = imgui.GetCursorScreenPos();
                -- Color matches the job name color scheme
                local barFill;
                if isMax or tier > 0 then
                    barFill = { 0.65, 0.55, 0.15, 0.70 }; -- gold
                elseif level >= 37 then
                    barFill = { 0.20, 0.40, 0.70, 0.70 }; -- blue
                else
                    barFill = { 0.20, 0.55, 0.25, 0.70 }; -- green
                end

                if level >= 75 then
                    local jobExp = data.exp[id] or 0;
                    renderExpBar(jobExp, jobExp, barW, sy, barFill,
                        string.format('%d / %d', jobExp, jobExp));
                else
                    local jobExp = data.exp[id] or 0;
                    local tnl = TNL[level] or 0;
                    if tnl > 0 then
                        renderExpBar(jobExp, tnl, barW, sy, barFill);
                    end
                end
                imgui.Dummy({ barW, BAR_HEIGHT });
            end
        end

        imgui.EndChild();
        -- omni: gold outline on the job whose armour is open.
        if openJob == id then
            local dl = imgui.GetWindowDrawList();
            local x1, y1 = imgui.GetItemRectMin();
            local x2, y2 = imgui.GetItemRectMax();
            dl:AddRect({ x1, y1 }, { x2, y2 }, imgui.GetColorU32({ 0.90, 0.80, 0.30, 0.9 }), 3, 0, 1.5);
        end

        -- Tooltip for the job row
        if imgui.IsItemHovered() then
            imgui.BeginTooltip();
            imgui.TextColored(ui.color('header'), string.format('%s  Lv%d', abbr, level));
            if isMain then
                local subAbbr = JOB_ABBR[player.subJob] or '---';
                imgui.TextColored(ui.color('dimmed'),
                    string.format('Sub: %s Lv%d', subAbbr, player.subLvl));
            end
            if loaded and level > 0 then
                if level < 75 then
                    local jobExp = data.exp[id] or 0;
                    local tnl = TNL[level] or 0;
                    imgui.TextColored(ui.color('dimmed'),
                        string.format('EXP: %d / %d', jobExp, tnl));
                else
                    imgui.TextColored({ 0.90, 0.80, 0.30, 1.0 }, 'Max Level');
                end
            end
            if tier > 0 then
                imgui.Separator();
                imgui.TextColored({ 0.90, 0.80, 0.30, 1.0 },
                    string.format('Prestige %d', tier));
                local desc = getPrestigeDesc(id, tier);
                if desc then
                    imgui.TextColored({ 0.70, 0.85, 0.70, 1.0 }, desc);
                end
                -- Show next tier requirement
                if tier < 5 then
                    local nextReq = TIER_REQS[tier + 1];
                    local canAdvance = count75 >= nextReq;
                    local reqColor = canAdvance
                        and { 0.40, 0.80, 0.40, 0.80 }
                        or  { 0.80, 0.40, 0.40, 0.80 };
                    imgui.TextColored(reqColor,
                        string.format('Next tier: %d/22 jobs at 75', nextReq));
                end
            elseif level >= 75 then
                imgui.Separator();
                local nextReq = TIER_REQS[1];
                local canAdvance = count75 >= nextReq;
                local reqColor = canAdvance
                    and { 0.40, 0.80, 0.40, 0.80 }
                    or  { 0.80, 0.40, 0.40, 0.80 };
                imgui.TextColored(ui.color('dimmed'), 'No prestige yet');
                imgui.TextColored(reqColor,
                    string.format('Requires: %d/22 jobs at 75', nextReq));
            end
            imgui.EndTooltip();
        end

        -- After each pair of jobs (or the last one), the open job's armour list, full width.
        if (id % 2 == 0 or id == 22) and openJob ~= nil and (openJob == id or openJob == id - 1) then
            renderJobArmour(openJob, colW * 2 + 12);
            imgui.Spacing();
        end
    end
end

------------------------------------------------------------
-- Render: Crafts tab
------------------------------------------------------------
local function renderCraftsTab()
    local avail = imgui.GetContentRegionAvail();

    if not loaded then
        imgui.TextColored(ui.color('dimmed'), 'Loading...');
        return;
    end

    imgui.Spacing();

    for i, name in ipairs(CRAFT_NAMES) do
        local level = data.crafts[i] or 0;
        local rank = getCraftRank(level);

        -- Craft row
        local childId = string.format('##craft_%d', i);
        imgui.BeginChild(childId, { avail, 36 }, false);

        -- Name + rank
        local nameColor = level > 0
            and { 0.85, 0.75, 0.55, 1.0 }
            or  { 0.40, 0.40, 0.45, 0.60 };
        imgui.TextColored(nameColor, string.format('%-14s', name));
        imgui.SameLine(0, 8);

        -- Rank label
        imgui.TextColored(ui.color('dimmed'), string.format('%-12s', rank));
        imgui.SameLine(0, 8);

        -- Progress bar
        local barW = avail - imgui.GetCursorPosX() - 8;
        if barW > 40 then
            renderCraftBar(level, 110, barW);
        end

        imgui.EndChild();
    end
end

------------------------------------------------------------
-- omni addition: Combat Skills, Magic Skills and Weapon Skills tabs
------------------------------------------------------------
local COMBAT_SKILLS = {
    { 1, 'Hand-to-Hand' }, { 2, 'Dagger' }, { 3, 'Sword' }, { 4, 'Great Sword' }, { 5, 'Axe' },
    { 6, 'Great Axe' }, { 7, 'Scythe' }, { 8, 'Polearm' }, { 9, 'Katana' }, { 10, 'Great Katana' },
    { 11, 'Club' }, { 12, 'Staff' }, { 25, 'Archery' }, { 26, 'Marksmanship' }, { 27, 'Throwing' },
    { 28, 'Guard' }, { 29, 'Evasion' }, { 30, 'Shield' }, { 31, 'Parrying' },
};
local MAGIC_SKILLS = {
    { 32, 'Divine' }, { 33, 'Healing' }, { 34, 'Enhancing' }, { 35, 'Enfeebling' }, { 36, 'Elemental' },
    { 37, 'Dark' }, { 38, 'Summoning' }, { 39, 'Ninjutsu' }, { 40, 'Singing' }, { 41, 'String' },
    { 42, 'Wind' }, { 43, 'Blue Magic' }, { 44, 'Geomancy' }, { 45, 'Handbell' },
};
local SKILL_NAME = {};
for _, s in ipairs(COMBAT_SKILLS) do SKILL_NAME[s[1]] = s[2]; end
for _, s in ipairs(MAGIC_SKILLS) do SKILL_NAME[s[1]] = s[2]; end

local WS_DATA = {};
do
    local ok, d = pcall(require, 'plugins/data/ws_data');
    if ok and type(d) == 'table' then WS_DATA = d; end
end

local JOB_ABBR = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM',
    'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };

-- Your skill level (for your current main job) and whether it is capped.
local function skillOf(id)
    local value, capped = 0, false;
    pcall(function()
        local sk = AshitaCore:GetMemoryManager():GetPlayer():GetCombatSkill(id);
        value = sk:GetSkill() or 0;
        capped = sk:IsCapped() == true;
    end);
    return value, capped;
end

local function renderSkillList(list)
    imgui.Spacing();
    local main = AshitaCore:GetMemoryManager():GetPlayer():GetMainJob();
    imgui.TextColored(ui.color('dimmed'), string.format('Skill levels for your current job (%s). Green = capped for your level.', JOB_ABBR[main] or '?'));
    imgui.Spacing();
    local half = imgui.GetContentRegionAvail() / 2;
    for i, s in ipairs(list) do
        local value, capped = skillOf(s[1]);
        local x = ((i - 1) % 2 == 0) and 0 or half;
        if (i - 1) % 2 == 1 then imgui.SameLine(x + 8); else imgui.SetCursorPosX(8); end
        local col = (value == 0) and { 0.40, 0.40, 0.45, 0.60 } or (capped and { 0.45, 0.90, 0.45, 1.0 } or { 0.85, 0.75, 0.55, 1.0 });
        imgui.TextColored(col, s[2]);
        imgui.SameLine(x + 150);
        imgui.TextColored(col, (value == 0) and '-' or (tostring(value) .. (capped and '  capped' or '')));
    end
end

-- Weapon skills, grouped by weapon type: green if you can use it now, red if not.
local extraTabs = {};   -- { name, render } pages added by omni
local craftsExtra = nil; -- omni: the Craftbook page under Crafts
local craftsWide = false; -- true on frames the Craftbook is showing (omni widens the panel)
local wsShowAll = { false };   -- also show weapon types with nothing you can use
local function renderWeaponSkillsTab()
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local main = player:GetMainJob();
    local job = JOB_ABBR[main] or '';
    imgui.Spacing();
    imgui.PushTextWrapPos(0);
    imgui.TextColored(ui.color('dimmed'), string.format('Green = you can use it now as %s (job, skill, or learned by quest). Red = not yet. Hover a name to see how to get it.', job));
    imgui.PopTextWrapPos();
    imgui.Spacing();

    local groups, order = {}, {};
    for _, ws in ipairs(WS_DATA) do
        if not groups[ws.skill] then groups[ws.skill] = {}; order[#order + 1] = ws.skill; end
        table.insert(groups[ws.skill], ws);
    end
    table.sort(order);

    if imgui.Checkbox('Show weapon types I cannot use##ws_all', wsShowAll) then end
    local hidden = 0;

    for _, skillId in ipairs(order) do
        local list = groups[skillId];
        local value = skillOf(skillId);
        local have = 0;
        local states = {};
        for i, ws in ipairs(list) do
            local ok, known = pcall(function() return player:HasWeaponSkill(ws.id); end);
            local jobOk = (' ' .. ws.jobs .. ' '):find(' ' .. job .. ' ', 1, true) ~= nil;
            local can = (ok and known == true) or (not ws.quest and jobOk and value >= ws.level);
            states[i] = { can = can, jobOk = jobOk };
            if can then have = have + 1; end
        end
        if have == 0 and not wsShowAll[1] then
            hidden = hidden + 1;
        else
        local label = string.format('%s  (%d / %d)   your skill: %d', SKILL_NAME[skillId] or ('Skill ' .. skillId), have, #list, value);
        if ui.sectionHeader(label, nil, 'profile:ws:' .. skillId) then
            local half = imgui.GetContentRegionAvail() / 2;
            for i, ws in ipairs(list) do
                local st = states[i];
                if (i - 1) % 2 == 1 then imgui.SameLine(half + 8); else imgui.SetCursorPosX(8); end
                imgui.TextColored(st.can and { 0.45, 0.90, 0.45, 1.0 } or { 1.0, 0.45, 0.45, 1.0 }, ws.name);
                if imgui.IsItemHovered() then
                    imgui.BeginTooltip();
                    imgui.TextColored({ 0.79, 0.69, 0.42, 1.0 }, ws.name);
                    imgui.Separator();
                    imgui.PushTextWrapPos(380);
                    imgui.Text('How to get it: ' .. ws.how);
                    imgui.TextColored(ui.color('dimmed'), 'Jobs: ' .. ws.jobs);
                    if not st.jobOk then
                        imgui.TextColored({ 1.0, 0.45, 0.45, 1.0 }, job .. ' cannot use this weapon skill.');
                    elseif ws.quest then
                        imgui.TextColored(ui.color('dimmed'), 'Quest weapon skills show green once learned, with that weapon type equipped.');
                    end
                    imgui.PopTextWrapPos();
                    imgui.EndTooltip();
                end
            end
        end
        imgui.Spacing();
        end
    end
    if hidden > 0 then
        imgui.TextColored(ui.color('dimmed'), string.format('%d weapon type%s hidden - nothing usable on %s yet.', hidden, hidden == 1 and '' or 's', job));
    end
end

------------------------------------------------------------
-- Render: main window
------------------------------------------------------------
local function renderWindow()
    if not isOpen[1] then
        wasOpen = false;
        return;
    end

    -- Request data on first open
    if not wasOpen then
        wasOpen = true;
        requestData();
    end

    -- Loading timeout
    if loading and os.clock() - requestTime > 5 then
        loading = false;
    end

    local pushed = ui.pushWindowStyle();
    imgui.SetNextWindowSize({ 540, 580 }, ImGuiCond_FirstUseEver);

    if imgui.Begin('Profile##trove_profile', isOpen, ImGuiWindowFlags_NoCollapse) then
        local _bgPop = ui.renderBackground();
        local player = getPlayerData();
        if not player then
            imgui.TextColored(ui.color('dimmed'), 'Character data unavailable');
            imgui.End();
            ui.popWindowStyle(pushed);
            return;
        end

        if loading then
            imgui.TextColored(ui.color('dimmed'), 'Loading prestige data...');
        end

        if imgui.BeginTabBar('##character_tabs_v2') then
            -- Order: Jobs, Magic (added by omni), Crafts, Weapon Skills, Combat Skills, Magic Skills.
            if imgui.BeginTabItem('Jobs') then
                renderJobsTab(player);
                imgui.EndTabItem();
            end
            -- Extra pages added by omni (e.g. Magic) sit right after Jobs.
            for _, x in ipairs(extraTabs) do
                if imgui.BeginTabItem(x.name) then
                    pcall(x.render);
                    imgui.EndTabItem();
                end
            end
            if imgui.BeginTabItem('Crafts') then
                -- omni: Crafts has two pages, your skills and the Craftbook.
                if craftsExtra ~= nil and imgui.BeginTabBar('##crafts_sub') then
                    if imgui.BeginTabItem('Skills##crafts_sub') then
                        renderCraftsTab();
                        imgui.EndTabItem();
                    end
                    if imgui.BeginTabItem('Craftbook##crafts_sub') then
                        craftsWide = true;
                        pcall(craftsExtra);
                        imgui.EndTabItem();
                    end
                    imgui.EndTabBar();
                else
                    renderCraftsTab();
                end
                imgui.EndTabItem();
            end
            if imgui.BeginTabItem('Weapon Skills') then
                renderWeaponSkillsTab();
                imgui.EndTabItem();
            end
            if imgui.BeginTabItem('Combat Skills') then
                renderSkillList(COMBAT_SKILLS);
                imgui.EndTabItem();
            end
            if imgui.BeginTabItem('Magic Skills') then
                renderSkillList(MAGIC_SKILLS);
                imgui.EndTabItem();
            end
            imgui.EndTabBar();
        end
        if _bgPop > 0 then imgui.PopStyleColor(_bgPop); end
    end
    imgui.End();
    ui.popWindowStyle(pushed);
end

------------------------------------------------------------
-- Plugin interface
------------------------------------------------------------
return {
    name        = 'Profile',
    author      = 'Loxley',
    version     = '1.0',
    description = 'Job levels, prestige stars, and crafting skills',
    pluginId    = PLUGIN_ID,

    init = function(iconFn, itemResFn, uiModule, tooltipFn, fileIconFn)
        renderIcon     = iconFn;
        getItemRes     = itemResFn;
        ui             = uiModule;
        renderTooltip  = tooltipFn;
        renderFileIcon = fileIconFn;
    end,

    commands = {
        profile = function(state) isOpen[1] = not isOpen[1]; end,
    },

    -- omni: add a page to the end of this screen's tab bar.
    addTab = function(name, render) extraTabs[#extraTabs + 1] = { name = name, render = render }; end,
    setCraftbook = function(render) craftsExtra = render; end,
    -- Was the Craftbook on screen this frame? (resets each time it is asked)
    takeWide = function() local w = craftsWide; craftsWide = false; return w; end,

    window = {
        category = 'Account',
        isOpen = isOpen,
        render = renderWindow,
        label  = 'Profile',
        icon   = 1601,
    },

    onRender = function(state)
        if not isOpen[1] then
            wasOpen = false;
        end
    end,

    onPluginData = function(rawData, state)
        local function u8(off)
            return struct.unpack('B', rawData, off + 1);
        end

        -- Prestige tiers (jobs 1-22) at offset 0x06..0x1B
        data.prestige = {};
        for i = 1, 22 do
            data.prestige[i] = u8(0x05 + i);
        end

        -- Craft skills as uint16 LE (9 crafts) at offset 0x1C..0x2D
        -- RealSkills value: 1000 = 100.0, 15 = 1.5
        data.crafts = {};
        for i = 0, 8 do
            local off = 0x1C + i * 2;
            local raw = u8(off) + u8(off + 1) * 256;
            data.crafts[i + 1] = raw / 10;
        end

        -- Is CW at offset 0x2E
        data.isCW = u8(0x2E) == 1;

        -- Per-job EXP (22 x uint16 LE) appended by C++ at offset 0x2F
        data.exp = {};
        for i = 0, 21 do
            local off = 0x2F + i * 2;
            data.exp[i + 1] = u8(off) + u8(off + 1) * 256;
        end

        loaded  = true;
        loading = false;
    end,
};
