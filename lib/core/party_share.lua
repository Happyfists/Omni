--[[
    Shared Party List

    Every omni (Happy Healer) session on this PC publishes its own party, with HP/MP, to
    config/addons/omni/hh_share/party_<CharName>.txt. Like Cure Please, the healer then
    picks one of those characters as its Monitored Player and tracks that character's
    party, so it can see and heal them from outside the party. Entries added this way
    carry .auto and are the only ones this module removes.

    See ARCHITECTURE.md, "party_share.lua -- Shared Party List", for the full design.
]]--

local common = require('lib.core.common')

local party_share = {}

local POLL_INTERVAL = 1.0   -- Seconds between publish/sync passes
local HEARTBEAT     = 10    -- Rewrite our file at least this often, so others know we're alive
local STALE_AFTER   = 30    -- A file not rewritten for this long belongs to a closed game
local last_write    = 0
local dir_made      = false

-- omni: Cure Please style. Only the Monitored Player's party is mirrored (nil = nobody).
party_share.monitored = nil
local rosters = {}          -- [owner] = { list = { {name, hpp, mpp, zone, ...}, ... }, at = os.time() }
local next_poll     = 0
local last_roster   = nil   -- Text last written, so an unchanged party is a no-op
local my_file       = nil   -- Path this session publishes to, for cleanup on unload

-- Made on first use.
local function shared_dir()
    local dir = string.format('%s\\config\\addons\\omni\\hh_share\\', AshitaCore:GetInstallPath())
    if not dir_made then
        dir_made = true
        for _, fn in ipairs({ 'create_dir', 'create_directory' }) do
            if ashita and ashita.fs and ashita.fs[fn] then pcall(ashita.fs[fn], dir) end
        end
    end
    return dir
end

local function shared_path(name)
    return string.format('%sparty_%s.txt', shared_dir(), name)
end

--[[
    Publishing
]]--

-- One line per active party slot, numeric fields first so the name stays unambiguous last:
--
--   <server_id> <main_job> <sub_job> <main_level> <sub_level> <max_hp> <name>
--
-- Read straight off game_state, which the tick already refreshed: a member's own party
-- list carries their real job/level, and max_hp is the observed-at-100% cache rather
-- than an hp/hpp derivation, so the value is stable and doesn't churn the file.
-- 0 means unknown (an /anon member publishes job 0 / level 0, same as a failed /check).
-- Job and level are always known to the publisher, but max_hp is *not*: the cache is only
-- seeded once that member has been seen at 100% HP, so a member who has been hurt since
-- we met them publishes max_hp 0. The reader ignores a 0 (common.set_tracked_target_info)
-- and stays on its AVERAGE_HP_BY_LEVEL estimate until a real value shows up.
-- Trusts are written with a trust flag so the tab can list them, but the reader never
-- tracks them: only their owner's own party can cast on them.
-- nil while game_state isn't populated (zoning) -- publishing nothing beats an empty roster.
local function roster_lines()
    local gs = common.game_state
    if not gs or not gs.player then return nil end

    local lines = {}
    for i = 0, 5 do
        local m = (i == 0) and gs.player or (gs.party and gs.party[i])
        if m and m.is_active ~= false
            and m.server_id and m.server_id > 0 and m.name and m.name ~= '' then
            local zone = 0
            pcall(function () zone = common.get_party():GetMemberZone(i) or 0 end)
            table.insert(lines, string.format('%d %d %d %d %d %d %d %d %d %d %s',
                m.server_id,
                m.job or 0, m.sub_job or 0,
                m.main_level or 0, m.sub_level or 0,
                m.max_hp or 0,
                m.hpp or 0, m.mpp or 0, zone,
                m.is_trust and 1 or 0,
                m.name))
        end
    end

    if #lines == 0 then return nil end
    return lines
end

local function publish(my_name)
    local lines = roster_lines()
    if not lines then return end

    local text = table.concat(lines, '\n') .. '\n'
    if text == last_roster and os.time() - last_write < HEARTBEAT then return end
    last_write = os.time()
    text = text .. '#t ' .. os.time() .. '\n'

    -- Write a temp file and swap it in, rather than truncating the live one: a reader
    -- that catches a truncated file parses a short-but-valid roster and drops the auto
    -- targets missing from it, where a reader that catches no file at all reads nil,
    -- and nil never drives a removal (see sync()). os.rename cannot clobber an existing
    -- file on Windows, so the old roster is removed first -- which is why the swap is a
    -- gap rather than an instant, and the gap is the safe state of the two.
    -- ponytail: with two or more publishers, another file reading back during that gap
    -- still satisfies read_any and costs this owner's members one pass (~2 s) before
    -- they are re-added. Needs per-owner read tracking to close, which is not worth it
    -- for a microsecond window hit by a 2 s poll.
    local path = shared_path(my_name)
    local tmp  = path .. '.tmp'
    local f = io.open(tmp, 'w')
    if not f then return end
    f:write(text)
    f:close()

    os.remove(path)
    if not os.rename(tmp, path) then
        os.remove(tmp)
        return
    end

    my_file     = path
    last_roster = text:gsub('#t %d+\n$', '')
    common.debugf('[PartyShare] Published %d member(s) to %s', #lines, path)
end

--[[
    Reading
]]--

-- Returns { [server_id] = {name, main_job, sub_job, main_level, sub_level, max_hp} } for a
-- published roster, or nil when there is no file or it parsed empty (caught mid-rewrite).
-- nil never drives removals -- see sync().
local function read_roster(owner)
    local f = io.open(shared_path(owner), 'r')
    if not f then return nil end

    local members, list, at = {}, {}, 0
    for raw in f:lines() do
        local line = raw:gsub('\r$', '')
        local t = line:match('^#t (%d+)')
        if t then at = tonumber(t) end
        local sid, job, sub, mlvl, slvl, mhp, hpp, mpp, zone, trust, member =
            line:match('^(%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (.+)$')
        if sid then
            local e = {
                server_id  = tonumber(sid),
                name       = member,
                main_job   = tonumber(job),
                sub_job    = tonumber(sub),
                main_level = tonumber(mlvl),
                sub_level  = tonumber(slvl),
                max_hp     = tonumber(mhp),
                hpp        = tonumber(hpp),
                mpp        = tonumber(mpp),
                zone       = tonumber(zone),
                is_trust   = trust == '1',
            }
            -- Trusts are listed for show only: just their owner's party can cast on them.
            if not e.is_trust then members[e.server_id] = e end
            list[#list + 1] = e
        end
    end
    f:close()

    if #list == 0 then return nil end
    -- A game that closed without cleaning up leaves an old file: ignore it.
    if os.time() - at > STALE_AFTER then return nil end
    rosters[owner] = { list = list, at = at }
    return members
end

-- Every roster published on this PC except our own, merged into one
-- { [server_id] = info }, plus whether any file actually read back with members.
-- That flag is what makes removals safe: nothing read means nothing is dropped, so a
-- file that is merely absent (owner logged out) or caught mid-rewrite can never wipe
-- the list.
-- ashita.fs.get_dir returns bare file names; the owner is what sits between the
-- 'party_' prefix and the extension. The listing is taken unfiltered ('.*') and narrowed
-- with a Lua pattern below -- get_dir's filter is a C++ std::regex, and there is no reason
-- to depend on its dialect for a match we have to make anyway to pull the owner out.
local function read_all_rosters(my_name)
    local members  = {}
    local read_any = false

    local ok, files = pcall(ashita.fs.get_dir, shared_dir(), '.*', true)
    if not ok or not files then return members, false end

    for _, file in ipairs(files) do
        local owner = tostring(file):match('^party_(.+)%.txt$')
        if owner and owner ~= my_name and owner == party_share.monitored then
            local roster = read_roster(owner)
            if roster then
                read_any = true
                for sid, info in pairs(roster) do members[sid] = info end
            end
        end
    end
    return members, read_any
end

-- Locate loaded entities for a set of server ids in one pass over the entity table
-- (one scan for the whole set, not one per member). Returns
-- [server_id] = stand-in table carrying the three fields common.add_tracked_target reads.
-- Players absent from our client's entity table -- out of range, another zone -- are simply
-- missing from the result and retried next poll, so HP and buff reads are never made
-- against a phantom entry.
local function find_entities(server_ids)
    local found = {}
    local ent   = common.get_entity_manager()
    if not ent then return found end

    for idx = 1, 0x8FF do
        local sid = ent:GetServerId(idx)
        if sid and server_ids[sid] then
            local name = ent:GetName(idx)
            if name and name ~= '' then
                found[sid] = { ServerId = sid, Name = name, TargetIndex = idx }
            end
        end
    end
    return found
end

--[[
    Syncing
]]--

local function drop_all_auto()
    local tracked, stale = common.get_tracked_targets(), {}
    for sid, tt in pairs(tracked) do if tt.auto then stale[#stale + 1] = sid end end
    for _, sid in ipairs(stale) do common.remove_tracked_target(sid) end
end

local function sync(my_name)
    if party_share.monitored == nil or party_share.monitored == '' or party_share.monitored == my_name then
        drop_all_auto()
        return
    end
    local published, read_any = read_all_rosters(my_name)
    if not read_any then return end

    -- Our own party (slot 0 included) is already covered by the normal party path and
    -- must never become a tracked target.
    local mine = {}
    for _, sid in ipairs(common.get_party_server_ids()) do mine[sid] = true end

    local wanted = {}  -- [server_id] = roster entry, minus anyone in our own party
    for sid, info in pairs(published) do
        if not mine[sid] then wanted[sid] = info end
    end

    -- Drop auto entries no roster lists any more. Hand-added targets have no .auto and
    -- are never touched.
    local tracked = common.get_tracked_targets()
    local stale   = {}
    for sid, tt in pairs(tracked) do
        if tt.auto and not wanted[sid] then
            table.insert(stale, sid)
        end
    end
    for _, sid in ipairs(stale) do
        common.remove_tracked_target(sid)
    end

    -- Refresh entries we already hold (a level-up or job change on the other box lands
    -- here), and collect the ones still missing. No /check is sent for a roster-driven
    -- add, so there is nothing to stagger and the whole party can land in one pass.
    local missing = {}
    for sid, info in pairs(wanted) do
        local tt = tracked[sid]
        if not tt then
            missing[sid] = true
        elseif tt.auto then
            common.set_tracked_target_info(sid, info)
        end
    end
    if not next(missing) then return end

    for sid, entity in pairs(find_entities(missing)) do
        if common.add_tracked_target(entity, wanted[sid]) then
            tracked[sid].auto = true
        end
    end
end

--[[
    Public
]]--

-- True while this game is writing its party file (so the tab can show "Sharing party").
function party_share.sharing()
    return my_file ~= nil and os.time() - last_write <= HEARTBEAT + 5
end

-- Other characters running omni on this PC right now (fresh files only).
local others_cache, others_at = {}, -math.huge
function party_share.others()
    if os.clock() - others_at < 2 then return others_cache end
    others_at = os.clock()
    local me = common.get_party_member_name(0) or ''
    local out = {}
    local ok, files = pcall(ashita.fs.get_dir, shared_dir(), '.*', true)
    if not ok or not files then return out end
    for _, file in ipairs(files) do
        local owner = tostring(file):match('^party_(.+)%.txt$')
        if owner and owner ~= me and read_roster(owner) then out[#out + 1] = owner end
    end
    table.sort(out)
    others_cache = out
    return out
end

-- The last party list read from a character's file: array of { name, hpp, mpp, zone, ... }.
function party_share.roster(owner)
    local r = owner and rosters[owner]
    if not r or os.time() - r.at > STALE_AFTER then return nil end
    return r.list
end

function party_share.tick()
    local now = os.clock()
    if now < next_poll then return end
    next_poll = now + POLL_INTERVAL

    -- Our own character name keys both halves: the file we write, and the one file in
    -- the directory we must not read back.
    local my_name = common.get_party_member_name(0)
    if not my_name or my_name == '' then return end

    -- omni: alts on non-healer jobs never run the engine, so make sure the party
    -- snapshot we publish is fresh.
    pcall(common.refresh_game_state_if_stale)

    publish(my_name)
    sync(my_name)
end

-- Drop our published file so a closed session doesn't leave a roster behind for
-- the other box to mirror.
function party_share.cleanup()
    if my_file then
        os.remove(my_file)
        my_file     = nil
        last_roster = nil
    end
end

return party_share
