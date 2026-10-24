# omni

All-in-one Ashita v4 addon for CatsEyeXI, by Happyfists. Approved for use on CatsEyeXI (October 2026).

A small bar along the top of the screen (job, XP/LP, wallet, buffs, target with TH and distance; in Abyssea, Dynamis and Nyzul Isle it shows their time, lights, time extensions or floor and objective instead) and a drop-down panel of tabs: Abyssea procs and NM pops, **Happy Pops** (HNM time-of-death and window timers), **Happy Translate** (chat translation), Quests, Multisend, Damage, Character, Ultimates, Currency, Dailies, Codex, Sky, Sea (with the Jailers pop chain and the AV helper), Ventures, Sparks, Options (with Happy Talks spoken alerts and the Roll Tracker) and Treasure Hunter. It also draws spell animations on the field (fireballs, lightning, rocks, cures...) and party job pictures.

## Newest pages

- **Happy Pops** - pick an HNM, type its time of death, and get 2 min / 1 min / 30 s / 10 s warnings and OPEN for every window (CatsEyeXI windows; 7 per HNM, the last one forced). Kills seen in chat, or an HNM seen dying near you, start a timer by themselves (only in that HNM's own zone, so Nyzul Isle bosses with the same name don't count). Every ToD is saved in a `tods` folder, timers come back after a reload, and L1 / L2 buttons announce a ToD to your linkshells when you press them. A Lock button keeps a ToD from being reset (e.g. by a pop-able NM with the same name) until 30 minutes before the window. `/pops`, `/pops history <hnm>`
- **Happy Translate** - reads every chat channel; tick the languages you want (Chinese pinyin, Japanese, French, German, Spanish, Portuguese - all off until you tick them) and those lines come back as one line with the English on the end in pink. Reply in pinyin with `/zl` `/zp` `/zl2` `/zt Name` `/zr`. Common game phrases are built in, everything translated is remembered in a file, and you can add your own phrases (`/translate learn zu wo = invite me`), so the free translator is used as little as possible. Uses MyMemory (free, about 5000 characters a day) and Google Input Tools for pinyin; only non-English lines are ever sent.
- **Happy Virtue (Sea > AV)** - Absolute Virtue helper: which 2-hours AV has used, who locks which, party calls, and an optional tick box to use your own 2-hour by itself to lock AV's (within 14 yalms; off by default).
- **Nyzul Isle on the bar** - floor (boss floors marked), the floor's objective with a tip for it, and the time left.
- **Sea > Jailers** - every Jailer, Ix'aern and Absolute Virtue: pop items with how many you hold (all bags plus Vision), where the ??? is, and the drops.

## Install

Copy the `omni` folder into your addons folder:

- VanaCore: `catseyexi-client\Vanacore\addons\ashita\omni\` then `/addon load omni ashita`
- Ashita: `catseyexi-client\Ashita\addons\omni\` then `/addon load omni`

See **README.txt** for everything it does, commands and settings.

## Credits

Happy Healer is no longer part of omni - it is its own addon.

Built on work by others; licence files are in the folder. Points / Pointwatch (Shinzaku, Byrthnoth), Trove (Loxley), AVHelper (ClutchHawks), FFXI Journal (AndreYMods), HXUI job pictures (Tirem), Abyssea Tracker CatsEyeXI Edition (IntegReady), Abystagger (Laudout), easyTH (Arielfy), targetlines (Jyouya), chatmon (atom0s, GPL v3), Craftbook, LandSandBoat recipes (GPL v3). Spell art and backgrounds made with Canva's AI image generator; voices made with Kokoro TTS. Pinyin table made with pypinyin (MIT).
