-- omni: Absolute Virtue Helper (avhelper 4.5) by ClutchHawks, MIT licence (see AVHELPER_LICENSE),
-- running inside omni as the "AV" tab. Changes for omni are marked "omni change" / "omni addition".
--[[
    Absolute Virtue Helper (avhelper) - Ashita v4 addon for CatsEyeXI (Final Fantasy XI private server)

    Trigger with /avh - Ashita intercepts every slash command before it reaches the server, the
    same way its own /addon, /bind, etc. work, so a single slash is correct here (not // - that
    was wrong in an earlier version of this file).

    Detects Absolute Virtue's own "special ability" reactions (Mighty Strikes, Manafont, etc.) as
    they happen, shows an on-screen alert + countdown for the follow-up player SP that locks them
    out, and keeps a persistent table of every trigger ability's lock state for the current pull.

    Built with Ashita's Dear ImGui binding (same approach as CraftGuard) rather than hand-placed
    fonts/primitives - this gives a single real window (drag/resize/close as one native unit)
    instead of a collection of independently movable text/box objects.

    Auto-detects your current job: if it's one of the tracked 2-hour jobs, that ability's name is
    highlighted in the table (colorblind-safe blue), and AV using that specific reaction plays a
    distinct notification sound (general.sound_trigger_own) instead of the normal trigger sound.

    IMPORTANT - about the lock window timing:
    CatsEyeXI's public "base" branch Absolute_Virtue.lua (github.com/CatsAndBoats/catseyexi)
    hard-codes a 3-second lock window, but the live server actually runs a private override script
    this addon's author doesn't have access to - confirmed via in-game testing that the real
    window is 10 seconds, not 3. The 10-second window is hard-coded as a constant (LOCK_WINDOW,
    below) rather than a setting, precisely so it can't drift out of sync with the tested value.
    The mob-skill ids (see MOB_SKILL_IDS) and ability list originally came from the public base
    branch, and have since been confirmed working end-to-end in-game (see README.md).

    Commands:
      /avh                     - Toggle the window.
      /avh show / hide         - Show/hide the window.
      /avh reset               - Clear all lock/unlock state (start of a new pull).
      /avh mute / unmute       - Toggle sound alerts.
      /avh speechreset on/off  - Toggle auto-reset when AV's engage speech is seen in chat.
      /avh abilities           - List tracked abilities and resolved ids.
      /avh lock <job>          - Manually mark a job's 2hr LOCKED (e.g. /avh lock drg).
      /avh unlock <job>        - Manually mark a job's 2hr UNLOCKED again (e.g. /avh unlock sam).
      /avh help                - Print this command list.
--]]

-- omni change: this file runs inside omni, so it must not overwrite omni's own addon.* fields.
local AVH_NAME    = 'avhelper';
local AVH_VERSION = '4.5';

require('common');

local chat      = require('chat');
local imgui     = require('imgui');
local settings  = require('settings');
local ffi       = require('ffi');
local bit       = require('bit');

ffi.cdef[[
    bool PlaySoundA(const char* pszSound, void* hmod, uint32_t fdwSound);
]];
local winmm_ok, winmm = pcall(ffi.load, 'winmm');

local SND_FILENAME  = 0x00020000;
local SND_ASYNC     = 0x00000001;
local SND_NODEFAULT = 0x00000002;

--------------------------------------------------------------------------------------------------
-- Default (per-character) settings
--------------------------------------------------------------------------------------------------
local default_settings = T{
    visible = T{ false, },   -- omni change: the floating window starts hidden (it lives in omni's AV tab)

    general = T{
        enabled             = true,    -- master on/off switch
        mob_name            = 'Absolute Virtue', -- must match the entity's in-game name exactly (case-insensitive)
        auto_reset_on_speech= true,    -- clear all lock/unlock state when AV's own engage speech is seen in chat
        play_sound          = true,
        party_callout       = true,    -- omni addition: say AV's 2-hours in party chat
        party_warning       = true,    -- omni addition: warn the party 10s before each 2-hour
        auto_open           = true,    -- omni addition: open the Happy Virtue window when AV pops
        party_call          = 14,      -- omni addition: <callN> sound on the party messages (0 = none)
        -- These point at stock Windows sound files so alerts work out of the box.
        -- Replace with your own .wav paths (e.g. C:\FFXI\config\addons\avhelper\alert.wav) if you like.
        sound_trigger       = 'C:\\Windows\\Media\\Windows Notify System Generic.wav',
        sound_trigger_own   = 'C:\\Windows\\Media\\Windows Notify Messaging.wav', -- AV used YOUR job's 2hr
        sound_lock          = 'C:\\Windows\\Media\\Windows Notify Calendar.wav',
    },

    -- Fragments of Absolute Virtue's own spoken/emote lines, used to auto-detect a fresh pull
    -- starting (see auto_reset_on_speech above). Matching is done against a *normalized* copy of
    -- each incoming chat line: lowercased, with runs of repeated "s" collapsed to one (AV's speech
    -- is rendered with a stretched-out sibilant, e.g. "lassst", "sssscattered", so the number of
    -- s's isn't reliable) and stripped of color/control bytes. Keep these entries lowercase, with
    -- single s's, and as short/distinctive substrings rather than whole lines - /avh addphrase /
    -- /avh delphrase manage this list without editing the file by hand.
    speech_phrases = T{
        'at last the time has come',
        'scattered fragments of my thoughts',
    },

    -- Which of the trigger abilities to watch/display. Set to false to ignore one, or use
    -- /avh enable|disable <name> instead of editing this by hand.
    -- Mijin Gakure / Familiar / Astral Flow are NOT included at all - per in-game testing,
    -- Absolute Virtue cannot use them, even though they exist in CatsEyeXI's public source.
    abilities = T{
        ['Mighty Strikes']     = true,
        ['Benediction']        = true,
        ['Hundred Fists']      = true,
        ['Manafont']           = true,
        ['Chainspell']         = true,
        ['Perfect Dodge']      = true,
        ['Invincible']         = true,
        ['Blood Weapon']       = true,
        ['Soul Voice']         = true,
        ['Meikyo Shisui']      = true,
        ['Eagle Eye Shot']     = true,
        ['Call Wyvern']        = true,
    },
};

-- Display order (matches the order AV's own ability pool is built in, in CatsEyeXI's public
-- source, minus Mijin Gakure / Familiar / Astral Flow - see the note above).
local ABILITY_ORDER = T{
    'Mighty Strikes', 'Benediction', 'Hundred Fists', 'Manafont', 'Chainspell',
    'Perfect Dodge', 'Invincible', 'Blood Weapon', 'Soul Voice', 'Meikyo Shisui',
    'Eagle Eye Shot', 'Call Wyvern',
};

-- AV's own "mob ability" ids for each reaction, taken from CatsEyeXI's public
-- scripts/enum/job_special_ability.lua (xi.jsa.*) - these are what should show up in the action
-- packet when ABSOLUTE VIRTUE performs the reaction (category 11, "mob_tp_finish"), as opposed to
-- the player's own job ability id (category 6), which is resolved dynamically further down.
-- Eagle Eye Shot uses the "Aern"-model-specific variant since AV is an Aern. These ids started as
-- a guess from the public source (the live server runs a private override - see header comment),
-- and have since been confirmed correct in-game for all 12 tracked abilities.
local MOB_SKILL_IDS = T{
    ['Mighty Strikes']     = 688,
    ['Benediction']        = 689,
    ['Hundred Fists']      = 690,
    ['Manafont']           = 691,
    ['Chainspell']         = 692,
    ['Perfect Dodge']      = 693,
    ['Invincible']         = 694,
    ['Blood Weapon']       = 695,
    ['Soul Voice']         = 696,
    ['Meikyo Shisui']      = 730,
    ['Call Wyvern']        = 626, -- confirmed via /avh debug: "Absolute Virtue uses Call Wyvern." -> Type=11 Id=626 (732 was wrong)
    ['Eagle Eye Shot']     = 1389, -- EES_AERN
};

-- Job -> 2-hour ability name, for /avh lock <job> (manually mark a job's 2hr LOCKED - a fallback
-- for when auto-detection misses a real lock that happened in-game).
local JOB_TO_ABILITY = T{
    war = 'Mighty Strikes',
    whm = 'Benediction',
    mnk = 'Hundred Fists',
    blm = 'Manafont',
    rdm = 'Chainspell',
    thf = 'Perfect Dodge',
    pld = 'Invincible',
    drk = 'Blood Weapon',
    brd = 'Soul Voice',
    sam = 'Meikyo Shisui',
    rng = 'Eagle Eye Shot',
    drg = 'Call Wyvern',
};

-- Numeric job id (AshitaCore:GetMemoryManager():GetPlayer():GetMainJob(), standard FFXI job
-- order: 1=WAR, 2=MNK, 3=WHM, 4=BLM, 5=RDM, 6=THF, 7=PLD, 8=DRK, 10=BRD, 11=RNG, 12=SAM, 14=DRG)
-- -> the 2-hour ability tied to that job, for highlighting "your" row and playing a distinct
-- notification when AV uses the reaction to YOUR own job's SP. Jobs with no tracked ability here
-- (BST, NIN, SMN, and everything without a public/AV-relevant 2hr) are simply absent.
local JOB_ID_TO_ABILITY = T{
    [1]  = 'Mighty Strikes',   -- WAR
    [2]  = 'Hundred Fists',    -- MNK
    [3]  = 'Benediction',      -- WHM
    [4]  = 'Manafont',         -- BLM
    [5]  = 'Chainspell',       -- RDM
    [6]  = 'Perfect Dodge',    -- THF
    [7]  = 'Invincible',       -- PLD
    [8]  = 'Blood Weapon',     -- DRK
    [10] = 'Soul Voice',       -- BRD
    [11] = 'Eagle Eye Shot',   -- RNG
    [12] = 'Meikyo Shisui',    -- SAM
    [14] = 'Call Wyvern',      -- DRG
};

local ALERT_DISPLAY_SECONDS = 4.0; -- how long the top alert line holds a message before going idle

-- Seconds a player has, after Absolute Virtue uses a tracked ability, to counter it with the
-- matching real SP and lock it out for the rest of the pull. Fixed at 10.0 (confirmed in-game;
-- see the header comment) - deliberately NOT a setting, so it can't end up stuck at a stale value
-- in an old settings file the way lock_window used to.
local LOCK_WINDOW = 10.0;

-- Fixed window width (pixels) - see render() for why this isn't just AlwaysAutoResize.
local WINDOW_WIDTH = 300.0;

--------------------------------------------------------------------------------------------------
-- Addon state
--------------------------------------------------------------------------------------------------
local avh = T{
    settings        = settings.load(default_settings, 'omni_av'),   -- omni change: its own settings file
    ability_ids     = T{},     -- name -> resolved numeric PLAYER ability id
    id_to_name      = T{},     -- offset-corrected PLAYER ability id (matches the real packet) -> name
    mobskill_to_name= T{},     -- mob skill id -> name (built from MOB_SKILL_IDS, filtered by enabled abilities)
    unresolved      = T{},     -- player ability names we could NOT resolve on this server
    state           = T{},     -- name -> { status, armed, armed_time }
    alert_text      = 'No activity yet.',
    alert_color     = T{ 0.60, 0.63, 0.67, 1.0 },
    alert_set_at    = 0,
    bar_active      = false,
    bar_start       = 0,
    bar_window      = 0,
    last_speech_reset_at = 0,
};

--------------------------------------------------------------------------------------------------
-- Colors (RGBA 0-1, as ImGui expects)
--------------------------------------------------------------------------------------------------
local COLOR_IDLE            = T{ 0.60, 0.63, 0.67, 1.0 };
local COLOR_ARMED           = T{ 1.00, 0.40, 0.27, 1.0 }; -- needs a response right now
local COLOR_LOCKED          = T{ 0.33, 0.87, 0.33, 1.0 }; -- successfully locked (good outcome)
local COLOR_UNLOCKED        = T{ 0.88, 0.75, 0.38, 1.0 }; -- still a live threat, no active window
local COLOR_WARNING         = T{ 1.00, 0.85, 0.30, 1.0 };
-- Highlights the ABILITY NAME (not its status) for whichever row is your current job's 2hr. Blue
-- is used deliberately: the status column already relies on red/orange vs. green vs. yellow, which
-- the most common forms of color blindness (deuteranopia/protanopia, red-green) can make hard to
-- tell apart - blue reads as clearly distinct from all of those regardless.
local COLOR_MY_JOB          = T{ 0.40, 0.70, 1.00, 1.0 };

--------------------------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------------------------
local function print_msg(str)
    print(chat.header(AVH_NAME):append(chat.message(str)));
end

local function reset_state()
    for _, name in ipairs(ABILITY_ORDER) do
        avh.state[name] = T{
            status      = 'unlocked',
            armed       = false,
            armed_time  = 0,
        };
    end
    avh.bar_active   = false;
    avh.alert_text   = 'No activity yet.';
    avh.alert_color  = COLOR_IDLE;
    avh.alert_set_at = 0;
end

-- Ashita's resource manager places job abilities into one merged ability-id space starting at
-- 512 (weaponskills, mob skills, etc. occupy other ranges of the same merged space), but the
-- actual 0x028 action packet's Id field for a job ability is the raw, un-offset id - confirmed
-- in-game via /avh debug: Blood Weapon resolved to resource id 535 but its real packet carried
-- Id=23 (535-512=23), and Call Wyvern resolved to 573 but carried Id=61 (573-512=61). Every
-- counter-SP lookup has to subtract this back out, or every single one silently never matches.
local JOB_ABILITY_ID_OFFSET = 512;

--------------------------------------------------------------------------------------------------
-- Resolves the numeric PLAYER ability ids for every tracked ability name by scanning the resource
-- manager's ability range. This is only used to recognize a player's counter-SP use; AV's own use
-- is matched via the hard-coded MOB_SKILL_IDS table above.
--------------------------------------------------------------------------------------------------
local function resolve_abilities()
    avh.ability_ids      = T{};
    avh.id_to_name        = T{};
    avh.mobskill_to_name  = T{};
    avh.unresolved        = T{};

    local resmgr = AshitaCore:GetResourceManager();
    if (resmgr == nil) then
        return;
    end

    for id = 0, 1535 do
        local ok, ability = pcall(function () return resmgr:GetAbilityById(id); end);
        if (ok and ability ~= nil and ability.Name ~= nil and ability.Name[1] ~= nil and #ability.Name[1] > 0) then
            local nm = ability.Name[1];
            for _, tracked in ipairs(ABILITY_ORDER) do
                -- Only take the FIRST id that matches a given name - if some other unrelated
                -- entry elsewhere in the merged resource space happens to share the exact same
                -- name, a later higher id must never silently overwrite an already-correct match.
                if (avh.settings.abilities[tracked] and avh.ability_ids[tracked] == nil and nm:lower() == tracked:lower()) then
                    -- Displayed via /avh abilities as the resource id (matches what you'd look up
                    -- elsewhere), but the packet-matching table uses the offset-corrected id.
                    avh.ability_ids[tracked] = id;
                    avh.id_to_name[id - JOB_ABILITY_ID_OFFSET] = tracked;
                end
            end
        end
    end

    for _, tracked in ipairs(ABILITY_ORDER) do
        if (avh.settings.abilities[tracked]) then
            if (avh.ability_ids[tracked] == nil) then
                avh.unresolved:append(tracked);
            end
            local skill_id = MOB_SKILL_IDS[tracked];
            if (skill_id ~= nil) then
                avh.mobskill_to_name[skill_id] = tracked;
            end
        end
    end

    if (#avh.unresolved > 0) then
        print(chat.header(AVH_NAME):append(chat.error('Warning: Could not resolve the following tracked PLAYER abilities (check spelling / server data):')));
        avh.unresolved:each(function (name)
            print(chat.header(AVH_NAME):append(chat.error('  - ')):append(chat.message(name)));
        end);
        print_msg('Locking will not work for them until this is fixed (the ARMED alert from AV will still show).');
    end
end

--------------------------------------------------------------------------------------------------
-- Returns the tracked ability name tied to your CURRENT main job (e.g. 'Call Wyvern' if you're
-- playing DRG right now), or nil if your current job has no tracked AV reaction. Read fresh each
-- time rather than cached, so a job change (which needs a zone anyway) is always picked up.
--------------------------------------------------------------------------------------------------
local function get_my_job_ability()
    local ok, player = pcall(function () return AshitaCore:GetMemoryManager():GetPlayer(); end);
    if (not ok or player == nil) then
        return nil;
    end
    local job_ok, job_id = pcall(function () return player:GetMainJob(); end);
    if (not job_ok or job_id == nil) then
        return nil;
    end
    return JOB_ID_TO_ABILITY[job_id];
end

--------------------------------------------------------------------------------------------------
-- Returns true + the member's display name if the given server id belongs to someone in your
-- current party/alliance.
--------------------------------------------------------------------------------------------------
local function get_ally_name(server_id)
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return false, nil;
    end

    for i = 0, 17 do
        local ok, sid = pcall(function () return party:GetMemberServerId(i); end);
        if (ok and sid ~= nil and sid ~= 0 and sid == server_id) then
            local active_ok, active = pcall(function () return party:GetMemberActive(i); end);
            -- GetMemberActive's return type isn't consistently documented (boolean vs 0/1), so
            -- accept either form; if the call fails entirely, fall back to trusting the server id match.
            local is_active = (not active_ok) or (active == true) or (active == 1) or (type(active) == 'number' and active ~= 0);
            if (is_active) then
                local name_ok, name = pcall(function () return party:GetMemberName(i); end);
                if (name_ok and name ~= nil and #name > 0) then
                    return true, name;
                end
                return true, ('id:%u'):fmt(server_id);
            end
        end
    end

    return false, nil;
end

--------------------------------------------------------------------------------------------------
-- Scans the zone's mob target-index range (0-1023: NPCs/mobs are 0-1023, PCs 1024-1791,
-- trusts/pets 1792-2303) for an entity with the given server id, and returns its name if found.
-- Used to confirm a mob-ability use actually came from Absolute Virtue and not some unrelated
-- monster that happens to share a mob skill id.
--------------------------------------------------------------------------------------------------
local function resolve_mob_name(server_id)
    local entity = AshitaCore:GetMemoryManager():GetEntity();
    if (entity == nil) then
        return nil;
    end

    for i = 0, 1023 do
        local ok, sid = pcall(function () return entity:GetServerId(i); end);
        if (ok and sid ~= nil and sid == server_id) then
            local name_ok, name = pcall(function () return entity:GetName(i); end);
            if (name_ok and name ~= nil and #name > 0) then
                return name;
            end
            return nil;
        end
    end

    return nil;
end

--------------------------------------------------------------------------------------------------
-- Action packet (0x028) parsing.
--
-- Adapted from the community-standard Ashita v4 action-packet parser pattern (see e.g.
-- ThornyFFXI/tTimers' actionpacket.lua) - the incoming action packet is a tightly packed
-- bitstream, not byte-aligned fields, so it has to be unpacked bit by bit.
--------------------------------------------------------------------------------------------------
local function parse_action_packet(e)
    local bit_offset = 40;

    local function unpack_bits(length)
        local value = ashita.bits.unpack_be(e.data_raw, 0, bit_offset, length);
        bit_offset = bit_offset + length;
        return value;
    end

    local pkt = T{};
    pkt.UserId  = unpack_bits(32);
    local target_count = unpack_bits(6);
    bit_offset  = bit_offset + 4;
    pkt.Type    = unpack_bits(4);
    pkt.Id      = unpack_bits(17);
    bit_offset  = bit_offset + 15;
    pkt.Recast  = unpack_bits(32);

    -- We don't need per-target hit data for this addon, but we still have to walk past it
    -- correctly in case something downstream cares about later bytes.
    pkt.Targets = T{};
    for _ = 1, target_count do
        local target = T{ Id = unpack_bits(32) };
        local action_count = unpack_bits(4);
        for _ = 1, action_count do
            unpack_bits(5);     -- Reaction
            unpack_bits(12);    -- Animation
            unpack_bits(7);     -- SpecialEffect
            unpack_bits(3);     -- Knockback
            unpack_bits(17);    -- Param
            unpack_bits(10);    -- Message
            unpack_bits(31);    -- Flags

            if (unpack_bits(1) == 1) then
                unpack_bits(10); unpack_bits(17); unpack_bits(10); -- additional effect
            end
            if (unpack_bits(1) == 1) then
                unpack_bits(10); unpack_bits(14); unpack_bits(10); -- spikes effect
            end
        end
        pkt.Targets:append(target);
    end

    return pkt;
end

-- Action packet categories (per Windower/Ashita's shared action-event categories).
-- NOTE: 2-hour/SP abilities are instant, no-telegraph job abilities, and in-game testing found
-- that real SP use (e.g. Meikyo Shisui) arrives as category 14 ("job ability, unblinkable"), not
-- plain category 6 - AV's own use of the reaction (category 11) was detected fine, but a genuine
-- player counter-SP wasn't recognized at all until both 6 and 14 were treated as job-ability use.
local CATEGORY_JOB_ABILITY              = 6;
local CATEGORY_JOB_ABILITY_UNBLINKABLE  = 14;
local CATEGORY_MOB_TP_MOVE              = 11;

-- Eagle Eye Shot fires an actual shot, so the game reports the real player use as a "Ranged
-- Attack" action (category 3) rather than a plain job ability (6/14) - confirmed via /avh debug:
-- a RNG's genuine Eagle Eye Shot showed up as Type=3, not Type=6/14, which is why the ARMED alert
-- from AV fired fine (that's the mob-skill/category-11 path) but the real counter never locked it
-- (category 3 wasn't being checked at all). Uses the same id_to_name table/offset as 6/14.
local CATEGORY_RANGED_ATTACK            = 3;

--------------------------------------------------------------------------------------------------
-- Chat text normalization + AV speech detection.
--
-- Strips Ashita/FFXI color and control bytes from an incoming chat-log line the same way
-- TreeFidyDad/lsbridge does (0x1E/0x1F/0x7F are 2-byte color/format codes, remaining control and
-- high-bit bytes are just noise for our purposes), then lowercases and collapses runs of "s" down
-- to one - AV's engage speech is rendered with a stretched sibilant ("lassst", "sssscattered")
-- and the exact number of repeated letters isn't something worth matching against.
--------------------------------------------------------------------------------------------------
local function normalize_chat_text(msg)
    if (msg == nil) then
        return '';
    end
    local clean = msg
        :gsub('\x1E.', '')
        :gsub('\x1F.', '')
        :gsub('\x7F.', '')
        :gsub('[%c]', '')
        :gsub('[\128-\255]', '');
    clean = clean:lower();
    clean = clean:gsub('s+', 's');
    return clean;
end

-- omni addition: fight timer. Starts when AV pops (its engage speech, or the first 2-hour it
-- uses if the speech was missed), stops when AV is defeated, or by hand.
local fight = { start = nil, stop = nil, next_2h = nil, warned = false, used = 0 };

-- AV's 2-hour timing: the first comes 2m10s after it spawns, then one every 90 seconds after
-- that, on a fixed clock.
local FIRST_2H = 130;
local EVERY_2H = 90;
local WARN_AT  = 10;

local function fight_begin(why)
    if (fight.start == nil or fight.stop ~= nil) then
        fight.start, fight.stop = os.time(), nil;
        fight.next_2h, fight.warned, fight.used = os.clock() + FIRST_2H, false, 0;
        print_msg(('Fight timer started (%s).'):fmt(why));
    end
end

local function fight_end(why)
    if (fight.start ~= nil and fight.stop == nil) then
        fight.stop = os.time();
        fight.next_2h = nil;
        local t = fight.stop - fight.start;
        print_msg(('Fight timer stopped (%s): %d:%02d.'):fmt(why, math.floor(t / 60), t % 60));
    end
end

-- Back to zero, ready for the next pop.
local function fight_reset()
    fight.start, fight.stop, fight.next_2h, fight.warned, fight.used = nil, nil, nil, false, 0;
    print_msg('Fight timer reset.');
end

-- Watch for Absolute Virtue appearing, so the clock starts the moment it pops (the 2-hour
-- timings count from its spawn). Checked once a second.
local spawn_seen, spawn_checked = false, 0;
local function check_spawn()
    if (os.clock() - spawn_checked < 1) then return; end
    spawn_checked = os.clock();
    local name = (avh.settings.general.mob_name or 'Absolute Virtue'):lower();
    local found, hpp = false, 0;
    pcall(function ()
        local ent = AshitaCore:GetMemoryManager():GetEntity();
        for i = 1, 0x3FF do
            local n = ent:GetName(i);
            if (n ~= nil and n:lower() == name and ent:GetHPPercent(i) > 0
                and bit.band(ent:GetRenderFlags0(i), 0x200) == 0x200) then
                found, hpp = true, ent:GetHPPercent(i);
                break;
            end
        end
    end);
    if (found and not spawn_seen) then
        if (hpp >= 100) then
            -- A fresh pop (full HP): always a new fight, even if an old timer was left running
            -- (a wipe or depop never shows the "defeats" line, so the old one never stopped).
            fight.start, fight.stop = nil, nil;
            fight_begin('Absolute Virtue popped');
            if (avh.settings.general.auto_reset_on_speech) then reset_state(); end
            if (avh.settings.general.auto_open ~= false and not avh.settings.visible[1]) then
                avh.settings.visible[1] = true;   -- open the Happy Virtue window
            end
        elseif (fight.start == nil or fight.stop ~= nil) then
            -- Walked up to a fight already going: start counting from now.
            fight_begin('Absolute Virtue in view');
        end
    end
    spawn_seen = found;
end

local function fight_text()
    if (fight.start == nil) then return nil; end
    local t = (fight.stop or os.time()) - fight.start;
    return ('%d:%02d:%02d'):fmt(math.floor(t / 3600), math.floor(t / 60) % 60, t % 60);
end

-- Engage speech starts the timer; "... defeats Absolute Virtue" stops it.
local function check_fight_text(raw_message)
    local clean = normalize_chat_text(raw_message or '');
    if (#clean == 0) then return; end
    for _, phrase in ipairs(avh.settings.speech_phrases) do
        if (clean:find(phrase, 1, true)) then
            fight_begin('Absolute Virtue engaged');
            return;
        end
    end
    local mob = avh.settings.general.mob_name:lower();
    if (clean:find('defeats ' .. mob, 1, true) or clean:find(mob .. ' was defeated', 1, true) or clean:find(mob .. ' falls', 1, true)) then
        fight_end('Absolute Virtue defeated');
    end
end

local function check_speech_reset(raw_message)
    if (not avh.settings.general.enabled or not avh.settings.general.auto_reset_on_speech) then
        return;
    end

    local clean = normalize_chat_text(raw_message);
    if (#clean == 0) then
        return;
    end

    for _, phrase in ipairs(avh.settings.speech_phrases) do
        if (clean:find(phrase, 1, true)) then
            -- The same line can sometimes reach text_in more than once (e.g. echoed to multiple
            -- log tabs); a short cooldown keeps one engage from triggering several resets.
            local now = os.clock();
            if ((now - avh.last_speech_reset_at) > 5.0) then
                avh.last_speech_reset_at = now;
                reset_state();
                print_msg(chat.success('New Absolute Virtue pull detected (engage speech) - state reset.'));
            end
            return;
        end
    end
end

--------------------------------------------------------------------------------------------------
-- Sound
--------------------------------------------------------------------------------------------------
local function play_sound(path)
    if (not avh.settings.general.play_sound) then
        return;
    end
    if (not winmm_ok or winmm == nil) then
        return;
    end
    if (path == nil or #path == 0 or not ashita.fs.exists(path)) then
        return;
    end
    winmm.PlaySoundA(path, nil, bit.bor(SND_FILENAME, SND_ASYNC, SND_NODEFAULT));
end

--------------------------------------------------------------------------------------------------
-- Core trigger handling
--
-- handle_av_use:     Absolute Virtue itself performed the reaction -> arm the countdown.
-- handle_player_use: An ally used the matching real SP -> lock it if it's currently armed.
--------------------------------------------------------------------------------------------------
local function set_alert(text, color)
    avh.alert_text   = text;
    avh.alert_color  = color;
    avh.alert_set_at = os.clock();
end

local function handle_av_use(name)
    local st = avh.state[name];
    if (st == nil or st.status == 'locked') then
        return; -- shouldn't happen (AV's own pool should exclude locked abilities), but be defensive
    end

    st.armed      = true;
    st.armed_time = os.clock();

    print_msg(chat.warning(('Absolute Virtue used %s! Counter within %.1fs to lock it.'):fmt(name, LOCK_WINDOW)));

    -- omni addition: call it out in party chat, naming the job that can lock it.
    if (avh.settings.general.party_callout) then
        local job = '';
        for code, ability in pairs(JOB_TO_ABILITY) do
            if (ability == name) then job = code:upper(); end
        end
        local line = ('/p AV used %s! %s use %s within %ds to lock it!'):fmt(name, (job ~= '') and job or 'Someone', name, math.floor(LOCK_WINDOW));
        local cn = tonumber(avh.settings.general.party_call) or 0;
        if (cn > 0) then line = line .. (' <call%d>'):fmt(cn); end
        pcall(function () AshitaCore:GetChatManager():QueueCommand(1, line); end);
    end
    set_alert(('%s used by AV - counter now!'):fmt(name), COLOR_ARMED);

    avh.bar_active = true;
    avh.bar_start  = os.clock();
    avh.bar_window = LOCK_WINDOW;

    -- Play a distinct notification when this is the reaction tied to YOUR current job, so it
    -- stands out from the general "something used, someone counter it" alert.
    if (name == get_my_job_ability()) then
        play_sound(avh.settings.general.sound_trigger_own);
    else
        play_sound(avh.settings.general.sound_trigger);
    end
end

--------------------------------------------------------------------------------------------------
-- Manually marks an ability LOCKED regardless of armed/timing state - a fallback for when
-- detection misses something that genuinely locked in-game, and for the /avh lock <job> command.
--------------------------------------------------------------------------------------------------
local function force_lock(name, note)
    local st = avh.state[name];
    if (st == nil) then
        return;
    end
    st.status = 'locked';
    st.armed  = false;
    avh.bar_active = false;

    print_msg(chat.success(('%s marked LOCKED (%s).'):fmt(name, note)));
    set_alert(('%s LOCKED (%s)'):fmt(name, note), COLOR_LOCKED);
    play_sound(avh.settings.general.sound_lock);
end

--------------------------------------------------------------------------------------------------
-- Manually marks an ability UNLOCKED again - for correcting a mistaken LOCKED (a false-positive
-- match, or a /avh lock used by accident), via the /avh unlock <job> command.
--------------------------------------------------------------------------------------------------
local function force_unlock(name, note)
    local st = avh.state[name];
    if (st == nil) then
        return;
    end
    st.status = 'unlocked';
    st.armed  = false;
    avh.bar_active = false;

    print_msg(chat.warning(('%s marked UNLOCKED (%s).'):fmt(name, note)));
    set_alert(('%s UNLOCKED (%s)'):fmt(name, note), COLOR_UNLOCKED);
end

local function handle_player_use(name, actor_name)
    local st = avh.state[name];
    if (st == nil) then
        return;
    end

    if (st.status == 'locked') then
        return; -- already neutralized, nothing to do
    end

    local now = os.clock();

    if (st.armed and (now - st.armed_time) <= LOCK_WINDOW) then
        st.status = 'locked';
        st.armed  = false;

        print_msg(chat.success(('%s LOCKED by %s!'):fmt(name, actor_name)));
        set_alert(('%s LOCKED by %s!'):fmt(name, actor_name), COLOR_LOCKED);
        play_sound(avh.settings.general.sound_lock);
        avh.bar_active = false;
    else
        -- Used outside any active window - informational only, doesn't change any state.
        print_msg(chat.message(('%s used %s (Absolute Virtue hasn\'t shown it recently - no effect).'):fmt(actor_name, name)));
    end
end

--------------------------------------------------------------------------------------------------
-- Renders the main window.
--------------------------------------------------------------------------------------------------
-- omni change: render() is split in three - update() (timers, every frame), draw_body() (the
-- contents, used by both the floating window and omni's AV tab) and render() (the window).
local function update()
    pcall(check_spawn);   -- omni addition: start the clock when AV appears
    -- omni addition: 2-hour countdown and the party warning 10 seconds before.
    if (fight.next_2h ~= nil and fight.stop == nil) then
        local left = fight.next_2h - os.clock();
        if (left <= WARN_AT and not fight.warned) then
            fight.warned = true;
            if (avh.settings.general.party_warning) then
                local line = ('/p Warning: AV 2-hour %d/%d incoming in 10 seconds!'):fmt(math.min(fight.used + 1, #ABILITY_ORDER), #ABILITY_ORDER);
                local cn = tonumber(avh.settings.general.party_call) or 0;
                if (cn > 0) then line = line .. (' <call%d>'):fmt(cn); end
                pcall(function () AshitaCore:GetChatManager():QueueCommand(1, line); end);
            end
            play_sound(avh.settings.general.sound_trigger);
        end
        if (left <= 0) then
            -- That 2-hour is due now; the next is 90 seconds later.
            fight.next_2h, fight.warned = fight.next_2h + EVERY_2H, false;
            fight.used = fight.used + 1;
        end
    end

    -- Auto-expire armed windows and the top alert line so the display reflects reality even with
    -- no new packets since the last frame.
    local now = os.clock();
    for _, name in ipairs(ABILITY_ORDER) do
        local st = avh.state[name];
        if (st ~= nil and st.armed and (now - st.armed_time) > LOCK_WINDOW) then
            st.armed = false;
        end
    end
    if (avh.bar_active and (now - avh.bar_start) > avh.bar_window) then
        avh.bar_active = false;
    end
    -- The alert line used to expire on its own fixed 4-second timer regardless of the bar, so the
    -- "used by AV - counter now!" message (and its orange color) vanished back to idle grey well
    -- before the real 10-second lock window ran out - looking like the countdown was much shorter
    -- than it actually was. Now it only expires once the bar itself is no longer active, so the
    -- alert and the bar always agree: it shows LOCKED (or reverts once the window truly expires)
    -- at the same moment, and only the ALERT_DISPLAY_SECONDS timer governs how long a LOCKED/no-bar
    -- message lingers afterward.
    if (not avh.bar_active and avh.alert_set_at > 0 and (now - avh.alert_set_at) > ALERT_DISPLAY_SECONDS) then
        avh.alert_text   = 'No activity yet.';
        avh.alert_color  = COLOR_IDLE;
        avh.alert_set_at = 0;
    end
end

local function draw_body()
    local now = os.clock();

    -- omni addition: fight timer. A small heading with Start/Stop and Reset on the right,
    -- the time big underneath, then the next 2-hour (or what the timer is waiting for).
    local running = fight.start ~= nil and fight.stop == nil;
    local avail = imgui.GetContentRegionAvail();
    imgui.TextDisabled('FIGHT TIME');
    local bw = 52;
    imgui.SameLine(math.max(90, avail - bw * 2 - 2));
    if (running) then
        if (imgui.SmallButton('Stop##avh_t_stop')) then fight_end('stopped by hand'); end
    else
        if (imgui.SmallButton('Start##avh_t_start')) then fight_begin('started by hand'); end
    end
    imgui.SameLine(0, 4);
    if (imgui.SmallButton('Reset##avh_t_reset')) then fight_reset(); end

    imgui.SetWindowFontScale(1.6);
    local ft = fight_text() or '0:00:00';
    local col = running and T{ 1.0, 0.82, 0.25, 1.0 } or ((fight.stop ~= nil) and COLOR_LOCKED or T{ 0.55, 0.55, 0.60, 1.0 });
    imgui.TextColored(col, ft);
    imgui.SetWindowFontScale(1.0);

    if (running and fight.next_2h ~= nil) then
        local left = math.max(0, fight.next_2h - os.clock());
        imgui.TextColored((left <= WARN_AT) and COLOR_ARMED or COLOR_UNLOCKED,
            ('Next 2-hour %d/%d in %d:%02d'):fmt(math.min(fight.used + 1, #ABILITY_ORDER), #ABILITY_ORDER, math.floor(left / 60), math.floor(left) % 60));
    elseif (fight.stop ~= nil) then
        imgui.TextDisabled('Finished. Reset for the next pop.');
    else
        imgui.TextDisabled('Starts by itself when AV pops.');
    end
    imgui.Separator();

    -- Fixed width, auto height: AlwaysAutoResize recomputes width every frame to fit whatever
    -- text is currently longest (the alert line, "ARMED 10.0s" labels, etc.), which made the
    -- window visibly grow and shrink as the countdown text changed. Passing a fixed width with
    -- height 0 every frame (ImGuiCond_Always) keeps the width constant while the height still
    -- auto-fits the content, and ImGuiWindowFlags_NoResize hides the now-pointless resize grip.
        imgui.TextColored(avh.alert_color, avh.alert_text);

        if (avh.bar_active) then
            local remaining = math.max(0, avh.bar_window - (now - avh.bar_start));
            local frac = (avh.bar_window > 0) and (remaining / avh.bar_window) or 0;
            imgui.ProgressBar(frac, { -1, 0 }, ('%.1fs'):fmt(remaining));
        end

        imgui.Separator();

        if (imgui.BeginTable('avh_table', 2, bit.bor(ImGuiTableFlags_Borders, ImGuiTableFlags_RowBg, ImGuiTableFlags_SizingStretchProp))) then
            -- Explicit stretch weights instead of the 50/50 default - the longest ability names
            -- ("Eagle Eye Shot", "Meikyo Shisui") need more room than the short status labels
            -- ("unlocked", "LOCKED"), and an even split was leaving visible dead space on the
            -- Status side.
            imgui.TableSetupColumn('Ability', ImGuiTableColumnFlags_WidthStretch, 0.58, 0);
            imgui.TableSetupColumn('Status', ImGuiTableColumnFlags_WidthStretch, 0.42, 0);
            imgui.TableHeadersRow();

            local my_ability = get_my_job_ability();
            for _, name in ipairs(ABILITY_ORDER) do
                if (avh.settings.abilities[name]) then
                    imgui.TableNextRow();

                    imgui.TableNextColumn();
                    if (name == my_ability) then
                        imgui.TextColored(COLOR_MY_JOB, name);
                    else
                        imgui.Text(name);
                    end

                    imgui.TableNextColumn();
                    local st = avh.state[name];
                    if (st == nil or st.status == 'unlocked' and not st.armed) then
                        imgui.TextColored(COLOR_UNLOCKED, 'unlocked');
                    elseif (st.status == 'locked') then
                        imgui.TextColored(COLOR_LOCKED, 'LOCKED');
                    elseif (st.armed) then
                        local remaining = math.max(0, LOCK_WINDOW - (now - st.armed_time));
                        imgui.TextColored(COLOR_ARMED, ('ARMED %.1fs'):fmt(remaining));
                    else
                        imgui.TextColored(COLOR_UNLOCKED, 'unlocked');
                    end
                end
            end

            imgui.EndTable();
        end

        imgui.Separator();
        imgui.TextDisabled(('Sound: %s'):fmt(avh.settings.general.play_sound and 'On' or 'Muted'));
        imgui.TextDisabled(('Auto-reset on AV speech: %s'):fmt(avh.settings.general.auto_reset_on_speech and 'On' or 'Off'));

        if (#avh.unresolved > 0) then
            imgui.Separator();
            imgui.TextColored(COLOR_WARNING, 'Unresolved (see chat log):');
            avh.unresolved:each(function (name)
                imgui.BulletText(name);
            end);
        end
end

-- The floating window (shown with /avh or /avh show).
local function render()
    if (not avh.settings.visible[1]) then
        return;
    end
    imgui.SetNextWindowSize({ WINDOW_WIDTH, 0, }, ImGuiCond_Always);
    -- omni change: drawn in omni's own look (the Look picked in Options), not the default red.
    local st = package.loaded['omni_style'];
    local ns = st and st.begin() or nil;
    if (imgui.Begin('Happy Virtue##avh_float', avh.settings.visible, bit.bor(ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoCollapse))) then
        draw_body();
    end
    imgui.End();
    if (st) then st.finish(ns); end
end

--------------------------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------------------------
local function print_help()
    print(chat.header(AVH_NAME):append(chat.message('Available commands:')));

    local cmds = T{
        { '/avh',                      'Toggle the window.', },
        { '/avh show',                 'Show the window.', },
        { '/avh hide',                 'Hide the window.', },
        { '/avh reset',                'Clear all lock/unlock state (start of a new pull).', },
        { '/avh mute / unmute',        'Toggle sound alerts.', },
        { '/avh party on/off',         'Say AV\'s 2-hours in party chat (omni addition).', },
        { '/avh speechreset on/off',   'Toggle auto-reset when AV\'s engage speech is seen in chat.', },
        { '/avh abilities',            'List tracked abilities and resolved ids.', },
        { '/avh lock <job>',           'Manually mark a job\'s 2hr LOCKED (e.g. /avh lock drg).', },
        { '/avh unlock <job>',         'Manually mark a job\'s 2hr UNLOCKED again (e.g. /avh unlock sam).', },
        { '/avh help',                 'Shows this help.', },
    };

    cmds:each(function (v)
        print(chat.header(AVH_NAME):append(chat.error('Usage: ')):append(chat.message(v[1]):append(' - ')):append(chat.color1(6, v[2])));
    end);
end

ashita.events.register('command', 'avh_command_cb', function (e)
    local args = e.command:args();
    if (#args == 0 or args[1]:lower() ~= '/avh') then
        return;
    end
    e.blocked = true;

    if (#args == 1) then
        avh.settings.visible[1] = not avh.settings.visible[1];
        settings.save('omni_av');
        return;
    end

    local sub = args[2]:lower();

    if (sub == 'help') then
        print_help();
    elseif (sub == 'show') then
        avh.settings.visible[1] = true;
        settings.save('omni_av');
    elseif (sub == 'hide') then
        avh.settings.visible[1] = false;
        settings.save('omni_av');
    elseif (sub == 'reset') then
        reset_state();
        print_msg('State reset - all abilities unlocked.');
    elseif (sub == 'party') then
        -- omni addition: /avh party on|off - the party chat call-out.
        local arg = (args[3] or ''):lower();
        if (arg == 'on' or arg == 'off') then
            avh.settings.general.party_callout = (arg == 'on');
        else
            avh.settings.general.party_callout = not avh.settings.general.party_callout;
        end
        settings.save('omni_av');
        print_msg(('Party chat call-out: %s'):fmt(avh.settings.general.party_callout and 'ON' or 'OFF'));
    elseif (sub == 'mute') then
        avh.settings.general.play_sound = false;
        settings.save('omni_av');
        print_msg('Sound alerts muted.');
    elseif (sub == 'unmute') then
        avh.settings.general.play_sound = true;
        settings.save('omni_av');
        print_msg('Sound alerts unmuted.');
    elseif (sub == 'speechreset') then
        local val = (args[3] or ''):lower();
        if (val == 'on') then
            avh.settings.general.auto_reset_on_speech = true;
            settings.save('omni_av');
            print_msg('Auto-reset on AV engage speech: ON.');
        elseif (val == 'off') then
            avh.settings.general.auto_reset_on_speech = false;
            settings.save('omni_av');
            print_msg('Auto-reset on AV engage speech: OFF.');
        else
            print_msg(('Auto-reset on AV engage speech is currently %s. Usage: /avh speechreset on|off'):fmt(
                avh.settings.general.auto_reset_on_speech and 'ON' or 'OFF'));
        end
    elseif (sub == 'abilities') then
        print_msg('Tracked abilities (player-side id used to detect the counter-SP):');
        for _, name in ipairs(ABILITY_ORDER) do
            if (avh.settings.abilities[name]) then
                local id = avh.ability_ids[name];
                print_msg(('  %-16s -> %s  (AV mob-skill id: %s)'):fmt(
                    name,
                    id ~= nil and tostring(id) or 'NOT FOUND',
                    tostring(MOB_SKILL_IDS[name])
                ));
            end
        end
    elseif (sub == 'lock') then
        if (args[3] == nil) then
            print_msg('Usage: /avh lock <job> (e.g. /avh lock drg, /avh lock sam)');
            return;
        end
        local job = args[3]:lower();
        local name = JOB_TO_ABILITY[job];
        if (name == nil) then
            print_msg('Unknown job: ' .. job .. '. Valid: war, whm, mnk, blm, rdm, thf, pld, drk, brd, sam, rng, drg');
            return;
        end
        force_lock(name, 'manual');
    elseif (sub == 'unlock') then
        if (args[3] == nil) then
            print_msg('Usage: /avh unlock <job> (e.g. /avh unlock drg, /avh unlock sam)');
            return;
        end
        local job = args[3]:lower();
        local name = JOB_TO_ABILITY[job];
        if (name == nil) then
            print_msg('Unknown job: ' .. job .. '. Valid: war, whm, mnk, blm, rdm, thf, pld, drk, brd, sam, rng, drg');
            return;
        end
        force_unlock(name, 'manual');
    else
        print_help();
    end
end);

--------------------------------------------------------------------------------------------------
-- event: load
--------------------------------------------------------------------------------------------------
ashita.events.register('load', 'avh_load_cb', function ()
    resolve_abilities();
    reset_state();
    print_msg(('Loaded inside omni (v%s). Use /avh help for commands.'):fmt(AVH_VERSION));
end);

--------------------------------------------------------------------------------------------------
-- omni addition: when the helper listens - 'zone' (only in Al'Taieu, where AV is; the default),
-- 'always', or 'off'. Set from omni's Options tab.
--------------------------------------------------------------------------------------------------
local AV_ZONE = 33;   -- Al'Taieu
local listen_mode = 'zone';
local function listening()
    if (listen_mode == 'off') then return false; end
    if (listen_mode == 'always') then return true; end
    local z = 0;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    return z == AV_ZONE;
end

--------------------------------------------------------------------------------------------------
-- event: packet_in
--------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'avh_packet_in_cb', function (e)
    if (not avh.settings.general.enabled) then
        return;
    end
    if (e.id ~= 0x0028 or not listening()) then
        return;
    end

    if (e.id ~= 0x0028) then
        return;
    end

    local ok, pkt = pcall(parse_action_packet, e);
    if (not ok or pkt == nil) then
        return;
    end

    if (pkt.Type == CATEGORY_MOB_TP_MOVE) then
        -- Is this one of AV's tracked reaction ids?
        local ability_name = avh.mobskill_to_name[pkt.Id];
        if (ability_name == nil) then
            return;
        end

        -- Confirm the actor is actually Absolute Virtue, not some unrelated monster that happens
        -- to share a mob skill id (several are reused across many NMs).
        local actor_name = resolve_mob_name(pkt.UserId);
        if (actor_name == nil or actor_name:lower() ~= avh.settings.general.mob_name:lower()) then
            return;
        end

        fight_begin('Absolute Virtue used a 2-hour');   -- omni addition: in case the speech was missed
        handle_av_use(ability_name);
        return;
    end

    if (pkt.Type == CATEGORY_JOB_ABILITY or pkt.Type == CATEGORY_JOB_ABILITY_UNBLINKABLE or pkt.Type == CATEGORY_RANGED_ATTACK) then
        local ability_name = avh.id_to_name[pkt.Id];
        if (ability_name == nil) then
            return;
        end

        local is_ally, ally_name = get_ally_name(pkt.UserId);
        if (not is_ally) then
            return;
        end

        handle_player_use(ability_name, ally_name);
        return;
    end
end);

--------------------------------------------------------------------------------------------------
-- event: text_in (incoming chat-log text - used to auto-detect a fresh pull via AV's own speech)
--------------------------------------------------------------------------------------------------
ashita.events.register('text_in', 'avh_text_in_cb', function (e)
    if (e.injected) then
        return; -- ignore lines injected by other addons (avoids feedback loops)
    end
    if (not listening()) then
        return;
    end
    check_speech_reset(e.message);
    pcall(check_fight_text, e.message);   -- omni addition: fight timer
end);

--------------------------------------------------------------------------------------------------
-- event: d3d_present
--------------------------------------------------------------------------------------------------
ashita.events.register('d3d_present', 'avh_present_cb', function ()
    if (listening()) then
        update();
    end
    render();
end);

--------------------------------------------------------------------------------------------------
-- event: unload
--------------------------------------------------------------------------------------------------
ashita.events.register('unload', 'avh_unload_cb', function ()
    settings.save('omni_av');
end);

--------------------------------------------------------------------------------------------------
-- omni addition: Absolute Virtue's weapon drops (one of these, 10% each), green if you own it,
-- red if not. Owned = in your inventory or any Mog House bag, matched by name.
--------------------------------------------------------------------------------------------------
local AV_WEAPONS = {
    'Bifrost', 'Broken Promise', 'Carver', "Elegy's Respite", 'Face Breakers',
    'Hax', 'Somnia Melodiam', 'Tonzoffun', 'Undulant Black', 'Raqia',
};
local weapon_ids = {};       -- name -> item id (looked up once, for the icon)
local weapon_owned = {};     -- lowercase name -> true
local weapons_at = -100;

local function scan_weapons()
    if (os.clock() - weapons_at < 3) then
        return;
    end
    weapons_at = os.clock();
    local wanted = {};
    for _, name in ipairs(AV_WEAPONS) do wanted[name:lower()] = true; end
    local found = {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();
        for bag = 0, 16 do
            for slot = 1, (inv:GetContainerCountMax(bag) or 0) do
                local item = inv:GetContainerItem(bag, slot);
                if (item ~= nil and item.Id ~= nil and item.Id ~= 0 and item.Id ~= 65535) then
                    local r = res:GetItemById(item.Id);
                    local name = r and r.Name and r.Name[1];
                    if (name ~= nil and wanted[name:lower()]) then
                        found[name:lower()] = true;
                        weapon_ids[name:lower()] = item.Id;
                    end
                end
            end
        end
        -- Item numbers for weapons you do not own yet, so they can still show their picture.
        for _, name in ipairs(AV_WEAPONS) do
            if (weapon_ids[name:lower()] == nil) then
                for _, lang in ipairs({ 0, 2, 1 }) do
                    local ok, r = pcall(function () return res:GetItemByName(name, lang); end);
                    if (ok and r ~= nil and r.Id ~= nil and r.Id ~= 0) then
                        weapon_ids[name:lower()] = r.Id;
                        break;
                    end
                end
                if (weapon_ids[name:lower()] == nil) then weapon_ids[name:lower()] = false; end
            end
        end
    end);
    weapon_owned = found;
end

local function draw_weapons(host)
    scan_weapons();
    local have = 0;
    for _, name in ipairs(AV_WEAPONS) do
        if (weapon_owned[name:lower()]) then have = have + 1; end
    end
    imgui.Spacing();
    imgui.Separator();
    imgui.TextColored({ 0.79, 0.69, 0.42, 1.0 }, string.format('AV Weapons  (%d / %d)', have, #AV_WEAPONS));
    imgui.TextDisabled('Absolute Virtue drops one of these (10%% each).');

    local ww = imgui.GetWindowWidth();
    local colW = math.floor((ww - 24) / 2);
    local boxH = 30;
    for i, name in ipairs(AV_WEAPONS) do
        local owned = weapon_owned[name:lower()] == true;
        local col = (i - 1) % 2;
        if (col == 1) then imgui.SameLine(0, 6); end
        imgui.PushStyleColor(ImGuiCol_ChildBg, owned and { 0.16, 0.42, 0.16, 1.0 } or { 0.45, 0.13, 0.13, 1.0 });
        imgui.BeginChild('##avw_' .. i, { colW, boxH }, true, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse));
        imgui.SetCursorPos({ 4, 3 });
        local id = weapon_ids[name:lower()];
        if (not (host and id and host.renderIcon(id, 22))) then
            imgui.Dummy({ 22, 22 });
        end
        imgui.SameLine(0, 8);
        imgui.SetCursorPosY(7);
        imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, name);
        imgui.EndChild();
        imgui.PopStyleColor(1);
        if (imgui.IsItemHovered()) then
            imgui.BeginTooltip();
            imgui.Text(name .. (owned and ' - you have this' or ' - you do not have this'));
            imgui.EndTooltip();
        end
    end
end

--------------------------------------------------------------------------------------------------
-- omni addition: what omni's AV tab draws, and whether the floating window is open.
--------------------------------------------------------------------------------------------------
return {
    -- omni: 'zone' (Al'Taieu only), 'always' or 'off'.
    set_mode = function (m) if (m == 'zone' or m == 'always' or m == 'off') then listen_mode = m; end end,
    get_mode = function () return listen_mode; end,
    -- omni: the floating AV tracker window (Options > Pop-outs).
    float_shown = function () return avh.settings.visible[1] == true; end,
    set_float = function (on) avh.settings.visible[1] = (on == true); settings.save('omni_av'); end,
    -- omni: open Happy Virtue by itself when AV pops (get, or set with a value).
    auto_open = function (on)
        if (on ~= nil) then avh.settings.general.auto_open = (on == true); settings.save('omni_av'); end
        return avh.settings.general.auto_open ~= false;
    end,
    draw_tab = function (host)
        draw_body();
        imgui.Spacing();
        local label = avh.settings.visible[1] and 'Hide floating window' or 'Show floating window';
        if (imgui.SmallButton(label .. '##avh_float')) then
            avh.settings.visible[1] = not avh.settings.visible[1];
            settings.save('omni_av');
        end
        imgui.SameLine(0, 8);
        if (imgui.SmallButton('Reset pull##avh_reset')) then
            reset_state();
            print_msg('State reset.');
        end
        imgui.SameLine(0, 8);
        local callout = { avh.settings.general.party_callout == true };
        if (imgui.Checkbox('Call out in party chat##avh_party', callout)) then
            avh.settings.general.party_callout = callout[1];
            settings.save('omni_av');
        end
        local warn = { avh.settings.general.party_warning ~= false };
        if (imgui.Checkbox('Warn party 10s before each 2-hour##avh_warn', warn)) then
            avh.settings.general.party_warning = warn[1];
            settings.save('omni_av');
        end
        -- Call sound on both party messages: everyone in the party hears it.
        local cn = tonumber(avh.settings.general.party_call) or 0;
        local con = { cn > 0 };
        if (imgui.Checkbox('Call sound##avh_call', con)) then
            avh.settings.general.party_call = con[1] and 14 or 0;
            settings.save('omni_av');
        end
        if (imgui.IsItemHovered()) then imgui.SetTooltip('Adds <call> to the party messages so everyone hears a sound.'); end
        if (cn > 0) then
            imgui.SameLine(0, 8);
            if (imgui.SmallButton('-##avh_call_dn')) then avh.settings.general.party_call = math.max(1, cn - 1); settings.save('omni_av'); end
            imgui.SameLine(0, 4);
            imgui.TextColored({ 0.92, 0.92, 0.95, 1.0 }, ('<call%d>'):fmt(cn));
            imgui.SameLine(0, 4);
            if (imgui.SmallButton('+##avh_call_up')) then avh.settings.general.party_call = math.min(21, cn + 1); settings.save('omni_av'); end
        end
        draw_weapons(host);
    end,
};
