--[[
    omni_vbattle.lua - Ventures > Venture Battles.

    Every Venture Battle boss (Regular, High-Tier, Final-Tier) and the HVNMs: where it pops,
    what you need to pop it, how the fight works, what it drops, and the upgrade route for each
    drop at Populox - with what you already own counted from all your bags.

    Data from the BG-Wiki page "CatsEyeXI Content/Ventures" (Nov 2026).
]]

local imgui = require('imgui');

local vb = {};

-- ============================================================================ colours
local GOLD   = { 0.90, 0.78, 0.40, 1.0 };
local DIM    = { 0.62, 0.66, 0.80, 1.0 };
local TEXT   = { 0.92, 0.90, 0.85, 1.0 };
local GOOD   = { 0.50, 0.88, 0.50, 1.0 };
local SHORT  = { 0.95, 0.60, 0.55, 1.0 };
local BLUE   = { 0.55, 0.75, 1.00, 1.0 };
local TIER_COL = {
    ['Regular']    = { 0.50, 0.88, 0.50, 1.0 },
    ['High-Tier']  = { 0.95, 0.70, 0.30, 1.0 },
    ['Final-Tier'] = { 1.00, 0.50, 0.50, 1.0 },
    ['HVNM']       = { 0.75, 0.55, 0.95, 1.0 },
};
local RATE = { VC = 'very common', C = 'common', U = 'uncommon', R = 'rare' };

-- ============================================================================ bosses
local BREW = {
    ['Regular']    = 'Goblin Brew (Lv30/40/50 fights) - trade to Brewnix, Lower Jeuno (I-8), who picks the NM',
    ['Regular75']  = 'Goblin Brew +1 (Lv75 / uncapped) - Brewnix picks the area',
    ['High-Tier']  = 'Goblin Brew +2 - trade to Brewnix, Lower Jeuno (I-8). Alliance fight',
    ['Final-Tier'] = 'Goblin Brew +3 - trade to Brewnix, Lower Jeuno (I-8). Well-prepared alliance',
};

local BOSSES = {
    -- Regular (Goblin Mark moves to a new spot after each battle)
    { tier = 'Regular', name = 'Coral Wyvern', lv = 'Lv30 cap', zone = 'Korroloka Tunnel', pop = 'Goblin Mark', brew = BREW['Regular'],
      spots = '(K-7), (G-7), (J-8) - use the Cargo Crab Colin map',
      drops = { { 'Zhulong Bell', 'U' }, { 'Goblin Brew +1', 'R' } } },
    { tier = 'Regular', name = 'Mystic Urn', lv = 'Lv30 cap', zone = 'Outer Horutoto Ruins', pop = 'Goblin Mark', brew = BREW['Regular'],
      spots = 'Lilac Tower: (G-6), (G-7), (I-6), (J-7)',
      drops = { { 'Enlightenment', 'U' }, { 'Goblin Brew +1', 'R' } } },
    { tier = 'Regular', name = 'Fallen Sorcerer', lv = 'Lv30 cap', zone = 'Batallia Downs', pop = 'Goblin Mark', brew = BREW['Regular'],
      spots = 'Middle of the map: (G-8), (G-7), (D-7), (I-7), (H-8)',
      drops = { { 'Sinister Sickle', 'U' }, { 'Goblin Brew +1', 'R' } } },
    { tier = 'Regular', name = 'Desert Prowler', lv = 'Lv40 cap', zone = 'Western Altepa Desert', pop = 'Goblin Mark', brew = BREW['Regular'],
      spots = '(E-6), top-left corner of (F-6), (G-5), the G-5/H-5 line, NE corner of (G-7) by the Field Manual',
      notes = { 'Uses Perfect Dodge and the usual tiger moves.' },
      drops = { { 'Tigris Grip', 'U' }, { 'Goblin Brew +1', 'R' } } },
    { tier = 'Regular', name = 'Jungle Toad', lv = 'Lv40 cap', zone = 'Yhoator Jungle', pop = 'Goblin Mark', brew = BREW['Regular'],
      spots = 'Bloodlet Spring (I-8), (I-10), (I-9), (I-11) along the south wall by the temple',
      drops = { { 'Slippery Cape', 'U' }, { 'Goblin Brew +1', 'R' } } },
    { tier = 'Regular', name = 'Cave Crab', lv = 'Lv40 cap', zone = 'Quicksand Caves', pop = 'Goblin Mark', brew = BREW['Regular'],
      spots = 'Map 1: (H-13), (I-10), (G-10), (F-9)',
      drops = { { 'Chivalric Emblem', 'U' }, { 'Goblin Brew +1', 'R' } } },
    { tier = 'Regular', name = 'Coastal Antlion', lv = 'Lv50 cap', zone = 'Bibiki Bay', pop = 'Goblin Mark', brew = BREW['Regular'],
      spots = '(G-7), (F-6), (H-6)',
      notes = { 'Uses Blood Weapon and the usual antlion moves.' },
      drops = { { 'Myrmeleo Ring', 'U' }, { 'Goblin Brew +1', 'R' } } },
    { tier = 'Regular', name = 'Burrow Spinner', lv = 'Lv50 cap', zone = "Carpenters' Landing", pop = 'Goblin Mark', brew = BREW['Regular'],
      spots = 'Map 1: (F-9 / F-10), (G-8)',
      notes = { 'Uses Hundred Fists and spider moves.' },
      drops = { { 'Liberty', 'U' }, { 'Goblin Brew +1', 'R' } } },
    { tier = 'Regular', name = 'Sequoia Sapling', lv = 'Lv50 cap', zone = "The Sanctuary of Zi'Tah", pop = 'Goblin Mark', brew = BREW['Regular'],
      spots = '(F-8), SE corner of (F-10), (E-9), south (G-8), NE corner of (H-9)',
      notes = { 'Uses Invincible. Sprout Spin hits for hundreds.' },
      drops = { { 'Wyrt Gorget', 'U' }, { 'Goblin Brew +1', 'R' } } },
    { tier = 'Regular', name = 'Smugnix', lv = 'Lv75 / uncapped', zone = 'Onzozo / Kuftal / Gustav', pop = 'Goblin Stash', brew = BREW['Regular75'],
      spots = 'Labyrinth of Onzozo: (I-8), (H-8), (J-9), SE corner (I-7), (I-6) room\n'
           .. 'Kuftal Tunnel: Map 2 (K-7), (M-9); Map 4 (J-7), (G-7) near Yowie, (J-9)\n'
           .. 'Gustav Tunnel: Map 1 (I-8), (H-8), (H-10)',
      notes = { 'Two Goblin Crony help him. They do not despawn when Smugnix dies.',
                'You are given one area; the area decides the special drop.' },
      drops = { { 'Random elemental ore (100%)', '' }, { 'Gold Beastcoin', 'VC' }, { 'Goblin Commendation', 'C' },
                { 'Plt. Beastcoin', 'R' }, { 'Goblin Brew +2', 'R' },
                { 'Avarice', 'C', 'Onzozo only' }, { 'Kyugutachi', 'C', 'Kuftal only' },
                { 'Sprightly Feather', 'C', 'Gustav only' }, { 'Orpiment', '', 'from the Goblin Crony' } } },

    -- High-Tier (Special Mark moves after each battle)
    { tier = 'High-Tier', name = 'Ice Lord', lv = 'Lv75 / uncapped', zone = 'Uleguerand Range', pop = 'Special Mark', brew = BREW['High-Tier'],
      spots = '(J-6), (I-6), (H-5), (I-5)',
      notes = { 'Very resistant until you magic burst Fire (Liquefaction / Fusion). Wind heals it.',
                'Ice added effect. Hundred Fists at 90/80/70/20%, Mighty Strikes at 60/50/40%.',
                'Ice Spikes after Ice Roar / Impact Roar; Grand Slam gives Frost to everyone.',
                'Three Ice Wolves join at 30% and 10% and cast strong ice magic.' },
      drops = { { 'Hibernal Ring', 'VC' }, { 'Hailstone Hose', 'VC' }, { 'Embersteel Ingot', 'C' }, { 'Goblin Brew +3', 'R' } } },
    { tier = 'High-Tier', name = 'Cape Chelonian', lv = 'Lv75 / uncapped', zone = 'Cape Teriggan', pop = 'Special Mark', brew = BREW['High-Tier'],
      spots = '(F-8), (H-6), (H-7), (G-6), (F-7)',
      notes = { 'Very resistant until you magic burst Wind (Detonation / Fragmentation). Lightning heals it.',
                'Lots of Regain, Earth added effect. Benediction at 90/80/70%, Blood Weapon 50%, Invincible 25%.',
                'Stoneskin after Harden Shell; Tortoise Stomp gives Rasp to everyone.',
                'Two Orichaltoise at 75% and 25% with a strong DoT stomp - keep them away from the boss.' },
      drops = { { 'Rikugame Nodowa', 'VC' }, { 'Tellus Pendulum', 'VC' }, { 'Embersteel Ingot', 'C' }, { 'Goblin Brew +3', 'R' } } },
    { tier = 'High-Tier', name = 'Avalerion', lv = 'Lv75 / uncapped', zone = 'Attohwa Chasm', pop = 'Special Mark', brew = BREW['High-Tier'],
      spots = '(J-7), (K-7), (L-8), (K-9)',
      notes = { 'Moderate resistances. Light heals it. Light added effect.',
                'Switches between Hundred Fists and other two-hours every 5%.',
                'Stormwind puts a strong Dia on everyone.',
                'Two Chasm Toucan at 50% and 30%: Mighty Strikes on spawn and at 25%, Benediction at 80%.' },
      drops = { { 'Bagua Ring', 'VC' }, { 'Luminous Earring', 'VC' }, { 'Embersteel Ingot', 'C' }, { 'Goblin Brew +3', 'R' } } },
    { tier = 'High-Tier', name = 'Pyrolynx', lv = 'Lv75 / uncapped', zone = "Ifrit's Cauldron", pop = 'Special Mark', brew = BREW['High-Tier'],
      spots = 'Map 3: (F-10), (F-9), (H-6), (I-6), (I-7)\n'
           .. 'Way in: east entrance from Yhoator Jungle. Map 1 pass the Flame Sprout (1 Ice Cluster) at A,\n'
           .. 'Map 2 drop at P, Map 7 go in at M, Map 6 go to I.',
      notes = { 'Very resistant until you magic burst Water (Reverberation / Distortion). Ice heals it.',
                'Fire added effect. Hundred Fists 75%, Mighty Strikes 50%, Perfect Dodge 25%, Invincible 10%.',
                'Petrifactive Breath (cone): petrify, heavy Burn, gives it Blaze Spikes, may reset hate.' },
      drops = { { 'Emberpearl Earring', 'VC' }, { 'Flamedancer Glaive', 'VC' }, { 'Embersteel Ingot', 'C' }, { 'Goblin Brew +3', 'R' } } },

    -- Final-Tier
    { tier = 'Final-Tier', name = 'Yasuo Hasaki', lv = 'Lv75 / uncapped', zone = 'Castle Zvahl Keep', pop = 'Goblin Seal', brew = BREW['Final-Tier'],
      spots = 'Map 4 (H-7)',
      notes = { 'Very resistant until hit with weapon skills or magic of the element that beats its current one',
                '(e.g. Viper Bite against Fire). Weapon skills count much more than magic.',
                'After enough hits it changes element: defence drops and hate resets.',
                'Dark added effect, tier III AoE and tier IV single-target black magic.',
                'Meikyo Shisui every 10%, Hundred Fists 75% and 25%, Chainspell 50%.',
                "Below 25% it only uses Oblivion's Mantle: 15 s of Weakness plus big AoE damage." },
      drops = { { 'Oathbreaker', '' }, { "Kennan's Longbow", '' }, { 'Manaflow Sash', '' }, { 'Beastly Girdle', '' } } },
    { tier = 'Final-Tier', name = 'Sinmara', lv = 'Lv75 / uncapped', zone = "Ve'Lugannon Palace", pop = 'Strange portal', brew = BREW['Final-Tier'],
      spots = '(H-3)',
      notes = { 'Arcana boss, very resistant, space-debris magic.',
                'Crystal Shield at set HP points: three animated relic weapons appear - work out their relic',
                'weapon skills and land a 3-step skillchain with those WSs on the boss to break the shield.',
                'Too slow: Volcanic Wrath (big fire AoE, partial hate reset, boss empowered for 60 s).',
                'Weapons not killed before the shield drops will self-destruct.' },
      drops = { { "Shaarat'kor", '' }, { 'Vesper Earring', '' }, { 'Cullet Gloves', '' }, { 'Eldritch Sabatons', '' } } },

    -- HVNMs (spawn once the server-wide EXP Venture progress hits 100%)
    { tier = 'HVNM', name = 'Tidepincher', zone = 'Batallia Downs', pop = 'Server progress 100%', spots = '(J-6)',
      drops = { { "Fury's Edge", '' }, { 'Pincer Mantle', '' }, { 'Scroll of Water V', '' }, { 'Scroll of Thunder V', '' } } },
    { tier = 'HVNM', name = 'Emberwing', zone = 'Rolanberry Fields', pop = 'Server progress 100%', spots = '(I-7)',
      drops = { { 'Eidolon Ring', '' }, { 'Hieratic Ring', '' }, { 'Scroll of Fire V', '' }, { 'Scroll of Arise', '' } } },
    { tier = 'HVNM', name = 'Swiftsting', zone = 'Sauromugue Champaign', pop = 'Server progress 100%', spots = '(H-6)',
      drops = { { "Archer's Shield", '' }, { 'Yoru Shuriken', '' }, { 'Scroll of Aero V', '' }, { 'Scroll of Absorb-Attri', '' } } },
    { tier = 'HVNM', name = 'Dustburrower', zone = 'Qufim Island', pop = 'Server progress 100%', spots = '(I-7)',
      drops = { { 'Resonance Sash', '' }, { 'Kiryoku Nenju', '' }, { 'Scroll of Stone V', '' }, { 'Scroll of Blizzard V', '' } } },
};
local HVNM_NOTES = {
    'Spawns when the server-wide EXP Venture progress reaches 100%.',
    'Trade Scarlet Cells to the Venture Chest for better rates.',
    'Popped version (ExHVNM): trade its Lure to an Elemental Scour at the Venture Seal spot.',
    'Lures cost 8,000 Venture Points at Populox or drop from HVNM chests. Scarlet Cell + Lure = better loot.',
    'Only when it is not the current HVNM, once per person per day. Alliance fight.',
};

-- ============================================================================ upgrades (Populox)
-- Each step: trade the item + these materials + Goblin Commendations.
local COMMEND = { 4, 6, 8 };
local function s(mats, stats) return { mats = mats, stats = stats }; end
local UPG = {
    ['Zhulong Bell']      = { s({ { 'Silver Sheet', 2 } }, 'Attack+1, "Magic Atk. Bonus"+1'), s({ { 'Silver Sheet', 3 } }, 'Attack+2, "Magic Atk. Bonus"+3'), s({ { 'Silver Sheet', 4 } }, 'Attack+3, "Magic Atk. Bonus"+3') },
    ['Enlightenment']     = { s({ { 'Vellum', 2 } }, 'Evasion+1, "Cure" potency+1%'), s({ { 'Vellum', 3 } }, 'Evasion+2, "Cure" potency+2%'), s({ { 'Vellum', 4 } }, 'Evasion+3, "Cure" potency+3%') },
    ['Sinister Sickle']   = { s({ { 'Chimera Blood', 2 } }, 'DMG+2, INT+2'), s({ { 'Chimera Blood', 3 } }, 'DMG+3, INT+3'), s({ { 'Chimera Blood', 4 } }, 'DMG+4, INT+4') },
    ['Tigris Grip']       = { s({ { 'Tiger Leather', 2 } }, 'DEX+1, CHR+1'), s({ { 'Tiger Leather', 3 } }, 'DEX+2, CHR+2'), s({ { 'Tiger Leather', 4 } }, 'DEX+3, CHR+3') },
    ['Slippery Cape']     = { s({ { 'Clot Plasma', 2 } }, 'DEX+1, AGI+1'), s({ { 'Clot Plasma', 3 } }, 'DEX+2, AGI+2'), s({ { 'Clot Plasma', 4 } }, 'DEX+3, AGI+3') },
    ['Liberty']           = { s({ { 'Gold Ingot', 2 } }, 'Ranged Attack+1, Evasion+1'), s({ { 'Gold Ingot', 3 } }, 'Ranged Attack+2, Evasion+2'), s({ { 'Gold Ingot', 4 } }, 'Ranged Attack+3, Evasion+3') },
    ['Wyrt Gorget']       = { s({ { 'Dryad Root', 2 } }, 'Accuracy+1, Attack+1'), s({ { 'Dryad Root', 3 } }, 'Accuracy+2, Attack+2'), s({ { 'Dryad Root', 4 } }, 'Accuracy+3, Attack+3') },
    ['Myrmeleo Ring']     = { s({ { 'Antlion Jaw', 2 } }, 'Evasion+1, Enmity+1'), s({ { 'Antlion Jaw', 3 } }, 'Evasion+2, Enmity+2'), s({ { 'Antlion Jaw', 4 } }, 'Evasion+3, Enmity+3') },
    ['Chivalric Emblem']  = { s({ { 'Steel Scales', 2 } }, 'MND+1, Accuracy+1'), s({ { 'Steel Scales', 3 } }, 'MND+2, Accuracy+2'), s({ { 'Steel Scales', 4 } }, 'MND+3, Accuracy+3') },
    ['Avarice']           = { s({ { 'Darksteel Ingot', 6 } }, 'STR+3, Attack+6'), s({ { 'Darksteel Ingot', 8 } }, 'STR+4, Attack+8'), s({ { 'Darksteel Ingot', 12 } }, 'STR+5, Attack+12') },
    ['Kyugutachi']        = { s({ { 'Wisteria Lumber', 6 } }, 'Attack+6, Ranged Attack+6'), s({ { 'Wisteria Lumber', 8 } }, 'Attack+8, Ranged Attack+8'), s({ { 'Wisteria Lumber', 12 } }, 'Attack+12, Ranged Attack+12') },
    ['Sprightly Feather'] = { s({ { 'Hippogryph Fthr.', 6 } }, 'Attack+2, Evasion+2'), s({ { 'Hippogryph Fthr.', 8 } }, 'Attack+3, Evasion+3'), s({ { 'Hippogryph Fthr.', 12 } }, 'Attack+4, Evasion+4') },

    ['Hibernal Ring']      = { s({ { 'Sarcenet Cloth', 4 }, { 'Mythril Ring +1', 1 } }, 'DEX+2, Accuracy+2'), s({ { 'Sarcenet Cloth', 6 }, { 'Genius Ring', 1 } }, 'DEX+3, Accuracy+3'), s({ { 'Sarcenet Cloth', 8 }, { 'Snow Ring', 1 } }, 'DEX+4, Accuracy+4, "Magic Atk. Bonus"+2') },
    ['Hailstone Hose']     = { s({ { 'Sarcenet Cloth', 4 }, { 'Wool Hose +1', 1 } }, 'AGI+2, Magic Acc.+2'), s({ { 'Sarcenet Cloth', 6 }, { 'Battle Hose +1', 1 } }, 'AGI+3, Magic Acc.+3'), s({ { 'Sarcenet Cloth', 8 }, { 'Dusk Trousers', 1 } }, 'AGI+4, Magic Acc.+4, Haste+2%') },
    ['Rikugame Nodowa']    = { s({ { 'Adamantoise Shell', 4 }, { 'Nodowa +1', 1 } }, 'HP+10, Accuracy+6'), s({ { 'Adamantoise Shell', 6 }, { 'Dst. Nodowa +1', 1 } }, 'HP+20, Accuracy+6'), s({ { 'Adamantoise Shell', 8 }, { 'Orochi Nodowa', 1 } }, 'HP+30, Accuracy+8, DEX+2') },
    ['Tellus Pendulum']    = { s({ { 'Adamantoise Shell', 4 }, { 'Mohbwa Scarf +1', 1 } }, 'MP+10, INT+2'), s({ { 'Adamantoise Shell', 6 }, { 'Torque +1', 1 } }, 'MP+20, INT+3'), s({ { 'Adamantoise Shell', 8 }, { 'Jeweled Collar', 1 } }, 'MP+30, INT+4, "Magic Atk. Bonus"+2') },
    ['Bagua Ring']         = { s({ { 'Luminium Ore', 4 }, { 'Smilodon Ring +1', 1 } }, 'Light+3, Accuracy+3'), s({ { 'Luminium Ore', 6 }, { 'Allure Ring', 1 } }, 'Light+6, Accuracy+4'), s({ { 'Luminium Ore', 8 }, { 'Light Ring', 1 } }, 'Light+9, Accuracy+5, Pet: Regen+2') },
    ['Luminous Earring']   = { s({ { 'Luminium Ore', 4 }, { 'Tor. Earring +1', 1 } }, 'HP+5, Magic Acc.+1'), s({ { 'Luminium Ore', 6 }, { 'Allure Earring', 1 } }, 'HP+10, Magic Acc.+2'), s({ { 'Luminium Ore', 8 }, { "Angel's Earring", 1 } }, 'HP+15, Magic Acc.+3, "Store TP"+2') },
    ['Emberpearl Earring'] = { s({ { 'Rhodonite', 4 }, { 'Beetle Earring +1', 1 } }, 'HP+5, Attack+1'), s({ { 'Rhodonite', 6 }, { 'Spike Earring', 1 } }, 'HP+10, Attack+2'), s({ { 'Rhodonite', 8 }, { 'Ruby Earring', 1 } }, 'HP+15, Attack+3, Weapon skill Acc.+2') },
    ['Flamedancer Glaive'] = { s({ { 'Rhodonite', 4 }, { 'Chakram +1', 1 } }, 'STR+2, DEX+2'), s({ { 'Rhodonite', 6 }, { 'Rising Sun +1', 1 } }, 'STR+3, DEX+3'), s({ { 'Rhodonite', 8 }, { 'Snakeeye', 1 } }, 'STR+4, DEX+4, Accuracy+2') },

    ['Oathbreaker']      = { s({ { 'Titanium Ingot', 2 }, { 'Dragon Essence', 2 }, { 'Beetle Knife +1', 1 } }, 'VIT+2, Enmity+1'), s({ { 'Titanium Ingot', 3 }, { 'Dragon Essence', 3 }, { 'Vnm. Baselard +1', 1 } }, 'VIT+3, Enmity+2'), s({ { 'Titanium Ingot', 4 }, { 'Dragon Essence', 4 }, { 'Khimaira Jambiya', 1 } }, 'VIT+4, Enmity+3, Refresh+1') },
    ["Kennan's Longbow"] = { s({ { 'Animated Lumber', 2 }, { 'Dragon Essence', 2 }, { 'Battle Bow +1', 1 } }, 'Rng. Acc.+1, Enmity-3'), s({ { 'Animated Lumber', 3 }, { 'Dragon Essence', 3 }, { 'Lightning Bow +1', 1 } }, 'Rng. Acc.+2, Enmity-4'), s({ { 'Animated Lumber', 4 }, { 'Dragon Essence', 4 }, { 'Cerberus Bow', 1 } }, 'Rng. Acc.+3, Enmity-5, Meditate duration+2') },
    ['Manaflow Sash']    = { s({ { 'Fable Cloth', 2 }, { 'Dragon Essence', 2 }, { 'Twinthread Obi +1', 1 } }, 'Haste+4%, Enmity-4'), s({ { 'Fable Cloth', 3 }, { 'Dragon Essence', 3 }, { 'Arachne Obi +1', 1 } }, 'Haste+5%, Enmity-5'), s({ { 'Fable Cloth', 4 }, { 'Dragon Essence', 4 }, { 'Visionary Obi', 1 } }, 'Haste+6%, Enmity-6, "Regen" potency+3') },
    ['Beastly Girdle']   = { s({ { 'Embersteel Rivet', 2 }, { 'Dragon Essence', 2 }, { 'Peiste Belt +1', 1 } }, 'Haste+4%, Pet: Acc.+3 Rng.Acc.+3'), s({ { 'Embersteel Rivet', 3 }, { 'Dragon Essence', 3 }, { 'Muscle Belt +1', 1 } }, 'Haste+5%, Pet: Acc.+4 Rng.Acc.+4'), s({ { 'Embersteel Rivet', 4 }, { 'Dragon Essence', 4 }, { 'Companion Belt', 1 } }, 'Haste+6%, Pet: Acc.+5 Rng.Acc.+5, Pet: Regen+3') },
    ["Shaarat'kor"]      = { s(nil, 'DMG / Resist Death+2, Enmity+2'), s(nil, 'DMG / Resist Death+4, Enmity+4'), s(nil, 'DMG / Resist Death+6, Enmity+6, Swordplay+3') },
    ['Vesper Earring']   = { s({ { 'Amph. Leather', 4 }, { 'Forgotten Touch', 99 }, { 'Necropsyche', 1 }, { 'Pennon Earring +1', 1 } }, 'Evasion+3, Pet: Damage taken -1%'), s({ { 'Amph. Leather', 6 }, { 'Frgtn. Thought', 99 }, { 'Malefic Dagger', 1 }, { 'Phtm. Earring +1', 1 } }, 'Evasion+4, Pet: Damage taken -2%'), s({ { 'Amph. Leather', 8 }, { 'Umbral Marrow', 1 }, { 'Ghillie Earring +1', 1 } }, 'CHR+3, Evasion+5, Pet: Damage taken -3%') },
    ['Cullet Gloves']    = { s({ { 'Fine Ochre', 1 }, { 'Forgotten Hope', 99 }, { 'Necropsyche', 1 }, { 'Hailstorm Tekko', 1 } }, 'AGI+3, Magic Acc.+2'), s({ { 'Fine Ochre', 2 }, { 'Forgotten Touch', 99 }, { 'Militant Knuckles', 1 }, { 'Scp. Gnt. +1', 1 } }, 'AGI+4, Magic Acc.+3'), s({ { 'Fine Ochre', 3 }, { 'Umbral Marrow', 1 }, { 'Chunin Ring', 1 } }, 'AGI+5, Magic Acc.+4, Haste+2% (4% total)') },
    ['Eldritch Sabatons'] = { s({ { 'Elementium Stud', 2 }, { 'Frgtn. Journey', 99 }, { 'Necropsyche', 1 }, { 'Shade Leggings +1', 1 } }, 'INT/MND+2, Sword skill+1'), s({ { 'Elementium Stud', 3 }, { 'Forgotten Step', 99 }, { 'Memento Scythe', 1 }, { 'Abtal Boots', 1 } }, 'INT/MND+3, Sword skill+2'), s({ { 'Elementium Stud', 4 }, { 'Umbral Marrow', 1 }, { 'Cursed Clogs -1', 1 } }, 'INT/MND+4, Sword skill+3, Magic burst dmg.+3%') },
};

-- ============================================================================ what you own
local idsByName = nil;   -- lower-case name -> { id, id, ... }
local function buildNames()
    idsByName = {};
    local res = AshitaCore:GetResourceManager();
    for id = 1, 65535 do
        local ok, it = pcall(function () return res:GetItemById(id); end);
        if ok and it ~= nil and it.Name ~= nil then
            for _, n in ipairs({ it.Name[1], it.LogNameSingular and it.LogNameSingular[1] }) do
                if n ~= nil and n ~= '' and n ~= '.' then
                    local k = n:lower();
                    idsByName[k] = idsByName[k] or {};
                    local list, dup = idsByName[k], false;
                    for _, x in ipairs(list) do if x == id then dup = true; end end
                    if not dup then list[#list + 1] = id; end
                end
            end
        end
    end
end

local counts, countsAt = {}, -100;
local function scan()
    if os.clock() - countsAt < 2 then return; end
    countsAt = os.clock();
    local c = {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for bag = 0, 16 do
            local max = (bag ~= 3) and (inv:GetContainerCountMax(bag) or 0) or 0;
            for slot = 1, max do
                local e = inv:GetContainerItem(bag, slot);
                if e ~= nil and e.Id ~= nil and e.Id ~= 0 and e.Id ~= 65535 and (e.Count or 0) > 0 then
                    c[e.Id] = (c[e.Id] or 0) + e.Count;
                end
            end
        end
    end);
    counts = c;
end

-- How many you own (all bags), by name. nil if the game has no item by that name.
local function have(name)
    if idsByName == nil then pcall(buildNames); end
    local ids = idsByName and idsByName[name:lower()];
    if ids == nil then return nil; end
    local n = 0;
    for _, id in ipairs(ids) do n = n + (counts[id] or 0); end
    return n;
end

-- ============================================================================ drawing
local selected = 1;
local showOwned = false;   -- "Only bosses with drops I'm missing"

local function wrapped(col, text)
    imgui.PushTextWrapPos(0);
    imgui.TextColored(col, text);
    imgui.PopTextWrapPos();
end

local function countText(name, need)
    local h = have(name);
    if h == nil then return '?/' .. need, DIM; end
    return string.format('%d/%d', h, need), (h >= need) and GOOD or SHORT;
end

local function drawMat(name, need)
    local t, col = countText(name, need);
    imgui.TextColored(TEXT, name);
    imgui.SameLine(0, 6);
    imgui.TextColored(col, t);
end

local function drawUpgrade(item)
    local steps = UPG[item];
    if steps == nil then return; end
    imgui.Indent(14);
    imgui.TextColored(BLUE, 'Upgrade at Populox (Port Jeuno):');
    imgui.SameLine(0, 6);
    imgui.TextColored(DIM, 'trade the item + materials + Goblin Commendations');
    if imgui.BeginTable('##vb_upg_' .. item, 3, bit.bor(ImGuiTableFlags_Borders, ImGuiTableFlags_RowBg, ImGuiTableFlags_SizingFixedFit)) then
        imgui.TableSetupColumn('Step', ImGuiTableColumnFlags_WidthFixed, 40);
        imgui.TableSetupColumn('Trade with the item', ImGuiTableColumnFlags_WidthFixed, 280);
        imgui.TableSetupColumn('Gives', ImGuiTableColumnFlags_WidthStretch);
        imgui.TableHeadersRow();
        for i, st in ipairs(steps) do
            imgui.TableNextRow();
            imgui.TableSetColumnIndex(0);
            imgui.TextColored(GOLD, 'A' .. i);
            imgui.TableSetColumnIndex(1);
            if st.mats == nil then
                imgui.TextColored(DIM, '??? (not on the wiki yet - trade it to Populox to see)');
            else
                for _, m in ipairs(st.mats) do drawMat(m[1], m[2]); end
            end
            drawMat('Goblin Commendation', COMMEND[i]);
            imgui.TableSetColumnIndex(2);
            imgui.PushTextWrapPos(0);
            imgui.TextColored(TEXT, st.stats);
            imgui.PopTextWrapPos();
        end
        imgui.EndTable();
    end
    imgui.Unindent(14);
end

local function missingDrops(b)
    for _, d in ipairs(b.drops) do
        if UPG[d[1]] ~= nil or b.tier == 'HVNM' then
            local h = have(d[1]);
            if h ~= nil and h == 0 then return true; end
        end
    end
    return false;
end

local function drawDetail(b)
    imgui.TextColored(GOLD, b.name);
    imgui.SameLine(0, 10);
    imgui.TextColored(TIER_COL[b.tier] or TEXT, b.tier == 'HVNM' and 'Higher VNM' or (b.tier .. ' Venture Battle'));
    if b.lv then imgui.SameLine(0, 10); imgui.TextColored(DIM, b.lv); end
    imgui.Separator();

    imgui.TextColored(BLUE, 'Zone');      imgui.SameLine(90); imgui.TextColored(TEXT, b.zone);
    imgui.TextColored(BLUE, 'Pops from'); imgui.SameLine(90);
    if b.tier == 'HVNM' then
        imgui.TextColored(TEXT, b.pop);
    else
        imgui.TextColored(TEXT, b.pop .. ' (moves to a new spot after each battle)');
    end
    if b.brew then imgui.TextColored(BLUE, 'You need'); imgui.SameLine(90); wrapped(TEXT, b.brew); end
    imgui.TextColored(BLUE, 'Spots');
    local first = true;
    for line in (b.spots .. '\n'):gmatch('(.-)\n') do
        if first then imgui.SameLine(90); first = false; else imgui.SetCursorPosX(90); end
        wrapped(TEXT, line);
    end

    local notes = b.notes or (b.tier == 'HVNM' and HVNM_NOTES) or nil;
    if notes then
        imgui.Dummy({ 0, 2 });
        imgui.TextColored(BLUE, 'The fight');
        for _, n in ipairs(notes) do wrapped(DIM, '  - ' .. n); end
    end

    imgui.Dummy({ 0, 4 });
    imgui.TextColored(BLUE, 'Drops');
    imgui.SameLine(0, 8);
    imgui.TextColored(DIM, '(green = you own one, counted from every bag)');
    for _, d in ipairs(b.drops) do
        local name, rate, note = d[1], d[2], d[3];
        local h = have(name);
        local col = (h == nil) and TEXT or ((h > 0) and GOOD or SHORT);
        imgui.Bullet();
        imgui.TextColored(col, name);
        if rate ~= '' then imgui.SameLine(0, 6); imgui.TextColored(DIM, '(' .. (RATE[rate] or rate) .. ')'); end
        if note then imgui.SameLine(0, 6); imgui.TextColored(DIM, '- ' .. note); end
        if h ~= nil and h > 0 then imgui.SameLine(0, 6); imgui.TextColored(GOOD, 'x' .. h); end
        drawUpgrade(name);
    end
end

function vb.render()
    scan();
    local avail = imgui.GetContentRegionAvail();
    local h = 560;

    imgui.BeginChild('##vb_list', { 210, h }, true);
    local box = { showOwned };
    if imgui.Checkbox('Missing drops only##vb_miss', box) then showOwned = box[1]; end
    if imgui.IsItemHovered() then imgui.SetTooltip('Only list bosses that drop gear you do not own yet.'); end
    local lastTier = nil;
    for i, b in ipairs(BOSSES) do
        if not showOwned or missingDrops(b) then
            if b.tier ~= lastTier then
                lastTier = b.tier;
                imgui.Dummy({ 0, 3 });
                imgui.TextColored(TIER_COL[b.tier] or TEXT, b.tier == 'HVNM' and 'Higher VNMs' or b.tier);
                imgui.Separator();
            end
            if imgui.Selectable(b.name .. '##vb_sel' .. i, selected == i) then selected = i; end
            if imgui.IsItemHovered() then imgui.SetTooltip(b.zone); end
        end
    end
    imgui.EndChild();

    imgui.SameLine();
    imgui.BeginChild('##vb_detail', { math.max(300, avail - 218), h }, true);
    local b = BOSSES[selected];
    if b then drawDetail(b); end
    imgui.Dummy({ 0, 6 });
    wrapped(DIM, 'From the BG-Wiki CatsEyeXI Ventures page. Venture Battle Points are spent at Brewnix (Lower Jeuno I-8).');
    imgui.EndChild();
end

vb.height = 600;
return vb;
