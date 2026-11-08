--[[
    Rest action
    Handles automatic MP recovery through resting (/heal on)
    - Starts resting when conditions are met (not moving, not casting, timer elapsed)
    - Stops resting only on full MP or the follow target exceeding rest_distance
]]--

local common = require('lib.core.common')

local rest = {}

-- MP window (omni change): rest starts only once MP drops below rest_mp_start %,
-- and keeps resting (resuming after any cure that stood us up) until MP reaches
-- rest_mp_stop %. `recovering` remembers that we are inside that window.
local recovering = false

local function mp_window(settings)
    local start = tonumber(settings.rest_mp_start) or 15
    local stop  = tonumber(settings.rest_mp_stop) or 90
    if stop < start then stop = start end
    return start, stop
end

local function current_mpp()
    local game_state = common.game_state
    local player     = game_state and game_state.player
    return player and player.mpp or 0
end

local function update_recovering(settings)
    local start, stop = mp_window(settings)
    local mpp = current_mpp()
    if mpp >= stop then
        recovering = false
    elseif mpp < start then
        recovering = true
    end
    return recovering
end

-- Check if we should start resting
local function should_start_resting(settings, job_def)
    -- Only for MP-based jobs
    if not job_def or job_def.resource_type ~= 'mp' then
        common.reset_rest_timer()
        return false
    end
    
    -- Check if resting is enabled
    if not settings.rest_enabled then
        common.reset_rest_timer()
        return false
    end
    
    -- Already resting
    if common.is_resting() then
        common.reset_rest_timer()
        return false
    end
    
    -- Check if player is engaged in combat
    if common.is_engaged() then
        common.reset_rest_timer()
        return false
    end
    
    -- Check if player is moving or casting
    if common.is_player_moving() then
        common.reset_rest_timer()
        return false
    end
    
    if common.is_casting() then
        common.reset_rest_timer()
        return false
    end
    
    -- Only inside the MP window: dropped below the start %, not yet back to the stop %.
    if not update_recovering(settings) then
        common.reset_rest_timer()
        return false
    end

    -- Check distance to follow target (if set) -- party member or tracked target
    local rest_distance = settings.rest_distance or 7
    local follow_target = settings.follow_target

    if follow_target then
        local distance = common.get_follow_target_distance(follow_target)
        if distance and distance > rest_distance then
            common.reset_rest_timer()
            return false
        end
    end
    
    -- All base conditions are met (not moving, not casting, MP not full, distance ok)
    local current_time = os.clock()
    local rest_timer = settings.rest_timer or 5
    
    -- Start the conditions timer if not already started
    if common.get_rest_timer() == 0 then
        common.set_rest_timer(current_time)
        return false
    end
    
    -- Check if enough time has passed since conditions became favorable
    local time_since_conditions = current_time - common.get_rest_timer()
    if time_since_conditions < rest_timer then
        return false
    end
    
    -- Timer has elapsed, can start resting
    return true
end

-- Check if we should stop resting
local function should_stop_resting(settings, job_def)
    -- Not resting, nothing to stop
    if not common.is_resting() then
        return false
    end
    
    -- Stand up once MP reaches the stop %.
    local _, stop = mp_window(settings)
    if current_mpp() >= stop then
        recovering = false
        return true
    end

    -- Check distance to follow target (if set) -- party member or tracked target
    local rest_distance = settings.rest_distance or 7

    local follow_target = settings.follow_target
    if follow_target then
        local distance = common.get_follow_target_distance(follow_target)
        if distance and distance > rest_distance then
            return true
        end
    end
    
    -- No reason to stop resting
    return false
end

-- Execute rest action
function rest.execute(settings, job_def, main_level, sub_level, player_resource)
    -- Only for MP-based jobs
    if not job_def or job_def.resource_type ~= 'mp' then
        return nil
    end
    
    -- Check if resting is enabled
    if not settings.rest_enabled then
        recovering = false
        return nil
    end
    
    -- Only the stop MP % or the follow target outrunning rest_distance ends a rest.
    -- Moving or casting stands the player up server-side anyway, and is_resting
    -- re-syncs from entity_status each tick, so neither needs a /heal off here.
    -- Check if we should stop resting (priority check)
    if should_stop_resting(settings, job_def) then
        common.set_resting(false)
        common.reset_rest_timer()
        return {
            command = '/heal off',
            description = 'Stopping rest (distance or MP reached the stand-up %)'
        }
    end
    
    -- Check if we should start resting
    if should_start_resting(settings, job_def) then
        local state_snap = common.game_state
        local mp_percent = state_snap and state_snap.player and state_snap.player.mpp or 0
        common.set_resting(true)
        common.reset_rest_timer()  -- Reset after starting
        return {
            command = '/heal on',
            description = string.format('Starting rest to recover MP (%.1f%%)', mp_percent)
        }
    end
    
    return nil
end

return rest
