--[[
    ja.lua - omni's Happy Healer: every other job ability, each with its own tick box.

    The abilities come from lib/jobs/all_abilities.lua (the server's own ability list) and are
    added to every job (main and support) by omni_sidekick.lua as the 'ja' list. They all start
    unticked. A ticked one is used in battle as soon as its recast is ready:
      - on the monster you're fighting (Provoke, Jump, Steal, Shield Bash...)
      - on yourself (Berserk, Hasso, Sekkanoki...) - but not while you already have the effect
        of the same name (so Berserk isn't used again while Berserk is still on)
      - pet ones (Sic, Reward...) only when you have a pet out
    Level and support job are checked by common.filter_abilities_by_level (support job: half
    level, no 2-hours and no merit abilities).
]]--

local ja = {}

local common      = require('lib.core.common')
local action_core = require('lib.core.action_core')

-- Buff name -> id, from the game's own list (built once).
local buff_ids = nil
local function buff_id_of(name)
    if buff_ids == nil then
        buff_ids = {}
        pcall(function ()
            local rm = AshitaCore:GetResourceManager()
            for id = 0, 1023 do
                local n = rm:GetString('buffs.names', id)
                if n and n ~= '' then
                    local k = n:lower():gsub('[^%w]', '')
                    if buff_ids[k] == nil then buff_ids[k] = id end
                end
            end
        end)
    end
    return buff_ids[(name or ''):lower():gsub('[^%w]', '')]
end

-- Don't try the same ability again straight away (the server may refuse it - no finishing moves,
-- out of range...). 2-hours share recast timer 0, which always reads as ready, so after trying one
-- it is left for 10 minutes.
local last_try = {}
local RETRY, RETRY_SP = 5, 600

function ja.execute(settings, job_def)
    if settings.ja_enabled == false then return nil end
    local list = job_def.abilities and job_def.abilities.ja
    if not list or #list == 0 then return nil end
    -- Only in battle: these are fighting abilities.
    if not common.is_combat() then return nil end

    local state  = common.game_state
    local player = state and state.player
    if not player then return nil end

    local usable = common.filter_abilities_by_level(list, settings, player.main_level, player.sub_level, job_def)
    local ready = {}
    for _, a in ipairs(usable) do
        local skip = false
        local t = last_try[a.name]
        if t and os.clock() - t < (a.sp and RETRY_SP or RETRY) then skip = true end
        -- a self ability whose effect you already have: wait until it wears off
        if a.target == 'self' then
            local bid = a.buff_check_id
            if bid == nil then bid = buff_id_of(a.name) or false; a.buff_check_id = bid end
            if bid and action_core.has_any_buff(player.buffs, bid) then skip = true end
        end
        if not skip then ready[#ready + 1] = a end
    end
    if #ready == 0 then return nil end
    return action_core.first_command(ready, job_def, settings, '[JA]', nil,
        function (a)
            last_try[a.name] = os.clock()
            return string.format('%s (job ability)', a.name)
        end)
end

return ja
