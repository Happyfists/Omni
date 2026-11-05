local chat = require('chat')
local settings = require('settings')
local gdi_encoding = require('trainmon.encoding')

local chat_modes = require('trainmon.chat_modes')
local monster_db = require('trainmon.monster_db.db')

local monitor = {}
monitor.__index = monitor

local train_data_defaults = T{
    target_monsters = {},
    target_zone_id = -1,
}

local test_rules = {
    en = require('trainmon.rules_en'),
    ja = require('trainmon.rules_ja'),
}

-- [omni] whole alliance (0-17), any case, and your own name even if the party list can't be read (VanaCore)
local function player_is_in_party(player_name)
    if player_name == nil then return false end
    local want = player_name:lower()
    local found = false
    pcall(function ()
        local party = AshitaCore:GetMemoryManager():GetParty()
        for i = 0,17 do
            local n = party:GetMemberName(i)
            if n ~= nil and n ~= '' and n:lower() == want then found = true end
        end
    end)
    if not found then
        pcall(function ()
            local me = GetPlayerEntity()
            if me ~= nil and me.Name ~= nil and me.Name:lower() == want then found = true end
        end)
    end
    return found
end

local function array_remove(t, fn_remove)
    local j, n = 1, #t

    for i = 1, n do
        if fn_remove(t, i, j) then
            t[i] = nil
        else
            -- Move i's kept value to j's position, if it's not already there.
            if i ~= j then
                t[j] = t[i]
                t[i] = nil
            end
            j = j + 1 -- Increment position of where we'll place the next kept value.
        end
    end

    return t
end

function monitor:new(lang_code, print_func, encoding_module, storage_key)
    local instance = {}
    setmetatable(instance, self)

    instance.print = print_func or print
    instance.encoding = encoding_module or gdi_encoding
    instance._storage_key = storage_key or 'training_data'
    instance._lang_code = lang_code or 'en'
    instance._rules = test_rules[lang_code]
    instance._data = {}

    instance:reset_training_data()

    LogManager:Log(5, 'Trainmon', 'monitor:new ' .. instance._lang_code .. ', ' .. instance._storage_key)

    -- Register for settings changes
    settings.register(instance._storage_key, instance._storage_key .. '_update', function (s)
        if (s ~= nil) then
            instance._data = s
            instance:on_training_data_updated()
        end
    end)
    instance._data = settings.load(train_data_defaults, instance._storage_key)

    return instance
end

function monitor:reset_training_data()
    self._target_monsters = {}
    self._target_monsters_options = {}
    self._target_zone_id = -1
    self._target_monster_kills = {}
    self._monster_kills = {}
    self._waiting_confirm_end = false
    self._target_monsters_repeat = {}
    self._target_zone_id_repeat = -1
end

function monitor:on_training_data_updated()
    self._target_monsters = self._data.target_monsters
    self._target_zone_id = tonumber(self._data.target_zone_id)
    LogManager:Log(5, 'Trainmon', 'on_training_data_updated: _target_zone_id=' .. tostring(self._target_zone_id))
end

function monitor:save_training_data()
    self._data.target_monsters = self._target_monsters
    self._data.target_zone_id = self._target_zone_id
    LogManager:Log(5, 'Trainmon', 'save_training_data: _target_zone_id=' .. tostring(self._target_zone_id))
    settings.save(self._storage_key)
end

function monitor:reconcile_target_kills()
    if #self._target_monster_kills == 0 or #self._monster_kills == 0 then
        return
    end

    local target_kills_count = #self._target_monster_kills
    local kills_count = #self._monster_kills

    local stale = os.clock() - 20 -- seconds
    -- Remove stale entries
    array_remove(self._target_monster_kills, function(t, i) return t[i].time < stale end)
    array_remove(self._monster_kills, function(t, i) return t[i].time < stale end)

    if target_kills_count ~= #self._target_monster_kills or kills_count ~= #self._monster_kills then
        LogManager:Log(5, 'Trainmon', 'removed stale kill entries: ' .. target_kills_count - #self._target_monster_kills .. ', ' .. kills_count - #self._monster_kills)
    end

    local remove_target_entries = {}

    for i, target_kill in ipairs(self._target_monster_kills) do
        local expected_count = target_kill.count - 1

        local remove_kill_entries = {}

        for j = #self._monster_kills, 1, -1 do
            local monster_kill = self._monster_kills[j]
            local target_monster = self._target_monsters[monster_kill.index]

            if target_monster.count == expected_count and target_monster.total == target_kill.total then
                target_monster.count = target_kill.count
                LogManager:Log(5, 'Trainmon', 'reconciled kill: ' .. target_monster.name .. ' = ' .. target_monster.count .. '/' .. target_monster.total)
                self:save_training_data()

                table.insert(remove_target_entries, i)
                table.insert(remove_kill_entries, j)
                break
            end
        end

        -- [omni] no exact match: the count had drifted (a kill missed earlier). Trust the game's progress
        -- line for the monster that was just named as killed.
        if #remove_kill_entries == 0 then
            for j = #self._monster_kills, 1, -1 do
                local monster_kill = self._monster_kills[j]
                local target_monster = self._target_monsters[monster_kill.index]
                if target_monster ~= nil and target_monster.total == target_kill.total then
                    target_monster.count = target_kill.count
                    LogManager:Log(5, 'Trainmon', 'resynced kill: ' .. target_monster.name .. ' = ' .. target_monster.count .. '/' .. target_monster.total)
                    self:save_training_data()
                    table.insert(remove_target_entries, i)
                    table.insert(remove_kill_entries, j)
                    break
                end
            end
        end

        for _, j in ipairs(remove_kill_entries) do
            table.remove(self._monster_kills, j)
        end
    end

    for _, i in ipairs(remove_target_entries) do
        table.remove(self._target_monster_kills, i)
    end
end

-- [omni] A "You defeated a designated target. (Progress: n/N)" with no named kill to pair it with:
-- if only one monster on the list was at n-1 of N, it was that one.
function monitor:reconcile_by_count()
    local left = {}
    for _, target_kill in ipairs(self._target_monster_kills) do
        local hit, hits = nil, 0
        for _, v in ipairs(self._target_monsters) do
            if v.count == target_kill.count - 1 and v.total == target_kill.total then hit = v; hits = hits + 1 end
        end
        if hits == 1 then
            hit.count = target_kill.count
            LogManager:Log(5, 'Trainmon', 'reconciled kill by count: ' .. hit.name .. ' = ' .. hit.count .. '/' .. hit.total)
            self:save_training_data()
        else
            table.insert(left, target_kill)
        end
    end
    self._target_monster_kills = left
end

function monitor:process_input(mode, input)
    if type(mode) == 'table' then
        mode, input = unpack(mode)
    end

    -- Confirming training
    if mode == chat_modes.system and string.find(input, self._rules.confirmed) then
        -- Split by new lines
        local monster_index = 1
        for line in string.gmatch(input, self._rules.line_split) do
            local captures = { string.match(line, self._rules.confirmed) }
            if #captures > 0 then
                local capture_data = self._rules.confirmed_captures(captures)
                local is_family = string.find(capture_data.name, self._rules.monster_family) ~= nil
                LogManager:Log(5, 'Trainmon', string.format('confirmed: %d, %s (%d/%d)', monster_index, capture_data.name, capture_data.count, capture_data.total))

                self._target_monsters_options[tonumber(monster_index)] = {
                    name = capture_data.name,
                    count = capture_data.count,
                    total = capture_data.total,
                    is_family = is_family
                }
                monster_index = monster_index + 1
            end
        end

        self._waiting_confirm_end = true
        return
    end

    -- Confirming zone
    if mode == chat_modes.system and self._waiting_confirm_end and string.find(input, self._rules.confirmed_zone) then
        local zone_name = string.match(input, self._rules.confirmed_zone):trim()
        local zone_id = AshitaCore:GetResourceManager():GetString('zones.names', self.encoding:UTF8_To_ShiftJIS(zone_name, true))
        if zone_id ~= -1 then
            self._target_zone_id = zone_id
            self:save_training_data()
        else
            self.print(chat.header(addon.name):append(chat.error(string.format('Unknown training zone: "%s"', zone_name))))
            local player_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
            local player_zone_name = self.encoding:ShiftJIS_To_UTF8(AshitaCore:GetResourceManager():GetString('zones.names', player_zone_id), true)
            self.print(chat.header(addon.name):append(chat.message(string.format('Player zone: %s (%d)', player_zone_name, player_zone_id))))
        end
        return
    end

    -- Confirming end
    if mode == chat_modes.system and self._waiting_confirm_end and string.find(input, self._rules.confirmed_end) then
        self._waiting_confirm_end = false
        if #self._target_monsters_options > 0 then
            -- Use the last options we parsed
            self._target_monsters = self._target_monsters_options
            self._target_monsters_options = {}
            self:save_training_data()
        end
        return
    end

    -- Viewing training options
    if mode == chat_modes.system and string.find(input, self._rules.options) then
        self:reset_training_data()

        -- Split by new lines
        local monster_index = 1
        for line in string.gmatch(input, self._rules.line_split) do
            local captures = { string.match(line, self._rules.options) }
            if #captures > 0 then
                local capture_data = self._rules.options_captures(captures)
                local is_family = string.find(capture_data.name, self._rules.monster_family, 1, true) ~= nil
                LogManager:Log(5, 'Trainmon', string.format('options: %d, %s (%d)', monster_index, capture_data.name, capture_data.total))

                self._target_monsters_options[tonumber(monster_index)] = {
                    name = capture_data.name,
                    count = 0,
                    total = capture_data.total,
                    is_family = is_family
                }
                monster_index = monster_index + 1
            end
        end
        return
    end

    -- User accepted the last viewed training options
    if (mode == chat_modes.misc_message2 or mode == chat_modes.misc_message) and string.find(input, self._rules.accepted) then
        if #self._target_monsters_options > 0 then
            -- Use the last options we parsed
            self._target_monsters = self._target_monsters_options
            self._target_monsters_options = {}
            self._target_zone_id = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0))
            self:save_training_data()
        end
        return
    end

    -- Training was cancelled
    if (mode == chat_modes.misc_message2 or mode == chat_modes.misc_message) and string.find(input, self._rules.cancelled) then
        self:reset_training_data()
        self:save_training_data()
        return
    end

    -- Active Training
    if #self._target_monsters > 0 then
        -- A target monster was killed which gives us the kill count, but not the name of the monster.
        -- [omni] any chat mode (VanaCore may not use the usual one)
        if string.find(input, self._rules.target_monster_killed) then
            local count, total = string.match(input, self._rules.target_monster_killed)
            table.insert(self._target_monster_kills, ({ count = tonumber(count), total = tonumber(total), time = os.clock() }))

            self:reconcile_target_kills()
            self:reconcile_by_count()
            return
        end

        -- Monster killed but we don't know if it's part of training or not
        do
            local killed_by, monster_name = string.match(input, self._rules.monster_killed_by)
            -- [omni] "The X falls to the ground." names no killer; the progress line right after shows it was ours
            local fell = false
            if monster_name == nil and self._rules.monster_fell ~= nil then
                monster_name = string.match(input, self._rules.monster_fell)
                fell = monster_name ~= nil
                killed_by = 'someone'
            end
            -- Make sure who killed the monster is in the party (includes the player)
            -- [omni] any killer: the game's "Progress" line (only sent for your kills) confirms it, and kills
            -- with no progress line after them go stale in 20 s
            if monster_name ~= nil then
                LogManager:Log(5, 'Trainmon', 'Monster killed: ' .. monster_name .. ', by ' .. killed_by)

                -- Find the target monster in our list
                local monster_index = 0

                -- Name match
                for i, v in ipairs(self._target_monsters) do
                    if v.name == monster_name then
                        monster_index = i
                        break
                    end
                end

                -- If we didn't find the monster name, it might be for a family of monsters
                -- Get the family name from the monster db
                if monster_index == 0 then
                    local family_name = monster_db:get_family_name(monster_name, self._lang_code)
                    if family_name ~= nil then
                        for i, v in ipairs(self._target_monsters) do
                            if v.name == family_name then
                                monster_index = i
                                break
                            end
                        end
                    end
                end

                -- Try by getting monster type from monster db
                if monster_index == 0 then
                    local monster_type = monster_db:get_type(monster_name, self._lang_code)
                    if monster_type ~= nil then
                        for i, v in ipairs(self._target_monsters) do
                            if v.name == monster_type then
                                monster_index = i
                                break
                            end
                        end
                    end
                end

                if monster_index > 0 then
                    table.insert(self._monster_kills, ({ name = monster_name, index = monster_index, time = os.clock() }))
                    self:reconcile_target_kills()
                end
            end
        end

        -- A training was just completed
        if mode == chat_modes.battle and string.find(input, self._rules.completed) then
            -- Reset the counts
            for i,v in ipairs(self._target_monsters) do
                v.count = 0
            end

            -- Make a copy of the target_monsters incase we repeat the training
            local target_monsters_repeat = self._target_monsters
            local target_zone_id_repeat = self._target_zone_id
            self:reset_training_data()
            self:save_training_data()
            self._target_monsters_repeat = target_monsters_repeat
            self._target_zone_id_repeat = target_zone_id_repeat
            return
        end
    end

    -- Training was repeated
    if mode == chat_modes.battle and #self._target_monsters_repeat > 0 and string.find(input, self._rules.repeated) then
        self._target_monsters = self._target_monsters_repeat
        self._target_monsters_repeat = {}
        self._target_zone_id = self._target_zone_id_repeat
        self._target_zone_id_repeat = -1
        self:save_training_data()
        return
    end
end

return monitor