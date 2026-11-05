--[[
    omni_blu.lua - Blue Magic: click-to-set BLU spells (Gear > Blue Magic).

    * Shows the spells you have set now, the set points used / available and the job traits
      they give you (with how far you are from the next tier).
    * A plan you build by clicking: click a spell on the right to add it, click it in the plan to
      take it off. Unlearned spells, a full plan (20) or not enough points are refused with the reason.
    * Ready sets (Cleave, Magic Burst, Physical TP, Tank, Healer, Debuff/Sleep, Solo). Each is a
      list of spells, best first, fitted to what you have learned and to YOUR set points, so you
      always get a set you can actually put on. Spells you're missing are listed.
    * Your blusets sets: every .txt in config\addons\blusets (cleave, Aby, EIN...) shows up as a button
      and can be loaded; the plan can be saved back as a blusets file, so both addons share them.
    * Set: only what changes is sent (spells that stay where they are aren't touched), one change a
      second, the same safe way blusets' "safe" mode does it. Changing spells locks blue magic for
      about 60 seconds - that's the game, not omni.

    How it works: the client keeps your set spells in the same buffer PUP attachments use, and changes
    them with its own extended-equip function (job type 0x1000, spell id - 512). Both, and the set
    points, are found by signature scan - the method atom0s' blusets uses. The code here is omni's own.
    Spell facts (set points, levels, traits and the CatsEyeXI-only spells) match the CatsEyeXI data that
    bludex publishes and LandSandBoat's blue_spell_list.
]]--

local imgui = require('imgui');
local ffi   = require('ffi');

local blu = {};
blu.height = 600;
blu.get_settings = nil;

local BLU_JOB = 16;

-- [spell id] = { name, level, set points, kind (O offensive, B buff, D debuff, H healing),
--                type (P physical, M magical, B breath, R ranged), aoe, trait category, trait weight, skillchain }
local SP = {
    [513] = { 'Venom Shell', 42, 3, 'D', 'M', true, 4, 1, nil },
    [515] = { 'Maelstrom', 61, 5, 'O', 'M', true, 4, 1, nil },
    [517] = { 'Metallic Body', 8, 1, 'B', 'M', true, 10, 1, nil },
    [519] = { 'Screwdriver', 26, 3, 'O', 'P', false, 18, 1, { 'Transfixion', 'Scission' } },
    [521] = { 'MP Drainkiss', 42, 4, 'O', 'M', false, 0, 0, nil },
    [522] = { 'Death Ray', 34, 2, 'O', 'M', false, 0, 0, nil },
    [524] = { 'Sandspin', 1, 2, 'O', 'M', true, 0, 0, nil },
    [527] = { 'Smite of Rage', 34, 3, 'O', 'P', false, 7, 1, { 'Detonation' } },
    [529] = { 'Bludgeon', 18, 2, 'O', 'P', false, 7, 1, { 'Liquefaction' } },
    [530] = { 'Refueling', 48, 4, 'B', 'M', true, 0, 0, nil },
    [531] = { 'Ice Break', 50, 3, 'O', 'M', true, 13, 1, nil },
    [532] = { 'Blitzstrahl', 44, 4, 'O', 'M', false, 0, 0, nil },
    [533] = { 'Self-Destruct', 50, 3, 'O', 'M', true, 14, 2, nil },
    [534] = { 'Mysterious Light', 40, 4, 'O', 'M', true, 10, 1, nil },
    [535] = { 'Cold Wave', 52, 1, 'D', 'M', true, 14, 1, nil },
    [536] = { 'Poison Breath', 22, 1, 'O', 'B', true, 4, 1, nil },
    [537] = { 'Stinking Gas', 44, 2, 'D', 'M', true, 14, 1, nil },
    [538] = { 'Memento Mori', 62, 4, 'B', 'M', true, 6, 1, nil },
    [539] = { 'Terror Touch', 40, 3, 'O', 'P', false, 11, 1, { 'Compression', 'Reverberation' } },
    [540] = { 'Spinal Cleave', 63, 4, 'O', 'P', false, 8, 1, { 'Scission', 'Detonation' } },
    [541] = { 'Blood Saber', 48, 2, 'O', 'M', true, 0, 0, nil },
    [542] = { 'Digest', 36, 2, 'O', 'M', false, 0, 0, nil },
    [543] = { 'Mandibular Bite', 44, 2, 'O', 'P', false, 12, 1, { 'Induration' } },
    [544] = { 'Cursed Sphere', 18, 2, 'O', 'M', true, 6, 1, nil },
    [545] = { 'Sickle Slash', 48, 4, 'O', 'P', false, 20, 1, { 'Compression' } },
    [547] = { 'Cocoon', 8, 1, 'B', 'M', true, 0, 0, nil },
    [548] = { 'Filamented Hold', 52, 3, 'D', 'M', true, 4, 1, nil },
    [549] = { 'Pollen', 1, 1, 'H', 'M', false, 5, 1, nil },
    [551] = { 'Power Attack', 4, 1, 'O', 'P', false, 12, 1, { 'Reverberation' } },
    [554] = { 'Death Scissors', 60, 5, 'O', 'P', false, 8, 1, { 'Compression', 'Reverberation' } },
    [555] = { 'Magnetite Cloud', 46, 3, 'O', 'B', true, 13, 1, nil },
    [557] = { 'Eyes On Me', 61, 4, 'O', 'M', false, 6, 1, nil },
    [560] = { 'Frenetic Rip', 63, 3, 'O', 'P', false, 16, 1, { 'Induration' } },
    [561] = { 'Frightful Roar', 50, 3, 'D', 'M', true, 14, 2, nil },
    [563] = { 'Hecatomb Wave', 54, 3, 'O', 'B', true, 10, 1, nil },
    [564] = { 'Body Slam', 62, 4, 'O', 'P', true, 15, 1, { 'Impaction' } },
    [565] = { 'Radiant Breath', 54, 4, 'O', 'B', true, 0, 0, nil },
    [567] = { 'Helldive', 16, 2, 'O', 'P', false, 0, 0, { 'Transfixion' } },
    [569] = { 'Jet Stream', 38, 4, 'O', 'P', false, 9, 1, { 'Impaction' } },
    [570] = { 'Blood Drain', 20, 2, 'O', 'M', false, 0, 0, nil },
    [572] = { 'Sound Blast', 32, 1, 'D', 'M', true, 6, 1, nil },
    [573] = { 'Feather Tickle', 64, 3, 'D', 'M', true, 4, 1, nil },
    [574] = { 'Feather Barrier', 56, 2, 'B', 'M', false, 19, 1, nil },
    [575] = { 'Jettatura', 48, 4, 'D', 'M', true, 0, 0, nil },
    [576] = { 'Yawn', 64, 3, 'D', 'M', true, 5, 1, nil },
    [577] = { 'Foot Kick', 1, 2, 'O', 'P', false, 3, 1, { 'Detonation' } },
    [578] = { 'Wild Carrot', 30, 3, 'H', 'M', false, 5, 1, nil },
    [579] = { 'Voracious Trunk', 64, 4, 'D', 'M', false, 14, 3, nil },
    [581] = { 'Healing Breeze', 16, 4, 'H', 'M', true, 2, 1, nil },
    [582] = { 'Chaotic Eye', 32, 2, 'D', 'M', false, 17, 1, nil },
    [584] = { 'Sheep Song', 16, 2, 'D', 'M', true, 2, 1, nil },
    [585] = { 'Ram Charge', 73, 4, 'O', 'P', false, 3, 1, { 'Fragmentation' } },
    [587] = { 'Claw Cyclone', 20, 2, 'O', 'P', true, 3, 1, { 'Scission' } },
    [588] = { 'Lowing', 71, 2, 'D', 'M', true, 4, 1, nil },
    [589] = { 'Dimensional Death', 60, 5, 'O', 'P', false, 16, 1, { 'Transfixion', 'Impaction' } },
    [591] = { 'Heat Breath', 71, 4, 'O', 'B', true, 6, 1, nil },
    [592] = { 'Blank Gaze', 38, 2, 'D', 'M', false, 0, 0, nil },
    [593] = { 'Magic Fruit', 58, 3, 'H', 'M', false, 5, 1, nil },
    [594] = { 'Uppercut', 38, 3, 'O', 'P', false, 8, 1, { 'Liquefaction', 'Impaction' } },
    [595] = { '1000 Needles', 62, 5, 'O', 'M', true, 1, 1, nil },
    [596] = { 'Pinecone Bomb', 36, 2, 'O', 'R', false, 0, 0, { 'Liquefaction' } },
    [597] = { 'Sprout Smack', 4, 2, 'O', 'P', false, 1, 1, { 'Reverberation' } },
    [598] = { 'Soporific', 24, 4, 'D', 'M', true, 4, 1, nil },
    [599] = { 'Queasyshroom', 8, 2, 'O', 'R', false, 0, 0, { 'Compression' } },
    [603] = { 'Wild Oats', 4, 3, 'O', 'P', false, 1, 1, { 'Transfixion' } },
    [604] = { 'Bad Breath', 61, 5, 'O', 'B', true, 22, 1, nil },
    [605] = { 'Geist Wall', 46, 3, 'D', 'M', true, 0, 0, nil },
    [606] = { 'Awful Eye', 46, 2, 'D', 'M', true, 4, 1, nil },
    [608] = { 'Frost Breath', 66, 3, 'O', 'B', true, 17, 1, nil },
    [610] = { 'Infrasonics', 65, 4, 'D', 'M', true, 0, 0, nil },
    [611] = { 'Disseverment', 72, 5, 'O', 'P', false, 16, 1, { 'Distortion' } },
    [612] = { 'Actinic Burst', 74, 4, 'D', 'M', true, 14, 4, nil },
    [613] = { 'Reactor Cool', 74, 5, 'B', 'M', true, 6, 1, nil },
    [614] = { 'Saline Coat', 72, 3, 'B', 'M', true, 11, 1, nil },
    [615] = { 'Plasma Charge', 75, 5, 'B', 'M', true, 14, 4, nil },
    [616] = { 'Temporal Shift', 73, 5, 'D', 'M', true, 8, 1, nil },
    [617] = { 'Vertical Cleave', 75, 3, 'O', 'P', false, 11, 1, { 'Gravitation' } },
    [618] = { 'Blast Bomb', 18, 2, 'O', 'M', true, 0, 0, nil },
    [620] = { 'Battle Dance', 12, 3, 'O', 'P', true, 8, 1, { 'Impaction' } },
    [621] = { 'Sandspray', 66, 2, 'D', 'M', true, 4, 1, nil },
    [622] = { 'Grand Slam', 30, 2, 'O', 'P', true, 11, 1, { 'Induration' } },
    [623] = { 'Head Butt', 12, 3, 'O', 'P', false, 0, 0, { 'Impaction' } },
    [626] = { 'Bomb Toss', 28, 3, 'O', 'M', true, 0, 0, nil },
    [628] = { 'Frypan', 63, 3, 'O', 'P', true, 15, 1, { 'Impaction' } },
    [629] = { 'Flying Hip Press', 58, 3, 'O', 'B', true, 15, 1, nil },
    [631] = { 'Hydro Shot', 63, 3, 'O', 'P', false, 9, 1, { 'Reverberation' } },
    [632] = { 'Diamondhide', 67, 3, 'B', 'M', true, 0, 0, nil },
    [633] = { 'Enervation', 67, 5, 'D', 'M', true, 21, 1, nil },
    [634] = { 'Light of Penance', 58, 5, 'D', 'M', false, 14, 2, nil },
    [636] = { 'Warm-Up', 68, 4, 'B', 'M', true, 4, 1, nil },
    [637] = { 'Firespit', 68, 5, 'O', 'M', false, 17, 1, nil },
    [638] = { 'Feather Storm', 12, 3, 'O', 'R', false, 9, 1, { 'Transfixion' } },
    [640] = { 'Tail Slap', 69, 4, 'O', 'P', true, 20, 1, { 'Reverberation' } },
    [641] = { 'Hysteric Barrage', 69, 5, 'O', 'P', false, 18, 1, { 'Detonation' } },
    [642] = { 'Amplification', 70, 3, 'B', 'M', true, 0, 0, nil },
    [643] = { 'Cannonball', 70, 3, 'O', 'P', false, 0, 0, { 'Fusion' } },
    [644] = { 'Mind Blast', 73, 4, 'O', 'M', false, 4, 1, nil },
    [645] = { 'Exuviation', 75, 4, 'H', 'M', true, 5, 1, nil },
    [646] = { 'Magic Hammer', 74, 4, 'O', 'M', false, 6, 1, nil },
    [647] = { 'Zephyr Mantle', 65, 2, 'B', 'M', true, 17, 1, nil },
    [648] = { 'Regurgitation', 69, 1, 'O', 'M', false, 19, 1, nil },
    [650] = { 'Seedspray', 61, 2, 'O', 'P', false, 1, 1, { 'Induration', 'Detonation' } },
    [651] = { 'Corrosive Ooze', 66, 4, 'O', 'M', false, 4, 1, nil },
    [652] = { 'Spiral Spin', 60, 3, 'O', 'P', false, 12, 1, { 'Transfixion' } },
    [653] = { 'Asuran Claws', 70, 2, 'O', 'P', false, 21, 1, { 'Liquefaction', 'Impaction' } },
    [654] = { 'Sub-zero Smash', 72, 4, 'O', 'P', true, 22, 1, { 'Fragmentation' } },
    [655] = { 'Triumphant Roar', 71, 3, 'B', 'M', true, 0, 0, nil },
    [656] = { 'Acrid Stream', 75, 3, 'O', 'M', true, 24, 1, nil },
    [657] = { 'Blazing Bound', 75, 3, 'O', 'M', false, 25, 1, nil },
    [658] = { 'Plenilune Embrace', 75, 4, 'H', 'M', false, 0, 0, nil },
    [659] = { 'Demoralizing Roar', 75, 4, 'D', 'M', true, 24, 1, nil },
    [661] = { 'Animating Wail', 75, 5, 'B', 'M', true, 25, 1, nil },
    [662] = { 'Battery Charge', 75, 3, 'B', 'M', true, 0, 0, nil },
    [668] = { 'Magic Barrier', 75, 3, 'B', 'M', true, 10, 1, nil },
    [672] = { 'Osmosis', 75, 5, 'O', 'M', false, 13, 1, nil },
    [673] = { 'Quad Continuum', 75, 4, 'O', 'P', false, 25, 1, { 'Distortion', 'Scission' } },
    [677] = { 'Empty Thrash', 75, 3, 'O', 'P', true, 24, 1, { 'Compression', 'Scission' } },
    [679] = { 'Occultation', 75, 3, 'B', 'M', true, 18, 1, nil },
    [685] = { 'Barrier Tusk', 75, 3, 'B', 'M', false, 15, 1, nil },
    [688] = { 'Heavy Strike', 75, 2, 'O', 'P', false, 24, 1, { 'Fragmentation', 'Transfixion' } },
    [696] = { 'O. Counterstance', 75, 5, 'B', 'M', false, 21, 1, nil },
    [699] = { 'Barbed Crescent', 75, 2, 'O', 'P', false, 25, 1, { 'Distortion', 'Scission' } },
    [706] = { 'Glutinous Dart', 75, 2, 'O', 'P', false, 15, 8, { 'Fragmentation' } },
    [719] = { 'Searing Tempest', 75, 8, 'O', 'M', false, 0, 0, nil },
    [720] = { 'Spectral Floe', 75, 8, 'O', 'M', false, 0, 0, nil },
    [721] = { 'Anvil Lightning', 75, 8, 'O', 'M', false, 0, 0, nil },
    [722] = { 'Entomb', 75, 8, 'O', 'M', false, 0, 0, nil },
    [725] = { 'Blinding Fulgor', 75, 8, 'D', 'M', false, 0, 0, nil },
    [726] = { 'Scouring Spate', 75, 8, 'O', 'M', false, 0, 0, nil },
    [727] = { 'Silent Storm', 75, 8, 'O', 'M', false, 0, 0, nil },
    [728] = { 'Tenebral Crush', 75, 8, 'O', 'M', false, 0, 0, nil },
};

-- [trait category] = { name, points needed for each tier }
local TR = {
    [1] = { 'Beast Killer', { 2 } },
    [2] = { 'Auto Regen', { 2 } },
    [3] = { 'Lizard Killer', { 2 } },
    [4] = { 'Clear Mind', { 2, 4, 6, 8 } },
    [5] = { 'Resist Sleep', { 2 } },
    [6] = { 'Magic Atk. Bonus', { 2 } },
    [7] = { 'Undead Killer', { 2 } },
    [8] = { 'Attack Bonus', { 2 } },
    [9] = { 'Rapid Shot', { 2 } },
    [10] = { 'Max MP Boost', { 2, 4 } },
    [11] = { 'Defense Bonus', { 2 } },
    [12] = { 'Plantoid Killer', { 2 } },
    [13] = { 'Magic Def. Bonus', { 2 } },
    [14] = { 'Auto Refresh', { 8 } },
    [15] = { 'Max HP Boost', { 8, 16, 24, 32 } },
    [16] = { 'Accuracy Bonus', { 2 } },
    [17] = { 'Conserve MP', { 2 } },
    [18] = { 'Evasion Bonus', { 2 } },
    [19] = { 'Resist Gravity', { 2 } },
    [20] = { 'Store TP', { 2, 4 } },
    [21] = { 'Counter', { 2 } },
    [22] = { 'Fast Cast', { 2, 4 } },
    [23] = { 'Skillchain Bonus', { 2 } },
    [24] = { 'Double Attack', { 2, 4 } },
    [25] = { 'Dual Wield', { 2, 4, 6 } },
    [26] = { 'Zanshin', { 2 } },
    [27] = { 'Magic Burst Bonus', { 2 } },
    [28] = { 'Gilfinder', { 2, 3 } },
};

local KIND = { O = 'Damage', B = 'Buff', D = 'Debuff', H = 'Healing' };
local TYPE = { P = 'Physical', M = 'Magical', B = 'Breath', R = 'Ranged' };
local KCOL = {
    O = { 1.00, 0.55, 0.45, 1 }, B = { 0.55, 0.85, 1.00, 1 }, D = { 0.80, 0.60, 1.00, 1 }, H = { 0.50, 0.95, 0.55, 1 },
};
local GOLD, DIM, RED, GREEN = { 0.95, 0.80, 0.45, 1 }, { 0.62, 0.62, 0.70, 1 }, { 1, 0.45, 0.45, 1 }, { 0.50, 0.95, 0.55, 1 };

local function norm(s) return (tostring(s or ''):lower():gsub('[^%a%d]', '')); end
local BYNAME = {};
for id, s in pairs(SP) do BYNAME[norm(s[1])] = id; end

----------------------------------------------------------------------------------------------------
-- Ready sets: spells best first. The fitter takes what you've learned and what still fits.
----------------------------------------------------------------------------------------------------
local BUILDS = {
    { name = 'Cleave', desc = 'AoE magic for pulling packs (Bibiki Bay style): magic attack traits, AoE nukes, Temporal Shift / Actinic Burst to stop the pack, and your buffs and heals to stay up.',
      spells = { 'Sound Blast', 'Cold Wave', 'Memento Mori', 'Cursed Sphere', 'Eyes On Me', 'Magic Hammer', 'Temporal Shift',
                 'Actinic Burst', 'Battery Charge', 'Animating Wail', 'Metallic Body', 'Cocoon', 'Barrier Tusk', 'Diamondhide',
                 'Magic Fruit', 'Healing Breeze', 'Mysterious Light', 'Ice Break', 'Maelstrom', 'Acrid Stream', 'Blood Saber',
                 'Spectral Floe', 'Tenebral Crush', 'Anvil Lightning', 'Entomb', 'Reactor Cool', 'Enervation', 'Plasma Charge' } },
    { name = 'Magic Burst', desc = 'Single-target nuking and magic bursts: the CatsEyeXI 8-point nukes, Magic Attack Bonus, MP from Magic Hammer.',
      spells = { 'Sound Blast', 'Cold Wave', 'Memento Mori', 'Cursed Sphere', 'Eyes On Me', 'Magic Hammer', 'Spectral Floe',
                 'Tenebral Crush', 'Anvil Lightning', 'Entomb', 'Searing Tempest', 'Scouring Spate', 'Silent Storm',
                 'Battery Charge', 'Magic Fruit', 'Cocoon', 'Metallic Body', 'Reactor Cool', 'Regurgitation', 'Firespit',
                 'Blinding Fulgor', 'Animating Wail', 'Plasma Charge' } },
    { name = 'Physical TP', desc = 'Melee and physical spells: Dual Wield, Double Attack, Store TP, Accuracy and Attack traits, the strongest physical spells, and haste.',
      spells = { 'Animating Wail', 'Quad. Continuum', 'Barbed Crescent', 'Blazing Bound', 'Empty Thrash', 'Heavy Strike',
                 'Sickle Slash', 'Tail Slap', 'Frenetic Rip', 'Dimensional Death', 'Disseverment', 'Death Scissors',
                 'Spinal Cleave', 'Vertical Cleave', 'Hysteric Barrage', 'Sub-zero Smash', 'Asuran Claws', 'Head Butt',
                 'Cocoon', 'Metallic Body', 'Magic Fruit', 'Refueling', 'Battery Charge', 'Uppercut', 'Battle Dance',
                 'Acrid Stream', 'Demoralizing Roar', 'Occultation' } },
    { name = 'Tank', desc = 'Holding hate and taking hits: defence and HP traits, Cocoon / Diamondhide / Barrier Tusk / Occultation, AoE sleeps and stuns, enmity spells and heals.',
      spells = { 'Cocoon', 'Metallic Body', 'Diamondhide', 'Barrier Tusk', 'Occultation', 'Magic Barrier', 'Saline Coat',
                 'Jettatura', 'Blank Gaze', 'Geist Wall', 'Actinic Burst', 'Temporal Shift', 'Sheep Song', 'Soporific',
                 'Head Butt', 'Magic Fruit', 'Healing Breeze', 'Wild Carrot', 'Exuviation', 'Glutinous Dart', 'Body Slam',
                 'Frypan', 'Terror Touch', 'Vertical Cleave', 'Grand Slam', 'Claw Cyclone', 'Frightful Roar', 'Light of Penance' } },
    { name = 'Healer', desc = 'Support: every heal you have, Battery Charge / Refueling / Animating Wail for the party side, defence buffs and sleeps for safety.',
      spells = { 'Magic Fruit', 'Healing Breeze', 'Wild Carrot', 'Plenilune Embrace', 'Exuviation', 'Pollen', 'Battery Charge',
                 'Animating Wail', 'Refueling', 'Cocoon', 'Metallic Body', 'Diamondhide', 'Barrier Tusk', 'Magic Barrier',
                 'Occultation', 'Sheep Song', 'Soporific', 'Yawn', 'Cold Wave', 'Frightful Roar', 'Plasma Charge',
                 'Actinic Burst', 'Saline Coat' } },
    { name = 'Debuff / Sleep', desc = 'Crowd control and enfeebles: AoE sleeps, stuns, flash, Slow/Paralyze/Silence style spells and stat downs, plus Auto Refresh.',
      spells = { 'Sheep Song', 'Soporific', 'Yawn', 'Temporal Shift', 'Actinic Burst', 'Head Butt', 'Sound Blast', 'Cold Wave',
                 'Frightful Roar', 'Infrasonics', 'Filamented Hold', 'Feather Tickle', 'Lowing', 'Sandspray', 'Awful Eye',
                 'Venom Shell', 'Stinking Gas', 'Geist Wall', 'Blank Gaze', 'Jettatura', 'Light of Penance', 'Enervation',
                 'Demoralizing Roar', 'Blinding Fulgor', 'Magic Fruit', 'Cocoon', 'Battery Charge', 'Plasma Charge' } },
    { name = 'Solo', desc = 'Levelling alone: a few big physical spells, a couple of nukes, heals, defence buffs and a sleep / stun to get out of trouble.',
      spells = { 'Magic Fruit', 'Cocoon', 'Metallic Body', 'Head Butt', 'Animating Wail', 'Refueling', 'Battery Charge',
                 'Quad. Continuum', 'Empty Thrash', 'Heavy Strike', 'Disseverment', 'Sub-zero Smash', 'Frenetic Rip',
                 'Sickle Slash', 'Tail Slap', 'Healing Breeze', 'Wild Carrot', 'Sheep Song', 'Diamondhide', 'Barrier Tusk',
                 'Spectral Floe', 'Tenebral Crush', 'Magic Hammer', 'Occultation', 'Death Scissors', 'Vertical Cleave' } },
};

----------------------------------------------------------------------------------------------------
-- Game memory
----------------------------------------------------------------------------------------------------
pcall(ffi.cdef, [[
    typedef uint8_t (__cdecl *omni_blu_equipex_t)(uint8_t isSubJob, uint16_t jobType, uint16_t index, uint8_t id);
]]);
local MEM = { ok = false };
pcall(function ()
    local a = ashita.memory.find('FFXiMain.dll', 0, 'C1E1032BC8B0018D????????????B9????????F3A55F5E5B', 10, 0);
    local p = ashita.memory.find('FFXiMain.dll', 0, 'A1????????33C98A4E5E33D28A565D5F5E8950148948185B83C414C20400', 1, 0);
    local b = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????81EC9C00000085C95356570F??????????8B', 0, 0);
    if a ~= nil and a ~= 0 and b ~= nil and b ~= 0 then
        MEM.offset  = ffi.cast('uint32_t*', a);
        MEM.equipex = ffi.cast('omni_blu_equipex_t', b);
        if p ~= nil and p ~= 0 then MEM.points = ffi.cast('uint8_t***', p); end
        MEM.ok = true;
    end
end);

local function player() return AshitaCore:GetMemoryManager():GetPlayer(); end
local function is_main() return player():GetMainJob() == BLU_JOB; end
local function is_sub() return player():GetSubJob() == BLU_JOB; end
local function blu_level()
    local p = player();
    if p:GetMainJob() == BLU_JOB then return p:GetMainJobLevel(); end
    if p:GetSubJob() == BLU_JOB then return p:GetSubJobLevel(); end
    return 0;
end
local function slot_limit()
    local l = blu_level();
    if l <= 0 then return 20; end
    return math.min(20, 6 + 2 * math.floor((l - 1) / 10));
end

-- The 20 set spells now: { [slot 1-20] = spell id or 0 }
local function current()
    local out = {};
    if not MEM.ok or not (is_main() or is_sub()) then return nil; end
    local ok = pcall(function ()
        local ptr = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('inventory'));
        if ptr == 0 then error('no inventory'); end
        ptr = ashita.memory.read_uint32(ptr);
        if ptr == 0 then error('no buffer'); end
        local arr = ashita.memory.read_array(ptr + MEM.offset[0] + (is_main() and 0x04 or 0xA0), 0x14);
        for i = 1, 20 do
            local v = arr[i] or 0;
            out[i] = (v ~= 0) and (v + 512) or 0;
        end
    end);
    return ok and out or nil;
end
local function points()
    local used, max = nil, nil;
    if MEM.points then
        pcall(function () used, max = MEM.points[0][0][0x14], MEM.points[0][0][0x18]; end);
    end
    return used, max;
end
local function learned(id)
    local ok, v = pcall(function () return player():HasSpell(id); end);
    return ok and v == true;
end
local NAMES = {};
local function name_of(id)
    if NAMES[id] then return NAMES[id]; end
    local n = nil;
    pcall(function ()
        local s = AshitaCore:GetResourceManager():GetSpellById(id);
        if s and s.Name and s.Name[1] and s.Name[1] ~= '' then n = s.Name[1]; end
    end);
    NAMES[id] = n or (SP[id] and SP[id][1]) or ('#' .. id);
    return NAMES[id];
end
local function id_of(name)
    local id = BYNAME[norm(name)];
    if id then return id; end
    pcall(function ()
        local s = AshitaCore:GetResourceManager():GetSpellByName(name, 0);
        if s and s.Index and s.Index >= 512 and s.Index < 1024 then id = s.Index; end
    end);
    return id;
end

----------------------------------------------------------------------------------------------------
-- Plans, points, traits
----------------------------------------------------------------------------------------------------
local function cost(list) local c = 0; for _, id in ipairs(list) do c = c + (SP[id] and SP[id][3] or 0); end return c; end
local function has(list, id) for _, v in ipairs(list) do if v == id then return true; end end return false; end
local function max_points()
    local _, m = points();
    return (m and m > 0) and m or nil;
end

local function refuse_reason(plan, id)
    if has(plan, id) then return 'already in the plan'; end
    if #plan >= slot_limit() then return 'all ' .. slot_limit() .. ' slots are full'; end
    if not learned(id) then return 'not learned yet'; end
    local s = SP[id];
    if s and s[2] > blu_level() and blu_level() > 0 then return 'needs level ' .. s[2]; end
    local m = max_points();
    if m and s and cost(plan) + s[3] > m then return string.format('needs %d points, %d left', s[3], m - cost(plan)); end
    return nil;
end

local function fit(build)
    local plan, missing = {}, {};
    for _, nm in ipairs(build.spells) do
        local id = id_of(nm);
        if id then
            if not learned(id) then
                missing[#missing + 1] = name_of(id);
            elseif refuse_reason(plan, id) == nil then
                plan[#plan + 1] = id;
            end
        end
    end
    return plan, missing;
end

-- { { name, have, next tier points or nil, tier reached, tiers } } for the categories the plan touches
local function traits(plan)
    local w = {};
    for _, id in ipairs(plan) do
        local s = SP[id];
        if s and s[7] and s[7] > 0 then w[s[7]] = (w[s[7]] or 0) + (s[8] > 0 and s[8] or 1); end
    end
    local out = {};
    for cat, have in pairs(w) do
        local t = TR[cat];
        if t then
            local tier, nxt = 0, nil;
            for i, need in ipairs(t[2]) do
                if have >= need then tier = i; elseif nxt == nil then nxt = need; end
            end
            out[#out + 1] = { name = t[1], have = have, tier = tier, next = nxt, tiers = #t[2] };
        end
    end
    table.sort(out, function (a, b) if (a.tier > 0) ~= (b.tier > 0) then return a.tier > 0; end return a.name < b.name; end);
    return out;
end

-- Auto trait: add learned spells of trait category cat to the plan to reach its highest tier, using
-- the fewest set points (or as high a tier as the free slots / points allow). Returns added names, message.
local function weight(id) local s = SP[id]; return (s and s[8] and s[8] > 0) and s[8] or 1; end
local function max_trait(plan, cat)
    local t = TR[cat];
    if not t then return nil, 'Unknown trait.'; end
    local have = 0;
    for _, id in ipairs(plan) do if SP[id] and SP[id][7] == cat then have = have + weight(id); end end
    local top = t[2][#t[2]];
    if have >= top then return {}, t[1] .. ' is already at its highest tier.'; end
    local cand = {};
    for id, s in pairs(SP) do
        if s[7] == cat and not has(plan, id) and learned(id) and not (blu_level() > 0 and s[2] > blu_level()) then
            cand[#cand + 1] = id;
        end
    end
    if #cand == 0 then return {}, 'You have no other learned spells with ' .. t[1] .. '.'; end
    table.sort(cand, function (a, b) return SP[a][3] < SP[b][3]; end);
    while #cand > 16 do table.remove(cand); end              -- (keeps the search small; cheapest first)
    local m = max_points();
    local free_pts = m and (m - cost(plan)) or math.huge;
    local free_slots = slot_limit() - #plan;
    -- every subset: best = highest tier reached, then fewest points, then fewest spells
    local function tier_of(w) local k = 0; for i, need in ipairs(t[2]) do if w >= need then k = i; end end return k; end
    local best, best_key = nil, nil;
    for mask = 1, bit.lshift(1, #cand) - 1 do
        local pts, n, w, pick = 0, 0, have, {};
        for i = 1, #cand do
            if bit.band(bit.rshift(mask, i - 1), 1) == 1 then
                local id = cand[i];
                pts, n, w = pts + SP[id][3], n + 1, w + weight(id);
                pick[#pick + 1] = id;
            end
        end
        if pts <= free_pts and n <= free_slots then
            local tr = tier_of(w);
            local key = tr * 1000000 - pts * 100 - n;
            if tr > tier_of(have) and (best_key == nil or key > best_key) then best, best_key = pick, key; end
        end
    end
    if best == nil then
        return {}, string.format('No room: %s needs more free slots or set points (%d slots, %s points free).',
            t[1], free_slots, free_pts == math.huge and '?' or tostring(free_pts));
    end
    local names = {};
    for _, id in ipairs(best) do plan[#plan + 1] = id; names[#names + 1] = name_of(id); end
    local w = have; for _, id in ipairs(best) do w = w + weight(id); end
    local tr = tier_of(w);
    local msg = string.format('%s %s: added %s.', t[1], (#t[2] > 1) and ('tier ' .. tr .. ' of ' .. #t[2]) or 'on', table.concat(names, ', '));
    if tr < #t[2] then msg = msg .. ' (Highest you can reach with what you have and the free slots / points.)'; end
    return names, msg;
end

----------------------------------------------------------------------------------------------------
-- blusets files: config\addons\blusets\<name>.txt, one spell name per line
----------------------------------------------------------------------------------------------------
local function sets_dir() return string.format('%s\\config\\addons\\blusets\\', AshitaCore:GetInstallPath()); end
local FILES = { at = -10, list = {} };
local function list_files()
    if os.clock() - FILES.at < 3 then return FILES.list; end
    FILES.at, FILES.list = os.clock(), {};
    pcall(function ()
        local files = ashita.fs.get_dir(sets_dir(), '.*.txt', true) or {};
        for _, f in ipairs(files) do
            local n = tostring(f):gsub('%.txt$', '');
            FILES.list[#FILES.list + 1] = n;
        end
    end);
    table.sort(FILES.list, function (a, b) return a:lower() < b:lower(); end);
    return FILES.list;
end
local function load_file(n)
    local f = io.open(sets_dir() .. n .. '.txt', 'r');
    if not f then return nil, 'could not open ' .. n .. '.txt'; end
    local plan, bad = {}, {};
    for raw in f:lines() do
        local line = raw:gsub('\r', ''):gsub('^%s+', ''):gsub('%s+$', '');
        if line ~= '' then
            local id = id_of(line);
            if id and not has(plan, id) then plan[#plan + 1] = id; elseif not id then bad[#bad + 1] = line; end
        end
    end
    f:close();
    return plan, bad;
end
local function save_file(n, plan)
    pcall(function () if not ashita.fs.exists(sets_dir()) then ashita.fs.create_dir(sets_dir()); end end);
    local f = io.open(sets_dir() .. n .. '.txt', 'w');
    if not f then return false; end
    for _, id in ipairs(plan) do f:write(name_of(id) .. '\n'); end
    f:close();
    FILES.at = -10;
    return true;
end

----------------------------------------------------------------------------------------------------
-- Setting spells: unset what goes, then fill free slots with what comes. One change a second.
----------------------------------------------------------------------------------------------------
local EQ = { active = false };
local GAP = 1.1;
local function say(t) print('\30\68[omni Blue Magic]\30\01 ' .. t); end

local function start_set(plan)
    if EQ.active then return; end
    if not MEM.ok then EQ.ok, EQ.msg = false, 'Could not find the game\'s equip function (signature scan failed).'; return; end
    if not (is_main() or is_sub()) then EQ.ok, EQ.msg = false, 'Blue Mage has to be your main or support job.'; return; end
    local cur = current();
    if not cur then EQ.ok, EQ.msg = false, 'Could not read your set spells.'; return; end
    local m = max_points();
    if m and cost(plan) > m then EQ.ok, EQ.msg = false, string.format('Plan needs %d points, you have %d.', cost(plan), m); return; end
    for _, id in ipairs(plan) do
        if not learned(id) then EQ.ok, EQ.msg = false, name_of(id) .. ' is not learned.'; return; end
    end
    local want = {};
    for _, id in ipairs(plan) do want[id] = true; end
    local q, slots = {}, {};
    for i = 1, 20 do slots[i] = cur[i]; end
    for i = 1, 20 do
        if slots[i] ~= 0 and not want[slots[i]] then q[#q + 1] = { i, 0 }; slots[i] = 0; end
    end
    local have = {};
    for i = 1, 20 do if slots[i] ~= 0 then have[slots[i]] = true; end end
    for _, id in ipairs(plan) do
        if not have[id] then
            for i = 1, slot_limit() do
                if slots[i] == 0 then q[#q + 1] = { i, id }; slots[i] = id; have[id] = true; break; end
            end
        end
    end
    if #q == 0 then EQ.ok, EQ.msg = true, 'Those spells are already set.'; return; end
    EQ = { active = true, q = q, i = 0, wait = 0, msg = 'Starting...' };
end

local function tick()
    if not EQ.active then return; end
    local t = os.clock();
    if player():GetIsZoning() ~= 0 then EQ.active, EQ.ok, EQ.msg = false, false, 'Stopped: you zoned.'; say(EQ.msg); return; end
    if t < EQ.wait then return; end
    EQ.i = EQ.i + 1;
    local op = EQ.q[EQ.i];
    if op == nil then
        EQ.active, EQ.ok = false, true;
        EQ.msg = string.format('Done: %d change%s. Blue magic is locked for about a minute.', #EQ.q, #EQ.q == 1 and '' or 's');
        say(EQ.msg);
        return;
    end
    local ok, err = pcall(function ()
        MEM.equipex(is_main() and 0 or 1, 0x1000, op[1] - 1, op[2] == 0 and 0 or (op[2] - 512));
    end);
    if not ok then EQ.active, EQ.ok, EQ.msg = false, false, 'Setting failed: ' .. tostring(err); say(EQ.msg); return; end
    EQ.wait = t + GAP;
    EQ.msg = string.format('%s %d / %d: %s', op[2] == 0 and 'Removing' or 'Setting', EQ.i, #EQ.q, op[2] == 0 and 'slot ' .. op[1] or name_of(op[2]));
end
ashita.events.register('d3d_present', 'omni_blu_tick', function () pcall(tick); end);

----------------------------------------------------------------------------------------------------
-- Page
----------------------------------------------------------------------------------------------------
local UI = { plan = nil, kind = 'all', search = { '' }, build = nil, missing = nil, note = nil, note_at = 0, fname = { '' } };
local function note(t) UI.note, UI.note_at = t, os.clock(); end

local function spell_tip(id)
    local s = SP[id];
    if not s or not imgui.IsItemHovered() then return; end
    local tr = (s[7] and s[7] > 0 and TR[s[7]]) and string.format('\nTrait: %s (%d point%s)', TR[s[7]][1], s[8], s[8] == 1 and '' or 's') or '';
    local sc = s[9] and ('\nSkillchain: ' .. table.concat(s[9], ' / ')) or '';
    imgui.SetTooltip(string.format('%s\nLevel %d, %d set points\n%s %s%s%s%s%s', name_of(id), s[2], s[3], TYPE[s[5]] or '', KIND[s[4]] or '',
        s[6] and ' (AoE)' or '', tr, sc, learned(id) and '' or '\nNot learned yet'));
end

local function spell_row(id, label_id)
    local s = SP[id];
    imgui.TextColored(s and KCOL[s[4]] or DIM, '*'); imgui.SameLine(0, 4);
    local clicked = imgui.Selectable(string.format('%s (%d)##%s', name_of(id), s and s[3] or 0, label_id));
    spell_tip(id);
    if s then
        imgui.SameLine(200);
        imgui.TextColored(DIM, (TYPE[s[5]] or '') .. ' ' .. (KIND[s[4]] or '') .. (s[6] and ' AoE' or ''));
    end
    return clicked;
end

blu.render = function ()
    local y0 = imgui.GetCursorPosY();
    local cur = current();
    local used, max = points();
    if not (is_main() or is_sub()) then
        imgui.TextColored(DIM, 'Set Blue Mage as your main or support job to read and set spells.');
    elseif not MEM.ok then
        imgui.TextColored(RED, 'The game\'s blue magic data could not be found (signature scan failed) - only planning works.');
    end
    if UI.plan == nil then
        UI.plan = {};
        if cur then for i = 1, 20 do if cur[i] ~= 0 then UI.plan[#UI.plan + 1] = cur[i]; end end end
    end
    local plan = UI.plan;

    -- Now
    imgui.TextColored(GOLD, 'Set now:');
    imgui.SameLine(0, 8);
    if cur then
        local n, t = 0, {};
        for i = 1, 20 do if cur[i] ~= 0 then n = n + 1; t[#t + 1] = name_of(cur[i]); end end
        imgui.Text(string.format('%d spells, %s / %s points', n, used and tostring(used) or '?', max and tostring(max) or '?'));
        if imgui.IsItemHovered() then imgui.SetTooltip(#t > 0 and table.concat(t, '\n') or 'nothing set'); end
        imgui.SameLine(0, 10);
        if imgui.SmallButton('Load into plan##blu_cur') then
            UI.plan = {}; for i = 1, 20 do if cur[i] ~= 0 then UI.plan[#UI.plan + 1] = cur[i]; end end
            plan = UI.plan; UI.build, UI.missing = nil, nil;
        end
    else
        imgui.TextDisabled('(not readable)');
    end

    -- Ready sets
    imgui.TextColored(GOLD, 'Ready sets:');
    for i, b in ipairs(BUILDS) do
        imgui.SameLine(0, 6);
        if imgui.Button(b.name .. '##blu_b' .. i) then UI.plan, UI.missing = fit(b); plan = UI.plan; UI.build = b; end
        if imgui.IsItemHovered() then imgui.SetTooltip(b.desc); end
    end
    -- blusets files
    local files = list_files();
    imgui.TextColored(GOLD, 'Your sets:');
    if #files == 0 then imgui.SameLine(0, 8); imgui.TextDisabled('none saved yet'); end
    for i, n in ipairs(files) do
        imgui.SameLine(0, 6);
        if imgui.Button(n .. '##blu_f' .. i) then
            local p, bad = load_file(n);
            if p then
                UI.plan, UI.build, UI.missing = p, nil, nil; plan = p; UI.fname[1] = n;
                note('Loaded ' .. n .. (bad and #bad > 0 and (' (unknown: ' .. table.concat(bad, ', ') .. ')') or '') .. '.');
            else note(bad); end
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('blusets file ' .. n .. '.txt - click to load it into the plan'); end
    end
    if UI.build then
        imgui.TextColored(DIM, UI.build.desc);
        if UI.missing and #UI.missing > 0 then
            local shown = {};
            for k = 1, math.min(10, #UI.missing) do shown[k] = UI.missing[k]; end
            imgui.TextColored({ 1, 0.75, 0.4, 1 }, 'Not learned yet: ' .. table.concat(shown, ', ') .. (#UI.missing > 10 and ', ...' or ''));
        end
    end
    imgui.Separator();

    -- Left: plan
    imgui.BeginGroup();
    local m = max_points();
    imgui.TextColored(GOLD, 'Plan  (click to take off)');
    imgui.SameLine(0, 10);
    local c = cost(plan);
    imgui.TextColored((m and c > m) and RED or DIM, string.format('%d / %d spells   %d / %s points', #plan, slot_limit(), c, m and tostring(m) or '?'));
    imgui.BeginChild('##blu_plan', { 360, 300 }, true);
    local drop = nil;
    for i, id in ipairs(plan) do if spell_row(id, 'blu_p' .. i) then drop = i; end end
    if #plan == 0 then imgui.TextDisabled('Empty - click spells on the right, or pick a set.'); end
    imgui.EndChild();
    if drop then table.remove(plan, drop); end

    if EQ.active then
        imgui.TextColored(GOLD, EQ.msg or 'Working...');
    else
        imgui.PushStyleColor(ImGuiCol_Button, { 0.20, 0.40, 0.55, 1 });
        if imgui.Button('Set these spells##blu_set', { 160, 0 }) then start_set(plan); end
        imgui.PopStyleColor(1);
        if imgui.IsItemHovered() then imgui.SetTooltip('Only the changes are sent, one a second.\nBlue magic is locked for about a minute after.'); end
        imgui.SameLine(0, 6);
        if imgui.Button('Clear##blu_clr') then plan = {}; UI.plan = plan; end
        if EQ.msg then imgui.TextColored(EQ.ok and GREEN or RED, EQ.msg); end
    end
    imgui.PushItemWidth(150);
    imgui.InputText('##blu_fname', UI.fname, 40);
    imgui.PopItemWidth();
    imgui.SameLine(0, 6);
    if imgui.Button('Save as blusets file##blu_save') then
        local n = (UI.fname[1] or ''):gsub('[\\/:%*%?"<>|]', ''):gsub('^%s+', ''):gsub('%s+$', '');
        if n == '' then note('Type a name first.');
        elseif save_file(n, plan) then note('Saved ' .. n .. '.txt (also works with /blusets load ' .. n .. ').');
        else note('Could not save ' .. n .. '.'); end
    end
    if UI.note and os.clock() - UI.note_at < 6 then imgui.PushTextWrapPos(imgui.GetCursorPosX() + 360); imgui.TextColored(GREEN, UI.note); imgui.PopTextWrapPos(); end
    imgui.EndGroup();

    -- Right: spells / traits
    imgui.SameLine(0, 14);
    imgui.BeginGroup();
    if imgui.BeginTabBar('##blu_right') then
        if imgui.BeginTabItem('Spells##blu_r1') then
            for _, k in ipairs({ { 'all', 'All' }, { 'O', 'Damage' }, { 'B', 'Buff' }, { 'D', 'Debuff' }, { 'H', 'Healing' }, { 'P', 'Physical' }, { 'M', 'Magical' } }) do
                if k[1] ~= 'all' then imgui.SameLine(0, 4); end
                if imgui.SmallButton((UI.kind == k[1] and '[' .. k[2] .. ']' or k[2]) .. '##blu_k' .. k[1]) then UI.kind = k[1]; end
            end
            imgui.PushItemWidth(150);
            imgui.InputText('search##blu_q', UI.search, 30);
            imgui.PopItemWidth();
            imgui.BeginChild('##blu_list', { 400, 320 }, true);
            local q = norm(UI.search[1]);
            local ids = {};
            for id, s in pairs(SP) do
                local kind_ok = UI.kind == 'all' or s[4] == UI.kind or s[5] == UI.kind;
                if kind_ok and (q == '' or norm(name_of(id)):find(q, 1, true)) and learned(id) then ids[#ids + 1] = id; end
            end
            table.sort(ids, function (a, b) return name_of(a) < name_of(b); end);
            for _, id in ipairs(ids) do
                local why = refuse_reason(plan, id);
                if why then imgui.PushStyleColor(ImGuiCol_Text, DIM); end
                if spell_row(id, 'blu_a' .. id) then
                    if why then note(name_of(id) .. ': ' .. why); else plan[#plan + 1] = id; end
                end
                if why then imgui.PopStyleColor(1); end
            end
            if #ids == 0 then imgui.TextDisabled('No learned spells here.'); end
            imgui.EndChild();
            imgui.TextDisabled('Only learned spells are listed. Grey = would not fit. Hover for details.');
            imgui.EndTabItem();
        end
        if imgui.BeginTabItem('Traits##blu_r2') then
            -- Auto: pick a trait, omni adds the spells for its highest tier.
            imgui.TextColored(GOLD, 'Auto:');
            imgui.SameLine(0, 6);
            imgui.PushItemWidth(190);
            local cur_name = UI.auto and TR[UI.auto] and TR[UI.auto][1] or 'pick a trait';
            if imgui.BeginCombo('##blu_auto', cur_name) then
                local cats = {};
                for cat in pairs(TR) do cats[#cats + 1] = cat; end
                table.sort(cats, function (a, b) return TR[a][1] < TR[b][1]; end);
                for _, cat in ipairs(cats) do
                    local n = 0;
                    for id, s in pairs(SP) do if s[7] == cat and learned(id) then n = n + 1; end end
                    if n > 0 then
                        if imgui.Selectable(string.format('%s  (%d spell%s)', TR[cat][1], n, n == 1 and '' or 's'), UI.auto == cat) then UI.auto = cat; end
                    end
                end
                imgui.EndCombo();
            end
            imgui.PopItemWidth();
            imgui.SameLine(0, 6);
            if imgui.Button('Max it##blu_automax') and UI.auto then
                local _, msg = max_trait(plan, UI.auto);
                note(msg);
            end
            if imgui.IsItemHovered() then imgui.SetTooltip('Adds your learned spells with this trait to the plan,\nreaching its highest tier for the fewest set points.\nSpells already in the plan stay.'); end
            imgui.BeginChild('##blu_tr', { 400, 330 }, true);
            local tl = traits(plan);
            if #tl == 0 then imgui.TextDisabled('No trait spells in the plan.'); end
            for _, t in ipairs(tl) do
                if t.tier > 0 then
                    imgui.TextColored(GREEN, t.name .. (t.tiers > 1 and (' ' .. t.tier) or ''));
                else
                    imgui.TextColored(DIM, t.name);
                end
                imgui.SameLine(190);
                if t.next then
                    imgui.TextColored(DIM, string.format('%d / %d for %s', t.have, t.next, t.tier > 0 and ('tier ' .. (t.tier + 1)) or 'the trait'));
                else
                    imgui.TextColored(DIM, string.format('%d points (max)', t.have));
                end
            end
            imgui.EndChild();
            imgui.TextDisabled('Two spells of the same trait (or enough points) give the trait.');
            imgui.EndTabItem();
        end
        imgui.EndTabBar();
    end
    imgui.EndGroup();

    blu.height = imgui.GetCursorPosY() - y0 + 20;
end

return blu;
