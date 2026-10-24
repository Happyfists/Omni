==========================================================================================
  OMNI  -  all-in-one addon for CatsEyeXI (Ashita v4)                 version 2.77       
  by Happyfists
==========================================================================================

Omni puts the things you check all the time into one small bar at the top of the screen,
with a drop-down panel of tabs underneath it for everything else.


------------------------------------------------------------------------------------------
 1. INSTALLING
------------------------------------------------------------------------------------------

  1. Copy the "omni" folder into BOTH of these (VanaCore runs the first one):
         D:\catseyexi-client\Vanacore\addons\ashita\
         D:\catseyexi-client\Ashita\addons\
     so you end up with  ...\addons\ashita\omni\omni.lua  and  ...\Ashita\addons\omni\omni.lua

  2. In game type:
         /addon load omni ashita        (VanaCore)
         /addon load omni               (plain Ashita)

  3. To load it every time, add the same line to your load script.

  After any update:  /addon reload omni   then   /omni version   to check the number.

  Optional:
    * Multisend plugin (/load multisend) - needed for the Multisend tab and Follow button.
    * You no longer need these separately (omni does their job):
      easyTH, statustimers, avhelper, craftbook, points, targetlines, chatmon.
      Unload them so you don't get things twice.


------------------------------------------------------------------------------------------
 2. WHAT'S ON SCREEN
------------------------------------------------------------------------------------------

  MAIN BAR (always there)
    * Job picture, with main and sub job levels stacked beside it.
    * XP / LP counter on a coloured fill bar, with XP per hour. Hover it for more detail.
    * Chain counter and wallet.
    * Drop-down arrow - opens / closes the panel of tabs.
    * Eye button - hides everything except the main bar. Click again to bring it all back.
    * Follow - Multisend "Follow Me" on/off (green = on).
    * SNK / INV (or S+I) - Sneak and Invisible on yourself, using whatever you can:
      Sneak/Invisible magic (WHM, RDM), Monomi / Tonko (NIN), Spectral Jig (DNC), or
      Silent Oil / Prism Powder from your bag. Green while it's on you. Hidden if nothing.
    * Inside Abyssea the XP part changes to Visitant time left and your seven lights.

  ROW UNDER THE BAR
    * Left: your buffs, each with its time left.
    * Right: your target - name, HP%, distance and the target's buffs inside the HP bar.
      Distance colour: green = in casting range (20), yellow = just outside (30), red = far.
      Treasure Hunter shows left of the distance:
          TH -      your party is fighting it, no thief has hit it yet
          TH Base   a thief (main or sub) has hit it
          TH3 ...   green - TH has gone up

  PARTY JOB PICTURES
    A see-through column with a job picture for each party member, to sit beside the game's
    party list. Its bottom stays where you put it and it grows upwards as people join, just
    like the game's list. Hover a picture for the name and jobs.
    To line it up: Options tab > tick "Move them", drag it beside the party list, untick.

  SPELL LINES (Options > Spell lines)
    Animations on the field when your party (or a monster) acts, with painted AI art
    (assets/fx/, made with Canva's AI image generator):
      * While casting: a rune circle under the caster, and the spell's element forming over
        their head (rock, fire, ice shard, water orb, wind blade, spark).
      * Fire, Ice, Water, Wind, Stone, Thunder, Dark: one shot per tier - Fire 1, Fire II 2,
        Fire III 3 ... Firaja 5, Katon: Ichi/Ni/San 1/2/3. Each flies in its own arc, shrinks
        as it nears the monster, then hits (explosion, shatter, splash, rock smash...).
      * Light: a holy beam.  Cures: green sparkles.  Raise: a golden halo floats down.
        Buffs: shield runes orbit the target.  Debuffs: a curse sigil.  Songs: music notes.
      * Ranged: muzzle flash and tracer.  Weapon skills: gold slashes (red for monster TP moves).
      * Melee: a dotted chain between who is hitting whom (like targetlines).
    Switches: Show spell and attack animations / Only my party and alliance /
              Lines (target lines and spell lines) / AI art (off = simple drawn look).
    Try one without casting: target something and type  /omni fx fire 3

  HAPPY TALKS (Options > Happy Talks)
    Spoken alerts: a tell, a GM tell, a party/alliance invite, a trade, an emote at you,
    someone checking you, bags full, a skill-up, or your name said in chat.
    * 16 voice packs: Heart, Emma, Lily, Sky, Michael, George, Moogle (kupo!), Butler,
      Pirate, HYPE!!! (air horn and all), Comedy, Drunk, Grumpy, Whisper,
      Classic (chatmon's own clips) and Chimes (tones, no voice).
      Click a pack to use it (it says a line), or Play to just listen.
    * Each alert has its own tick box and a Test button.
    * Replaces chatmon - unload chatmon (there's a button) so you don't hear both.
    Sounds are in assets\alerts\<pack>\ - swap in your own .wav with the same name.

  POP-OUTS (small movable windows)
    * Abyssea proc tracker - what weapon skills / spells to use right now.


------------------------------------------------------------------------------------------
 3. THE TABS
------------------------------------------------------------------------------------------

  Top row:     Abyssea  Quests  Multisend  Damage
  Second row:  Character  Currency  Dailies  Codex  Sky  Sea  Ventures  Sparks  Options  TH

  (Happy Healer used to be a tab here. It is now its own addon - happyhealer - so omni has
   no healing automation in it at all.)

  ABYSSEA
    Procs page
      * Vana'diel time, which blue (damage type) window is open, the yellow element of the day,
        and your target.
      * Red / Blue / Yellow cards: everything that procs right now, the ones YOU can use first
        (green). Click a row to tick it off once tried. Ticks clear on a new target.
      * Pop-out button for a small always-on-top version.
    NM Pops page
      * Buttons for the nine Abyssea zones - opens on the zone you are in (marked *).
      * Every NM in the zone with:  Ready (you have all pops) / 2/3 (some) / Timed, Roams...
      * Filters: All NMs, Need pops, Ready to pop.
      * Click an NM:
          To pop  - tick or cross for each item / key item; if you have it, which bag it's in;
                    if not, which monster drops it (click the name to jump to that NM), and
                    whether a gold Pyxis can give it.
          Gives   - key items it drops and which NM they pop (clickable).
          Drops   - coloured by the proc needed (red / blue / yellow).
      * Key items: read from the list the game sends when you change zone. If one shows a
        cross but you have it, change zone once - it is then saved for that character.

  QUESTS
    Journey (what you have in progress, and progress per area / storyline), Quests by region
    with search and filters, Missions by storyline with cover pictures.
    Your quest log is read when you change zone and saved per character.

  MULTISEND
    Follow Me, sim-cast (your other characters cast the same spell; optionally WS / JA),
    quick Assist / Attack / Stop / Follow, and a free command box. Needs /load multisend.

  DAMAGE
    Simple: damage list for you and your party.  Advanced: full breakdown for one person.
    /ddr resets it,  /ddp [n] posts the top n in party chat.

  CHARACTER
    Jobs (with an Armor button per job: Artifact / Relic pieces, their rank, and what is
    needed to cap them; Vision storage from !vision), Magic (spells learned and still to get;
    Corsair rolls; Summoner avatars including quested ones), Crafts (skills and Craftbook
    recipes), Weapon Skills, Combat Skills, Magic Skills.

  CURRENCY      Currency and Points (Sparks, Unity Accolades and more).
  DAILIES       Your dailies.
  CODEX         Odious Codex with pictures; which you have and how many in your bags.
  SKY           Sky / Sky 2.0 / Pops: pop items, god drops, Kirin checklist.
  SEA           Sea armour, and the AV (Absolute Virtue) helper: fight timer, 2-hour clock,
                party call-outs, and an optional "use my 2-hour to lock it" tick box
                (uses yours by itself within 14 yalms; off by default).
  VENTURES      !ventures areas, HELM, fishing, and VNM armour.
  SPARKS        Sparks shop (buy N / buy all) and Sell It.
  OPTIONS       AV helper (Only in Al'Taieu / Everywhere / Off), Look (Crystal & Gold, Black & Gold or
                Classic), Abyssea bar, hide the game's own buff icons, brighter chat colours,
                spell lines, party job pictures (size and spacing per party, move, show when
                solo), pop-outs, Follow Me.
  TH            Treasure Hunter on your target, monsters being fought, and defeated ones with
                their final TH. When TH goes up it says in party chat (on by default):
                    Happyfists lands TH3 on Ogre Beetle
                Switches: Announce to party (/p), and Only mine.
                (If two of your characters are in the party, turn one of them off.)


------------------------------------------------------------------------------------------
 3b. HAPPY POPS, HAPPY TRANSLATE, SEA > JAILERS
------------------------------------------------------------------------------------------

  HAPPY POPS (top row tab, /pops)
    * Pick an HNM, type its time of death (21:35, 21:35:10, empty = now, "2d 21:35" = two days
      ago) and press Start. Every HNM is listed; running timers are on top with a countdown bar.
    * Each window: warnings at 2 min, 1 min, 30 sec and 10 sec, then OPEN, then "closed" 50 sec
      later. Windows are counted 1/7 ... 7/7 (the last one is the forced pop).
      21h HNMs: every 5 min from 21:00.  57h and 81h HNMs: every 10 min from 57:00 / 81:00.
      Wyrms (Jormungand, Tiamat, Vrtra): 7 windows 10 min apart from 81:00 (forced at 82:00).
    * A kill seen in chat ("... defeats Fafnir"), or an HNM seen dying near you (0% HP), starts a
      new timer by itself - only in that HNM's own zone, so same-named monsters elsewhere
      (Nyzul Isle floor bosses, Einherjar...) don't count.
    * Every ToD is saved in config\addons\omni\tods\<HNM>.txt; /pops history <hnm> shows the
      last ones, and after a reload any timer still running comes back from there.
    * Tick boxes: Window warnings, Warn the party too (<call14> on OPEN), 1h warning to linkshell
      (one hour before the first window of every timer: "/l Jormungand window 1/7 in 1 hour (22:18:49)").
    * L1 / L2 buttons on each running timer announce its ToD to linkshell 1 or 2 when you
      press them ("/l Fafnir ToD 13:40:00 - Repop at Thu 22 Oct 10:40:00 ..."). Nothing is
      posted by itself. Also /pops ls <hnm> and /pops ls2 <hnm>.
    * Lock button beside each running timer's name: locks the ToD in until 30 min before the
      first window, so killing a pop-able NM of the same name can't reset it (/pops lock <hnm>,
      /pops unlock <hnm>). It unlocks by itself 30 min before the window.

  HAPPY TRANSLATE (top row tab, On/Off slider next to it, /translate on|off)
    * Tick the languages you want: Chinese (pinyin), Japanese, French, German, Spanish, Portuguese.
      All are OFF until you tick them (/translate chinese, /translate french ... also toggle them).
    * Reads every chat channel. Lines in a ticked language are held for a second and come back as ONE line in the same channel:
          [1]<Kennan> kuai lai  >> come quickly          (the English part in pink)
      English lines are never touched or sent anywhere.
    * Reply in pinyin:  /zl text  /zl2 text  /zp text  /zs text  /zsh text  /zt Name text
      /zr text = reply on the channel of the last translated line. Or use the box on the tab and
      click Send (press Escape afterwards if the game's own chat line picked up your typing).
    * Built-in game phrases (zu wo = invite me, kuai lai = come quickly, hao = ok ...) and chat
      shorthand (sm = shen me "what") are translated instantly.
    * Everything translated is remembered in translate\memory.txt, so a line is never sent twice.
      Your own phrases go in translate\phrases.txt, or:  /translate learn zu wo = invite me
    * Uses Google Translate (free web version) with MyMemory as a backup, and Google Input Tools (pinyin), through a
      small hidden PowerShell helper (omni_translate.ps1). /translate status shows today's use.

  SEA > JAILERS
    * Temperance, Fortitude, Faith -> Ix'aern Deeds -> Hope, Justice, Prudence -> Love -> AV.
    * Each one: where the ??? is, what to trade (held/needed, green when you have it - every bag
      and organs kept at Vision), where the items drop, and the drops (CatsEyeXI extras in blue).


------------------------------------------------------------------------------------------
 4. COMMANDS
------------------------------------------------------------------------------------------

    /omni                open or close the panel
    /omni reset          put the bar back in its default place
    /omni version        show the running version
    /omni fx <kind> [n]  play a spell animation at your target (fire, ice, earth... n shots)
    /ddr                 reset the damage meter
    /ddp [n]             post the top n damage dealers in party chat
    /avh help            AV helper commands
    /pops                Happy Pops tab   (/pops add <hnm> [21:35], kill, del, list, history, ls <hnm>, ls2 <hnm>,
                         warn, party, ls)
    /translate           Happy Translate on/off  (status, learn, test, window)
    /zl /zl2 /zp /zs /zsh /zt <name> /zr   send a message translated into pinyin


------------------------------------------------------------------------------------------
 5. WHERE THINGS ARE SAVED
------------------------------------------------------------------------------------------

    Ashita\config\addons\omni\  (per character)
        settings          bar position, options, pop-out positions
        quests_<Name>.lua      your quest / mission log
        vision_<Name>.txt      Vision storage counts
        rolls_<Name>.txt       Corsair rolls seen
        abypops_<Name>.lua     Abyssea key items
        pops.txt               Happy Pops timers and switches
        tods\                  Happy Pops: every ToD, one file per HNM
        translate\             Happy Translate: settings.txt, memory.txt, phrases.txt


------------------------------------------------------------------------------------------
 6. IF SOMETHING LOOKS WRONG
------------------------------------------------------------------------------------------

    * Changed files but nothing changed in game  -> /addon reload omni, check /omni version.
    * Quest log or Abyssea key items empty/wrong -> change zone once.
    * Party pictures not lined up               -> Options > Move them, drag, untick;
                                                    adjust "Space between rows".
    * Old buff icons back on screen              -> Options > "Hide the game's own buff icons".
    * Backups of whole versions are in  Ashita\addons\omni_backups\


------------------------------------------------------------------------------------------
 7. CREDITS
------------------------------------------------------------------------------------------

    Licence files are in the omni folder.
    * Bar style and job icon sheet: points addon by Shinzaku, based on Pointwatch by
      Byrthnoth (POINTS_LICENSE)
    * Trove by Loxley - Currency, Dailies, Codex, Character, Sea screens (TROVE_LICENSE)
    * AVHelper by ClutchHawks (AVHELPER_LICENSE)
    * FFXI Journal by AndreYMods - quest / mission data and pictures (JOURNAL_LICENSE)
    * Abyssea Tracker - CatsEyeXI Edition by IntegReady - Abyssea NM / pop / drop data
    * Abystagger by Laudout
    * easyTH by Arielfy - TH idea
    * HXUI by Tirem - FFXI job pictures for the party lists (HXUI_LICENSE)
    * chatmon by atom0s (Ashita Development Team, GNU GPL v3) - Happy Talks' alert events;
      Classic voice pack is chatmon's clips. Other voices made with Kokoro TTS.
    * targetlines by Jyouya - the line idea, world-to-screen maths and bone lookup (spell lines)
    * Craftbook by Happys; recipes from the LandSandBoat database (GNU GPL v3)
    * Spell art (assets/fx/) and tab backgrounds made with Canva's AI image generator.
    * HNM windows from bg-wiki "CatsEyeXI Content/HNMs"; Sea data from bg-wiki "CatsEyeXI
      Content/Sea", the HorizonXI wiki and Allakhazam.
    * Happy Translate: Google Translate, MyMemory (translated.net) and Google Input Tools; pinyin table made with
      pypinyin (MIT licence).
