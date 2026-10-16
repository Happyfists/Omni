-- Action packet (0x028) parser and damage classification.
-- Plain Lua 5.1 arithmetic so it runs anywhere.
--
-- Parsed shape (the Windower adapter converts its native action table to this):
--   { actor_id, category, param, targets = { { id, actions = {
--       { message, param, add = { message, param } } } } } }

local action = {}

-- Read `len` bits starting at bit `off`, least significant bit first.
local function bits(data, off, len)
    local value, mul = 0, 1
    for i = 0, len - 1 do
        local p = off + i
        local byte = data:byte(math.floor(p / 8) + 1) or 0
        if math.floor(byte / 2 ^ (p % 8)) % 2 == 1 then
            value = value + mul
        end
        mul = mul * 2
    end
    return value
end

function action.parse(data)
    local size = #data * 8
    local pos = 40 -- 4 byte header + 1 byte length

    local function take(n)
        if pos + n > size then
            pos = size
            return 0
        end
        local v = bits(data, pos, n)
        pos = pos + n
        return v
    end

    local act = { targets = {} }
    act.actor_id = take(32)
    local target_count = take(6)
    take(4)
    act.category = take(4)
    act.param = take(16)
    take(16)
    act.recast = take(32)

    for _ = 1, target_count do
        local target = { actions = {} }
        target.id = take(32)
        local action_count = take(4)
        for _ = 1, action_count do
            local a = {}
            a.reaction = take(5)
            a.animation = take(12)
            a.effect = take(7)
            a.knockback = take(3)
            a.param = take(17)
            a.message = take(10)
            take(31)
            if take(1) == 1 then
                local add = {}
                add.animation = take(10)
                add.param = take(17)
                add.message = take(10)
                a.add = add
            end
            if take(1) == 1 then
                local spike = {}
                spike.animation = take(10)
                spike.param = take(14)
                spike.message = take(10)
                a.spike = spike
            end
            target.actions[#target.actions + 1] = a
        end
        act.targets[#act.targets + 1] = target
    end
    return act
end

local function set(list)
    local out = {}
    for _, v in ipairs(list) do
        out[v] = true
    end
    return out
end

-- Action message ids, grouped by what they mean for a damage meter.
local MELEE = set { 1, 67 }                    -- hit, critical hit
local RANGED = set { 352, 353, 576, 577, 157 } -- ranged hit/crit, squarely, true strike, Barrage
local WEAPONSKILL = set { 185, 197 }           -- weapon skill damage (incl. resisted)
local MAGIC = set { 2, 252, 264 }              -- spell damage, magic burst, extra AoE targets
local ABILITY = set { 110, 317, 77 }           -- job ability damage, Sange
local MISS = set { 15, 354, 188 }              -- melee miss, ranged miss, weapon skill miss
local ADD_EFFECT = set { 163, 229 }            -- additional effect damage (enspells etc.)
local SKILLCHAIN = set {
    288, 289, 290, 291, 292, 293, 294, 295, 296, 297, 298, 299, 300, 301, 302,
    385, 386, 387, 388, 389, 390, 391, 392, 393, 394, 395, 396, 397, 398,
    732, 767, 768, 769, 770,
}

-- Returns 'melee' | 'ranged' | 'ws' | 'magic' | 'ability' | 'miss' | nil
function action.classify(message)
    if MELEE[message] then return 'melee' end
    if RANGED[message] then return 'ranged' end
    if WEAPONSKILL[message] then return 'ws' end
    if MAGIC[message] then return 'magic' end
    if ABILITY[message] then return 'ability' end
    if MISS[message] then return 'miss' end
    return nil
end

-- Returns 'skillchain' | 'add' | nil
function action.classify_add(message)
    if SKILLCHAIN[message] then return 'skillchain' end
    if ADD_EFFECT[message] then return 'add' end
    return nil
end

return action
