-- omni: where to get each spell scroll, die or plate.
-- GENERATED from the public CatsEyeXI server repository (github.com/CatsAndBoats/catseyexi,
-- GPL-3.0): NPC shop scripts, battlefield loot tables and mob drop lists. The live
-- server can differ. Pre-Abyssea sources only. Do not edit by hand.
--   vendors = { { npc, area }, ... }
--   bcnm    = { { battlefield, area }, ... }
--   drops   = { [zone id] = 'Mob (rate), Mob (rate)', ... }
return {
    [4609] = { -- Cure
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4610] = { -- Cure II
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Quelpia', 'Selbina' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4611] = { -- Cure III
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4612] = { -- Cure IV
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4613] = { -- Cure V
        bcnm = { { 'Cactuar Suave [Clotho Orb]', 'Chamber of Oracles' }, { 'Come Into My Parlor [Clotho Orb]', 'Qu\'Bia Arena' }, { 'E-vase-ive Action [Lachesis Orb]', 'Qu\'Bia Arena' }, { 'Eye of the Storm [Lachesis Orb]', 'Chamber of Oracles' }, { 'Infernal Swarm [Atropos Orb]', 'Qu\'Bia Arena' }, { 'The Scarlet King [Atropos Orb]', 'Chamber of Oracles' } },
        drops = {
            [9] = 'Goblin Alchemist (1%)',
            [113] = 'Goblin Alchemist (1%)',
            [148] = 'Diamond Quadav (5%)',
            [151] = 'Yagudo High Priest (5%)',
            [174] = 'Goblin Alchemist (1%)',
            [176] = 'Lagoon Sahagin (5%), Novv the Whitehearted (5%), Yarr the Pearleyed (1%)',
            [205] = 'Foreseer Oramix (10%), Goblin Alchemist (1%)',
            [212] = 'Goblin Alchemist (1%)',
            [213] = 'Goblin Alchemist (1%)',
        },
    },
    [4614] = { -- Cure VI
        vendors = { { 'Brave Ox', 'Rabao' } },
    },
    [4615] = { -- Curaga
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4616] = { -- Curaga II
        vendors = { { 'Hasim', 'Lower Jeuno' }, { 'Quelpia', 'Selbina' } },
    },
    [4617] = { -- Curaga III
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4618] = { -- Curaga IV
        drops = {
            [9] = 'Goblin Alchemist (1%)',
            [113] = 'Goblin Alchemist (0.5%)',
            [148] = 'Diamond Quadav (1%)',
            [151] = 'Yagudo High Priest (1%)',
            [174] = 'Goblin Alchemist (1%)',
            [176] = 'Novv the Whitehearted (5%), Lagoon Sahagin (1%), Yarr the Pearleyed (1%)',
            [205] = 'Foreseer Oramix (5%), Goblin Alchemist (1%)',
            [212] = 'Goblin Alchemist (1%)',
            [213] = 'Goblin Alchemist (1%)',
        },
    },
    [4620] = { -- Raise
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4621] = { -- Raise II
        bcnm = { { '3, 2, 1... [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'Amphibian Assault [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'An Awful Autopsy [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Eye of the Tiger [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Hostile Herbivores [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Idol Thoughts [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Jungle Boogymen [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'Legion XI Comitatensis [Lv60 cap, Moon Orb]', 'Chamber of Oracles' }, { 'Rapid Raptors [Lv50 cap, Comet Orb]', 'Balgas Dais' }, { 'The Final Bout [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'Treasure and Tribulations [Lv50 cap, Comet Orb]', 'Balgas Dais' } },
        drops = {
            [148] = 'Diamond Quadav (5%)',
            [151] = 'Yagudo High Priest (5%)',
            [176] = 'Coral Sahagin (5%)',
        },
    },
    [4622] = { -- Poisona
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4623] = { -- Paralyna
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4624] = { -- Blindna
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4625] = { -- Silena
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4626] = { -- Stona
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4627] = { -- Viruna
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4628] = { -- Cursna
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4629] = { -- Holy
        vendors = { { 'Hasim', 'Lower Jeuno' }, { 'Quelpia', 'Selbina' } },
    },
    [4631] = { -- Dia
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4632] = { -- Dia II
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4633] = { -- Dia III
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4636] = { -- Banish
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4637] = { -- Banish II
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4638] = { -- Banish III
        vendors = { { 'Brave Ox', 'Rabao' } },
        drops = {
            [176] = 'Coral Sahagin (5%), Lagoon Sahagin (1%)',
        },
    },
    [4641] = { -- Diaga
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4646] = { -- Banishga
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4647] = { -- Banishga II
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4651] = { -- Protect
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4652] = { -- Protect II
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4653] = { -- Protect III
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4654] = { -- Protect IV
        vendors = { { 'Brave Ox', 'Rabao' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
        bcnm = { { 'Compliments to the Chef [Lv75 cap]', 'Talacca Cove' }, { 'Happy Caster [Lv75 cap]', 'Navukgo Execution Chamber' }, { 'Shadows of the Mind [Lv75 cap]', 'Jade Sepulcher' } },
    },
    [4655] = { -- Protect V
        vendors = { { 'Brave Ox', 'Rabao' } },
    },
    [4656] = { -- Shell
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4657] = { -- Shell II
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4658] = { -- Shell III
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4659] = { -- Shell IV
        bcnm = { { 'Cactuar Suave [Clotho Orb]', 'Chamber of Oracles' }, { 'Come Into My Parlor [Clotho Orb]', 'Qu\'Bia Arena' }, { 'E-vase-ive Action [Lachesis Orb]', 'Qu\'Bia Arena' }, { 'Eye of the Storm [Lachesis Orb]', 'Chamber of Oracles' }, { 'Infernal Swarm [Atropos Orb]', 'Qu\'Bia Arena' }, { 'The Scarlet King [Atropos Orb]', 'Chamber of Oracles' } },
        drops = {
            [122] = 'Magic Flagon (1%)',
            [130] = 'Sprinkler (1%)',
            [148] = 'Ruby Quadav (15%)',
            [158] = 'Magic Pot (1%)',
            [159] = 'Hover Tank (1%)',
            [177] = 'Dustbuster (1%)',
            [178] = 'Aura Pot (0.2%)',
            [200] = 'Magic Jug (5%)',
        },
    },
    [4660] = { -- Shell V
        vendors = { { 'Brave Ox', 'Rabao' } },
    },
    [4661] = { -- Blink
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4662] = { -- Stoneskin
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4663] = { -- Aquaveil
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' } },
    },
    [4664] = { -- Slow
        vendors = { { 'Kususu', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Sororo', 'Bastok Markets' } },
    },
    [4665] = { -- Haste
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4666] = { -- Paralyze
        drops = {
            [88] = 'Amethyst Quadav (1%)',
            [89] = 'Amethyst Quadav (1%), Sapphirine Quadav (1%)',
            [91] = 'Sapphirine Quadav (1%)',
            [95] = 'Yagudo Acolyte (1%)',
            [96] = 'Yagudo Priest (1%)',
            [103] = 'Goblin Leecher (5%)',
            [104] = 'Goblin Leecher (5%)',
            [105] = 'Goblin Leecher (5%)',
            [106] = 'Goblin Leecher (5%), Amethyst Quadav (1%)',
            [107] = 'Amethyst Quadav (1%)',
            [108] = 'Amethyst Quadav (1%)',
            [109] = 'Goblin Leecher (5%)',
            [110] = 'Goblin Leecher (5%)',
            [115] = 'Yagudo Acolyte (1%)',
            [116] = 'Yagudo Acolyte (1%)',
            [117] = 'Yagudo Acolyte (1%)',
            [118] = 'Goblin Leecher (5%)',
            [119] = 'Goblin Leecher (5%)',
            [120] = 'Goblin Leecher (5%)',
            [121] = 'Goblin Leecher (5%)',
            [143] = 'Amethyst Quadav (1%)',
            [145] = 'Yagudo Acolyte (1%)',
            [166] = 'Goblin Leecher (5%)',
            [171] = 'Sapphirine Quadav (1%)',
            [184] = 'Goblin Leecher (5%)',
            [190] = 'Goblin Leecher (5%)',
            [192] = 'Goblin Leecher (5%)',
            [193] = 'Goblin Leecher (5%)',
            [198] = 'Goblin Leecher (5%)',
        },
    },
    [4667] = { -- Silence
        drops = {
            [103] = 'Goblin Leecher (1%)',
            [104] = 'Goblin Leecher (1%)',
            [105] = 'Goblin Leecher (1%)',
            [106] = 'Goblin Leecher (1%)',
            [109] = 'Goblin Leecher (1%)',
            [110] = 'Garnet Quadav (10%), Goblin Leecher (1%)',
            [118] = 'Goblin Leecher (1%)',
            [119] = 'Yagudo Priest (5%), Goblin Leecher (1%)',
            [120] = 'Yagudo Priest (5%), Goblin Leecher (1%)',
            [121] = 'Goblin Leecher (1%)',
            [145] = 'Yagudo Priest (5%)',
            [151] = 'Yagudo Priest (5%)',
            [166] = 'Goblin Leecher (5%)',
            [184] = 'Goblin Leecher (5%)',
            [190] = 'Goblin Leecher (5%)',
            [192] = 'Goblin Leecher (5%)',
            [193] = 'Goblin Leecher (5%)',
            [198] = 'Goblin Leecher (5%)',
        },
    },
    [4668] = { -- Barfire
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4669] = { -- Barblizzard
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4670] = { -- Baraero
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4671] = { -- Barstone
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4672] = { -- Barthunder
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4673] = { -- Barwater
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4674] = { -- Barfira
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4675] = { -- Barblizzara
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4676] = { -- Baraera
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4677] = { -- Barstonra
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4678] = { -- Barthundra
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4679] = { -- Barwatera
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4680] = { -- Barsleep
        vendors = { { 'Hasim', 'Lower Jeuno' } },
        drops = {
            [88] = 'Amethyst Quadav (1%)',
            [89] = 'Amethyst Quadav (1%), Sapphirine Quadav (1%)',
            [91] = 'Sapphirine Quadav (1%)',
            [95] = 'Yagudo Acolyte (1%)',
            [103] = 'Goblin Leecher (1%)',
            [104] = 'Goblin Leecher (1%)',
            [105] = 'Goblin Leecher (1%)',
            [106] = 'Amethyst Quadav (1%), Goblin Leecher (1%)',
            [107] = 'Amethyst Quadav (1%)',
            [108] = 'Amethyst Quadav (1%)',
            [109] = 'Goblin Leecher (1%)',
            [110] = 'Goblin Leecher (1%)',
            [115] = 'Yagudo Acolyte (1%)',
            [116] = 'Yagudo Acolyte (1%)',
            [117] = 'Yagudo Acolyte (1%)',
            [118] = 'Goblin Leecher (1%)',
            [119] = 'Goblin Leecher (1%)',
            [120] = 'Goblin Leecher (1%)',
            [121] = 'Goblin Leecher (1%)',
            [143] = 'Amethyst Quadav (1%)',
            [145] = 'Yagudo Acolyte (1%)',
            [166] = 'Goblin Leecher (5%)',
            [171] = 'Sapphirine Quadav (1%)',
            [184] = 'Goblin Leecher (5%)',
            [190] = 'Goblin Leecher (5%)',
            [192] = 'Goblin Leecher (5%)',
            [193] = 'Goblin Leecher (5%)',
            [198] = 'Goblin Leecher (5%)',
        },
    },
    [4681] = { -- Barpoison
        vendors = { { 'Hasim', 'Lower Jeuno' } },
        drops = {
            [103] = 'Goblin Leecher (1%)',
            [104] = 'Goblin Leecher (1%)',
            [105] = 'Goblin Leecher (1%)',
            [106] = 'Goblin Leecher (1%)',
            [109] = 'Goblin Leecher (1%)',
            [110] = 'Garnet Quadav (5%), Goblin Leecher (1%)',
            [118] = 'Goblin Leecher (1%)',
            [119] = 'Goblin Leecher (1%)',
            [120] = 'Goblin Leecher (1%)',
            [121] = 'Goblin Leecher (1%)',
            [166] = 'Goblin Leecher (1%)',
            [184] = 'Goblin Leecher (1%)',
            [190] = 'Goblin Leecher (1%)',
            [192] = 'Goblin Leecher (1%)',
            [193] = 'Goblin Leecher (1%)',
            [198] = 'Goblin Leecher (1%)',
        },
    },
    [4682] = { -- Barparalyze
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4683] = { -- Barblind
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4684] = { -- Barsilence
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4685] = { -- Barpetrify
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4686] = { -- Barvirus
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4687] = { -- Recall-Jugner
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4688] = { -- Recall-Pashh
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4689] = { -- Recall-Meriph
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4690] = { -- Baramnesia
        vendors = { { 'Tya Padolih', 'Mhaura' } },
    },
    [4691] = { -- Baramnesra
        vendors = { { 'Tya Padolih', 'Mhaura' } },
    },
    [4694] = { -- Barsleepra
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4695] = { -- Barpoisonra
        vendors = { { 'Hasim', 'Lower Jeuno' } },
        drops = {
            [119] = 'Yagudo Priest (1%)',
            [120] = 'Yagudo Priest (1%)',
            [145] = 'Yagudo Priest (1%)',
            [151] = 'Yagudo Priest (1%)',
        },
    },
    [4696] = { -- Barparalyzra
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4697] = { -- Barblindra
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4698] = { -- Barsilencera
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4699] = { -- Barpetra
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4700] = { -- Barvira
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4701] = { -- Cura
        vendors = { { 'Brave Ox', 'Rabao' } },
        drops = {
            [123] = 'River Sahagin (5%)',
            [147] = 'Garnet Quadav (5%)',
            [176] = 'Spring Sahagin (10%)',
        },
    },
    [4702] = { -- Sacrifice
        vendors = { { 'Brave Ox', 'Rabao' } },
        drops = {
            [9] = 'Goblin Alchemist (10%)',
            [174] = 'Goblin Alchemist (10%)',
            [205] = 'Goblin Alchemist (10%)',
            [212] = 'Goblin Alchemist (10%)',
            [213] = 'Goblin Alchemist (10%)',
        },
    },
    [4703] = { -- Esuna
        vendors = { { 'Brave Ox', 'Rabao' } },
        drops = {
            [113] = 'Goblin Alchemist (10%)',
            [176] = 'Lagoon Sahagin (5%)',
        },
    },
    [4704] = { -- Auspice
        vendors = { { 'Brave Ox', 'Rabao' } },
        drops = {
            [147] = 'Topaz Quadav (10%)',
            [151] = 'Yagudo Abbot (5%)',
            [162] = 'Topaz Quadav (10%), Yagudo Abbot (5%)',
            [176] = 'Rivulet Sahagin (10%)',
        },
    },
    [4708] = { -- Enfire
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4709] = { -- Enblizzard
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4710] = { -- Enaero
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4711] = { -- Enstone
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4712] = { -- Enthunder
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4713] = { -- Enwater
        vendors = { { 'Quelpia', 'Selbina' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
    },
    [4714] = { -- Phalanx
        bcnm = { { 'Amphibian Assault [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'Factory Rejects [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' }, { 'Jungle Boogymen [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'Legion XI Comitatensis [Lv60 cap, Moon Orb]', 'Chamber of Oracles' }, { 'Royal Jelly [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Royal Succession [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Steamed Sprouts [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Tails of Woe [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'The Worm\'s Turn [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Under Observation [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'Undying Promise [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' } },
    },
    [4716] = { -- Regen
        vendors = { { 'Tya Padolih', 'Mhaura' } },
        bcnm = { { 'Die by the Sword [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Harem Scarem [Lv30 cap, Sky Orb]', 'Balgas Dais' } },
        drops = {
            [104] = 'Boggart (5%)',
            [119] = 'Boggart (5%)',
            [192] = 'Boggart (5%)',
        },
    },
    [4717] = { -- Refresh
        bcnm = { { 'Factory Rejects [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' }, { 'Royal Jelly [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Royal Succession [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Steamed Sprouts [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Tails of Woe [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'The Worm\'s Turn [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Under Observation [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'Undying Promise [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' } },
        drops = {
            [166] = 'Taisaijin (95%)',
        },
    },
    [4718] = { -- Regen II
        vendors = { { 'Tya Padolih', 'Mhaura' } },
        drops = {
            [176] = 'Rivulet Sahagin (5%)',
            [194] = 'Ten of Cups (5%)',
        },
    },
    [4719] = { -- Regen III
        bcnm = { { '3, 2, 1... [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'An Awful Autopsy [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Eye of the Tiger [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Hostile Herbivores [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Idol Thoughts [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Rapid Raptors [Lv50 cap, Comet Orb]', 'Balgas Dais' }, { 'The Final Bout [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'Treasure and Tribulations [Lv50 cap, Comet Orb]', 'Balgas Dais' } },
        drops = {
            [9] = 'Goblin Alchemist (5%)',
            [113] = 'Goblin Alchemist (5%)',
            [148] = 'Diamond Quadav (10%)',
            [151] = 'Yagudo High Priest (5%)',
            [174] = 'Goblin Alchemist (5%)',
            [176] = 'Novv the Whitehearted (10%), Lagoon Sahagin (5%), Yarr the Pearleyed (1%)',
            [205] = 'Foreseer Oramix (10%), Goblin Alchemist (5%)',
            [212] = 'Goblin Alchemist (5%)',
            [213] = 'Goblin Alchemist (5%)',
        },
    },
    [4720] = { -- Flash
        vendors = { { 'Brave Ox', 'Rabao' } },
        drops = {
            [114] = 'Antican Decurio (5%)',
            [125] = 'Antican Eques (5%)',
            [147] = 'Steel Quadav (5%)',
            [149] = 'Orcish Trooper (5%), Orcish Warchief (5%)',
            [150] = 'Orcish Trooper (5%), Orcish Warchief (5%)',
            [161] = 'Iron Quadav (5%), Orcish Trooper (5%)',
            [162] = 'Iron Quadav (5%), Orcish Trooper (5%), Orcish Warchief (5%), Steel Quadav (5%)',
        },
    },
    [4721] = { -- Repose
        vendors = { { 'Sororo', 'Bastok Markets' } },
    },
    [4722] = { -- Enfire II
        drops = {
            [204] = 'Droma (5%)',
        },
    },
    [4723] = { -- Enblizzard II
        drops = {
            [88] = 'Onyx Quadav (10%)',
            [89] = 'Onyx Quadav (10%)',
        },
    },
    [4724] = { -- Enaero II
        drops = {
            [200] = 'Magic Jug (10%)',
        },
    },
    [4725] = { -- Enstone II
        drops = {
            [122] = 'Magic Flagon (5%)',
        },
    },
    [4726] = { -- Enthunder II
        drops = {
            [159] = 'Hover Tank (5%)',
        },
    },
    [4727] = { -- Enwater II
        drops = {
            [91] = 'Emerald Quadav (10%)',
            [171] = 'Emerald Quadav (10%)',
        },
    },
    [4728] = { -- Teleport-Yhoat
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4729] = { -- Teleport-Altep
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4730] = { -- Teleport-Holla
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4731] = { -- Teleport-Dem
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4732] = { -- Teleport-Mea
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4733] = { -- Protectra
        drops = {
            [88] = 'Amethyst Quadav (1%)',
            [89] = 'Amethyst Quadav (1%), Sapphirine Quadav (1%)',
            [91] = 'Sapphirine Quadav (1%)',
            [95] = 'Yagudo Acolyte (1%)',
            [96] = 'Yagudo Priest (1%)',
            [103] = 'Goblin Leecher (1%)',
            [104] = 'Goblin Leecher (1%)',
            [105] = 'Goblin Leecher (1%)',
            [106] = 'Amethyst Quadav (1%), Goblin Leecher (1%)',
            [107] = 'Amethyst Quadav (1%)',
            [108] = 'Amethyst Quadav (1%)',
            [109] = 'Goblin Leecher (1%)',
            [110] = 'Goblin Leecher (1%)',
            [115] = 'Yagudo Acolyte (1%)',
            [116] = 'Yagudo Acolyte (1%)',
            [117] = 'Yagudo Acolyte (1%)',
            [118] = 'Goblin Leecher (1%)',
            [119] = 'Goblin Leecher (1%)',
            [120] = 'Goblin Leecher (1%)',
            [121] = 'Goblin Leecher (1%)',
            [143] = 'Amethyst Quadav (1%)',
            [145] = 'Yagudo Acolyte (1%)',
            [166] = 'Goblin Leecher (5%)',
            [171] = 'Sapphirine Quadav (1%)',
            [184] = 'Goblin Leecher (5%)',
            [190] = 'Goblin Leecher (5%)',
            [192] = 'Goblin Leecher (5%)',
            [193] = 'Goblin Leecher (5%)',
            [198] = 'Goblin Leecher (5%)',
        },
    },
    [4734] = { -- Protectra II
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [4735] = { -- Protectra III
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4736] = { -- Protectra IV
        vendors = { { 'Brave Ox', 'Rabao' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
        bcnm = { { 'Compliments to the Chef [Lv75 cap]', 'Talacca Cove' }, { 'Happy Caster [Lv75 cap]', 'Navukgo Execution Chamber' }, { 'Shadows of the Mind [Lv75 cap]', 'Jade Sepulcher' } },
    },
    [4737] = { -- Protectra V
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4738] = { -- Shellra
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [4739] = { -- Shellra II
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4740] = { -- Shellra III
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4741] = { -- Shellra IV
        drops = {
            [9] = 'Goblin Alchemist (5%)',
            [113] = 'Goblin Alchemist (5%)',
            [148] = 'Diamond Quadav (10%)',
            [151] = 'Yagudo High Priest (10%)',
            [174] = 'Goblin Alchemist (5%)',
            [176] = 'Novv the Whitehearted (10%), Lagoon Sahagin (5%), Yarr the Pearleyed (1%)',
            [205] = 'Foreseer Oramix (15%), Goblin Alchemist (5%)',
            [212] = 'Goblin Alchemist (5%)',
            [213] = 'Goblin Alchemist (5%)',
        },
    },
    [4742] = { -- Shellra V
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [4743] = { -- Reraise
        drops = {
            [147] = 'Topaz Quadav (10%), Garnet Quadav (5%)',
            [151] = 'Yagudo Abbot (1%)',
            [162] = 'Topaz Quadav (10%), Yagudo Abbot (1%)',
        },
    },
    [4744] = { -- Invisible
        vendors = { { 'Falgima', 'Selbina' }, { 'Tya Padolih', 'Mhaura' } },
        bcnm = { { 'Wings of Fury [Lv20 cap, Cloudy Orb]', 'Ghelsba Outpost' } },
        drops = {
            [103] = 'Goblin Leecher (0.5%)',
            [104] = 'Goblin Leecher (0.5%)',
            [105] = 'Goblin Leecher (0.5%)',
            [106] = 'Goblin Leecher (0.5%)',
            [109] = 'Goblin Leecher (0.5%)',
            [110] = 'Garnet Quadav (1%), Goblin Leecher (0.5%)',
            [118] = 'Goblin Leecher (0.5%)',
            [119] = 'Yagudo Priest (1%), Goblin Leecher (0.5%)',
            [120] = 'Yagudo Priest (1%), Goblin Leecher (0.5%)',
            [121] = 'Goblin Leecher (0.5%)',
            [145] = 'Yagudo Priest (1%)',
            [147] = 'GeDha Evileye (10%)',
            [151] = 'Yagudo Priest (1%)',
            [166] = 'Goblin Leecher (1%)',
            [184] = 'Goblin Leecher (1%)',
            [190] = 'Goblin Leecher (1%)',
            [192] = 'Goblin Leecher (1%)',
            [193] = 'Goblin Leecher (1%)',
            [198] = 'Goblin Leecher (1%)',
        },
    },
    [4745] = { -- Sneak
        vendors = { { 'Falgima', 'Selbina' }, { 'Tya Padolih', 'Mhaura' } },
        bcnm = { { 'Wings of Fury [Lv20 cap, Cloudy Orb]', 'Ghelsba Outpost' } },
        drops = {
            [88] = 'Amethyst Quadav (1%)',
            [89] = 'Amethyst Quadav (1%), Sapphirine Quadav (1%)',
            [91] = 'Sapphirine Quadav (1%)',
            [95] = 'Yagudo Acolyte (1%)',
            [103] = 'Goblin Leecher (1%)',
            [104] = 'Goblin Leecher (1%)',
            [105] = 'Goblin Leecher (1%)',
            [106] = 'Amethyst Quadav (1%), Goblin Leecher (1%)',
            [107] = 'Amethyst Quadav (1%)',
            [108] = 'Amethyst Quadav (1%)',
            [109] = 'Goblin Leecher (1%)',
            [110] = 'Goblin Leecher (1%)',
            [115] = 'Yagudo Acolyte (1%)',
            [116] = 'Yagudo Acolyte (1%)',
            [117] = 'Yagudo Acolyte (1%)',
            [118] = 'Goblin Leecher (1%)',
            [119] = 'Goblin Leecher (1%)',
            [120] = 'Goblin Leecher (1%)',
            [121] = 'Goblin Leecher (1%)',
            [143] = 'Amethyst Quadav (1%)',
            [145] = 'Yagudo Acolyte (1%)',
            [147] = 'GeDha Evileye (10%)',
            [166] = 'Goblin Leecher (5%)',
            [171] = 'Sapphirine Quadav (1%)',
            [184] = 'Goblin Leecher (5%)',
            [190] = 'Goblin Leecher (5%)',
            [192] = 'Goblin Leecher (5%)',
            [193] = 'Goblin Leecher (5%)',
            [198] = 'Goblin Leecher (5%)',
        },
    },
    [4746] = { -- Deodorize
        vendors = { { 'Falgima', 'Selbina' }, { 'Tya Padolih', 'Mhaura' } },
        bcnm = { { 'Wings of Fury [Lv20 cap, Cloudy Orb]', 'Ghelsba Outpost' } },
        drops = {
            [103] = 'Goblin Leecher (0.5%)',
            [104] = 'Goblin Leecher (0.5%)',
            [105] = 'Goblin Leecher (0.5%)',
            [106] = 'Goblin Leecher (0.5%)',
            [109] = 'Goblin Leecher (0.5%)',
            [110] = 'Garnet Quadav (1%), Goblin Leecher (0.5%)',
            [118] = 'Goblin Leecher (0.5%)',
            [119] = 'Yagudo Priest (1%), Goblin Leecher (0.5%)',
            [120] = 'Yagudo Priest (1%), Goblin Leecher (0.5%)',
            [121] = 'Goblin Leecher (0.5%)',
            [145] = 'Hoo Mjuu the Torrent (15%), Yagudo Priest (1%)',
            [151] = 'Yagudo Priest (1%)',
            [166] = 'Goblin Leecher (1%)',
            [184] = 'Goblin Leecher (1%)',
            [190] = 'Goblin Leecher (1%)',
            [192] = 'Goblin Leecher (1%)',
            [193] = 'Goblin Leecher (1%)',
            [198] = 'Goblin Leecher (1%)',
        },
    },
    [4747] = { -- Teleport-Vahzl
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4748] = { -- Raise III
        bcnm = { { 'Bionic Bug [Lv75 cap]', 'Mine Shaft 2716' }, { 'Brothers [Lv75 cap]', 'Bearclaw Pinnacle' }, { 'Cactuar Suave [Clotho Orb]', 'Chamber of Oracles' }, { 'Come Into My Parlor [Clotho Orb]', 'Qu\'Bia Arena' }, { 'E-vase-ive Action [Lachesis Orb]', 'Qu\'Bia Arena' }, { 'Eye of the Storm [Lachesis Orb]', 'Chamber of Oracles' }, { 'Holy Cow [Lv75 cap]', 'Bearclaw Pinnacle' }, { 'Infernal Swarm [Atropos Orb]', 'Qu\'Bia Arena' }, { 'The Scarlet King [Atropos Orb]', 'Chamber of Oracles' }, { 'When Hell Freezes Over [Lv75 cap]', 'Bearclaw Pinnacle' } },
        drops = {
            [148] = 'ZaDha Adamantking (100%)',
            [178] = 'Kirin (10%)',
        },
    },
    [4749] = { -- Reraise II
        bcnm = { { 'Brothers D\'Aurphe [Lv60 cap, Moon Orb]', 'Qu\'Bia Arena' }, { 'Demolition Squad [Lv60 cap, Moon Orb]', 'Qu\'Bia Arena' }, { 'Kindred Spirits [Lv60 cap, Moon Orb]', 'Throne Room' } },
        drops = {
            [204] = 'Hellish Weapon (5%)',
        },
    },
    [4750] = { -- Reraise III
        vendors = { { 'Brave Ox', 'Rabao' } },
        bcnm = { { 'Compliments to the Chef [Lv75 cap]', 'Talacca Cove' }, { 'Happy Caster [Lv75 cap]', 'Navukgo Execution Chamber' }, { 'Shadows of the Mind [Lv75 cap]', 'Jade Sepulcher' } },
        drops = {
            [9] = 'Goblin Alchemist (5%)',
            [113] = 'Goblin Alchemist (5%)',
            [151] = 'Yagudo High Priest (24%)',
            [174] = 'Goblin Alchemist (5%)',
            [176] = 'Coral Sahagin (15%), Yarr the Pearleyed (5%)',
            [205] = 'Goblin Alchemist (5%)',
            [212] = 'Goblin Alchemist (5%)',
            [213] = 'Goblin Alchemist (5%)',
        },
    },
    [4751] = { -- Erase
        bcnm = { { 'Amphibian Assault [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'Birds of a Feather [Lv30 cap, Sky Orb]', 'Waughroon Shrine' }, { 'Carapace Combatants [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Compliments to the Chef [Lv75 cap]', 'Talacca Cove' }, { 'Creeping Doom [Lv30 cap, Sky Orb]', 'Balgas Dais' }, { 'Die by the Sword [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Dropping Like Flies [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Factory Rejects [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' }, { 'Grove Guardians [Lv30 cap, Sky Orb]', 'Waughroon Shrine' }, { 'Happy Caster [Lv75 cap]', 'Navukgo Execution Chamber' }, { 'Harem Scarem [Lv30 cap, Sky Orb]', 'Balgas Dais' }, { 'Jungle Boogymen [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'Legion XI Comitatensis [Lv60 cap, Moon Orb]', 'Chamber of Oracles' }, { 'Let Sleeping Dogs Die [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Petrifying Pair [Lv30 cap, Sky Orb]', 'Ghelsba Outpost' }, { 'Royal Jelly [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Royal Succession [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Shadows of the Mind [Lv75 cap]', 'Jade Sepulcher' }, { 'Steamed Sprouts [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Tails of Woe [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'The Worm\'s Turn [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Under Observation [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'Undying Promise [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' } },
    },
    [4752] = { -- Fire
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4753] = { -- Fire II
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
        bcnm = { { 'Carapace Combatants [Lv30 cap, Sky Orb]', 'Horlais Peak' } },
    },
    [4754] = { -- Fire III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { 'Kindred Spirits [Lv60 cap, Moon Orb]', 'Throne Room' } },
        drops = {
            [5] = 'Dread Demon (5%)',
            [137] = 'Inferno Demon (5%)',
            [138] = 'Soulsearer Demon (5%)',
            [155] = 'Inferno Demon (5%)',
            [160] = 'Hakutaku (10%), Million Eyes (5%)',
            [161] = 'Marquis Amon (10%), Dread Demon (5%)',
            [176] = 'Mindgazer (10%)',
            [190] = 'Locus Thousand Eyes (5%)',
            [205] = 'Dodomeki (10%)',
        },
    },
    [4755] = { -- Fire IV
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [5] = 'Dread Demon (1%)',
            [137] = 'Inferno Demon (1%)',
            [138] = 'Soulsearer Demon (1%)',
            [155] = 'Inferno Demon (1%)',
            [160] = 'Hakutaku (5%), Million Eyes (1%)',
            [161] = 'Marquis Amon (5%), Dread Demon (1%)',
        },
    },
    [4757] = { -- Blizzard
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4758] = { -- Blizzard II
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4759] = { -- Blizzard III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [5] = 'Doom Mage (5%)',
            [7] = 'Tomb Mage (5%)',
            [113] = 'Doom Mage (5%)',
            [169] = 'Doom Mage (5%), Mindcraver (5%)',
            [190] = 'Locus Spartoi Sorcerer (1%), Spartoi Sorcerer (1%)',
            [195] = 'Tomb Mage (5%)',
            [200] = 'Fallen Mage (5%)',
            [212] = 'Taxim (25%), Doom Mage (5%), Doom Warlock (1.8%)',
        },
    },
    [4760] = { -- Blizzard IV
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { 'Compliments to the Chef [Lv75 cap]', 'Talacca Cove' }, { 'Happy Caster [Lv75 cap]', 'Navukgo Execution Chamber' }, { 'Shadows of the Mind [Lv75 cap]', 'Jade Sepulcher' } },
        drops = {
            [190] = 'Locus Spartoi Sorcerer (1%), Spartoi Sorcerer (1%)',
            [212] = 'Taxim (12%), Doom Warlock (0.8%)',
        },
    },
    [4762] = { -- Aero
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4763] = { -- Aero II
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4764] = { -- Aero III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [12] = 'Moblin Engineman (1%)',
            [97] = 'Yagudo Prelate (5%)',
            [98] = 'Yagudo Prior (5%)',
            [99] = 'Yagudo Prelate (5%), Yagudo Hierogrammat (1.8%)',
            [138] = 'Yagudo Prelate (5%)',
            [151] = 'Yagudo Prelate (5%)',
            [155] = 'Yagudo Hierogrammat (1.8%)',
            [164] = 'Yagudo Prior (5%)',
        },
    },
    [4765] = { -- Aero IV
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { 'Call to Arms [Lv60 cap]', 'Talacca Cove' }, { 'Making a Mockery [Lv60 cap]', 'Jade Sepulcher' }, { 'Tough Nut to Crack [Lv60 cap]', 'Navukgo Execution Chamber' } },
        drops = {
            [12] = 'Moblin Engineman (1%)',
            [97] = 'Yagudo Prelate (1%)',
            [98] = 'Yagudo Prior (1%)',
            [99] = 'Yagudo Prelate (1%), Yagudo Hierogrammat (0.8%)',
            [138] = 'Yagudo Prelate (1%)',
            [151] = 'Yagudo Prelate (1%)',
            [155] = 'Yagudo Hierogrammat (0.8%)',
            [164] = 'Yagudo Prior (1%)',
        },
    },
    [4767] = { -- Stone
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4768] = { -- Stone II
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4769] = { -- Stone III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [12] = 'Moblin Draftsman (1%)',
            [88] = 'Goblin Chapman (1%)',
            [150] = 'Orcish Hexspinner (15%), Orcish Warlord (1%)',
            [208] = 'Centurio X-I (15%)',
        },
    },
    [4770] = { -- Stone IV
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [88] = 'Goblin Chapman (0.5%)',
            [150] = 'Orcish Hexspinner (1%), Orcish Warlord (1%)',
            [208] = 'Antican Praetor (10%), Antican Proconsul (10%), Antican Quaestor (10%), Centurio X-I (10%)',
        },
    },
    [4772] = { -- Thunder
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4773] = { -- Thunder II
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4774] = { -- Thunder III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { 'Cactuar Suave [Clotho Orb]', 'Chamber of Oracles' }, { 'Come Into My Parlor [Clotho Orb]', 'Qu\'Bia Arena' }, { 'E-vase-ive Action [Lachesis Orb]', 'Qu\'Bia Arena' }, { 'Eye of the Storm [Lachesis Orb]', 'Chamber of Oracles' }, { 'Infernal Swarm [Atropos Orb]', 'Qu\'Bia Arena' }, { 'The Scarlet King [Atropos Orb]', 'Chamber of Oracles' } },
        drops = {
            [122] = 'Magic Flagon (1.8%)',
            [124] = 'Tonberry Jinxer (1%)',
            [130] = 'Sprinkler (1.8%)',
            [158] = 'Magic Pot (1.8%)',
            [159] = 'Hover Tank (1.8%), Tonberry Maledictor (1%)',
            [160] = 'Tonberry Imprecator (1%)',
            [177] = 'Dustbuster (1.8%)',
            [178] = 'Aura Pot (0.3%)',
            [213] = 'Mysticmaker Profblix (45%)',
        },
    },
    [4775] = { -- Thunder IV
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [122] = 'Magic Flagon (0.8%)',
            [130] = 'Sprinkler (0.8%)',
            [158] = 'Magic Pot (0.8%)',
            [159] = 'Hover Tank (0.8%)',
            [177] = 'Dustbuster (0.8%)',
            [178] = 'Aura Pot (0.1%)',
            [213] = 'Mysticmaker Profblix (20%)',
        },
    },
    [4777] = { -- Water
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4778] = { -- Water II
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4779] = { -- Water III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [92] = 'Baetyl Quadav (5%)',
            [147] = 'Sapphire Quadav (5%)',
            [148] = 'Sapphire Quadav (5%)',
            [160] = 'Tonberry Pontifex (15%), Bistre-hearted Malberry (5%)',
        },
    },
    [4780] = { -- Water IV
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { 'Compliments to the Chef [Lv75 cap]', 'Talacca Cove' }, { 'Happy Caster [Lv75 cap]', 'Navukgo Execution Chamber' }, { 'Shadows of the Mind [Lv75 cap]', 'Jade Sepulcher' } },
        drops = {
            [92] = 'Baetyl Quadav (0.5%)',
            [147] = 'Sapphire Quadav (1%)',
            [148] = 'Sapphire Quadav (1%)',
            [160] = 'Sozu Bliberry (15%), Bistre-hearted Malberry (5%), Tonberry Pontifex (5%)',
        },
    },
    [4782] = { -- Firaga
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4783] = { -- Firaga II
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [5] = 'Dread Demon (5%), Kindred Black Mage (5%)',
            [137] = 'Inferno Demon (5%)',
            [138] = 'Soulsearer Demon (5%)',
            [155] = 'Inferno Demon (5%)',
            [161] = 'Dread Demon (10%)',
        },
    },
    [4784] = { -- Firaga III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [5] = 'Dread Demon (1%)',
            [137] = 'Inferno Demon (1%)',
            [138] = 'Soulsearer Demon (1%)',
            [155] = 'Inferno Demon (1%)',
            [160] = 'Hakutaku (10%), Million Eyes (1%)',
            [161] = 'Marquis Amon (5%), Dread Demon (1%)',
        },
    },
    [4787] = { -- Blizzaga
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4788] = { -- Blizzaga II
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [5] = 'Phasma (10%), Srei Ap (5%)',
            [190] = 'Locus Spartoi Sorcerer (1%), Spartoi Sorcerer (1%)',
            [195] = 'Haunt (10%)',
            [212] = 'Taxim (25%), Doom Warlock (1.2%)',
        },
    },
    [4789] = { -- Blizzaga III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [190] = 'Locus Spartoi Sorcerer (1%), Spartoi Sorcerer (1%)',
            [212] = 'Taxim (25%), Doom Warlock (0.8%)',
        },
    },
    [4792] = { -- Aeroga
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4793] = { -- Aeroga II
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [12] = 'Moblin Engineman (1%)',
            [97] = 'Yagudo Prelate (5%)',
            [98] = 'Yagudo Prior (5%)',
            [99] = 'Yagudo Prelate (5%), Yagudo Hierogrammat (1%)',
            [138] = 'Yagudo Prelate (5%)',
            [151] = 'Yagudo Prelate (5%)',
            [155] = 'Yagudo Hierogrammat (1%)',
            [164] = 'Yagudo Prior (5%)',
        },
    },
    [4794] = { -- Aeroga III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [12] = 'Moblin Engineman (1%)',
            [97] = 'Yagudo Prelate (1%)',
            [98] = 'Yagudo Prior (1%)',
            [99] = 'Yagudo Hierogrammat (1%), Yagudo Prelate (1%)',
            [138] = 'Yagudo Prelate (1%)',
            [151] = 'Yagudo Prelate (1%)',
            [155] = 'Yagudo Hierogrammat (1%)',
            [162] = 'Baron Vapula (15%)',
            [164] = 'Yagudo Prior (1%)',
        },
    },
    [4797] = { -- Stonega
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4798] = { -- Stonega II
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [12] = 'Moblin Draftsman (1%)',
            [88] = 'Goblin Chapman (0.5%)',
            [150] = 'Orcish Hexspinner (10%), Orcish Warlord (5%)',
            [208] = 'Centurio X-I (15%), Antican Quaestor (10%)',
        },
    },
    [4799] = { -- Stonega III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [12] = 'Moblin Draftsman (1%)',
            [88] = 'Goblin Chapman (1%)',
            [150] = 'Orcish Hexspinner (5%), Orcish Warlord (1%)',
            [208] = 'Antican Praetor (10%), Antican Proconsul (10%), Centurio X-I (10%), Antican Quaestor (5%)',
        },
    },
    [4802] = { -- Thundaga
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4803] = { -- Thundaga II
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [124] = 'Tonberry Jinxer (5%)',
            [159] = 'Tonberry Maledictor (5%)',
            [160] = 'Tonberry Imprecator (5%)',
            [162] = 'Baron Vapula (15%)',
        },
    },
    [4804] = { -- Thundaga III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [122] = 'Magic Flagon (1%)',
            [130] = 'Sprinkler (1%)',
            [158] = 'Magic Pot (1%)',
            [159] = 'Hover Tank (1%)',
            [177] = 'Dustbuster (1%)',
            [178] = 'Aura Pot (0.2%)',
            [213] = 'Mysticmaker Profblix (25%)',
        },
    },
    [4807] = { -- Waterga
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4808] = { -- Waterga II
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [92] = 'Baetyl Quadav (1%)',
            [147] = 'Sapphire Quadav (1%)',
            [148] = 'Sapphire Quadav (1%)',
            [160] = 'Bistre-hearted Malberry (10%), Tonberry Pontifex (10%)',
        },
    },
    [4809] = { -- Waterga III
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [92] = 'Baetyl Quadav (1%)',
            [147] = 'Sapphire Quadav (1%)',
            [148] = 'Sapphire Quadav (1%)',
            [160] = 'Bistre-hearted Malberry (10%), Sozu Bliberry (10%), Tonberry Pontifex (10%)',
        },
    },
    [4812] = { -- Flare
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { 'Brothers D\'Aurphe [Lv60 cap, Moon Orb]', 'Qu\'Bia Arena' }, { 'Call to Arms [Lv60 cap]', 'Talacca Cove' }, { 'Demolition Squad [Lv60 cap, Moon Orb]', 'Qu\'Bia Arena' }, { 'Making a Mockery [Lv60 cap]', 'Jade Sepulcher' }, { 'Tough Nut to Crack [Lv60 cap]', 'Navukgo Execution Chamber' } },
        drops = {
            [5] = 'Dread Demon (0.5%)',
            [137] = 'Inferno Demon (0.5%)',
            [138] = 'Soulsearer Demon (0.5%)',
            [155] = 'Inferno Demon (0.5%)',
            [160] = 'Hakutaku (1%), Million Eyes (1%)',
            [161] = 'Marquis Amon (1%), Dread Demon (0.5%)',
        },
    },
    [4813] = { -- Flare II
        vendors = { { 'Susu', 'Lower Jeuno' } },
    },
    [4814] = { -- Freeze
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { '3, 2, 1... [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'An Awful Autopsy [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Eye of the Tiger [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Hostile Herbivores [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Idol Thoughts [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Rapid Raptors [Lv50 cap, Comet Orb]', 'Balgas Dais' }, { 'The Final Bout [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'Treasure and Tribulations [Lv50 cap, Comet Orb]', 'Balgas Dais' } },
        drops = {
            [190] = 'Locus Spartoi Sorcerer (1%), Spartoi Sorcerer (1%)',
            [195] = 'Haunt (5%)',
            [212] = 'Taxim (12%), Doom Warlock (0.5%)',
        },
    },
    [4815] = { -- Freeze II
        vendors = { { 'Susu', 'Lower Jeuno' } },
    },
    [4816] = { -- Tornado
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { 'Call to Arms [Lv60 cap]', 'Talacca Cove' }, { 'Making a Mockery [Lv60 cap]', 'Jade Sepulcher' }, { 'Tough Nut to Crack [Lv60 cap]', 'Navukgo Execution Chamber' } },
        drops = {
            [97] = 'Yagudo Prelate (1%)',
            [98] = 'Yagudo Prior (1%)',
            [99] = 'Yagudo Prelate (1%), Yagudo Hierogrammat (0.5%)',
            [138] = 'Yagudo Prelate (1%)',
            [151] = 'Yagudo Prelate (1%)',
            [155] = 'Yagudo Hierogrammat (0.5%)',
            [164] = 'Yagudo Prior (1%)',
        },
    },
    [4817] = { -- Tornado II
        vendors = { { 'Susu', 'Lower Jeuno' } },
    },
    [4818] = { -- Quake
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { '3, 2, 1... [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'An Awful Autopsy [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Compliments to the Chef [Lv75 cap]', 'Talacca Cove' }, { 'Eye of the Tiger [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Happy Caster [Lv75 cap]', 'Navukgo Execution Chamber' }, { 'Hostile Herbivores [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Idol Thoughts [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Rapid Raptors [Lv50 cap, Comet Orb]', 'Balgas Dais' }, { 'Shadows of the Mind [Lv75 cap]', 'Jade Sepulcher' }, { 'The Final Bout [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'Treasure and Tribulations [Lv50 cap, Comet Orb]', 'Balgas Dais' } },
        drops = {
            [12] = 'Moblin Draftsman (1%)',
            [88] = 'Goblin Chapman (0.1%)',
            [150] = 'Orcish Hexspinner (5%), Orcish Warlord (1%)',
            [178] = 'Kirin (10%)',
            [208] = 'Centurio X-I (5%)',
        },
    },
    [4819] = { -- Quake II
        vendors = { { 'Susu', 'Lower Jeuno' } },
    },
    [4820] = { -- Burst
        vendors = { { 'Susu', 'Lower Jeuno' } },
        drops = {
            [122] = 'Magic Flagon (0.5%)',
            [130] = 'Sprinkler (0.5%)',
            [158] = 'Magic Pot (0.5%)',
            [159] = 'Hover Tank (0.5%)',
            [177] = 'Dustbuster (0.5%)',
            [178] = 'Aura Pot (0.1%)',
            [213] = 'Mysticmaker Profblix (10%)',
        },
    },
    [4821] = { -- Burst II
        vendors = { { 'Susu', 'Lower Jeuno' } },
    },
    [4822] = { -- Flood
        vendors = { { 'Susu', 'Lower Jeuno' } },
        bcnm = { { 'Call to Arms [Lv60 cap]', 'Talacca Cove' }, { 'Making a Mockery [Lv60 cap]', 'Jade Sepulcher' }, { 'Tough Nut to Crack [Lv60 cap]', 'Navukgo Execution Chamber' } },
        drops = {
            [92] = 'Baetyl Quadav (0.5%)',
            [147] = 'Sapphire Quadav (1%)',
            [148] = 'Sapphire Quadav (1%)',
            [160] = 'Bistre-hearted Malberry (5%), Tonberry Pontifex (5%)',
        },
    },
    [4823] = { -- Flood II
        vendors = { { 'Susu', 'Lower Jeuno' } },
    },
    [4824] = { -- Gravity
        drops = {
            [2] = 'Wight blm (5%)',
            [192] = 'Wendigo blm (1%)',
            [194] = 'Ghoul blm (5%), Ghoul war (5%)',
            [196] = 'Ghoul blm (1%), Ghoul war (1%)',
            [198] = 'Wendigo blm (5%)',
        },
    },
    [4828] = { -- Poison
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4829] = { -- Poison II
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4833] = { -- Poisonga
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4838] = { -- Bio
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4839] = { -- Bio II
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4840] = { -- Bio III
        vendors = { { 'Susu', 'Lower Jeuno' } },
    },
    [4843] = { -- Burn
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4844] = { -- Frost
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4845] = { -- Choke
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4846] = { -- Rasp
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4847] = { -- Shock
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4848] = { -- Drown
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4849] = { -- Addle
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [4850] = { -- Refresh II
        drops = {
            [166] = 'Taisaijin (5%)',
        },
    },
    [4853] = { -- Drain
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
        bcnm = { { 'Charming Trio [Lv20 cap, Cloudy Orb]', 'Balgas Dais' } },
    },
    [4855] = { -- Aspir
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4857] = { -- Blaze Spikes
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
        bcnm = { { 'Shooting Fish [Lv20 cap, Cloudy Orb]', 'Horlais Peak' } },
    },
    [4858] = { -- Ice Spikes
        bcnm = { { 'Factory Rejects [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' }, { 'Royal Jelly [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Royal Succession [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Steamed Sprouts [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Tails of Woe [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'The Worm\'s Turn [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Under Observation [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'Undying Promise [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' } },
        drops = {
            [220] = 'Phantom (5%)',
            [221] = 'Phantom (5%)',
            [227] = 'Phantom (5%)',
            [228] = 'Phantom (5%)',
        },
    },
    [4859] = { -- Shock Spikes
        vendors = { { 'Chutarmire', 'Selbina' }, { 'Hilkomu-Makimu', 'Windurst Waters' } },
    },
    [4860] = { -- Stun
        vendors = { { 'Brave Ox', 'Rabao' } },
        drops = {
            [121] = 'Rot Prowler (1%)',
            [125] = 'Fallen Knight (1%)',
            [127] = 'Lost Soul blm (1%), Lost Soul war (1%)',
            [149] = 'Orcish Zerker (5%)',
            [150] = 'Orcish Warlord (15%), Orcish Zerker (5%)',
            [161] = 'Goblin Reaper (5%)',
            [162] = 'Goblin Reaper (5%), Orcish Zerker (5%)',
            [195] = 'Shade drk (5%), Shade rng (5%), Shade thf (5%), Shade war (5%), Mummy (1%)',
            [200] = 'Fallen Soldier blm (1%), Fallen Soldier war (1%)',
            [212] = 'Goblin Reaper (5%)',
            [213] = 'Goblin Reaper (5%)',
        },
    },
    [4861] = { -- Sleep
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
    },
    [4862] = { -- Blind
        vendors = { { 'Aroro', 'Port Windurst' }, { 'Regine', 'Port San d\'Oria' }, { 'Zaira', 'Batok Markets' } },
        drops = {
            [89] = 'Heliodor Quadav (1%)',
            [90] = 'Zircon Quadav (5%)',
            [91] = 'Heliodor Quadav (1%)',
            [92] = 'Magnes Quadav (5%)',
            [100] = 'Orcish Mesmerizer (5%)',
            [101] = 'Orcish Mesmerizer (5%)',
            [102] = 'Orcish Mesmerizer (5%)',
            [106] = 'Amber Quadav (5%)',
            [107] = 'Amber Quadav (5%)',
            [108] = 'Amber Quadav (5%)',
            [115] = 'Yagudo Scribe (5%)',
            [116] = 'Yagudo Scribe (5%)',
            [117] = 'Yagudo Scribe (5%)',
            [138] = 'Magnes Quadav (5%)',
            [140] = 'Orcish Mesmerizer (5%)',
            [141] = 'Orcish Mesmerizer (5%)',
            [143] = 'Amber Quadav (1%)',
            [145] = 'Yagudo Scribe (5%)',
            [155] = 'Baetyl Quadav (5%)',
            [171] = 'Heliodor Quadav (1%)',
        },
    },
    [4866] = { -- Bind
        drops = {
            [89] = 'Heliodor Quadav (1%)',
            [90] = 'Zircon Quadav (5%)',
            [91] = 'Heliodor Quadav (1%)',
            [92] = 'Magnes Quadav (5%)',
            [100] = 'Orcish Mesmerizer (5%)',
            [101] = 'Orcish Mesmerizer (5%)',
            [102] = 'Orcish Mesmerizer (5%)',
            [106] = 'Amber Quadav (5%)',
            [107] = 'Amber Quadav (5%)',
            [108] = 'Amber Quadav (5%)',
            [115] = 'Yagudo Scribe (5%)',
            [116] = 'Yagudo Scribe (5%)',
            [117] = 'Yagudo Scribe (5%)',
            [138] = 'Magnes Quadav (5%)',
            [140] = 'Orcish Mesmerizer (5%)',
            [141] = 'Orcish Mesmerizer (5%)',
            [143] = 'Amber Quadav (1%)',
            [145] = 'Yagudo Scribe (5%)',
            [155] = 'Baetyl Quadav (5%)',
            [171] = 'Heliodor Quadav (1%)',
        },
    },
    [4867] = { -- Sleep II
        vendors = { { 'Susu', 'Lower Jeuno' } },
    },
    [4868] = { -- Dispel
        vendors = { { 'Brave Ox', 'Rabao' }, { 'Shohrun-Tuhrun', 'Windurst Waters' } },
        bcnm = { { 'Birds of a Feather [Lv30 cap, Sky Orb]', 'Waughroon Shrine' }, { 'Carapace Combatants [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Compliments to the Chef [Lv75 cap]', 'Talacca Cove' }, { 'Creeping Doom [Lv30 cap, Sky Orb]', 'Balgas Dais' }, { 'Die by the Sword [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Dropping Like Flies [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Grove Guardians [Lv30 cap, Sky Orb]', 'Waughroon Shrine' }, { 'Happy Caster [Lv75 cap]', 'Navukgo Execution Chamber' }, { 'Harem Scarem [Lv30 cap, Sky Orb]', 'Balgas Dais' }, { 'Let Sleeping Dogs Die [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Petrifying Pair [Lv30 cap, Sky Orb]', 'Ghelsba Outpost' }, { 'Shadows of the Mind [Lv75 cap]', 'Jade Sepulcher' } },
    },
    [4869] = { -- Warp
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
        bcnm = { { 'Shooting Fish [Lv20 cap, Cloudy Orb]', 'Horlais Peak' } },
    },
    [4870] = { -- Warp II
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4871] = { -- Escape
        drops = {
            [126] = 'Banshee (5%)',
            [157] = 'Banshee (5%)',
            [196] = 'Banshee (5%)',
        },
    },
    [4872] = { -- Tractor
        drops = {
            [105] = 'Wight blm (1%), Wight war (1%)',
            [110] = 'Wight blm (1%), Wight war (1%)',
            [120] = 'Wight blm (1%), Wight war (1%)',
            [196] = 'Wight blm (1%), Wight war (1%)',
            [198] = 'Wight blm (1%), Wight war (1%)',
        },
    },
    [4873] = { -- Retrace
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4874] = { -- Absorb-STR
        bcnm = { { 'Amphibian Assault [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'Factory Rejects [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' }, { 'Jungle Boogymen [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'Legion XI Comitatensis [Lv60 cap, Moon Orb]', 'Chamber of Oracles' }, { 'Royal Jelly [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Royal Succession [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Steamed Sprouts [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Tails of Woe [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'The Worm\'s Turn [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Under Observation [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'Undying Promise [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' } },
    },
    [4875] = { -- Absorb-DEX
        drops = {
            [5] = 'Judicator Demon (5%)',
            [137] = 'Eclipse Demon (1%)',
            [155] = 'Eclipse Demon (1%)',
            [161] = 'Duke Haborym (24%)',
            [162] = 'Count Bifrons (15%)',
        },
    },
    [4876] = { -- Absorb-VIT
        bcnm = { { 'Let Sleeping Dogs Die [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Petrifying Pair [Lv30 cap, Sky Orb]', 'Ghelsba Outpost' } },
        drops = {
            [5] = 'Doom Soldier (1%)',
            [7] = 'Goblin Reaper (1%)',
            [81] = 'Goblin Franctireur (1%)',
            [82] = 'Ghoul war (1%)',
            [88] = 'Goblin Franctireur (1%)',
            [91] = 'Goblin Franctireur (1%)',
            [95] = 'Goblin Franctireur (1%)',
            [111] = 'Ghast blm (1%), Ghast war (1%), Goblin Reaper (1%)',
            [112] = 'Demon Knight (1%), Lost Soul blm (1%), Lost Soul war (1%)',
            [114] = 'Goblin Reaper (1%)',
            [121] = 'Rot Prowler (5%), Goblin Reaper (1%)',
            [123] = 'Goblin Reaper (1%)',
            [124] = 'Goblin Reaper (1%)',
            [125] = 'Fallen Knight (1%)',
            [147] = 'Mythril Quadav (1%)',
            [149] = 'Orcish Zerker (5%), Tigerbane Bakdak (5%), Orcish Beastrider (1%)',
            [150] = 'Orcish Zerker (5%)',
            [161] = 'Demon General (1%), Demon Knight (1%), Goblin Reaper (1%)',
            [162] = 'Orcish Zerker (5%), Demon Knight (1%), Goblin Reaper (1%), Mythril Quadav (1%)',
            [169] = 'Fallen Knight (1%)',
            [176] = 'Ghast blm (1%), Ghast war (1%)',
            [195] = 'Dark Stalker blm (1%), Dark Stalker rng (1%), Dark Stalker war (1%), Fallen Knight (1%), Ka blm (1%), Ka rng (1%), Ka thf (1%), Ka war (1%), Mummy (1%), Shade drk (1%), Shade rng (1%), Shade thf (1%), Shade war (1%)',
            [196] = 'Wight blm (1%), Wight war (1%)',
            [198] = 'Wight blm (1%), Wight war (1%)',
            [200] = 'Fallen Officer blm (1%), Fallen Officer war (1%), Fallen Soldier blm (1%), Fallen Soldier war (1%), Fallen Evacuee blm (0.5%), Fallen Evacuee war (0.5%)',
            [204] = 'Specter blm (1%), Specter rng (1%), Specter thf (1%), Specter war (1%)',
            [212] = 'Goblin Reaper (1%)',
            [213] = 'Goblin Reaper (1%)',
        },
    },
    [4877] = { -- Absorb-AGI
        bcnm = { { 'Carapace Combatants [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Let Sleeping Dogs Die [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Petrifying Pair [Lv30 cap, Sky Orb]', 'Ghelsba Outpost' } },
        drops = {
            [5] = 'Doom Soldier (1%)',
            [7] = 'Goblin Reaper (1%)',
            [81] = 'Goblin Franctireur (1%)',
            [82] = 'Ghoul war (1%)',
            [88] = 'Goblin Franctireur (1%)',
            [91] = 'Goblin Franctireur (1%)',
            [95] = 'Goblin Franctireur (1%)',
            [111] = 'Ghast blm (1%), Ghast war (1%), Goblin Reaper (1%)',
            [112] = 'Demon Knight (1%), Lost Soul blm (1%), Lost Soul war (1%)',
            [114] = 'Goblin Reaper (1%)',
            [121] = 'Goblin Reaper (1%), Rot Prowler (1%)',
            [123] = 'Goblin Reaper (1%)',
            [124] = 'Goblin Reaper (1%)',
            [125] = 'Fallen Knight (1%)',
            [147] = 'Mythril Quadav (1%)',
            [149] = 'Orcish Zerker (5%), Tigerbane Bakdak (5%), Orcish Beastrider (1%)',
            [150] = 'Orcish Zerker (5%)',
            [161] = 'Demon General (1%), Demon Knight (1%), Goblin Reaper (1%)',
            [162] = 'Orcish Zerker (5%), Demon Knight (1%), Goblin Reaper (1%), Mythril Quadav (1%)',
            [169] = 'Fallen Knight (1%)',
            [176] = 'Ghast blm (1%), Ghast war (1%)',
            [195] = 'Dark Stalker blm (1%), Dark Stalker rng (1%), Dark Stalker war (1%), Fallen Knight (1%), Ka blm (1%), Ka rng (1%), Ka thf (1%), Ka war (1%), Mummy (1%), Shade drk (1%), Shade rng (1%), Shade thf (1%), Shade war (1%)',
            [196] = 'Wight blm (1%), Wight war (1%)',
            [198] = 'Wight blm (1%), Wight war (1%)',
            [200] = 'Fallen Officer blm (1%), Fallen Officer war (1%), Fallen Soldier blm (1%), Fallen Soldier war (1%), Fallen Evacuee blm (0.5%), Fallen Evacuee war (0.5%)',
            [204] = 'Specter blm (1%), Specter rng (1%), Specter thf (1%), Specter war (1%)',
            [212] = 'Goblin Reaper (1%)',
            [213] = 'Goblin Reaper (1%)',
        },
    },
    [4878] = { -- Absorb-INT
        bcnm = { { 'Carapace Combatants [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Let Sleeping Dogs Die [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Petrifying Pair [Lv30 cap, Sky Orb]', 'Ghelsba Outpost' } },
        drops = {
            [5] = 'Doom Soldier (1%)',
            [7] = 'Goblin Reaper (1%)',
            [81] = 'Goblin Franctireur (1%)',
            [82] = 'Ghoul war (1%)',
            [88] = 'Goblin Franctireur (1%)',
            [91] = 'Goblin Franctireur (1%)',
            [95] = 'Goblin Franctireur (1%)',
            [111] = 'Ghast blm (1%), Ghast war (1%), Goblin Reaper (1%)',
            [112] = 'Demon Knight (5%), Lost Soul blm (1%), Lost Soul war (1%)',
            [114] = 'Goblin Reaper (1%)',
            [121] = 'Rot Prowler (5%), Goblin Reaper (1%)',
            [123] = 'Goblin Reaper (1%)',
            [124] = 'Goblin Reaper (1%)',
            [125] = 'Fallen Knight (1%)',
            [147] = 'Mythril Quadav (1%)',
            [149] = 'Orcish Zerker (5%), Orcish Beastrider (1%), Tigerbane Bakdak (1%)',
            [150] = 'Orcish Zerker (5%)',
            [161] = 'Demon General (5%), Demon Knight (5%), Goblin Reaper (1%)',
            [162] = 'Demon Knight (5%), Orcish Zerker (5%), Goblin Reaper (1%), Mythril Quadav (1%)',
            [169] = 'Fallen Knight (1%)',
            [176] = 'Ghast blm (1%), Ghast war (1%)',
            [195] = 'Dark Stalker blm (5%), Dark Stalker rng (5%), Dark Stalker war (5%), Fallen Knight (1%), Ka blm (1%), Ka rng (1%), Ka thf (1%), Ka war (1%), Mummy (1%), Shade drk (1%), Shade rng (1%), Shade thf (1%), Shade war (1%)',
            [196] = 'Wight blm (1%), Wight war (1%)',
            [198] = 'Wight blm (1%), Wight war (1%)',
            [200] = 'Fallen Evacuee blm (1%), Fallen Evacuee war (1%), Fallen Officer blm (1%), Fallen Officer war (1%), Fallen Soldier blm (1%), Fallen Soldier war (1%)',
            [204] = 'Specter blm (1%), Specter rng (1%), Specter thf (1%), Specter war (1%)',
            [212] = 'Goblin Reaper (1%)',
            [213] = 'Goblin Reaper (1%)',
        },
    },
    [4881] = { -- Sleepga
        vendors = { { 'Susu', 'Lower Jeuno' }, { 'Tya Padolih', 'Mhaura' } },
    },
    [4882] = { -- Sleepga II
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4884] = { -- Blind II
        vendors = { { 'Susu', 'Lower Jeuno' } },
    },
    [4886] = { -- Absorb-Acc
        drops = {
            [81] = 'Orcish Neckchopper (1%)',
        },
    },
    [4896] = { -- Fire Spirit
        bcnm = { { '3, 2, 1... [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'Amphibian Assault [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'An Awful Autopsy [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Eye of the Tiger [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Factory Rejects [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' }, { 'Idol Thoughts [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Jungle Boogymen [Lv60 cap, Moon Orb]', 'Sacrificial Chamber' }, { 'Legion XI Comitatensis [Lv60 cap, Moon Orb]', 'Chamber of Oracles' }, { 'Rapid Raptors [Lv50 cap, Comet Orb]', 'Balgas Dais' }, { 'Royal Jelly [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Royal Succession [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Steamed Sprouts [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Tails of Woe [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'The Worm\'s Turn [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Under Observation [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'Undying Promise [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' } },
    },
    [4897] = { -- Ice Spirit
        bcnm = { { 'Kindred Spirits [Lv60 cap, Moon Orb]', 'Throne Room' } },
        drops = {
            [5] = 'Stygian Demon (5%)',
            [137] = 'Adjudicator Demon (1%)',
            [155] = 'Adjudicator Demon (1%)',
            [161] = 'Abyssal Demon (5%), Stygian Demon (5%), Demon Magistrate (1%), Demon Warlock (1%)',
            [162] = 'Demon Warlock (1%)',
        },
    },
    [4898] = { -- Air Spirit
        bcnm = { { 'Charming Trio [Lv20 cap, Cloudy Orb]', 'Balgas Dais' } },
        drops = {
            [95] = 'Yagudo Mendicant (1%)',
            [97] = 'Yagudo Prioress (5%)',
            [98] = 'Yagudo Pythoness (5%)',
            [99] = 'Yagudo Prioress (5%), Yagudo Superior (1%)',
            [120] = 'Yagudo Oracle (5%)',
            [151] = 'Yagudo Avatar (100%), Yagudo Oracle (5%)',
            [164] = 'Yagudo Pythoness (5%)',
        },
    },
    [4899] = { -- Earth Spirit
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4900] = { -- Thunder Spirit
        bcnm = { { 'Shooting Fish [Lv20 cap, Cloudy Orb]', 'Horlais Peak' }, { 'Wings of Fury [Lv20 cap, Cloudy Orb]', 'Ghelsba Outpost' } },
    },
    [4901] = { -- Water Spirit
        drops = {
            [9] = 'Cryptonberry Harrier (1%)',
            [124] = 'Tonberry Harasser (1%)',
            [159] = 'Tonberry Dismayer (5%), Tonberry Kinq (5%), Tonberry Harrier (1%)',
            [160] = 'Carmine-tailed Janberry (10%), Tonberry Beleaguerer (5%)',
        },
    },
    [4902] = { -- Light Spirit
        bcnm = { { '3, 2, 1... [Lv50 cap, Comet Orb]', 'Waughroon Shrine' }, { 'An Awful Autopsy [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Cactuar Suave [Clotho Orb]', 'Chamber of Oracles' }, { 'Call to Arms [Lv60 cap]', 'Talacca Cove' }, { 'Come Into My Parlor [Clotho Orb]', 'Qu\'Bia Arena' }, { 'E-vase-ive Action [Lachesis Orb]', 'Qu\'Bia Arena' }, { 'Eye of the Storm [Lachesis Orb]', 'Chamber of Oracles' }, { 'Eye of the Tiger [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Hostile Herbivores [Lv50 cap, Comet Orb]', 'Horlais Peak' }, { 'Idol Thoughts [Lv50 cap, Comet Orb]', 'Qu\'Bia Arena' }, { 'Infernal Swarm [Atropos Orb]', 'Qu\'Bia Arena' }, { 'Making a Mockery [Lv60 cap]', 'Jade Sepulcher' }, { 'Rapid Raptors [Lv50 cap, Comet Orb]', 'Balgas Dais' }, { 'The Scarlet King [Atropos Orb]', 'Chamber of Oracles' }, { 'Tough Nut to Crack [Lv60 cap]', 'Navukgo Execution Chamber' }, { 'Treasure and Tribulations [Lv50 cap, Comet Orb]', 'Balgas Dais' } },
        drops = {
            [159] = 'Crimson-toothed Pawberry (10%), Tonberry Kinq (5%)',
        },
    },
    [4903] = { -- Dark Spirit
        bcnm = { { 'Call to Arms [Lv60 cap]', 'Talacca Cove' }, { 'Making a Mockery [Lv60 cap]', 'Jade Sepulcher' }, { 'Tough Nut to Crack [Lv60 cap]', 'Navukgo Execution Chamber' } },
        drops = {
            [5] = 'Kindred Summoner (1%)',
            [162] = 'Viscount Morax (10%)',
        },
    },
    [4912] = { -- Distract
        vendors = { { 'Tya Padolih', 'Mhaura' } },
    },
    [4914] = { -- Frazzle
        vendors = { { 'Tya Padolih', 'Mhaura' } },
    },
    [4928] = { -- Katon: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4929] = { -- Katon: Ni
        drops = {
            [151] = 'Yagudo Conquistador (1%)',
            [161] = 'Yagudo Conquistador (1%)',
            [162] = 'Yagudo Conquistador (1%)',
        },
    },
    [4930] = { -- Katon: San
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4931] = { -- Hyoton: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4932] = { -- Hyoton: Ni
        drops = {
            [151] = 'Yagudo Conquistador (1%)',
            [161] = 'Yagudo Conquistador (1%)',
            [162] = 'Yagudo Conquistador (1%)',
        },
    },
    [4933] = { -- Hyoton: San
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4934] = { -- Huton: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4935] = { -- Huton: Ni
        drops = {
            [151] = 'Yagudo Conquistador (1%)',
            [161] = 'Yagudo Conquistador (1%)',
            [162] = 'Yagudo Conquistador (1%)',
        },
    },
    [4936] = { -- Huton: San
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4937] = { -- Doton: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4938] = { -- Doton: Ni
        drops = {
            [151] = 'Yagudo Conquistador (1%)',
            [161] = 'Yagudo Conquistador (1%)',
            [162] = 'Yagudo Conquistador (1%)',
        },
    },
    [4939] = { -- Doton: San
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4940] = { -- Raiton: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4941] = { -- Raiton: Ni
        drops = {
            [151] = 'Yagudo Conquistador (1%)',
            [161] = 'Yagudo Conquistador (1%)',
            [162] = 'Yagudo Conquistador (1%)',
        },
    },
    [4942] = { -- Raiton: San
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4943] = { -- Suiton: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4944] = { -- Suiton: Ni
        drops = {
            [151] = 'Yagudo Conquistador (1%)',
            [161] = 'Yagudo Conquistador (1%)',
            [162] = 'Yagudo Conquistador (1%)',
        },
    },
    [4945] = { -- Suiton: San
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4946] = { -- Utsusemi: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4947] = { -- Utsusemi: Ni
        bcnm = { { 'Birds of a Feather [Lv30 cap, Sky Orb]', 'Waughroon Shrine' }, { 'Carapace Combatants [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Creeping Doom [Lv30 cap, Sky Orb]', 'Balgas Dais' }, { 'Die by the Sword [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Dropping Like Flies [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Factory Rejects [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' }, { 'Grove Guardians [Lv30 cap, Sky Orb]', 'Waughroon Shrine' }, { 'Harem Scarem [Lv30 cap, Sky Orb]', 'Balgas Dais' }, { 'Let Sleeping Dogs Die [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Petrifying Pair [Lv30 cap, Sky Orb]', 'Ghelsba Outpost' }, { 'Royal Jelly [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Royal Succession [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Steamed Sprouts [Lv40 cap, Star Orb]', 'Balgas Dais' }, { 'Tails of Woe [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'The Worm\'s Turn [Lv40 cap, Star Orb]', 'Waughroon Shrine' }, { 'Under Observation [Lv40 cap, Star Orb]', 'Horlais Peak' }, { 'Undying Promise [Lv40 cap, Star Orb]', 'Qu\'Bia Arena' } },
    },
    [4949] = { -- Jubaku: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4952] = { -- Hojo: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4953] = { -- Hojo: Ni
        drops = {
            [9] = 'Cryptonberry Cutter (0.5%)',
            [124] = 'Tonberry Chopper (0.1%)',
            [151] = 'Yagudo Assassin (1%)',
            [159] = 'Sozu Sarberry (10%), Tonberry Cutter (0.1%), Tonberry Stabber (0.1%)',
            [160] = 'Tonberry Decapitator (1%), Tonberry Slasher (0.1%)',
        },
    },
    [4955] = { -- Kurayami: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4956] = { -- Kurayami: Ni
        drops = {
            [9] = 'Cryptonberry Cutter (0.5%)',
            [151] = 'Yagudo Assassin (1%)',
            [159] = 'Sozu Sarberry (5%), Tonberry Cutter (0.5%), Tonberry Stabber (0.1%)',
            [160] = 'Tonberry Decapitator (5%), Tonberry Slasher (0.1%)',
        },
    },
    [4958] = { -- Dokumori: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4961] = { -- Tonko: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
    },
    [4962] = { -- Tonko: Ni
        drops = {
            [9] = 'Cryptonberry Cutter (1%)',
            [124] = 'Tonberry Chopper (0.5%)',
            [151] = 'Yagudo Assassin (5%)',
            [159] = 'Sozu Sarberry (10%), Tonberry Cutter (1%), Tonberry Stabber (0.5%)',
            [160] = 'Tonberry Decapitator (5%), Tonberry Slasher (0.5%)',
        },
    },
    [4964] = { -- Monomi: Ichi
        vendors = { { 'Amalasanda', 'Lower Jeuno' }, { 'Toji Mumosulah', 'Kazham' } },
    },
    [4965] = { -- Aisha: Ichi
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4966] = { -- Myoshu: Ichi
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4967] = { -- Yurin: Ichi
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4968] = { -- Kakka: Ichi
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4970] = { -- Gekka: Ichi
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4971] = { -- Yain: Ichi
        vendors = { { 'Solby-Maholby', 'Norg' } },
    },
    [4976] = { -- Foe Requiem
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [4977] = { -- Foe Requiem II
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [4978] = { -- Foe Requiem III
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [4979] = { -- Foe Requiem IV
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [4980] = { -- Foe Requiem V
        drops = {
            [151] = 'Yagudo Chanter (1%)',
            [162] = 'Yagudo Chanter (1%)',
        },
    },
    [4981] = { -- Foe Requiem VI
        drops = {
            [151] = 'Yagudo Conductor (5%)',
            [176] = 'Abyss Sahagin (15%), Coastal Sahagin (5%), Denn the Orcavoiced (5%)',
        },
    },
    [4982] = { -- Foe Requiem VII
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [4984] = { -- Horde Lullaby
        bcnm = { { 'Shooting Fish [Lv20 cap, Cloudy Orb]', 'Horlais Peak' } },
        drops = {
            [151] = 'Yagudo Drummer (5%)',
        },
    },
    [4986] = { -- Armys Paeon
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [4987] = { -- Armys Paeon II
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [4988] = { -- Armys Paeon III
        vendors = { { 'Hortense', 'Bastok Markets' }, { 'Toji Mumosulah', 'Kazham' } },
    },
    [4989] = { -- Armys Paeon IV
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [4990] = { -- Armys Paeon V
        bcnm = { { 'Like the Wind [Lv75 cap]', 'Boneyard Gully' }, { 'Shell We Dance? [Lv75 cap]', 'Boneyard Gully' } },
        drops = {
            [176] = 'Coastal Sahagin (1%)',
        },
    },
    [4991] = { -- Armys Paeon VI
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [4994] = { -- Mages Ballad
        vendors = { { 'Amalasanda', 'Lower Jeuno' } },
        drops = {
            [145] = 'Vuu Puqu the Beguiler (15%), Yagudo Piper (5%)',
        },
    },
    [4997] = { -- Knights Minne
        vendors = { { 'Ferdoulemiont', 'Southern San d\'Oria' } },
    },
    [4998] = { -- Knights Minne II
        vendors = { { 'Ferdoulemiont', 'Southern San d\'Oria' } },
    },
    [4999] = { -- Knights Minne III
        vendors = { { 'Ferdoulemiont', 'Southern San d\'Oria' } },
    },
    [5000] = { -- Knights Minne IV
        drops = {
            [151] = 'Yagudo Conductor (1%)',
            [176] = 'Abyss Sahagin (3.3%), Coastal Sahagin (1%), Denn the Orcavoiced (1%)',
        },
    },
    [5001] = { -- Knights Minne V
        vendors = { { 'Ferdoulemiont', 'Southern San d\'Oria' } },
    },
    [5002] = { -- Valor Minuet
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [5003] = { -- Valor Minuet II
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [5004] = { -- Valor Minuet III
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [5005] = { -- Valor Minuet IV
        bcnm = { { 'Brothers D\'Aurphe [Lv60 cap, Moon Orb]', 'Qu\'Bia Arena' }, { 'Demolition Squad [Lv60 cap, Moon Orb]', 'Qu\'Bia Arena' } },
        drops = {
            [151] = 'Yagudo Conductor (0.5%)',
            [176] = 'Abyss Sahagin (3.3%), Denn the Orcavoiced (1%), Coastal Sahagin (0.5%)',
        },
    },
    [5006] = { -- Valor Minuet V
        vendors = { { 'Hortense', 'Bastok Markets' } },
    },
    [5007] = { -- Sword Madrigal
        vendors = { { 'Boncort', 'Northern San d\'Oria' } },
    },
    [5008] = { -- Blade Madrigal
        drops = {
            [95] = 'Yagudo Piper (5%)',
            [96] = 'Yagudo Drummer (5%)',
            [151] = 'Yagudo Lutenist (5%)',
            [161] = 'Yagudo Lutenist (5%)',
            [162] = 'Yagudo Lutenist (5%)',
        },
    },
    [5009] = { -- Hunters Prelude
        vendors = { { 'Mono Nchaa', 'Windurst Woods' } },
    },
    [5010] = { -- Archers Prelude
        drops = {
            [149] = 'Orcish Farkiller (1%)',
            [150] = 'Orcish Farkiller (1%)',
            [158] = 'Jotunn Wallkeeper (1%)',
            [208] = 'Antican Aedilis (1%)',
        },
    },
    [5011] = { -- Sheepfoe Mambo
        vendors = { { 'Dohdjuma', 'Selbina' } },
    },
    [5012] = { -- Dragonfoe Mambo
        drops = {
            [95] = 'Yagudo Piper (1%)',
            [96] = 'Yagudo Drummer (1%)',
            [151] = 'Yagudo Lutenist (1%)',
            [161] = 'Yagudo Lutenist (1%)',
            [162] = 'Yagudo Lutenist (1%)',
        },
    },
    [5014] = { -- Herb Pastoral
        vendors = { { 'Wije Tiren', 'Windurst Woods' } },
    },
    [5016] = { -- Shining Fantasia
        drops = {
            [151] = 'Yagudo Conductor (10%)',
        },
    },
    [5020] = { -- Gold Capriccio
        drops = {
            [151] = 'Yagudo Chanter (5%)',
            [162] = 'Yagudo Chanter (5%)',
        },
    },
    [5022] = { -- Warding Round
        drops = {
            [97] = 'Yagudo Chanter (5%)',
            [98] = 'Yagudo Lutenist (10%)',
            [99] = 'Yagudo Chanter (5%), Yagudo Conductor (5%)',
            [138] = 'Yagudo Chanter (10%)',
            [151] = 'Yagudo Conductor (10%)',
            [155] = 'Yagudo Conductor (10%)',
            [164] = 'Yagudo Lutenist (10%)',
            [176] = 'Coastal Sahagin (10%)',
        },
    },
    [5023] = { -- Goblin Gavotte
        vendors = { { 'Creepstix', 'Lower Jeuno' } },
    },
    [5028] = { -- Victory March
        drops = {
            [151] = 'Yagudo Conductor (1%)',
            [176] = 'Abyss Sahagin (3.3%)',
        },
    },
    [5029] = { -- Battlefield Elegy
        vendors = { { 'Thadiene', 'Southern San d\'Oria' } },
    },
    [5030] = { -- Carnage Elegy
        bcnm = { { 'Call to Arms [Lv60 cap]', 'Talacca Cove' }, { 'Kindred Spirits [Lv60 cap, Moon Orb]', 'Throne Room' }, { 'Making a Mockery [Lv60 cap]', 'Jade Sepulcher' }, { 'Tough Nut to Crack [Lv60 cap]', 'Navukgo Execution Chamber' } },
        drops = {
            [151] = 'Yagudo Chanter (1%)',
            [162] = 'Yagudo Chanter (1%)',
        },
    },
    [5032] = { -- Sinewy Etude
        vendors = { { 'Leyla', 'Port Jeuno' }, { 'Manyny', 'Windurst Woods' } },
    },
    [5033] = { -- Dextrous Etude
        vendors = { { 'Leyla', 'Port Jeuno' }, { 'Manyny', 'Windurst Woods' } },
    },
    [5034] = { -- Vivacious Etude
        vendors = { { 'Leyla', 'Port Jeuno' }, { 'Manyny', 'Windurst Woods' } },
    },
    [5035] = { -- Quick Etude
        vendors = { { 'Leyla', 'Port Jeuno' }, { 'Manyny', 'Windurst Woods' } },
    },
    [5036] = { -- Learned Etude
        vendors = { { 'Leyla', 'Port Jeuno' }, { 'Manyny', 'Windurst Woods' } },
    },
    [5037] = { -- Spirited Etude
        vendors = { { 'Leyla', 'Port Jeuno' }, { 'Manyny', 'Windurst Woods' } },
    },
    [5038] = { -- Enchanting Etude
        vendors = { { 'Leyla', 'Port Jeuno' }, { 'Manyny', 'Windurst Woods' } },
    },
    [5039] = { -- Herculean Etude
        vendors = { { 'Harmodios', 'Bastok Markets' } },
        drops = {
            [176] = 'Abyss Sahagin (3.4%), Denn the Orcavoiced (2.1%), Coastal Sahagin (1.4%)',
        },
    },
    [5040] = { -- Uncanny Etude
        vendors = { { 'Harmodios', 'Bastok Markets' } },
        drops = {
            [176] = 'Abyss Sahagin (3.4%), Denn the Orcavoiced (2.1%), Coastal Sahagin (1.4%)',
        },
    },
    [5041] = { -- Vital Etude
        vendors = { { 'Harmodios', 'Bastok Markets' } },
        drops = {
            [176] = 'Abyss Sahagin (3.4%), Denn the Orcavoiced (2.1%), Coastal Sahagin (1.4%)',
        },
    },
    [5042] = { -- Swift Etude
        vendors = { { 'Harmodios', 'Bastok Markets' } },
        drops = {
            [176] = 'Abyss Sahagin (3.4%), Denn the Orcavoiced (2.1%), Coastal Sahagin (1.4%)',
        },
    },
    [5043] = { -- Sage Etude
        vendors = { { 'Harmodios', 'Bastok Markets' } },
        drops = {
            [176] = 'Abyss Sahagin (3.4%), Denn the Orcavoiced (2.1%), Coastal Sahagin (1.4%)',
        },
    },
    [5044] = { -- Logical Etude
        vendors = { { 'Harmodios', 'Bastok Markets' } },
        drops = {
            [176] = 'Abyss Sahagin (3.4%), Denn the Orcavoiced (2.1%), Coastal Sahagin (1.4%)',
        },
    },
    [5045] = { -- Bewitching Etude
        vendors = { { 'Harmodios', 'Bastok Markets' } },
        drops = {
            [176] = 'Abyss Sahagin (3.4%), Denn the Orcavoiced (2.1%), Coastal Sahagin (1.4%)',
        },
    },
    [5046] = { -- Fire Carol
        vendors = { { 'Yoskolo', 'Lower Jeuno' } },
    },
    [5047] = { -- Ice Carol
        vendors = { { 'Yoskolo', 'Lower Jeuno' } },
    },
    [5048] = { -- Wind Carol
        vendors = { { 'Yoskolo', 'Lower Jeuno' } },
    },
    [5049] = { -- Earth Carol
        vendors = { { 'Yoskolo', 'Lower Jeuno' } },
    },
    [5050] = { -- Lightning Carol
        vendors = { { 'Yoskolo', 'Lower Jeuno' } },
    },
    [5051] = { -- Water Carol
        vendors = { { 'Yoskolo', 'Lower Jeuno' } },
    },
    [5052] = { -- Light Carol
        vendors = { { 'Yoskolo', 'Lower Jeuno' } },
    },
    [5053] = { -- Dark Carol
        vendors = { { 'Yoskolo', 'Lower Jeuno' } },
    },
    [5062] = { -- Fire Threnody
        vendors = { { 'Ensasa', 'Windurst Waters' } },
    },
    [5063] = { -- Ice Threnody
        vendors = { { 'Mjoll', 'Batok Markets' } },
    },
    [5064] = { -- Wind Threnody
        vendors = { { 'Champalpieu', 'Upper Jeuno' } },
    },
    [5065] = { -- Earth Threnody
        vendors = { { 'Ensasa', 'Windurst Waters' } },
    },
    [5066] = { -- Ltng. Threnody
        vendors = { { 'Lusiane', 'Southern San d\'Oria' } },
    },
    [5067] = { -- Water Threnody
        vendors = { { 'Champalpieu', 'Upper Jeuno' } },
    },
    [5068] = { -- Light Threnody
        vendors = { { 'Lusiane', 'Southern San d\'Oria' } },
    },
    [5069] = { -- Dark Threnody
        vendors = { { 'Mjoll', 'Batok Markets' } },
    },
    [5070] = { -- Magic Finale
        bcnm = { { 'Birds of a Feather [Lv30 cap, Sky Orb]', 'Waughroon Shrine' }, { 'Carapace Combatants [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Creeping Doom [Lv30 cap, Sky Orb]', 'Balgas Dais' }, { 'Die by the Sword [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Dropping Like Flies [Lv30 cap, Sky Orb]', 'Horlais Peak' }, { 'Grove Guardians [Lv30 cap, Sky Orb]', 'Waughroon Shrine' }, { 'Harem Scarem [Lv30 cap, Sky Orb]', 'Balgas Dais' }, { 'Let Sleeping Dogs Die [Lv30 cap, Sky Orb]', 'Qu\'Bia Arena' }, { 'Petrifying Pair [Lv30 cap, Sky Orb]', 'Ghelsba Outpost' } },
        drops = {
            [151] = 'Yagudo Drummer (5%)',
        },
    },
    [5071] = { -- Foe Lullaby
        drops = {
            [117] = 'Yagudo Piper (5%)',
            [119] = 'Yagudo Piper (5%)',
            [145] = 'Yagudo Piper (10%)',
        },
    },
    [5072] = { -- Goddesss Hymnus
        drops = {
            [97] = 'Yagudo Chanter (1%)',
            [98] = 'Yagudo Lutenist (5%)',
            [99] = 'Yagudo Chanter (1%), Yagudo Conductor (1%)',
            [138] = 'Yagudo Chanter (5%)',
            [151] = 'Yagudo Conductor (10%)',
            [155] = 'Yagudo Conductor (5%)',
            [164] = 'Yagudo Lutenist (5%)',
            [176] = 'Coastal Sahagin (5%)',
        },
    },
    [5073] = { -- Chocobo Mazurka
        vendors = { { 'Ferdoulemiont', 'Southern San d\'Oria' }, { 'Generoit', 'Rabao' }, { 'Mamerie', 'Kazham' }, { 'Neigepance', 'Bastok Mines' }, { 'Quesse', 'Windurst Woods' } },
        drops = {
            [151] = 'Yagudo Conductor (0.5%)',
            [176] = 'Denn the Orcavoiced (1%), Abyss Sahagin (0.5%), Coastal Sahagin (0.5%)',
        },
    },
    [5074] = { -- Maidens Virelai
        bcnm = { { 'Call to Arms [Lv60 cap]', 'Talacca Cove' }, { 'Making a Mockery [Lv60 cap]', 'Jade Sepulcher' }, { 'Tough Nut to Crack [Lv60 cap]', 'Navukgo Execution Chamber' } },
        drops = {
            [176] = 'Abyss Sahagin (5%)',
        },
    },
    [5076] = { -- Foe Sirvente
        vendors = { { 'Harmodios', 'Bastok Markets' } },
    },
    [5077] = { -- Adventurers Dirge
        vendors = { { 'Harmodios', 'Bastok Markets' } },
    },
    [5078] = { -- Sentinels Scherzo
        vendors = { { 'Yoskolo', 'Lower Jeuno' } },
    },
    [5079] = { -- Foe Lullaby II
        vendors = { { 'Toji Mumosulah', 'Kazham' } },
    },
    [5082] = { -- Cura II
        vendors = { { 'Brave Ox', 'Rabao' } },
    },
    [5085] = { -- Regen IV
        vendors = { { 'Gekko', 'Port Jeuno' } },
    },
    [5087] = { -- Gain-STR
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [5088] = { -- Gain-DEX
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [5089] = { -- Gain-VIT
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [5090] = { -- Gain-AGI
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [5091] = { -- Gain-INT
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [5092] = { -- Gain-MND
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [5093] = { -- Gain-CHR
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [5094] = { -- Boost-STR
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [5095] = { -- Boost-DEX
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [5096] = { -- Boost-VIT
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [5097] = { -- Boost-AGI
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [5098] = { -- Boost-INT
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [5099] = { -- Boost-MND
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [5100] = { -- Boost-CHR
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [5103] = { -- Crusade
        vendors = { { 'Brave Ox', 'Rabao' } },
    },
    [5104] = { -- Flurry
        vendors = { { 'Falgima', 'Selbina' } },
    },
    [5106] = { -- Inundation
        vendors = { { 'Creepstix', 'Lower Jeuno' }, { 'Hasim', 'Lower Jeuno' } },
    },
    [6569] = { -- Slow II
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [6570] = { -- Paralyze II
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
    [6571] = { -- Phalanx II
        vendors = { { 'Hasim', 'Lower Jeuno' } },
    },
}
