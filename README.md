# omni

All-in-one Ashita v4 addon for CatsEyeXI, by Happyfists. Approved for use on CatsEyeXI (October 2026).

A small bar along the top of the screen (job, XP/LP, wallet, buffs, target with TH and distance; in Abyssea, Dynamis and Nyzul Isle it shows their time, lights, time extensions or floor and objective instead) and a drop-down panel of tabs, grouped by subject:

- **Top row (places and content):** Abyssea, Sea, Sky, HNMs (Happy Pops + Roll Tracker), Ventures, Dailies, Codex, Quests
- **Second row (you and tools):** Happy Healer, Character, Gear (Ultimates, Automaton, Blue Magic), Currency (with Sparks), Items, Combat (Damage + TH), Multisend, Happy Translate, Options

It also draws spell animations on the field (fireballs, lightning, rocks, cures...) and party job pictures.

## Newest pages

- **Gear > Automaton** - Puppetmaster click-to-equip: click attachments into a plan, see capacity per element, pick a ready build (Melee, Tank, Ranged, Nuker, Healer, Enfeebler) fitted to what you've learned, see what each maneuver does for your attachments, then Equip (Deactivate, set, Activate). Five save slots.
- **Gear > Blue Magic** - Blue Mage click-to-set spells with set points and traits, ready sets (Cleave, Magic Burst, Physical TP, Tank, Healer, Debuff / Sleep, Solo), "Auto: max a trait", and your blusets files. Only the changes are sent.
- **Happy Healer** - Sneaky's Sidekick, just easier to use. Back in omni as a tab with an On/Off switch (off: not loaded).
- **Abyssea** - Atma and Empyrean pages, weapon filters, a stagger popup, and the Discernment weakness in /p with everything that procs it.
- **Happy Chests (Abyssea > Chests)** - Abyssea Sturdy Pyxis opener: pick Blue / Gold / Red, `/py` opens the nearest one with a Forbidden Key, Open all, skip Red lights, Auto, and an Augments page. Based on Pyxis by Integrity.
- **Happy Pouches (Items > Pouches)** - open a whole stack of pouches / coffers one after another (`/pouches <item>`). Based on Pouches by Omnys.
- **Training counter** - Fields of Valor / Grounds of Tome kill counts under the buff box ("Goblin 2/4"), from trainmon by onimitch. Options > Bars, `/tmon`.
- **Sky > Map** - the real Ru'Aun Gardens map (Remapster) with every god's ??? marked.
- **Happy Pops** - pick an HNM, type its time of death, and get 2 min / 1 min / 30 s / 10 s warnings and OPEN for every window (CatsEyeXI windows; 7 per HNM, the last one forced). Press Killed when it dies to start the next timer; L1 / L2 buttons announce a ToD to your linkshells when you press them. An hour before the first window it tells the linkshell (tick box). When it pops (seen near you, or the Up button) the window countdown stops. `/pops`, `/pops kill <hnm>`
- **Happy Translate** - reads every chat channel; tick the languages you want (Chinese pinyin, Japanese, French, German, Spanish, Portuguese - all off until you tick them) and those lines come back as one line with the English on the end in pink. Reply in pinyin with `/zl` `/zp` `/zl2` `/zt Name` `/zr`. Common game phrases are built in, everything translated is remembered in a file, and you can add your own phrases (`/translate learn zu wo = invite me`), so the free translator is used as little as possible. Uses Google Translate (free web version, no key) with MyMemory as a backup, and Google Input Tools for pinyin; only non-English lines are ever sent.
- **Happy Virtue (Sea > AV)** - Absolute Virtue helper: which 2-hours AV has used, who locks which, party calls, and an optional tick box to use your own 2-hour by itself to lock AV's (within 14 yalms; off by default).
- **Monster info under the target bar** - level, job, NM, aggro (sight / sound / scent / magic / low HP / true sight), links, weaknesses, resistances, immunities and respawn; hover for drops. Reads the database of Thorny's **mobdb** addon, so keep mobdb in your addons folder (it does not need to be loaded). Options > Bars.
- **Nyzul Isle on the bar** - floor (boss floors marked), the floor's objective with a tip for it, and the time left.
- **Sea > Jailers** - every Jailer, Ix'aern and Absolute Virtue: pop items with how many you hold (all bags plus Vision), where the ??? is, and the drops.

## Install

1. On GitHub press **Code > Download ZIP** and unzip it. You get a folder called **`Omni-main`**.
2. **Rename `Omni-main` to `omni`** (all lower case). The folder name has to be exactly `omni`, or the game can't find it.
3. Check that `omni.lua` is straight inside it: `...\addons\omni\omni.lua` - not `...\addons\omni\Omni-main\omni.lua` (unzipping often adds an extra folder level).
4. Put it in your addons folder and load it:

- VanaCore: `catseyexi-client\Vanacore\addons\ashita\omni\` then `/addon load omni ashita`
- Ashita: `catseyexi-client\Ashita\addons\omni\` then `/addon load omni`

**Updating:** once it's installed, type `/omniupdate` in game - it downloads the latest from here, copies it over your omni folder and reloads omni (your settings are kept). `/omniupdate check` only tells you if there's a newer one.

See **README.txt** for everything it does, commands and settings.

## Credits

Happy Healer is Sneaky's Sidekick (Sidekick by Seekey, MIT), just easier to use. The Ru'Aun Gardens map is by Remapster (CC BY-SA 4.0).

Built on work by others; licence files are in the folder. mobdb database (Thorny, read at run time), Points / Pointwatch (Shinzaku, Byrthnoth), Trove (Loxley), AVHelper (ClutchHawks), FFXI Journal (AndreYMods), HXUI job pictures (Tirem), Abyssea Tracker CatsEyeXI Edition (IntegReady), Abystagger (Laudout), easyTH (Arielfy), targetlines (Jyouya), chatmon (atom0s, GPL v3), Craftbook, LandSandBoat recipes (GPL v3). Spell art and backgrounds made with Canva's AI image generator; voices made with Kokoro TTS. Pinyin table made with pypinyin (MIT).
