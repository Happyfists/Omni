--[[
    omni_currency.lua - the balances from the game's own Status > Currencies menu.

    The game sends these in one packet (0x113) when asked. omni asks for it
    while the Points tab is showing, reads the numbers out, and hands the
    non-zero ones to the Points tab as extra rows.

    Field positions follow the packet layout documented by the Windower
    project (fields.lua, "Currency Info").
]]

require('common');

local currency = {};

-- { group, label, offset in the packet, size: 4 = 32-bit, 2 = 16-bit, 1 = 8-bit }
local FIELDS = {
    { 'Conquest',             "Conquest Points (San d'Oria)", 0x04, 4 },
    { 'Conquest',             'Conquest Points (Bastok)',     0x08, 4 },
    { 'Conquest',             'Conquest Points (Windurst)',   0x0C, 4 },

    { 'Seals & Crests',       "Beastmen's Seals",             0x10, 2 },
    { 'Seals & Crests',       "Kindred's Seals",              0x12, 2 },
    { 'Seals & Crests',       "Kindred's Crests",             0x14, 2 },
    { 'Seals & Crests',       "High Kindred's Crests",        0x16, 2 },
    { 'Seals & Crests',       "Sacred Kindred's Crests",      0x18, 2 },

    { 'Battle',               'Ancient Beastcoins',           0x1A, 2 },
    { 'Battle',               'Valor Points',                 0x1C, 2 },
    { 'Battle',               'Scylds',                       0x1E, 2 },
    { 'Battle',               'Ballista Points',              0x50, 4 },
    { 'Battle',               'Legion Points',                0x70, 4 },

    { 'Guild Points',         'Fishing',                      0x20, 4 },
    { 'Guild Points',         'Woodworking',                  0x24, 4 },
    { 'Guild Points',         'Smithing',                     0x28, 4 },
    { 'Guild Points',         'Goldsmithing',                 0x2C, 4 },
    { 'Guild Points',         'Weaving',                      0x30, 4 },
    { 'Guild Points',         'Leathercraft',                 0x34, 4 },
    { 'Guild Points',         'Bonecraft',                    0x38, 4 },
    { 'Guild Points',         'Alchemy',                      0x3C, 4 },
    { 'Guild Points',         'Cooking',                      0x40, 4 },

    { 'Aht Urhgan',           'Imperial Standing',            0x7C, 4 },
    { 'Aht Urhgan',           'Assault Pts (Leujaoam)',       0x80, 4 },
    { 'Aht Urhgan',           'Assault Pts (Mamool Ja)',      0x84, 4 },
    { 'Aht Urhgan',           'Assault Pts (Lebros)',         0x88, 4 },
    { 'Aht Urhgan',           'Assault Pts (Periqia)',        0x8C, 4 },
    { 'Aht Urhgan',           'Assault Pts (Ilrusi)',         0x90, 4 },
    { 'Aht Urhgan',           'Nyzul Isle Tokens',            0x94, 4 },
    { 'Aht Urhgan',           'Zeni',                         0x98, 4 },
    { 'Aht Urhgan',           'Jettons',                      0x9C, 4 },
    { 'Aht Urhgan',           'Therion Ichor',                0xA0, 4 },

    { 'Other',                'Allied Notes',                 0xA4, 4 },
    { 'Other',                'Cinders',                      0x44, 4 },
    { 'Other',                'Fellow Points',                0x54, 4 },
    { 'Other',                "Chocobucks (San d'Oria)",      0x58, 2 },
    { 'Other',                'Chocobucks (Bastok)',          0x5A, 2 },
    { 'Other',                'Chocobucks (Windurst)',        0x5C, 2 },
    { 'Other',                'Research Marks',               0x60, 4 },
    { 'Other',                'Moblin Marbles',               0x68, 4 },
    { 'Other',                'Infamy',                       0x6C, 2 },
    { 'Other',                'Prestige',                     0x6E, 2 },
    { 'Other',                'Shining Stars',                0x78, 4 },
    { 'Other',                'Login Points',                 0xAA, 2 },
    { 'Other',                'Cruor',                        0xAC, 4 },
    { 'Other',                'Resistance Credits',           0xB0, 4 },
    { 'Other',                'Dominion Notes',               0xB4, 4 },
    { 'Other',                'Traverser Stones',             0xC0, 4 },
    { 'Other',                'Voidstones',                   0xC4, 4 },
    { 'Other',                "Kupofried's Corundums",        0xC8, 4 },
};

local values = {};          -- index in FIELDS -> number
local received = false;
local asked_at = -1000;
local ASK_EVERY = 30;       -- seconds between requests while the tab is showing

local function read(data, offset, size)
    local value = 0;
    for i = size - 1, 0, -1 do
        value = value * 256 + (data:byte(offset + 1 + i) or 0);
    end
    -- 32-bit balances are signed in the packet; none should be negative, so clamp.
    if (size == 4 and value >= 0x80000000) then
        value = 0;
    end
    return value;
end

-- data is the raw 0x113 packet.
currency.on_packet = function (data)
    for i, field in ipairs(FIELDS) do
        values[i] = read(data, field[3], field[4]);
    end
    received = true;
end

-- Ask the game for fresh numbers (the same request it makes when you open the menu).
currency.request = function (force)
    local now = os.clock();
    if (not force and now - asked_at < ASK_EVERY) then
        return;
    end
    asked_at = now;
    pcall(function ()
        AshitaCore:GetPacketManager():AddOutgoingPacket(0x10F, { 0x00, 0x00, 0x00, 0x00 });
    end);
end

-- Rows for the Points tab: only the currencies you actually have some of.
currency.rows = function ()
    local out = {};
    if (not received) then
        return out;
    end
    for i, field in ipairs(FIELDS) do
        local value = values[i] or 0;
        if (value > 0) then
            out[#out + 1] = { group = field[1], label = field[2], value = value };
        end
    end
    return out;
end

-- One balance by its label (0 until the numbers have arrived).
currency.get = function (label)
    for i, field in ipairs(FIELDS) do
        if (field[2] == label) then
            return values[i] or 0;
        end
    end
    return 0;
end

return currency;
