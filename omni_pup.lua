--[[
    omni_pup.lua - Automaton: a click-to-equip attachment page for Puppetmaster (Gear > Automaton).

    What it does
      * Shows the automaton you have on now: head, frame, the 12 attachments and how much of each
        element's capacity they use.
      * A plan you build by clicking: click an attachment in the list on the right to add it, click it
        in the plan to take it off. Pick a head and frame from the drop-downs. Over capacity, too many
        attachments, or something you haven't learned is refused with the reason.
      * Ready builds (Melee, Tank, Ranged, Nuker, Healer, Enfeebler). Each one is a list of the best
        attachments for that role, best first; it is fitted to what YOU have learned and to the
        capacity of the head/frame, so you always get the best version you can actually equip, and
        it tells you which upgrades you are missing.
      * Maneuvers: for every element, what one maneuver of it gives (the stat bonus at your level)
        and what it does for each attachment in the plan of that element.
      * Equip: Deactivate, put the plan on, then Activate (or Deus Ex Automata if Activate is
        recharging). Five save slots for your own sets.

    How equipping works: the client keeps the automaton's loadout and what you've learned in one
    buffer, and changes it with its own extended-equip function. Both are found by signature scan, the
    way atom0s' blusets and the pupsets addon do it. This file is written for omni; no code was copied
    from puphq (QB1985), which gave the idea.

    The attachment data (element and capacity cost) matches LandSandBoat's item_puppet table; the
    effect / maneuver notes are short summaries written for omni.
]]--

local imgui = require('imgui');
local ffi   = require('ffi');

local pup = {};
pup.height = 600;
pup.get_settings = nil;      -- omni sets this (returns omni.settings)

local PUP_JOB = 18;
local SLOTS   = 12;

----------------------------------------------------------------------------------------------------
-- Elements: the game's order, as in the capacity numbers.
----------------------------------------------------------------------------------------------------
local EL = {
    { name = 'Fire',    stat = 'STR', col = { 1.00, 0.45, 0.30, 1 } },
    { name = 'Ice',     stat = 'INT', col = { 0.55, 0.85, 1.00, 1 } },
    { name = 'Wind',    stat = 'AGI', col = { 0.45, 0.95, 0.55, 1 } },
    { name = 'Earth',   stat = 'VIT', col = { 0.90, 0.75, 0.40, 1 } },
    { name = 'Thunder', stat = 'DEX', col = { 0.85, 0.60, 1.00, 1 } },
    { name = 'Water',   stat = 'MND', col = { 0.35, 0.60, 1.00, 1 } },
    { name = 'Light',   stat = 'CHR', col = { 1.00, 1.00, 0.85, 1 } },
    { name = 'Dark',    stat = nil,   col = { 0.70, 0.55, 0.80, 1 } },
};

-- Heads (byte 1-6) and frames (byte 32-35): capacity per element, and what they're for.
local HEADS = {
    [1] = { caps = { 2, 2, 2, 2, 2, 2, 0, 0 }, role = 'All-round: melee plus a little healing and enfeebling' },
    [2] = { caps = { 3, 0, 2, 3, 2, 0, 2, 0 }, role = 'Melee / tank: cures itself and you, high HP' },
    [3] = { caps = { 3, 0, 3, 0, 2, 2, 2, 0 }, role = 'Ranged: shoots, casts a few enfeebles' },
    [4] = { caps = { 0, 3, 2, 2, 0, 3, 0, 2 }, role = 'Red mage style: enfeebles, nukes, some cures' },
    [5] = { caps = { 0, 3, 2, 2, 0, 3, 3, 0 }, role = 'Healer: cures, -na spells, buffs' },
    [6] = { caps = { 0, 3, 2, 2, 0, 3, 0, 3 }, role = 'Nuker: elemental magic, magic bursts' },
};
local FRAMES = {
    [32] = { caps = { 3, 3, 3, 3, 3, 3, 3, 3 }, role = 'All-round frame' },
    [33] = { caps = { 4, 2, 3, 4, 3, 3, 3, 2 }, role = 'Melee / tank frame: shield, high HP and defence' },
    [34] = { caps = { 3, 2, 4, 3, 4, 3, 3, 2 }, role = 'Ranged frame: no MP, ranged attacks' },
    [35] = { caps = { 2, 4, 2, 3, 3, 3, 3, 4 }, role = 'Mage frame: big MP' },
};

----------------------------------------------------------------------------------------------------
-- Attachments: [byte id] = { element, cost, what it does, what its element's maneuvers do for it }
-- (item id = 0x2100 + byte id; names come from the client)
----------------------------------------------------------------------------------------------------
local A = {
    -- Fire
    [1]   = { 1, 1, 'Raises enmity; can use Provoke', 'Provoke needs a Fire maneuver; more maneuvers = more enmity' },
    [2]   = { 1, 1, 'Attack +', 'More attack per Fire maneuver' },
    [3]   = { 1, 1, 'Store TP +', 'More Store TP per Fire maneuver' },
    [4]   = { 1, 2, 'Attack ++', 'More attack per Fire maneuver' },
    [5]   = { 1, 2, 'Ignores some defence of strong (tough+) enemies', 'Stronger with Fire maneuvers' },
    [6]   = { 1, 1, 'Blaze Spikes', 'Spikes come on with a Fire maneuver; damage grows with more' },
    [7]   = { 1, 1, 'Weapon skill damage +', 'Uses up Fire maneuver energy to power up its weapon skills' },
    [8]   = { 1, 1, 'Restores its TP', 'Turns Fire maneuver burden into TP (removes Fire maneuvers)' },
    [9]   = { 1, 2, 'Raises enmity more; Provoke', 'Provoke needs a Fire maneuver; more maneuvers = more enmity' },
    [10]  = { 1, 3, 'Attack +++', 'More attack per Fire maneuver' },
    [11]  = { 1, 2, 'Store TP ++', 'More Store TP per Fire maneuver' },
    [12]  = { 1, 4, 'Attack ++++', 'More attack per Fire maneuver' },
    [13]  = { 1, 2, 'Restores more TP', 'Turns Fire maneuver burden into TP (removes Fire maneuvers)' },
    [14]  = { 1, 1, 'Skillchain damage +', 'More per Fire maneuver' },
    [15]  = { 1, 2, 'Skillchain damage ++', 'More per Fire maneuver' },
    [16]  = { 1, 5, 'Attack +++++', 'More attack per Fire maneuver' },
    [17]  = { 1, 1, 'Weapon damage +', 'More per Fire maneuver' },
    [18]  = { 1, 2, 'Weapon damage ++', 'More per Fire maneuver' },
    -- Ice
    [33]  = { 2, 2, 'Casts spells more often', 'Shorter waits between spells per Ice maneuver' },
    [34]  = { 2, 1, 'Magic attack +', 'More magic attack per Ice maneuver' },
    [35]  = { 2, 1, 'Scans the target for magic weaknesses', 'Ice maneuvers make it scan more' },
    [36]  = { 2, 2, 'Magic attack ++', 'More magic attack per Ice maneuver' },
    [37]  = { 2, 1, 'Thinks faster (acts sooner)', 'Faster per Ice maneuver' },
    [38]  = { 2, 1, 'Magic accuracy +', 'More magic accuracy per Ice maneuver' },
    [39]  = { 2, 1, 'Magic damage +', 'Uses up Ice maneuver energy to power up its next spell' },
    [40]  = { 2, 2, 'Lower MP cost', 'Lower MP cost per Ice maneuver' },
    [41]  = { 2, 3, 'Magic attack +++', 'More magic attack per Ice maneuver' },
    [42]  = { 2, 2, 'Magic accuracy ++', 'More magic accuracy per Ice maneuver' },
    [43]  = { 2, 2, 'Magic burst damage and chance +', 'More per Ice maneuver' },
    [44]  = { 2, 4, 'Magic attack ++++', 'More magic attack per Ice maneuver' },
    [45]  = { 2, 3, 'Magic accuracy +++', 'More magic accuracy per Ice maneuver' },
    [46]  = { 2, 3, 'Magic burst damage and chance ++', 'More per Ice maneuver' },
    [47]  = { 2, 5, 'Magic attack +++++', 'More magic attack per Ice maneuver' },
    [48]  = { 2, 4, 'Magic accuracy ++++', 'More magic accuracy per Ice maneuver' },
    [49]  = { 2, 1, 'Magic damage +', 'More per Ice maneuver' },
    [50]  = { 2, 2, 'Magic damage ++', 'More per Ice maneuver' },
    -- Wind
    [65]  = { 3, 2, 'Evasion +', 'More evasion per Wind maneuver' },
    [66]  = { 3, 1, 'Ranged accuracy +', 'More ranged accuracy per Wind maneuver' },
    [67]  = { 3, 1, 'Learns enemy attacks, evasion slowly rises', 'Rises faster with Wind maneuvers' },
    [68]  = { 3, 3, 'Evasion ++', 'More evasion per Wind maneuver' },
    [69]  = { 3, 2, 'Faster ranged attacks, less ranged accuracy', 'Faster per Wind maneuver' },
    [70]  = { 3, 2, 'Haste', 'Haste only with Wind maneuvers; more per maneuver' },
    [71]  = { 3, 1, 'Shadows at low HP', 'Turns Wind maneuvers into shadow images when its HP is low' },
    [72]  = { 3, 2, 'Barrage now and then', 'Uses up Wind maneuvers to fire a Barrage; more maneuvers = more shots' },
    [73]  = { 3, 3, 'Haste ++', 'Haste only with Wind maneuvers; more per maneuver' },
    [74]  = { 3, 4, 'Evasion +++', 'More evasion per Wind maneuver' },
    [75]  = { 3, 2, 'Ranged accuracy ++', 'More ranged accuracy per Wind maneuver' },
    [76]  = { 3, 2, 'Fires more than one shot now and then', 'More often per Wind maneuver' },
    [77]  = { 3, 5, 'Evasion ++++', 'More evasion per Wind maneuver' },
    [78]  = { 3, 3, 'Ranged accuracy +++', 'More ranged accuracy per Wind maneuver' },
    [79]  = { 3, 4, 'Ranged accuracy ++++', 'More ranged accuracy per Wind maneuver' },
    [80]  = { 3, 1, 'Ranged damage +', 'More per Wind maneuver' },
    -- Earth
    [97]  = { 4, 1, 'Stoneskin', 'Casts Stoneskin only with an Earth maneuver; stronger with more' },
    [98]  = { 4, 2, 'Physical damage taken -', 'Less damage per Earth maneuver' },
    [99]  = { 4, 1, 'Better at dodging special attacks it has seen', 'Better per Earth maneuver' },
    [100] = { 4, 3, 'Physical damage taken --', 'Less damage per Earth maneuver' },
    [101] = { 4, 2, 'Big hits are reduced', 'More reduction per Earth maneuver' },
    [102] = { 4, 1, 'Can stop a deadly hit', 'Uses up an Earth maneuver to cut a heavy physical hit' },
    [103] = { 4, 1, 'Shield Bash damage +, may Slow', 'Stronger per Earth maneuver' },
    [104] = { 4, 2, 'Shield block rate ++', 'Earth maneuvers add Shield Mastery and quicker Shield Bash' },
    [105] = { 4, 2, 'Stoneskin ++', 'Casts Stoneskin only with an Earth maneuver; stronger with more' },
    [106] = { 4, 4, 'Physical damage taken ---', 'Less damage per Earth maneuver' },
    [107] = { 4, 1, 'Shield block rate +', 'Earth maneuvers add Shield Mastery and quicker Shield Bash' },
    [108] = { 4, 5, 'Physical damage taken ----', 'Less damage per Earth maneuver' },
    [109] = { 4, 3, 'Stoneskin +++', 'Casts Stoneskin only with an Earth maneuver; stronger with more' },
    -- Thunder
    [129] = { 5, 1, 'Accuracy +', 'More accuracy per Thunder maneuver' },
    [130] = { 5, 1, 'Lightning damage on hits', 'Works with Thunder maneuvers; more chance/damage per maneuver' },
    [131] = { 5, 1, 'Learns the enemy, accuracy slowly rises', 'Rises faster with Thunder maneuvers' },
    [132] = { 5, 2, 'Accuracy ++', 'More accuracy per Thunder maneuver' },
    [133] = { 5, 2, 'Accuracy vs strong enemies', 'More per Thunder maneuver' },
    [134] = { 5, 2, 'Critical hit rate +', 'More per Thunder maneuver' },
    [135] = { 5, 2, 'Double attack', 'More double attacks per Thunder maneuver' },
    [136] = { 5, 2, 'Counter', 'Counter rate rises with Thunder maneuvers' },
    [137] = { 5, 3, 'Accuracy +++', 'More accuracy per Thunder maneuver' },
    [138] = { 5, 3, 'Double attack ++', 'More double attacks per Thunder maneuver' },
    [139] = { 5, 3, 'Critical hit rate ++', 'More per Thunder maneuver' },
    [140] = { 5, 4, 'Accuracy ++++', 'More accuracy per Thunder maneuver' },
    [141] = { 5, 4, 'Critical hit rate +++', 'More per Thunder maneuver' },
    [142] = { 5, 5, 'Accuracy +++++', 'More accuracy per Thunder maneuver' },
    -- Water
    [161] = { 6, 2, 'Magic defence +', 'More per Water maneuver' },
    [162] = { 6, 1, 'Burden goes down faster', 'Faster per Water maneuver' },
    [163] = { 6, 1, 'Enmity -', 'Less enmity per Water maneuver' },
    [164] = { 6, 3, 'Magic defence ++', 'More per Water maneuver' },
    [165] = { 6, 2, 'Magic attack + but slower recasts', 'Stronger per Water maneuver' },
    [166] = { 6, 1, 'Can stop an overload', 'Uses up a Water maneuver to stop an overload' },
    [167] = { 6, 1, 'Less damage from the same attack type hitting again', 'Stronger per Water maneuver' },
    [168] = { 6, 1, 'Skill-up rate +', 'More per Water maneuver' },
    [169] = { 6, 4, 'Magic defence +++', 'More per Water maneuver' },
    [170] = { 6, 2, 'Enmity --', 'Less enmity per Water maneuver' },
    [171] = { 6, 1, 'Status resistance +', 'More per Water maneuver' },
    [172] = { 6, 2, 'Status resistance ++', 'More per Water maneuver' },
    [173] = { 6, 5, 'Magic defence ++++', 'More per Water maneuver' },
    [174] = { 6, 3, 'Magic attack ++ but slower recasts', 'Stronger per Water maneuver' },
    -- Light
    [193] = { 7, 2, 'HP regen', 'More HP per tick per Light maneuver' },
    [194] = { 7, 2, 'Flash', 'Casts Flash only with a Light maneuver' },
    [195] = { 7, 1, 'Cures itself sooner when hurt', 'Heals at higher HP with Light maneuvers' },
    [196] = { 7, 3, 'HP regen ++', 'More HP per tick per Light maneuver' },
    [197] = { 7, 2, 'Removes status ailments', 'Uses a Light maneuver to erase an ailment' },
    [198] = { 7, 1, 'Boosts ALL other attachments', 'Boosts attachments of each maneuver element you have up' },
    [200] = { 7, 2, 'Cure potency +', 'More per Light maneuver' },
    [201] = { 7, 3, 'Cure potency ++', 'More per Light maneuver' },
    [202] = { 7, 4, 'HP regen +++', 'More HP per tick per Light maneuver' },
    [203] = { 7, 1, 'Light-based weapon skill / magic help', 'Stronger per Light maneuver' },
    [204] = { 7, 2, 'Light-based weapon skill / magic help ++', 'Stronger per Light maneuver' },
    [205] = { 7, 5, 'HP regen ++++', 'More HP per tick per Light maneuver' },
    [206] = { 7, 2, 'Boosts ALL other attachments ++', 'Boosts attachments of each maneuver element you have up' },
    [207] = { 7, 2, 'Cures itself sooner when hurt ++', 'Heals at higher HP with Light maneuvers' },
    -- Dark
    [225] = { 8, 2, 'MP + and MP regen', 'MP regen per Dark maneuver' },
    [226] = { 8, 2, 'Refills MP when low', 'Uses up Dark maneuvers to restore MP' },
    [227] = { 8, 1, 'Conserve MP', 'More often per Dark maneuver' },
    [228] = { 8, 3, 'MP ++ and MP regen', 'MP regen per Dark maneuver' },
    [229] = { 8, 2, 'Harder to hit', 'Stronger per Dark maneuver' },
    [230] = { 8, 1, 'Restores MP', 'Uses up Dark maneuvers to restore MP' },
    [232] = { 8, 2, 'Dispel', 'Casts Dispel only with a Dark maneuver' },
    [233] = { 8, 4, 'MP +++ and MP regen', 'MP regen per Dark maneuver' },
    [234] = { 8, 3, 'Steals good effects from the enemy', 'Needs Dark maneuvers' },
    [235] = { 8, 5, 'MP ++++ and MP regen', 'MP regen per Dark maneuver' },
};

----------------------------------------------------------------------------------------------------
-- Builds: preferred heads and frames (first one you have wins) and attachments, best first.
-- The fitter goes down the list and takes what you have and what still fits.
----------------------------------------------------------------------------------------------------
local BUILDS = {
    { name = 'Melee', desc = 'Hard-hitting melee automaton. Keep Fire (attack) and Thunder (accuracy) up; Wind for haste.',
      heads = { 2, 1 }, frames = { 33, 32 }, man = 'Fire / Thunder / Wind',
      att = { 3, 5, 11, 16, 12, 10, 4, 2, 17, 18, 142, 140, 137, 132, 129, 138, 135, 141, 139, 134,
              73, 70, 206, 198, 205, 202, 196, 193, 98, 100 } },
    { name = 'Tank', desc = 'Holds hate and takes hits. Fire for Provoke, Earth for Stoneskin and damage taken, Light for Flash and regen.',
      heads = { 2, 1 }, frames = { 33, 32 }, man = 'Fire / Earth / Light',
      att = { 9, 1, 108, 106, 100, 98, 109, 105, 97, 104, 107, 101, 194, 206, 198, 205, 202, 196, 193,
              173, 169, 164, 161, 162, 132, 129, 73, 70 } },
    { name = 'Ranged', desc = 'Sharpshot archer. Wind for ranged accuracy and haste, Fire for attack, Thunder for accuracy and crits.',
      heads = { 3, 1 }, frames = { 34, 32 }, man = 'Wind / Fire / Thunder',
      att = { 79, 78, 75, 66, 76, 80, 73, 70, 3, 5, 15, 14, 12, 10, 4, 2, 141, 139, 134, 142, 140, 137, 132, 129,
              206, 198, 202, 196, 193, 162 } },
    { name = 'Nuker', desc = 'Black mage style. Ice for magic attack and accuracy, Dark for MP. Spiritreaver head is best.',
      heads = { 6, 4, 1 }, frames = { 35, 32 }, man = 'Ice / Dark',
      att = { 47, 44, 41, 36, 34, 46, 43, 48, 45, 42, 38, 50, 49, 39, 33, 40, 235, 233, 228, 225, 227, 230,
              206, 198, 174, 165, 162, 73, 70 } },
    { name = 'Healer', desc = 'White mage style. Light for cure potency and regen, Dark for MP, Ice to cast more often.',
      heads = { 5, 4, 1 }, frames = { 35, 32 }, man = 'Light / Dark / Water',
      att = { 201, 200, 206, 198, 197, 202, 196, 193, 235, 233, 228, 225, 227, 230, 33, 37, 40,
              172, 171, 170, 163, 162, 73, 70, 108, 106, 100, 98 } },
    { name = 'Enfeebler', desc = 'Red mage style debuffer. Ice for magic accuracy and casting speed, Dark for MP and Dispel.',
      heads = { 4, 1 }, frames = { 35, 32 }, man = 'Ice / Dark',
      att = { 48, 45, 42, 38, 33, 37, 40, 232, 235, 233, 228, 225, 227, 230, 206, 198, 201, 200, 73, 70,
              162, 172, 171 } },
};

----------------------------------------------------------------------------------------------------
-- Game memory: the automaton buffer and the extended-equip function (signature scan).
----------------------------------------------------------------------------------------------------
pcall(ffi.cdef, [[
    typedef uint8_t (__cdecl *omni_pup_equipex_t)(uint8_t isSubJob, uint16_t jobType, uint16_t index, uint8_t id);
]]);
local MEM = { ok = false };
pcall(function ()
    local a = ashita.memory.find('FFXiMain.dll', 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);
    local b = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????81EC9C00000085C95356570F??????????8B', 0, 0);
    if a ~= nil and a ~= 0 and b ~= nil and b ~= 0 then
        MEM.offset  = ffi.cast('uint32_t*', a);
        MEM.equipex = ffi.cast('omni_pup_equipex_t', b);
        MEM.ok = true;
    end
end);

local function player() return AshitaCore:GetMemoryManager():GetPlayer(); end
local function is_main() return player():GetMainJob() == PUP_JOB; end
local function is_sub() return player():GetSubJob() == PUP_JOB; end
local function pup_level()
    local p = player();
    if p:GetMainJob() == PUP_JOB then return p:GetMainJobLevel(); end
    if p:GetSubJob() == PUP_JOB then return p:GetSubJobLevel(); end
    return 0;
end

local function buffer()
    if not MEM.ok then return 0; end
    local ok, ptr = pcall(function ()
        local p = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
        if p == 0 then return 0; end
        p = ashita.memory.read_uint32(p);
        if p == 0 then return 0; end
        return p + MEM.offset[0] + (is_main() and 0 or 0x9C);
    end);
    return ok and ptr or 0;
end

local function bit_on(v, n) return bit.band(bit.rshift(v, n), 1) == 1; end
local function u32(b, o) return b[o + 1] + b[o + 2] * 256 + b[o + 3] * 65536 + b[o + 4] * 16777216; end

-- What the client says: now = { head, frame, att = {...} }, learned heads/frames/attachments, capacity bonus
local ST = { at = -10, ok = false, now = { head = 0, frame = 0, att = {} }, heads = {}, frames = {}, att = {}, bonus = 0 };
local function read(force)
    local t = os.clock();
    if not force and t - ST.at < 0.5 then return ST; end
    ST.at, ST.ok = t, false;
    if not (is_main() or is_sub()) then return ST; end
    local base = buffer();
    if base == 0 then return ST; end
    local ok, b = pcall(ashita.memory.read_array, base, 0x9C);
    if not ok or type(b) ~= 'table' or #b < 0x9C then return ST; end
    ST.now = { head = b[5], frame = b[6], att = {} };
    for i = 0, SLOTS - 1 do
        local v = b[7 + i];
        if v and v ~= 0 then ST.now.att[#ST.now.att + 1] = v; end
    end
    local hb, fb = u32(b, 0x14), u32(b, 0x18);
    ST.heads, ST.frames, ST.att = {}, {}, {};
    for id = 1, 7 do if bit_on(hb, id) then ST.heads[id] = true; end end
    for id = 32, 39 do if bit_on(fb, id - 32) then ST.frames[id] = true; end end
    for id in pairs(A) do
        if bit_on(b[0x35 + math.floor(id / 8)] or 0, id % 8) then ST.att[id] = true; end
    end
    ST.bonus = b[0x99] or 0;
    ST.ok = true;
    return ST;
end

-- Names from the client
local NAMES = {};
local function name_of(itemid)
    if NAMES[itemid] then return NAMES[itemid]; end
    local n = nil;
    pcall(function ()
        local it = AshitaCore:GetResourceManager():GetItemById(itemid);
        if it and it.Name and it.Name[1] and it.Name[1] ~= '' and it.Name[1] ~= '.' then n = it.Name[1]; end
    end);
    NAMES[itemid] = n or ('#' .. itemid);
    return NAMES[itemid];
end
local function att_name(id) return name_of(0x2100 + id); end
local function hf_name(id) return (id and id ~= 0) and name_of(0x2000 + id) or 'none'; end

----------------------------------------------------------------------------------------------------
-- Capacity and fitting
----------------------------------------------------------------------------------------------------
local function caps_of(head, frame)
    local c = {};
    local h, f = HEADS[head], FRAMES[frame];
    for e = 1, 8 do c[e] = (h and h.caps[e] or 0) + (f and f.caps[e] or 0) + (ST.bonus or 0); end
    return c;
end
local function used_of(list)
    local u = { 0, 0, 0, 0, 0, 0, 0, 0 };
    for _, id in ipairs(list) do local a = A[id]; if a then u[a[1]] = u[a[1]] + a[2]; end end
    return u;
end
local function has(list, id) for _, v in ipairs(list) do if v == id then return true; end end return false; end

-- Why id can't go into plan (nil = it can)
local function refuse_reason(plan, id)
    if has(plan.att, id) then return 'already in the plan'; end
    if #plan.att >= SLOTS then return 'all 12 slots are full'; end
    if ST.ok and not ST.att[id] then return 'not learned yet (trade it to Tateeya)'; end
    local a = A[id];
    local cap, used = caps_of(plan.head, plan.frame), used_of(plan.att);
    if used[a[1]] + a[2] > cap[a[1]] then
        return string.format('%s capacity would be %d/%d', EL[a[1]].name, used[a[1]] + a[2], cap[a[1]]);
    end
    return nil;
end

-- Build fitted to what you have: { head, frame, att, missing = {names} }
local function fit(build)
    local plan = { head = 0, frame = 0, att = {} };
    for _, h in ipairs(build.heads) do if not ST.ok or ST.heads[h] then plan.head = h; break; end end
    for _, f in ipairs(build.frames) do if not ST.ok or ST.frames[f] then plan.frame = f; break; end end
    local missing = {};
    if plan.head ~= build.heads[1] then missing[#missing + 1] = hf_name(build.heads[1]); end
    if plan.frame ~= build.frames[1] then missing[#missing + 1] = hf_name(build.frames[1]); end
    for _, id in ipairs(build.att) do
        if A[id] then
            if ST.ok and not ST.att[id] then
                if #missing < 8 then missing[#missing + 1] = att_name(id); end
            elseif refuse_reason(plan, id) == nil then
                plan.att[#plan.att + 1] = id;
            end
        end
    end
    plan.missing = missing;
    return plan;
end

----------------------------------------------------------------------------------------------------
-- Equipping: Deactivate -> clear -> head, frame, attachments one by one -> Activate / Deus Ex Automata
----------------------------------------------------------------------------------------------------
local EQ = { active = false, msg = nil, ok = nil };
local GAP = 1.3;

local function say(t) print('\30\68[omni Automaton]\30\01 ' .. t); end
local function cmd(c) AshitaCore:GetChatManager():QueueCommand(1, c); end
local function pet_out()
    local out = false;
    pcall(function ()
        local mm = AshitaCore:GetMemoryManager();
        local me = mm:GetParty():GetMemberTargetIndex(0);
        local pi = mm:GetEntity():GetPetTargetIndex(me);
        out = pi ~= nil and pi ~= 0 and (mm:GetEntity():GetHPPercent(pi) or 0) > 0;
    end);
    return out;
end
local function recast(name)
    local left = 0;
    pcall(function ()
        local rc, res = AshitaCore:GetMemoryManager():GetRecast(), AshitaCore:GetResourceManager();
        for x = 0, 31 do
            local id, timer = rc:GetAbilityTimerId(x), rc:GetAbilityTimer(x);
            if (id ~= 0 or x == 0) and timer > 0 then
                local ab = res:GetAbilityByTimerId(id);
                if ab and ab.Name[1] == name then left = timer; end
            end
        end
    end);
    return left;
end
local function finish(ok, msg)
    EQ.active, EQ.ok, EQ.msg = false, ok, msg;
    say(msg);
end

local function start_equip(plan)
    if EQ.active then return; end
    if not MEM.ok then EQ.ok, EQ.msg = false, 'Could not find the game\'s equip function (signature scan failed).'; return; end
    if not (is_main() or is_sub()) then EQ.ok, EQ.msg = false, 'Puppetmaster has to be your main or support job.'; return; end
    if plan.head == 0 or plan.frame == 0 then EQ.ok, EQ.msg = false, 'Pick a head and a frame first.'; return; end
    read(true);
    local cap, used = caps_of(plan.head, plan.frame), used_of(plan.att);
    for e = 1, 8 do
        if used[e] > cap[e] then EQ.ok, EQ.msg = false, string.format('%s is over capacity (%d/%d).', EL[e].name, used[e], cap[e]); return; end
    end
    if ST.ok then
        if not ST.heads[plan.head] or not ST.frames[plan.frame] then EQ.ok, EQ.msg = false, 'That head or frame is not unlocked.'; return; end
        for _, id in ipairs(plan.att) do
            if not ST.att[id] then EQ.ok, EQ.msg = false, att_name(id) .. ' is not learned.'; return; end
        end
    end
    local q = { { 'clear' }, { 0, plan.head }, { 1, plan.frame } };
    for i, id in ipairs(plan.att) do q[#q + 1] = { 1 + i, id }; end
    EQ = { active = true, phase = 'deactivate', q = q, i = 0, wait = 0, msg = 'Starting...' };
end

local function tick()
    if not EQ.active then return; end
    local t = os.clock();
    if player():GetIsZoning() ~= 0 then finish(false, 'Stopped: you zoned.'); return; end
    if t < (EQ.wait or 0) then return; end
    local ph = EQ.phase;
    if ph == 'deactivate' then
        if pet_out() then
            cmd('/ja "Deactivate" <me>');
            EQ.phase, EQ.deadline, EQ.msg = 'gone', t + 8, 'Deactivating...';
        else
            EQ.phase = 'apply';
        end
    elseif ph == 'gone' then
        if not pet_out() then EQ.phase, EQ.wait = 'apply', t + 1.5;
        elseif t > EQ.deadline then finish(false, 'The automaton did not deactivate.'); end
    elseif ph == 'apply' then
        EQ.i = EQ.i + 1;
        local op = EQ.q[EQ.i];
        if op == nil then EQ.phase = 'activate'; return; end
        local ok, err = pcall(function ()
            if op[1] == 'clear' then
                local base = buffer();
                if base == 0 then error('no automaton data'); end
                AshitaCore:GetPacketManager():QueuePacket(0x102, 0xA4, 0x00, 0x00, 0x00, function (ptr)
                    local p = ffi.cast('uint8_t*', ptr);
                    ffi.fill(p + 0x04, 0xA0);
                    ffi.copy(p + 0x08, ffi.cast('uint8_t*', base), 0x9C);
                    ffi.fill(p + 0x0C, 0x2);          -- head and frame: none (takes everything off)
                end);
            else
                MEM.equipex(is_main() and 0 or 1, 0x1200, op[1], op[2]);
            end
        end);
        if not ok then finish(false, 'Equipping failed: ' .. tostring(err)); return; end
        EQ.wait, EQ.msg = t + GAP, string.format('Equipping %d / %d...', EQ.i, #EQ.q);
    elseif ph == 'activate' then
        if recast('Activate') == 0 then cmd('/ja "Activate" <me>'); EQ.used = 'Activate';
        elseif recast('Deus Ex Automata') == 0 then cmd('/ja "Deus Ex Automata" <me>'); EQ.used = 'Deus Ex Automata';
        else finish(true, 'Attachments set. Activate and Deus Ex Automata are recharging - call it out yourself.'); return; end
        EQ.phase, EQ.deadline, EQ.msg = 'pet', t + 5, 'Activating...';
    elseif ph == 'pet' then
        if pet_out() then finish(true, 'Equipped (' .. EQ.used .. ').');
        elseif t > EQ.deadline then finish(true, 'Attachments set, but the automaton did not come out.'); end
    end
end
ashita.events.register('d3d_present', 'omni_pup_tick', function () pcall(tick); end);

----------------------------------------------------------------------------------------------------
-- Page
----------------------------------------------------------------------------------------------------
local UI = { plan = nil, filter = 0, build = nil, note = nil, note_at = 0, slot = 1 };
local GOLD, DIM, RED, GREEN = { 0.95, 0.80, 0.45, 1 }, { 0.62, 0.62, 0.70, 1 }, { 1, 0.45, 0.45, 1 }, { 0.50, 0.95, 0.55, 1 };

local function S()
    local s = pup.get_settings and pup.get_settings() or nil;
    if s and s.pup_sets == nil then s.pup_sets = {}; end
    return s;
end
local function save() pcall(function () require('settings').save('omni'); end); end
local function copy_plan(p) local a = {}; for i, v in ipairs(p.att or {}) do a[i] = v; end return { head = p.head or 0, frame = p.frame or 0, att = a }; end
local function note(t) UI.note, UI.note_at = t, os.clock(); end

local function el_dot(e)
    imgui.TextColored(EL[e].col, '*');
end

local function att_label(id)
    local a = A[id];
    return string.format('%s (%d)', att_name(id), a and a[2] or 0);
end

local function att_tip(id)
    local a = A[id];
    if not a then return; end
    if imgui.IsItemHovered() then
        imgui.SetTooltip(string.format('%s  -  %s, capacity %d\n%s\n%s maneuver: %s', att_name(id), EL[a[1]].name, a[2], a[3], EL[a[1]].name, a[4]));
    end
end

local function capacity_bars(plan)
    local cap, used = caps_of(plan.head, plan.frame), used_of(plan.att);
    for e = 1, 8 do
        imgui.TextColored(EL[e].col, string.format('%-7s', EL[e].name));
        imgui.SameLine(70);
        local over = used[e] > cap[e];
        local frac = cap[e] > 0 and math.min(1, used[e] / cap[e]) or 0;
        imgui.PushStyleColor(ImGuiCol_PlotHistogram, over and RED or EL[e].col);
        imgui.ProgressBar(frac, { 160, 14 }, string.format('%d / %d', used[e], cap[e]));
        imgui.PopStyleColor(1);
    end
    imgui.TextDisabled(string.format('Slots %d / %d', #plan.att, SLOTS));
end

local function maneuvers(plan)
    local lvl = pup_level();
    local per = (lvl > 0) and (math.floor(lvl / 15) + 1) or 0;
    for e = 1, 8 do
        local mine = {};
        for _, id in ipairs(plan.att) do if A[id] and A[id][1] == e then mine[#mine + 1] = id; end end
        imgui.TextColored(EL[e].col, EL[e].name .. ' Maneuver');
        imgui.SameLine(0, 8);
        if EL[e].stat then
            imgui.TextDisabled(string.format('%s +%d each%s', EL[e].stat, per, lvl > 0 and '' or ' (PUP not set)'));
        else
            imgui.TextDisabled('no stat bonus');
        end
        if #mine == 0 then
            imgui.TextDisabled('    nothing in the plan uses it');
        else
            for _, id in ipairs(mine) do
                imgui.Text('    ' .. att_name(id) .. ':');
                imgui.SameLine(0, 6);
                imgui.TextColored(DIM, A[id][4]);
            end
        end
    end
    if has(plan.att, 198) or has(plan.att, 206) then
        imgui.TextColored(GOLD, 'Optic Fiber: every attachment of an element you have a maneuver up for gets stronger.');
    end
end

pup.render = function ()
    read(false);
    local y0 = imgui.GetCursorPosY();
    if not (is_main() or is_sub()) then
        imgui.TextColored(DIM, 'Set Puppetmaster as your main or support job to read and change the automaton.');
    elseif not MEM.ok then
        imgui.TextColored(RED, 'The game\'s automaton data could not be found (signature scan failed) - only planning works.');
    end
    if UI.plan == nil then
        UI.plan = (ST.ok and ST.now.head ~= 0) and copy_plan(ST.now) or { head = 2, frame = 33, att = {} };
    end
    local plan = UI.plan;

    -- Now on the automaton
    imgui.TextColored(GOLD, 'On your automaton now:');
    imgui.SameLine(0, 8);
    if ST.ok then
        imgui.Text(hf_name(ST.now.head) .. '  /  ' .. hf_name(ST.now.frame) .. '   (' .. #ST.now.att .. ' attachments)');
        if imgui.IsItemHovered() then
            local t = {};
            for _, id in ipairs(ST.now.att) do t[#t + 1] = att_name(id); end
            imgui.SetTooltip(#t > 0 and table.concat(t, '\n') or 'no attachments');
        end
        imgui.SameLine(0, 10);
        if imgui.SmallButton('Load into plan##pup_cur') then UI.plan = copy_plan(ST.now); UI.build = nil; plan = UI.plan; end
    else
        imgui.TextDisabled('(not readable)');
    end

    -- Builds
    imgui.TextColored(GOLD, 'Best builds:');
    for i, b in ipairs(BUILDS) do
        imgui.SameLine(0, 6);
        if imgui.Button(b.name .. '##pup_b' .. i) then
            UI.plan = fit(b); plan = UI.plan; UI.build = b;
        end
        if imgui.IsItemHovered() then imgui.SetTooltip(b.desc .. '\nManeuvers: ' .. b.man); end
    end
    if UI.build then
        imgui.TextColored(DIM, UI.build.desc .. '  Maneuvers: ' .. UI.build.man);
        if plan.missing and #plan.missing > 0 then
            imgui.TextColored({ 1, 0.75, 0.4, 1 }, 'Upgrades you don\'t have yet: ' .. table.concat(plan.missing, ', '));
        elseif ST.ok then
            imgui.TextColored(GREEN, 'You have everything this build wants.');
        end
    end
    imgui.Separator();

    -- Left: the plan
    imgui.BeginGroup();
    imgui.PushItemWidth(170);
    if imgui.BeginCombo('##pup_head', 'Head: ' .. hf_name(plan.head)) then
        for id = 1, 6 do
            local ok_ = not ST.ok or ST.heads[id];
            if imgui.Selectable(hf_name(id) .. (ok_ and '' or '  (not unlocked)'), plan.head == id) and ok_ then plan.head = id; end
            if imgui.IsItemHovered() then imgui.SetTooltip(HEADS[id].role); end
        end
        imgui.EndCombo();
    end
    imgui.SameLine(0, 6);
    if imgui.BeginCombo('##pup_frame', 'Frame: ' .. hf_name(plan.frame)) then
        for id = 32, 35 do
            local ok_ = not ST.ok or ST.frames[id];
            if imgui.Selectable(hf_name(id) .. (ok_ and '' or '  (not unlocked)'), plan.frame == id) and ok_ then plan.frame = id; end
            if imgui.IsItemHovered() then imgui.SetTooltip(FRAMES[id].role); end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();

    imgui.TextColored(GOLD, 'Plan  (click to take off)');
    imgui.BeginChild('##pup_plan', { 350, 230 }, true);
    local drop = nil;
    for i, id in ipairs(plan.att) do
        local a = A[id];
        if a then imgui.TextColored(EL[a[1]].col, '*'); imgui.SameLine(0, 4); end
        if imgui.Selectable(att_label(id) .. '##pup_p' .. i) then drop = i; end
        att_tip(id);
        if a then imgui.SameLine(190); imgui.TextColored(DIM, a[3]); end
    end
    if #plan.att == 0 then imgui.TextDisabled('Empty - click attachments on the right, or pick a build.'); end
    imgui.EndChild();
    if drop then table.remove(plan.att, drop); end

    capacity_bars(plan);

    -- Equip and saves
    if EQ.active then
        imgui.TextColored(GOLD, EQ.msg or 'Working...');
    else
        imgui.PushStyleColor(ImGuiCol_Button, { 0.20, 0.45, 0.25, 1 });
        if imgui.Button('Equip this plan##pup_eq', { 170, 0 }) then start_equip(plan); end
        imgui.PopStyleColor(1);
        if imgui.IsItemHovered() then imgui.SetTooltip('Deactivate, put the plan on, then Activate (or Deus Ex Automata).'); end
        imgui.SameLine(0, 6);
        if imgui.Button('Clear##pup_clr') then plan.att = {}; end
        if EQ.msg then imgui.TextColored(EQ.ok and GREEN or RED, EQ.msg); end
    end
    local s = S();
    if s then
        imgui.Text('My sets:');
        for n = 1, 5 do
            local saved = s.pup_sets[n];
            imgui.SameLine(0, 4);
            local lbl = saved and (saved.name or ('Set ' .. n)) or ('(' .. n .. ')');
            if imgui.Button(lbl .. '##pup_ld' .. n) then
                if saved then UI.plan = copy_plan(saved); UI.build = nil; plan = UI.plan; note('Loaded ' .. lbl .. '.'); end
            end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(saved and (hf_name(saved.head) .. ' / ' .. hf_name(saved.frame) .. ', ' .. #saved.att .. ' attachments\nRight-click: save the plan here') or 'Right-click: save the plan here');
            end
            if imgui.IsItemClicked(1) then
                local c = copy_plan(plan);
                c.name = UI.build and UI.build.name or ('Set ' .. n);
                s.pup_sets[n] = c; save(); note('Saved to slot ' .. n .. '.');
            end
        end
        if UI.note and os.clock() - UI.note_at < 3 then imgui.TextColored(GREEN, UI.note); end
    end
    imgui.EndGroup();

    -- Right: attachments you can add, and the maneuver guide
    imgui.SameLine(0, 14);
    imgui.BeginGroup();
    if imgui.BeginTabBar('##pup_right') then
        if imgui.BeginTabItem('Attachments##pup_r1') then
            if imgui.SmallButton((UI.filter == 0 and '[All]' or 'All') .. '##pup_f0') then UI.filter = 0; end
            for e = 1, 8 do
                imgui.SameLine(0, 4);
                imgui.PushStyleColor(ImGuiCol_Text, EL[e].col);
                if imgui.SmallButton((UI.filter == e and '[' .. EL[e].name .. ']' or EL[e].name) .. '##pup_f' .. e) then UI.filter = e; end
                imgui.PopStyleColor(1);
            end
            imgui.BeginChild('##pup_list', { 380, 360 }, true);
            local ids = {};
            for id in pairs(A) do if (UI.filter == 0 or A[id][1] == UI.filter) then ids[#ids + 1] = id; end end
            table.sort(ids);
            local learned_any = false;
            for _, id in ipairs(ids) do
                local learned = not ST.ok or ST.att[id];
                if learned then
                    learned_any = true;
                    local why = refuse_reason(plan, id);
                    local a = A[id];
                    imgui.TextColored(EL[a[1]].col, '*'); imgui.SameLine(0, 4);
                    if why then imgui.PushStyleColor(ImGuiCol_Text, DIM); end
                    if imgui.Selectable(att_label(id) .. '##pup_a' .. id) then
                        if why then note(att_name(id) .. ': ' .. why); else plan.att[#plan.att + 1] = id; end
                    end
                    if why then imgui.PopStyleColor(1); end
                    att_tip(id);
                    imgui.SameLine(190); imgui.TextColored(DIM, a[3]);
                end
            end
            if not learned_any then imgui.TextDisabled('No learned attachments here.'); end
            imgui.EndChild();
            imgui.TextDisabled('Greyed out = would not fit or already in. Hover for details.');
            imgui.EndTabItem();
        end
        if imgui.BeginTabItem('Maneuvers##pup_r2') then
            imgui.BeginChild('##pup_man', { 380, 380 }, true);
            maneuvers(plan);
            imgui.EndChild();
            imgui.EndTabItem();
        end
        if imgui.BeginTabItem('Head / Frame##pup_r3') then
            imgui.BeginChild('##pup_hf', { 380, 380 }, true);
            imgui.TextColored(GOLD, hf_name(plan.head));
            imgui.TextWrapped(HEADS[plan.head] and HEADS[plan.head].role or '');
            imgui.TextColored(GOLD, hf_name(plan.frame));
            imgui.TextWrapped(FRAMES[plan.frame] and FRAMES[plan.frame].role or '');
            imgui.Separator();
            imgui.TextColored(GOLD, 'Capacity (head + frame' .. ((ST.bonus or 0) > 0 and (' + ' .. ST.bonus .. ' bonus') or '') .. ')');
            local cap = caps_of(plan.head, plan.frame);
            for e = 1, 8 do
                imgui.TextColored(EL[e].col, EL[e].name); imgui.SameLine(80); imgui.Text(tostring(cap[e]));
            end
            imgui.EndChild();
            imgui.EndTabItem();
        end
        imgui.EndTabBar();
    end
    imgui.EndGroup();

    pup.height = imgui.GetCursorPosY() - y0 + 20;
end

pup.equip_plan = function () if UI.plan then start_equip(UI.plan); end end
return pup;
