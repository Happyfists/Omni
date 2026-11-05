--[[
    omni_pyxis.lua - Happy Chests: Abyssea Sturdy Pyxis opener.

    Pick which chest colours to open (Blue / Gold / Red), then each /py opens ONE enabled chest
    within 5.9 yalms by trading it a Forbidden Key from your main inventory.
    The "Open all" button under each chest opens every chest of that colour in range, one after
    another (half a second apart), and stops when there are none left, you run out of keys or you leave.
        /py                  open the nearest enabled chest
        /py all blue|gold|red   open every chest of that colour in range (/py stop to stop)
        /py skip ruby        leave Red chests with that light shut (ruby, amber, azure, pearl, golden,
                             silvery, ebon); omni looks inside each Red chest before using a key
        /py destroy on|off   destroy skipped Red chests (on) or just leave them shut (off)
        /py auto on|off      Auto: deal with every chest next to you by itself - open the colours
                             switched on, destroy the ones switched off (and skipped Red lights)
        /py peek             look inside the nearest chest and say what's in it
        /py blue|gold|red    turn that colour on/off (add on or off to set it)
        /py hud              show / hide the chest window (it only shows inside Abyssea)
        /py status           counts in chat
        /py reset            forget which chests were already tried (they're skipped for 2 minutes)

    Also on the Abyssea > Chests tab. Your colour choices are saved in config\addons\omni\pyxis.txt.

    Based on Pyxis 0.6.1 by Integrity (github.com/deadplaything/Pyxis), rewritten for omni. The trade is
    sent as the game's own NPC trade packet (0x036), the same way Pyxis does it. Pyxis' chest pictures
    aren't included here (no licence was given for them): put pyxis_blue/gold/red.png in omni\images\
    to have pictures, otherwise each chest is a coloured button.
]]

local imgui = require('imgui');
local ffi   = require('ffi');
local d3d   = require('d3d8');

local py = {};

local RANGE = 5.9;
local RANGE_SQ = RANGE * RANGE;
local ATTEMPT_TTL = 120;
local MODEL = { [965] = 'blue', [968] = 'red', [969] = 'gold' };
local ORDER = { 'blue', 'gold', 'red' };
local LABEL = { blue = 'Blue', gold = 'Gold', red = 'Red' };
local TIP = {
    blue = 'Blue chests: Cruor, experience, or restore HP/MP/TP.',
    gold = 'Gold chests: Atma, key items, Abyssite, lights.',
    red  = 'Red chests: temporary items (and lights).',
};
local COL = {
    blue = { 0.45, 0.70, 1.00, 1.0 },
    gold = { 1.00, 0.84, 0.35, 1.0 },
    red  = { 1.00, 0.45, 0.45, 1.0 },
};

local set = { blue = true, gold = true, red = true, show = true,
    skip_ruby = true, skip_amber = false, skip_azure = false, skip_pearl = false, skip_golden = false, skip_silvery = false, skip_ebon = false, destroy = true, auto = true, spoils = true,
    temps_take = true, temps_give = false, ki_party = true, small = false, list = true, aug_auto = true };   -- small: pop-out minimised   -- destroy temp-item chests: the pick-from-the-chest kind / the given-to-everyone kind
local SAVE_KEYS = { 'blue', 'gold', 'red', 'show', 'skip_ruby', 'skip_amber', 'skip_azure', 'skip_pearl', 'skip_golden', 'skip_silvery', 'skip_ebon', 'destroy', 'auto', 'spoils', 'temps_take', 'temps_give', 'ki_party', 'small', 'list', 'aug_auto' };
-- Temp-item chests: 0x100 = temps you take out of the chest, 0x12 = temps given to everyone on opening.
local function destroy_temp(code) return (code == 0x100 and set.temps_take) or (code == 0x12 and set.temps_give) or false; end
local function any_temps() return set.temps_take or set.temps_give; end
local st = { nearby = {}, counts = { blue = 0, gold = 0, red = 0, unknown = 0 }, last = 0, keys = nil, keys_at = 0 };
local attempted = {};
local contents = {};     -- [chest key] = content name, or false if we couldn't see inside
local codes = {};        -- [chest key] = the content code (see CONTENT)
local chat_contents = {}; -- [chest key] = contents with chat colours (key item name in red), if any
local win_open = { true };

local function say(t) print('\30\68[Happy Chests]\30\01 ' .. t); end

----------------------------------------------------------------------------------------------------
-- Saved choices
----------------------------------------------------------------------------------------------------
local function file() return ('%s\\config\\addons\\omni\\pyxis.txt'):format(AshitaCore:GetInstallPath()); end
local function save()
    pcall(function ()
        local f = io.open(file(), 'w');
        if not f then return; end
        for _, k in ipairs(SAVE_KEYS) do f:write(k, ' ', set[k] and '1' or '0', '\n'); end
        f:close();
    end);
end
local function load()
    pcall(function ()
        local f = io.open(file(), 'r');
        if not f then return; end
        for raw in f:lines() do
            local k, v = raw:gsub('\r', ''):match('^([%a_]+)%s+(%d)');
            if k and set[k] ~= nil then set[k] = (v == '1'); end
        end
        f:close();
    end);
end
load();

----------------------------------------------------------------------------------------------------
-- Chest pictures (omni\images\pyxis_<colour>.png)
----------------------------------------------------------------------------------------------------
pcall(ffi.cdef, [[
    HRESULT __stdcall D3DXCreateTextureFromFileA(IDirect3DDevice8* pDevice, const char* pSrcFile, IDirect3DTexture8** ppTexture);
]]);
local tex, tex_failed = {}, {};
local function texture(colour)
    if tex[colour] or tex_failed[colour] then return tex[colour]; end
    local ok, t = pcall(function ()
        local out = ffi.new('IDirect3DTexture8*[1]');
        local path = ('%s\\images\\pyxis_%s.png'):format(addon.path, colour);
        if ffi.C.D3DXCreateTextureFromFileA(d3d.get_device(), path, out) ~= ffi.C.S_OK then return nil; end
        return d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', out[0]));
    end);
    if ok and t then tex[colour] = t; else tex_failed[colour] = true; end
    return tex[colour];
end

----------------------------------------------------------------------------------------------------
-- Finding chests and keys
----------------------------------------------------------------------------------------------------
local function in_abyssea()
    local aby = package.loaded['omni_abyssea'];
    if aby and aby.inside then
        local ok, r = pcall(aby.inside);
        if ok then return r; end
    end
    return true;
end

local function pos(e)
    local m = e and e.Movement;
    local p = m and m.LocalPosition;
    if not p then return nil; end
    return tonumber(p.X), tonumber(p.Z);
end
local function dist_sq(a, b)
    local ax, az = pos(a);
    local bx, bz = pos(b);
    if not ax or not az or not bx or not bz then return math.huge; end
    return (ax - bx) ^ 2 + (az - bz) ^ 2;
end
local function model_of(e)
    local ok, r = pcall(function () return e.Look.Hair; end);
    return ok and tonumber(r) or nil;
end

-- Chests that belong to another party ("Your party does not have claim over that treasure chest"):
-- left alone and not counted. [server id] = os.clock() when found. Chest slots get reused for new
-- chests, so this is forgotten when that chest disappears or after 5 minutes (a chest lasts 3).
local not_ours = {};
local function is_not_ours(id)
    local t = not_ours[id or -1];
    if t and os.clock() - t > 300 then not_ours[id] = nil; return false; end
    return t ~= nil;
end
local last_target = nil;   -- the chest we last talked to / traded with, and when
-- [3.70] You clicked a chest yourself: hands off it (and every chest) for a while, so omni never hides
-- the menu you opened - that left your character frozen waiting for it.
local you = { id = nil, at = -100 };
local HANDS_OFF = 15;      -- seconds omni leaves the chests alone after you click one
local last_menu = nil;     -- the last chest menu omni hid: { chest, zone, menu, at } (for Unstick)
local function hands_off() return os.clock() - you.at < HANDS_OFF; end

-- A chest that's still in the game's memory after it went away isn't drawn any more.
local function visible(i)
    local v = true;
    pcall(function ()
        local em = AshitaCore:GetMemoryManager():GetEntity();
        if bit.band(em:GetRenderFlags0(i), 0x200) ~= 0x200 then v = false; end
    end);
    return v;
end

local function scan()
    local player = GetPlayerEntity();
    local nearby, counts = {}, { blue = 0, gold = 0, red = 0, unknown = 0 };
    if player then
        for i = 0, 2303 do
            local e = GetEntity(i);
            local pyx = e and type(e.Name) == 'string' and e.Name == 'Sturdy Pyxis';
            if pyx and not visible(i) then
                -- gone: forget it, so a new chest in this slot starts fresh
                local id = tonumber(e.ServerId) or -1;
                not_ours[id] = nil;
                local k = tostring(i) .. ':' .. tostring(id);
                contents[k], codes[k], attempted[k] = nil, nil, nil;
            end
            if pyx and visible(i) and not is_not_ours(tonumber(e.ServerId)) then
                local d = dist_sq(player, e);
                if d <= RANGE_SQ then
                    local model = model_of(e);
                    local colour = MODEL[model] or 'unknown';
                    counts[colour] = counts[colour] + 1;
                    nearby[#nearby + 1] = { index = i, server_id = tonumber(e.ServerId), model = model, colour = colour, distance = math.sqrt(d) };
                end
            end
        end
    end
    table.sort(nearby, function (a, b) return a.distance < b.distance; end);
    st.nearby, st.counts = nearby, counts;
end

local function key_id()
    local res = AshitaCore:GetResourceManager();
    local r = res and (res:GetItemByName('Forbidden Key', 2) or res:GetItemByName('Forbidden key', 2));
    return r and tonumber(r.Id or r.ItemId) or nil;
end

local function find_key()
    local inv = AshitaCore:GetMemoryManager():GetInventory();
    local id = key_id();
    if not inv or not id then return nil, 'can\'t find the Forbidden Key item.'; end
    local max = math.min(tonumber(inv:GetContainerCountMax(0)) or 80, 80);
    for slot = 1, max do
        local it = inv:GetContainerItem(0, slot);
        if it and tonumber(it.Id) == id and (tonumber(it.Count) or 0) > 0 then return slot; end
    end
    return nil, 'no Forbidden Key in your main inventory.';
end

local function count_keys()
    local ok, n = pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local id = key_id();
        if not inv or not id then return nil; end
        local c = 0;
        local max = math.min(tonumber(inv:GetContainerCountMax(0)) or 80, 80);
        for slot = 1, max do
            local it = inv:GetContainerItem(0, slot);
            if it and tonumber(it.Id) == id then c = c + (tonumber(it.Count) or 0); end
        end
        return c;
    end);
    return ok and n or nil;
end

local function keys()
    if os.time() ~= st.keys_at then st.keys_at = os.time(); st.keys = count_keys(); end
    return st.keys;
end

local function ready()
    local n = 0;
    for _, c in ipairs(ORDER) do if set[c] then n = n + st.counts[c]; end end
    return n;
end

----------------------------------------------------------------------------------------------------
-- What's inside: talking to a locked chest makes the server send its menu (0x034), and the first
-- menu number says what is in it. We "look" (0x01A talk), read that, hide the menu from the game
-- and close it straight away (0x05B, option 0 = cancel), so you never see it.
----------------------------------------------------------------------------------------------------
local CONTENT = {
    [0x01] = 'Feeble soothing light', [0x05] = 'Faint soothing light', [0x09] = 'Mild soothing light',
    [0x0D] = 'Strong soothing light', [0x11] = 'Intense soothing light',
    [0x02] = 'Miniscule cruor', [0x06] = 'Small cruor', [0x0A] = 'Moderate cruor', [0x0E] = 'Considerable cruor', [0x13] = 'Princely cruor',
    [0x03] = 'Tiny exp', [0x07] = 'Little exp', [0x0B] = 'Some exp', [0x0F] = 'Considerable exp', [0x14] = 'Tremendous exp',
    [0x12] = 'Numerous temp items (given to everyone when opened)', [0x15] = 'Time extension',
    [0x16] = 'Faint Pearl light', [0x17] = 'Faint Azure light', [0x18] = 'Faint Ruby light', [0x19] = 'Faint Amber light',
    [0x1A] = 'Mild Pearl light', [0x1B] = 'Mild Azure light', [0x1C] = 'Mild Ruby light', [0x1D] = 'Mild Amber light',
    [0x1E] = 'Strong Pearl light', [0x1F] = 'Strong Azure light', [0x20] = 'Strong Ruby light', [0x21] = 'Strong Amber light',
    [0x22] = 'Faint Golden light', [0x23] = 'Faint Silvery light', [0x24] = 'Faint Ebon light',
    [0x25] = 'Intense Azure light', [0x26] = 'Intense Ruby light', [0x27] = 'Intense Amber light',
    [0x28] = 'Mild Golden light', [0x29] = 'Mild Silvery light', [0x2A] = 'Mild Ebon light',
    [0x2B] = 'Strong Golden light', [0x2C] = 'Strong Silvery light', [0x2D] = 'Strong Ebon light',
    [0x100] = 'Temp items to take from the chest', [0x200] = 'Items', [0x300] = 'Powerful items', [0x400] = 'Key items',
};
local LIGHTS = { 'Ruby', 'Amber', 'Azure', 'Pearl', 'Golden', 'Silvery', 'Ebon' };
local LIGHT_COL = {
    Ruby = { 1.0, 0.40, 0.40, 1 }, Amber = { 1.0, 0.72, 0.30, 1 }, Azure = { 0.45, 0.70, 1.0, 1 },
    Pearl = { 0.95, 0.95, 0.90, 1 }, Golden = { 1.0, 0.84, 0.35, 1 }, Silvery = { 0.80, 0.82, 0.88, 1 }, Ebon = { 0.65, 0.55, 0.80, 1 },
};

-- contents / codes are declared at the top (the scan clears them when a chest goes away).
local claim = nil;       -- { chest, key, kind, at } - an opened chest whose items we take next
local TEMP_CODES = { [0x12] = true, [0x100] = true };   -- temporary items only
local SPOIL_CODES = { [0x200] = 'items', [0x400] = 'ki', [0x300] = 'aug' }; -- opened chest: add items to the pool / take the key item / list the augmented items

-- [3.75] Augmented ("Powerful items") gold chests: once open, a look lists up to 2 items with their
-- augments (0x05C: item1, flag, aug, aug, item2, flag, aug, aug). They show in the pop-out with a
-- Take button each (menu answer slot << 16 | 65). Augment names: pyxis_augs.lua (Windower extdata).
local okaug, AUG = pcall(require, 'pyxis_augs');
if not okaug or type(AUG) ~= 'table' then AUG = {}; end
local aug_chests = {};    -- [chest key] = { chest, items = { { slot, id, name, augs = { text, ... } } } }
local function aug_text(w)
    if not w or w == 0 then return nil; end
    local id, val = w % 2048, math.floor(w / 2048);
    local parts = AUG[id];
    if not parts then return ('augment %d (%d)'):format(id, val + 1); end
    local out = {};
    for _, p in ipairs(parts) do
        local n = (val + (p[2] or 0)) * (p[3] or 1);
        local stat = tostring(p[1] or ''):gsub('%s+$', '');
        out[#out + 1] = ('%s%s%d%s'):format(stat, n >= 0 and '+' or '', n, p[4] and '%' or '');
    end
    return table.concat(out, ' ');
end
-- The best each augment can roll on each item (pyxis_augmax.lua, from the server's own table).
local okmax, AUGMAX = pcall(require, 'pyxis_augmax');
if not okmax or type(AUGMAX) ~= 'table' then AUGMAX = {}; end
-- For one rolled augment word on an item: its text, the best it can be, and whether it is the best.
-- [3.84] Augments you want (Abyssea > Augments): [item id .. ':' .. aug id] = lowest roll you'll take.
-- Saved in config\addons\omni\pyxis_augwant.txt as "item aug roll" lines.
local WANT = {};
local function want_file() return ('%s\\config\\addons\\omni\\pyxis_augwant.txt'):format(AshitaCore:GetInstallPath()); end
local function want_load()
    pcall(function ()
        local f = io.open(want_file(), 'r');
        if not f then return; end
        for raw in f:lines() do
            local i, a, r = raw:match('^(%d+)%s+(%d+)%s+(%d+)');
            if i then WANT[i .. ':' .. a] = tonumber(r); end
        end
        f:close();
    end);
end
local function want_save()
    pcall(function ()
        local f = io.open(want_file(), 'w');
        if not f then return; end
        for k, r in pairs(WANT) do
            local i, a = k:match('^(%d+):(%d+)$');
            if i then f:write(i, ' ', a, ' ', tostring(r), '\n'); end
        end
        f:close();
    end);
end
want_load();
local pending_take = nil;   -- { key, slot, item, text, top } - a wanted augment to take as soon as we can
local banner = nil;         -- { text, sub, till } - the big MAX AUG COLLECTED message on screen

local function aug_max(item_id, w)
    local id, val = w % 2048, math.floor(w / 2048);
    local e = AUGMAX[item_id];
    if not e then return nil, false; end
    local best = nil;
    for _, r in ipairs(e[2] or {}) do
        if r[1] == id and (best == nil or r[3] > best) then best = r[3]; end
    end
    if best == nil then return nil, false; end
    return aug_text(id + (best - 1) * 2048), (val + 1) >= best;
end
local peek = nil;        -- { chest, key, until } while waiting for the chest's menu
local run = nil;         -- the current open run (see below)

local function ckey(c) return tostring(c.index) .. ':' .. tostring(c.server_id); end

local function u32(s, o) local a, b, c, d = s:byte(o + 1, o + 4); return a + b * 256 + c * 65536 + d * 16777216; end
local function u16(s, o) local a, b = s:byte(o + 1, o + 2); return a + b * 256; end

local function light_of(name) return name and name:match('(%a+) light$') or nil; end
local function is_skipped(name)
    local l = light_of(name);
    return l ~= nil and set['skip_' .. l:lower()] == true;
end
local function any_skip()
    for _, l in ipairs(LIGHTS) do if set['skip_' .. l:lower()] then return true; end end
    return false;
end

-- What was in the last few chests (shown in the pop-out), and a debug log file for checking
-- the server's answers (config\addons\omni\pyxis_debug.txt).
st.log = {};
-- Chat colours (Ashita colour table 1), matching the chest and light colours on omni's bars.
local CHAT_COL = { blue = 71, gold = 69, red = 76 };              -- royal blue, yellow, tomato
local LIGHT_CHAT = { Ruby = 76, Amber = 8, Azure = 71, Pearl = 1, Golden = 69, Silvery = 67, Ebon = 89 };
local function chest_word(colour)
    local n = CHAT_COL[colour];
    local w = (LABEL[colour] or 'A') .. ' chest';
    return n and ('\30' .. string.char(n) .. w .. '\30\01') or w;
end
local function tint_lights(text)
    return (text:gsub('(%a+) light', function (l)
        local n = LIGHT_CHAT[l];
        return n and ('\30' .. string.char(n) .. l .. ' light\30\01') or (l .. ' light');
    end));
end

-- text: plain (for the pop-out); chat_text: the same with chat colours, if different.
-- What happens to each chest goes in the pop-out only (not the chat log). colour nil = a plain line.
local function note(colour, text, chat_text, red)
    table.insert(st.log, 1, { col = colour, text = text, t = os.time(), red = red });
    while #st.log > 10 do table.remove(st.log); end
end
local function info(text) note(nil, text); end
local RED = '\30\76';
local function hex(s, n)
    local t = {};
    for i = 1, math.min(#s, n or 64) do t[#t + 1] = ('%02X'):format(s:byte(i)); end
    return table.concat(t, ' ');
end
local function dbg(line)
    pcall(function ()
        local f = io.open(('%s\\config\\addons\\omni\\pyxis_debug.txt'):format(AshitaCore:GetInstallPath()), 'a');
        if f then f:write(os.date('%H:%M:%S '), line, '\n'); f:close(); end
    end);
end

-- Fighting (or dead / resting / crafting...): the game won't let you talk to or trade with a chest,
-- and trying knocks you out of combat. Anything but standing idle counts as busy.
local function busy()
    local b = false;
    pcall(function ()
        local me = GetPlayerEntity();
        if me ~= nil and (me.Status or 0) ~= 0 then b = true; end
    end);
    return b;
end
py.busy = busy;

local function send_peek(chest)
    last_target = { id = chest.server_id, at = os.clock() };
    local p = ffi.new('uint8_t[28]');
    ffi.cast('uint32_t*', p + 0x04)[0] = chest.server_id;
    ffi.cast('uint16_t*', p + 0x08)[0] = chest.index;
    ffi.cast('uint16_t*', p + 0x0A)[0] = 0;     -- 0 = talk / examine
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x01A, ffi.string(p, 28):totable());
    local status = -1;
    pcall(function () status = GetPlayerEntity().Status; end);
    dbg(('look  %s chest id %d index %d (your status %s) -> 0x01A %s'):format(chest.colour, chest.server_id, chest.index, tostring(status), hex(ffi.string(p, 28), 28)));
end

-- "Your party does not have claim over that treasure chest." - remember that chest isn't ours.
ashita.events.register('text_in', 'omni_pyxis_claim', function (e)
    if e.injected or last_target == nil or os.clock() - last_target.at > 4 then return; end
    local m = (e.message or ''):lower();
    if m:find('does not have claim over that treasure chest', 1, true) then
        not_ours[last_target.id] = os.clock();
        dbg(('chest id %d is another party\'s - leaving it alone'):format(last_target.id));
        if peek and peek.chest and peek.chest.server_id == last_target.id then peek.till = os.clock(); end
    end
end);

-- While looking, log every event packet the server sends (so a different reply can be found).
ashita.events.register('packet_in', 'omni_pyxis_dbg', function (e)
    if peek == nil then return; end
    -- 0x052 = the server let go of you without opening a menu: the look was refused.
    if e.id == 0x052 and not peek.got_menu then
        peek.till = math.min(peek.till, os.clock() + 0.3);
        if not peek.claim and not peek.got_menu then not_ours[peek.chest.server_id] = os.clock(); end   -- not ours, or already gone
        if peek.got_menu then return; end
    end
    if e.id == 0x032 or e.id == 0x034 or e.id == 0x033 or e.id == 0x052 or e.id == 0x053 or e.id == 0x036 or e.id == 0x05C then
        pcall(function () dbg(('in    0x%03X len %d: %s'):format(e.id, #e.data, hex(e.data, 56))); end);
    end
end);

-- The chest's menu arrives: remember what's inside, keep it off the screen and close it.
-- Answer the chest's menu: mode 0 = finish with this option (0 cancel, 999 destroy, ...),
-- mode 1 = "update" - asks the server for the menu's item list (it answers with 0x05C).
local function send_end(chest, zone, menu, option, mode)
    local p = ffi.new('uint8_t[20]');
    ffi.cast('uint32_t*', p + 0x04)[0] = chest.server_id;
    ffi.cast('uint32_t*', p + 0x08)[0] = option;
    ffi.cast('uint16_t*', p + 0x0C)[0] = chest.index;
    ffi.cast('uint16_t*', p + 0x0E)[0] = mode or 0;
    ffi.cast('uint16_t*', p + 0x10)[0] = zone;
    ffi.cast('uint16_t*', p + 0x12)[0] = menu;
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x05B, ffi.string(p, 20):totable());
end

local function item_name(id)
    local n = nil;
    pcall(function ()
        local it = AshitaCore:GetResourceManager():GetItemById(id);
        if it and it.Name and it.Name[1] and it.Name[1] ~= '' then n = it.Name[1]; end
    end);
    return n or ('item ' .. tostring(id));
end

-- Chests whose menu can list what's in them (temporary items, items).
local LISTS = { [0x100] = true, [0x200] = true, [0x400] = true };

local function ki_name(id)
    local n = nil;
    pcall(function ()
        local r = AshitaCore:GetResourceManager():GetString('keyitems.names', id);
        if r and r ~= '' then n = r; end
    end);
    return n or ('key item ' .. tostring(id));
end

-- Finish a look: say what was inside (with the item names if we got them) and close / destroy.
local function finish_peek(names)
    local f = peek.fin;
    local inside = f.inside;
    local chat = nil;
    if names and #names > 0 then
        local list = table.concat(names, ', ');
        if f.ki then
            -- a key item: its name in red
            chat = tint_lights(f.inside) .. ' (' .. RED .. list .. '\30\01)';
            peek.ki_name = list;
        end
        inside = inside .. ' (' .. list .. ')';
    end
    contents[peek.key] = inside;
    chat_contents[peek.key] = chat;
    if f.suffix then note(peek.chest.colour, inside .. f.suffix, chat and (chat .. f.suffix), f.ki); end
    send_end(peek.chest, f.zone, f.menu, f.option, 0);
    peek = nil;
end
py.finish_peek = function () if peek and peek.fin then finish_peek(nil); end end;

ashita.events.register('packet_in', 'omni_pyxis_peek', function (e)
    if peek == nil then return; end
    -- The item list we asked for.
    if e.id == 0x05C and peek.fin and peek.fin.aug then
        pcall(function ()
            local d = e.data;
            local items = {};
            for slot = 1, 2 do
                local base = 0x04 + (slot - 1) * 16;
                local id = u32(d, base);
                if id > 0 and id < 65535 then
                    local augs, maxes, words = {}, {}, {};
                    for _, o in ipairs({ 8, 12 }) do
                        local w = u32(d, base + o);
                        local t = aug_text(w);
                        if t then
                            augs[#augs + 1] = t;
                            words[#words + 1] = w;
                            local mt, top = aug_max(id, w);
                            maxes[#maxes + 1] = { max = mt, top = top };
                        end
                    end
                    items[#items + 1] = { slot = slot, id = id, name = item_name(id), augs = augs, maxes = maxes, words = words };
                end
            end
            local f = peek.fin;
            if #items > 0 then
                aug_chests[peek.key] = { chest = peek.chest, items = items };
                -- a wanted augment? (rolled at least what you picked on Abyssea > Augments)
                if set.aug_auto and pending_take == nil then
                    for _, it in ipairs(items) do
                        for ai, w in ipairs(it.words or {}) do
                            local want = WANT[tostring(it.id) .. ':' .. tostring(w % 2048)];
                            if want and (math.floor(w / 2048) + 1) >= want then
                                pending_take = { key = peek.key, slot = it.slot, item = it.name, text = it.augs[ai],
                                    top = it.maxes and it.maxes[ai] and it.maxes[ai].top, at = os.clock() };
                                break;
                            end
                        end
                        if pending_take then break; end
                    end
                end
                local names = {};
                for _, it in ipairs(items) do names[#names + 1] = it.name .. ((#it.augs > 0) and (' (' .. table.concat(it.augs, ', ') .. ')') or ''); end
                note(peek.chest.colour, 'Powerful items: ' .. table.concat(names, ' / '));
                dbg('augmented: ' .. table.concat(names, ' / '));
            else
                aug_chests[peek.key] = nil;
            end
            send_end(peek.chest, f.zone, f.menu, 0, 0);
            peek = nil;
        end);
        return;
    end
    if e.id == 0x05C and peek.fin then
        pcall(function ()
            local d = e.data;
            local names = {};
            for i = 0, 7 do
                local id = u32(d, 0x04 + i * 4);
                if id > 0 and id < 65535 then
                    if peek.fin.ki then
                        if i == 0 then names[#names + 1] = ki_name(id); end   -- the key item is the first number
                    else
                        names[#names + 1] = item_name(id);
                    end
                end
            end
            dbg('items ' .. table.concat(names, ', '));
            finish_peek(names);
        end);
        return;
    end
    if e.id ~= 0x034 then return; end
    local ok = pcall(function ()
        local d = e.data;
        if type(d) ~= 'string' or #d < 0x30 then return; end
        if u32(d, 0x04) ~= peek.chest.server_id then return; end
        -- you clicked this chest yourself: the menu is yours - show it, and forget our look
        if you.id == peek.chest.server_id and hands_off() then
            dbg('you opened this chest yourself - menu left for you');
            peek = nil;
            return;
        end
        e.blocked = true;
        peek.got_menu = true;
        not_ours[peek.chest.server_id] = nil;   -- it answered, so it's ours
        last_menu = { chest = peek.chest, zone = u16(d, 0x2A), menu = u16(d, 0x2C), at = os.clock() };
        local zone, menu = u16(d, 0x2A), u16(d, 0x2C);
        -- [3.75] Take one augmented item from an open chest.
        if peek.claim == 'take' then
            send_end(peek.chest, zone, menu, peek.slot * 65536 + 65, 0);
            local ac = aug_chests[peek.key];
            if ac then
                for i, it in ipairs(ac.items) do
                    if it.slot == peek.slot then
                        note(peek.chest.colour, 'took ' .. it.name);
                        if peek.announce then
                            local a = peek.announce;
                            local head = a.top and '******** MAX AUG COLLECTED ********' or '******** WANTED AUG COLLECTED ********';
                            print('\30\69' .. head .. '\30\01');
                            print('\30\69' .. it.name .. ': ' .. table.concat(it.augs, ', ') .. '\30\01');
                            print('\30\69' .. head .. '\30\01');
                            banner = { text = head, sub = it.name .. ': ' .. table.concat(it.augs, ', '), till = os.clock() + 15 };
                            pcall(function () ashita.misc.play_sound('C:\\Windows\\Media\\tada.wav'); end);
                            dbg('wanted augment taken: ' .. it.name .. ' ' .. table.concat(it.augs, ', '));
                        end
                        table.remove(ac.items, i);
                        break;
                    end
                end
                if #ac.items == 0 then aug_chests[peek.key] = nil; end
            end
            peek = nil;
            return;
        end
        -- An open chest (menu 2068+): augmented items -> ask for the list; anything else -> just note it.
        local unlocked = menu >= 2067;
        if peek.claim == 'aug' or (unlocked and not peek.claim and u32(d, 0x14) == 3) then
            codes[peek.key] = 0x300;
            attempted[peek.key] = os.clock();
            peek.fin = { zone = zone, menu = menu, option = 0, aug = true, inside = 'Powerful items' };
            send_end(peek.chest, zone, menu, 0, 1);
            peek.till = os.clock() + 1.5;
            return;
        end
        if unlocked and not peek.claim then
            -- someone already opened it: nothing for a key to do here
            contents[peek.key] = 'already open';
            attempted[peek.key] = os.clock();
            send_end(peek.chest, zone, menu, 0, 0);
            peek = nil;
            return;
        end
        -- An opened chest's menu: "Add spoils to the treasure pool" (items) or take the key item.
        if peek.claim then
            if peek.claim == 'items' then
                send_end(peek.chest, zone, menu, 9 * 65536 + 65, 0);
                note(peek.chest.colour, 'items added to the treasure pool');
            else
                send_end(peek.chest, zone, menu, 65, 0);
                local kn = contents[peek.key] and contents[peek.key]:match('%((.+)%)$');
                note(peek.chest.colour, 'key item taken' .. (kn and (' - ' .. kn) or ''), nil, true);
            end
            peek = nil;
            return;
        end
        local code = math.floor(u32(d, 0x08) / 65536);
        codes[peek.key] = code;
        local inside = CONTENT[code] or ('unknown (code 0x%X)'):format(code);
        dbg(('got   %s chest: %s (code 0x%X)'):format(peek.chest.colour, inside, code));
        -- What to do with it: option 999 destroys it (no key used, a little cruor), 0 just closes.
        local option, suffix = 0, nil;
        if peek.show then
            suffix = ' (just looking)';
        elseif peek.run and peek.kill then
            -- a colour you switched off, with Auto + Destroy on
            attempted[peek.key] = os.clock();
            if run then run.skipped = run.skipped + 1; end
            option, suffix = 999, ' - destroyed (colour switched off)';
        elseif peek.run and destroy_temp(code) then
            -- only temporary items: not worth a key
            attempted[peek.key] = os.clock();
            if run then run.skipped = run.skipped + 1; end
            option, suffix = 999, ' - destroyed';
        elseif peek.run and is_skipped(inside) then
            attempted[peek.key] = os.clock();
            if run then run.skipped = run.skipped + 1; end
            if set.destroy then option, suffix = 999, ' - destroyed'; else suffix = ' - left shut'; end
        end
        peek.fin = { zone = zone, menu = menu, option = option, suffix = suffix, inside = inside, ki = (code == 0x400) };
        if LISTS[code] then
            -- ask for the list of items first; the answer (0x05C) finishes the look
            send_end(peek.chest, zone, menu, 0, 1);
            peek.till = os.clock() + 1.5;
            return;
        end
        finish_peek(nil);
    end);
    if not ok then peek = nil; end
end);

----------------------------------------------------------------------------------------------------
-- Opening chests: a "run" opens one (/py) or all of a colour (Open all), one step every so often
----------------------------------------------------------------------------------------------------
local GAP = 0.5;          -- seconds after a key trade
local LOOK_GAP = 0.5;     -- seconds after looking inside, before trading
-- run = { only = colour or nil, limit, opened, skipped, zone, next_at }

local function zone_now()
    local z = 0;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    return z;
end

local function run_name(r) return r.auto and 'Auto chests' or (r.only and (LABEL[r.only] .. ' chests') or 'Chests'); end
local auto_hold = 0;      -- Auto waits until then (after running out of keys etc.)
local auto_last = 0;

local function stop_run(why)
    if not run then return; end
    local r = run;
    run, peek, claim = nil, nil, nil;
    if r.limit == 1 and why == 'done' then return; end   -- a single /py that worked: the game says it
    if r.auto and r.opened == 0 and r.skipped == 0 and why ~= 'you turned Auto off' then return; end
    local extra = (r.skipped > 0) and ((set.destroy and ', destroyed %d' or ', skipped %d')):format(r.skipped) or '';
    if not r.auto and why ~= 'none left in range' and why ~= 'done' then info(('stopped - %s'):format(why)); end
    if r.auto and why == 'no Forbidden Key' then info('no Forbidden Key - Auto waits a minute'); end
end

-- Reset: forget everything about the chests around you and start fresh - for when it stops opening
-- (a chest stuck as "tried", "not ours" or "couldn't see inside", a look that never answered...).
-- Unstick: if a chest menu was hidden in the last 2 minutes, close it with the server (cancel), which
-- also lets your character go again.
local function unstick()
    if last_menu == nil or os.clock() - last_menu.at > 120 then return false; end
    pcall(send_end, last_menu.chest, last_menu.zone, last_menu.menu, 0, 0);
    dbg('unstick: sent cancel for the last hidden chest menu');
    last_menu = nil;
    return true;
end
local function reset_all()
    unstick();
    if run then stop_run('reset'); end
    run, peek, claim = nil, nil, nil;
    attempted = {};
    contents = {};
    for k in pairs(not_ours) do not_ours[k] = nil; end
    auto_hold = 0;
    st.keys_at = 0;
end

-- Take an augmented item (slot 1 or 2) from an open chest near you.
local function take_aug(key, slot)
    if peek or run then info('busy with another chest - try again in a moment'); return; end
    if busy() then info('can\'t take items while fighting'); return; end
    local ac = aug_chests[key];
    if not ac then return; end
    local here = ac.chest;
    not_ours[here.server_id] = nil;
    peek = { chest = here, key = key, till = os.clock() + 3, claim = 'take', slot = slot };
    if not pcall(send_peek, here) then peek = nil; end
end
py.take_aug = take_aug;

local function start_run(only, limit)
    if run then stop_run('stopped'); end
    run = { only = only, limit = limit, opened = 0, skipped = 0, zone = zone_now(), next_at = 0 };
end
py.open_all = function (colour) if LABEL[colour] then start_run(colour, 999); end end;

-- Trade a key to this chest. Returns true, or false + why.
local function trade(chest)
    local e, player = GetEntity(chest.index), GetPlayerEntity();
    if not e or not player or e.Name ~= 'Sturdy Pyxis' or model_of(e) ~= chest.model
       or tonumber(e.ServerId) ~= chest.server_id or dist_sq(player, e) > RANGE_SQ then
        attempted[ckey(chest)] = os.clock();
        return false, 'moved';
    end
    local slot, err = find_key();
    if not slot then info(err); return false, 'key'; end
    if slot < 1 or slot > 255 or chest.index > 65535 or not chest.server_id then say('something looked wrong - nothing sent.'); return false, 'bad'; end
    last_target = { id = chest.server_id, at = os.clock() };
    local p = ffi.new('uint8_t[64]');
    ffi.cast('uint32_t*', p + 0x04)[0] = chest.server_id;
    ffi.cast('uint32_t*', p + 0x08)[0] = 1;
    p[0x30] = slot;
    ffi.cast('uint16_t*', p + 0x3A)[0] = chest.index;
    p[0x3C] = 1;
    local ok, r = pcall(function () AshitaCore:GetPacketManager():AddOutgoingPacket(0x036, ffi.string(p, 64):totable()); end);
    if ok and r ~= false then
        attempted[ckey(chest)] = os.clock();
        st.keys_at = 0;
        return true;
    end
    say('the trade could not be sent: ' .. tostring(r));
    return false, 'api';
end

local function run_tick()
    if not run then return; end
    local now = os.clock();
    if hands_off() and not peek then return; end   -- you're using a chest yourself: wait
    if peek then
        if now < peek.till then return; end
        if peek.fin then finish_peek(nil); return; end   -- no item list came: finish without names
        dbg(('no answer from the %s chest (%s)'):format(peek.chest.colour, peek.claim and 'taking items' or 'looking'));
        if peek.claim then
            note(peek.chest.colour, 'is open - talk to it to take what\'s inside');
        else
            dbg('  (left shut: not opening a chest we can\'t see inside)');
            contents[peek.key] = false;            -- no menu came back
            if peek.kill then attempted[peek.key] = now; end
        end
        peek = nil;
    end
    -- An opened chest with items / a key item: talk to it again and take them.
    if claim then
        if now < claim.at then return; end
        local c = claim;
        claim = nil;
        peek = { chest = c.chest, key = c.key, till = now + 3, claim = c.kind };
        if not pcall(send_peek, c.chest) then peek = nil; end
        run.next_at = now + LOOK_GAP;
        return;
    end
    if run.opened >= run.limit then stop_run('done'); return; end
    -- (after a destroy the chest is already marked tried, so the loop below moves on to the next one)
    if now < run.next_at then return; end
    if zone_now() ~= run.zone then stop_run('you zoned'); return; end
    if busy() then
        if run.auto then stop_run('you\'re fighting'); return; end   -- Auto starts again once you're idle
        if not run.told_busy then run.told_busy = true; info('waiting until you\'re not fighting...'); end
        run.next_at = now + 0.5;
        return;
    end
    scan();
    for k, t in pairs(attempted) do if now - t >= ATTEMPT_TTL then attempted[k] = nil; end end
    local found = false;
    for _, c in ipairs(st.nearby) do
        local want = (run.only and c.colour == run.only) or (not run.only and set[c.colour]);
        local key = ckey(c);
        if not want and run.auto and set.destroy and not attempted[key] and LABEL[c.colour] then
            -- Auto: a colour you switched off gets destroyed
            found = true;
            peek = { chest = c, key = key, till = now + 3, run = true, kill = true };
            if not pcall(send_peek, c) then peek = nil; attempted[key] = now; end
            run.next_at = now + LOOK_GAP;
            return;
        end
        if is_not_ours(c.server_id) then goto continue; end
        if want and not attempted[key] then
            found = true;
            local look = any_temps() or set.spoils or (c.colour == 'red' and any_skip());
            if look then
                local inside = contents[key];
                local code = codes[key];
                if inside == nil or (is_skipped(inside) and set.destroy) or destroy_temp(code) then
                    peek = { chest = c, key = key, till = now + 3, run = true };
                    local ok = pcall(send_peek, c);
                    if not ok then peek = nil; contents[key] = false; end
                    run.next_at = now + LOOK_GAP;
                    return;
                end
                if inside == false then
                    -- No answer when we looked: someone else's chest, or one that's already gone.
                    attempted[key] = now;
                    goto continue;
                end
                if inside and is_skipped(inside) then
                    note('red', inside .. ' - left shut');
                    attempted[key] = now; run.skipped = run.skipped + 1;
                    goto continue;
                end
            end
            local ok, why = trade(c);
            if ok then
                run.opened = run.opened + 1;
                local what = contents[key];
                if what == false then what = 'couldn\'t see inside'; elseif what == nil then what = 'not looked inside'; end
                note(c.colour, what .. ' - opened', chat_contents[key] and (chat_contents[key] .. ' - opened'), codes[key] == 0x400);
                -- A key item: tell the party its name.
                if codes[key] == 0x400 and set.ki_party then
                    local kn = type(what) == 'string' and what:match('%((.+)%)$');
                    if kn then pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. kn); end); end
                end
                local kind = set.spoils and SPOIL_CODES[codes[key] or -1];
                if kind then
                    claim = { chest = c, key = key, kind = kind, at = now + 1.5 };   -- let it open first
                    run.next_at = now;
                    return;
                end
                if run.opened >= run.limit then stop_run('done'); return; end
                run.next_at = now + GAP;
                return;
            elseif why == 'moved' then
                run.next_at = now + 0.5;
                return;
            else
                if run.auto then auto_hold = now + ((why == 'key') and 60 or 10); end
                stop_run((why == 'key') and 'no Forbidden Key' or 'stopped');
                return;
            end
        end
        ::continue::
    end
    if run.auto then stop_run('none left in range'); return; end
    if run.opened == 0 and run.skipped == 0 then
        local s = 0;
        for _, c in ipairs(st.nearby) do if attempted[ckey(c)] then s = s + 1; end end
        if s > 0 and not found then
            info(('no new chest in range (%d already tried - /py reset)'):format(s));
            run, peek = nil, nil;
            return;
        end
        info('no ' .. (run.only and (LABEL[run.only] .. ' ') or '') .. 'chest within 5.9 yalms');
        run, peek = nil, nil;
        return;
    end
    stop_run('none left in range');
end

py.open = function () start_run(nil, 1); end

-- Auto: start a run by itself whenever there's a chest to open (or destroy) next to you.
local function auto_tick()
    if not set.auto or run or peek then return; end
    if hands_off() then return; end
    local now = os.clock();
    if now < auto_hold or now - auto_last < 0.5 then return; end
    auto_last = now;
    if not in_abyssea() then return; end
    if busy() then return; end
    scan();
    for k, t in pairs(attempted) do if now - t >= ATTEMPT_TTL then attempted[k] = nil; end end
    for _, c in ipairs(st.nearby) do
        if not attempted[ckey(c)] and LABEL[c.colour] and (set[c.colour] or set.destroy) then
            start_run(nil, 999);
            run.auto = true;
            return;
        end
    end
end

----------------------------------------------------------------------------------------------------
-- Drawing: three chest cards (shared by the window and the Abyssea > Chests tab)
----------------------------------------------------------------------------------------------------
local function cards(w)
    for i, c in ipairs(ORDER) do
        if i > 1 then imgui.SameLine(0, 8); end
        imgui.BeginGroup();
        local on = set[c];
        local n = st.counts[c] or 0;
        imgui.TextColored(on and COL[c] or { 0.5, 0.5, 0.55, 1.0 }, ('%s  %d'):format(LABEL[c], n));
        local t = texture(c);
        local clicked = false;
        if t then
            local ok = pcall(function ()
                imgui.Image(tonumber(ffi.cast('uint32_t', t)), { w, math.floor(w * 0.77) }, { 0, 0 }, { 1, 1 },
                    on and { 1, 1, 1, 1 } or { 0.35, 0.35, 0.38, 0.8 }, { 1, 1, 1, 0 });
                clicked = imgui.IsItemClicked(0);
            end);
            if not ok then tex[c] = nil; tex_failed[c] = true; end
        else
            local cc = COL[c] or { 0.6, 0.6, 0.6, 1 };
            local k = on and 0.55 or 0.22;
            imgui.PushStyleColor(ImGuiCol_Button, { cc[1] * k, cc[2] * k, cc[3] * k, 1 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { cc[1] * (k + 0.15), cc[2] * (k + 0.15), cc[3] * (k + 0.15), 1 });
            clicked = imgui.Button(LABEL[c] .. ' chest##pyx_img_' .. c, { w, math.floor(w * 0.77) });
            imgui.PopStyleColor(2);
        end
        if imgui.IsItemHovered() then imgui.SetTooltip(TIP[c] .. '\nClick to turn ' .. (on and 'off.' or 'on.')); end
        local sty = package.loaded['omni_style'];
        if sty and sty.switch then
            if sty.switch('##pyx_sw_' .. c, on, 'Open ' .. LABEL[c] .. ' chests') then clicked = true; end
            imgui.SameLine(0, 6);
            local kill = (not on) and set.auto and set.destroy;
            imgui.TextColored(on and { 0.55, 0.92, 0.55, 1 } or (kill and { 1.0, 0.45, 0.45, 1 } or { 0.55, 0.57, 0.63, 1 }),
                on and 'Open' or (kill and 'Destroy' or 'Off'));
        elseif imgui.Button((on and 'On' or 'Off') .. '##pyx_btn_' .. c, { w, 0 }) then
            clicked = true;
        end
        if clicked then set[c] = not on; save(); end
        if run and run.only == c and run.limit > 1 then
            if imgui.Button(('Stop (%d)##pyx_stop_%s'):format(run.opened, c), { w, 0 }) then stop_run('you pressed Stop'); end
        else
            if imgui.Button('Open all##pyx_all_' .. c, { w, 0 }) then py.open_all(c); end
            if imgui.IsItemHovered() then
                imgui.SetTooltip(('Opens every %s chest within 5.9 yalms, one every %s seconds,\nwhether or not %s is switched on. Stops when none are left.%s'):format(LABEL[c], GAP, LABEL[c],
                    (c == 'red') and '\nRed chests are looked inside first: lights you tick under Skip are left shut.' or ''));
            end
        end
        imgui.EndGroup();
    end
end

local function skip_row()
    imgui.TextColored(COL.red, 'Red - skip:');
    for _, l in ipairs(LIGHTS) do
        imgui.SameLine(0, 8);
        local k = 'skip_' .. l:lower();
        local v = { set[k] == true };
        imgui.PushStyleColor(ImGuiCol_Text, LIGHT_COL[l]);
        if imgui.Checkbox(l .. '##pyx_' .. k, v) then set[k] = v[1]; save(); end
        imgui.PopStyleColor(1);
        if imgui.IsItemHovered() then imgui.SetTooltip(('Don\'t open Red chests with %s light\n(omni looks inside each Red chest before using a key).'):format(l)); end
    end
    imgui.SameLine(0, 14);
    local dv = { set.destroy == true };
    if imgui.Checkbox('Destroy them##pyx_destroy', dv) then set.destroy = dv[1]; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('On: skipped chests are destroyed (no key used, a little cruor).\nOff: they are just left shut.'); end
end

local function auto_row()
    local sty = package.loaded['omni_style'];
    if sty and sty.switch then
        if sty.switch('##pyx_auto', set.auto, 'Open chests by themselves') then
            set.auto = not set.auto; auto_hold = 0; save();
            if not set.auto and run and run.auto then stop_run('you turned Auto off'); end
        end
        imgui.SameLine(0, 6);
    else
        local v = { set.auto == true };
        if imgui.Checkbox('##pyx_auto_cb', v) then set.auto = v[1]; auto_hold = 0; save(); end
        imgui.SameLine(0, 6);
    end
    imgui.TextColored(set.auto and { 0.55, 0.92, 0.55, 1 } or { 0.55, 0.57, 0.63, 1 }, set.auto and 'Auto ON' or 'Auto off');
    if imgui.IsItemHovered() then
        imgui.SetTooltip('Auto ON: every chest within 5.9 yalms is dealt with by itself, no button or /py needed.\n'
            .. 'Colours switched to Open are opened with a key; Red ones with a ticked light are destroyed.\n'
            .. 'Colours switched off are destroyed too (no key used) while "Destroy them" is ticked.');
    end
    if run and run.auto then imgui.SameLine(0, 10); imgui.TextDisabled(('working... opened %d'):format(run.opened)); end
end

local function footer()
    local k = keys();
    imgui.TextColored({ 0.48, 0.81, 1.0, 1.0 }, 'Forbidden Keys ' .. (k ~= nil and tostring(k) or '--'));
    imgui.SameLine(0, 16);
    imgui.TextDisabled(('Ready %d'):format(ready()));
    imgui.SameLine(0, 16);
    if imgui.Button('Open one##pyx_open') then py.open(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Same as /py: trades a key to the nearest chest\nof a colour you have on (within 5.9 yalms).'); end
end

-- Abyssea > Chests tab.
-- [3.84] Abyssea > Augments: every augmented gold-chest item, tick the augments you want and the
-- lowest roll you'll take. A chest with one is taken by itself (Auto-take) with a big message.
local okmx2, AM = pcall(require, 'pyxis_augmax');
py.render_augs = function ()
    if not okmx2 or type(AM) ~= 'table' or not AM.order then imgui.Text('pyxis_augmax.lua is missing.'); return; end
    local v = { set.aug_auto ~= false };
    if imgui.Checkbox('Auto-take chests that have an augment I ticked##pyx_augauto', v) then set.aug_auto = v[1]; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('When an open gold chest has one of the augments you ticked below,\nrolled at least as high as you picked, it is taken for you and you get\n******** MAX AUG COLLECTED ******** in chat and on screen.'); end
    local n = 0; for _ in pairs(WANT) do n = n + 1; end
    imgui.SameLine(0, 16);
    imgui.TextColored({ 0.55, 0.57, 0.63, 1 }, ('%d ticked.  T3+ = only from tier 3 or better chests.'):format(n));
    -- Zone buttons like NM Pops (opens on the zone you're in), then that zone's items in full.
    local ZONES = { 'La Theine', 'Konschtat', 'Tahrongi', 'Attohwa', 'Misareaux', 'Vunkerl', 'Altepa', 'Uleguerand', 'Grauberg' };
    local ZID = { [132] = 'La Theine', [15] = 'Konschtat', [45] = 'Tahrongi', [215] = 'Attohwa', [216] = 'Misareaux',
        [217] = 'Vunkerl', [218] = 'Altepa', [253] = 'Uleguerand', [254] = 'Grauberg' };
    local here = ZID[zone_now()];
    if py.aug_zone == nil or (here and py.aug_here ~= here) then py.aug_zone = here or py.aug_zone or ZONES[1]; py.aug_here = here; end
    imgui.Spacing();
    local W = imgui.GetContentRegionAvail();
    if type(W) ~= 'number' then W = 600; end
    local x = 0;
    for i, z in ipairs(ZONES) do
        local ticked = 0;
        for _, iid in ipairs(AM.order) do
            local e = AM[iid];
            if e and e[3] == z then for _, r in ipairs(e[2]) do if WANT[iid .. ':' .. r[1]] then ticked = ticked + 1; end end end
        end
        local label = z .. ((here == z) and ' *' or '') .. ((ticked > 0) and (' (' .. ticked .. ')') or '');
        local bw = imgui.CalcTextSize(label) + 22;
        if i > 1 then
            if x + 6 + bw <= W then imgui.SameLine(0, 6); x = x + 6; else x = 0; end
        end
        local sel = py.aug_zone == z;
        imgui.PushStyleColor(ImGuiCol_Button, sel and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
        imgui.PushStyleColor(ImGuiCol_Text, sel and { 1, 0.96, 0.85, 1 } or { 0.62, 0.66, 0.80, 1 });
        if imgui.Button(label .. '##pyx_augz' .. i, { bw, 0 }) then py.aug_zone = z; end
        imgui.PopStyleColor(2);
        if imgui.IsItemHovered() then imgui.SetTooltip('Abyssea - ' .. z .. ((here == z) and ' (you are here)' or '') .. ((ticked > 0) and ('\n' .. ticked .. ' augment(s) ticked') or '')); end
        x = x + bw;
    end
    imgui.Spacing();
    imgui.TextColored({ 0.90, 0.78, 0.40, 1 }, 'Abyssea - ' .. py.aug_zone .. ' - augmented gold chest items');
    imgui.Separator();
    for _, iid in ipairs(AM.order) do
        local e = AM[iid];
        if e and e[3] == py.aug_zone then
            imgui.Spacing();
            imgui.TextColored({ 1.0, 0.88, 0.35, 1 }, e[1]);
            do
                -- one row per augment (an augment listed twice: the wider range)
                local rows, seen = {}, {};
                for _, r in ipairs(e[2]) do
                    local s0 = seen[r[1]];
                    if s0 then s0[2] = math.min(s0[2], r[2]); s0[3] = math.max(s0[3], r[3]); s0[4] = math.min(s0[4], r[4]);
                    else s0 = { r[1], r[2], r[3], r[4] }; seen[r[1]] = s0; rows[#rows + 1] = s0; end
                end
                for ri, r in ipairs(rows) do
                    local key = iid .. ':' .. r[1];
                    local on = { WANT[key] ~= nil };
                    local label = (aug_text(r[1] + (r[3] - 1) * 2048) or ('augment ' .. r[1])) .. ((r[4] > 1) and ('  T' .. r[4] .. '+') or '');
                    imgui.Indent(12);
                    if imgui.Checkbox(label .. '##pyx_want_' .. key, on) then
                        WANT[key] = on[1] and r[3] or nil;   -- ticked: the max roll to start with
                        want_save();
                    end
                    if imgui.IsItemHovered() then imgui.SetTooltip(('Rolls %s to %s%s'):format(aug_text(r[1] + (r[2] - 1) * 2048) or '?',
                        aug_text(r[1] + (r[3] - 1) * 2048) or '?', (r[4] > 1) and ('\nOnly from tier ' .. r[4] .. ' or better chests') or '')); end
                    if WANT[key] then
                        imgui.SameLine(0, 12);
                        imgui.TextColored({ 0.55, 0.57, 0.63, 1 }, 'at least');
                        imgui.SameLine(0, 6);
                        local names, cur = {}, 0;
                        for roll = r[2], r[3] do
                            names[#names + 1] = aug_text(r[1] + (roll - 1) * 2048) or tostring(roll);
                            if roll == WANT[key] then cur = roll - r[2]; end
                        end
                        imgui.PushItemWidth(190);
                        local pick = { cur };
                        if imgui.Combo('##pyx_wantroll_' .. key, pick, table.concat(names, '\0') .. '\0') then
                            WANT[key] = r[2] + pick[1];
                            want_save();
                        end
                        imgui.PopItemWidth();
                    end
                    imgui.Unindent(12);
                end
            end
        end
    end
end

py.render = function ()
    if os.clock() - st.last >= 0.25 then st.last = os.clock(); pcall(scan); end
    imgui.TextDisabled('Auto ON = chests next to you are opened by themselves; colours switched off are destroyed.');
    imgui.TextDisabled('Open all = every chest of one colour now. /py = one chest.');
    imgui.Spacing();
    auto_row();
    imgui.Spacing();
    cards(110);
    imgui.Spacing();
    skip_row();
    imgui.Text('Destroy temp chests:');
    imgui.SameLine(0, 8);
    local tk = { set.temps_take == true };
    if imgui.Checkbox('ones you take from##pyx_temps_take', tk) then set.temps_take = tk[1]; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Chests holding up to 3 temp items you\'d have to take out yourself.\nTicked: destroyed (no key used). Unticked: opened.'); end
    imgui.SameLine(0, 10);
    local tg = { set.temps_give == true };
    if imgui.Checkbox('ones that give to everyone##pyx_temps_give', tg) then set.temps_give = tg[1]; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Blue chests that hand several temp items to your whole party when opened.\nTicked: destroyed. Unticked: opened.'); end
    -- Own line, so the row doesn't run off the side of the panel.
    imgui.Text('When opened:');
    imgui.SameLine(0, 8);
    local sv = { set.spoils == true };
    if imgui.Checkbox('Add items to the treasure pool##pyx_spoils', sv) then set.spoils = sv[1]; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('After opening a chest with items, omni picks "add spoils to the treasure pool"\n(and takes a key item if that\'s what it holds).'); end
    imgui.SameLine(0, 18);
    local kv = { set.ki_party == true };
    if imgui.Checkbox('Say key items in party##pyx_kip', kv) then set.ki_party = kv[1]; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('When a chest with a key item is opened, its name goes to /p.'); end
    imgui.Spacing();
    footer();
    imgui.Spacing();
    local sty = package.loaded['omni_style'];
    if sty and sty.switch then
        if sty.switch('##pyx_show', set.show, 'Show the small Open pop-out while in Abyssea') then set.show = not set.show; save(); end
        imgui.SameLine(0, 8);
    end
    imgui.Text('Small Open pop-out in Abyssea');
    imgui.Spacing();
    imgui.TextDisabled('Forbidden Keys must be in your main inventory. Chests already tried are skipped for 2 minutes (/py reset).');
    imgui.TextDisabled('Based on Pyxis by Integrity.');
end

-- [3.78] Augmented items in open gold chests near you: Take, and a /p tick box to tell the party.
local function aug_list()
    local out = {};
    for key, ac in pairs(aug_chests) do
        local there = false;
        pcall(function ()
            local e = GetEntity(ac.chest.index);
            there = e ~= nil and tonumber(e.ServerId) == ac.chest.server_id and visible(ac.chest.index);
        end);
        if not there then aug_chests[key] = nil;
        elseif #ac.items > 0 then out[#out + 1] = { key = key, ac = ac }; end
    end
    return out;
end
py.aug_visible = function () return #aug_list() > 0; end
py.aug_body = function ()
    local list = aug_list();
    if #list == 0 then return; end
    imgui.SetWindowFontScale(0.85);
    imgui.TextColored({ 1.0, 0.84, 0.35, 1 }, 'Augmented items');
    for _, a in ipairs(list) do
        for _, it in ipairs(a.ac.items) do
            if imgui.SmallButton(('Take##pyx_take_%s_%d'):format(a.key, it.slot)) then take_aug(a.key, it.slot); end
            if imgui.IsItemHovered() then imgui.SetTooltip('Take ' .. it.name .. ' from the chest (needs a free inventory slot)'); end
            imgui.SameLine(0, 6);
            imgui.TextColored({ 1.0, 0.88, 0.35, 1 }, it.name);
            imgui.SameLine(0, 6);
            local v = { it.told == true };
            if imgui.Checkbox(('/p##pyx_tell_%s_%d'):format(a.key, it.slot), v) then
                it.told = v[1] or nil;
                if v[1] then
                    local line = ('Gold chest: %s%s'):format(it.name, (#it.augs > 0) and (' - ' .. table.concat(it.augs, ', ')) or '');
                    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. line); end);
                end
            end
            if imgui.IsItemHovered() then imgui.SetTooltip(it.told and 'Already told the party (untick to say it again)' or 'Tick to tell the party what this item has on it'); end
            if #it.augs > 0 then
                -- each augment, and the best it can roll on this item (gold = a top roll)
                for ai, at in ipairs(it.augs) do
                    local mx = it.maxes and it.maxes[ai];
                    imgui.TextColored(mx and mx.top and { 1.0, 0.84, 0.35, 1 } or { 0.55, 0.80, 1.0, 1 }, '    ' .. at);
                    if mx and mx.max then
                        imgui.SameLine(0, 6);
                        imgui.TextColored({ 0.55, 0.57, 0.63, 1 }, mx.top and '(max!)' or ('(max ' .. mx.max .. ')'));
                    end
                end
            end
        end
    end
    imgui.SetWindowFontScale(1.0);
end

-- The small pop-out: just the open buttons. Everything else is on Abyssea > Chests.
local function mini()
    local sty = package.loaded['omni_style'];
    -- Minimise / restore
    if imgui.SmallButton((set.small and '+' or '-') .. '##pyx_small') then set.small = not set.small; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip(set.small and 'Show the full pop-out' or 'Minimise (just keys and Auto)'); end
    imgui.SameLine(0, 8);
    if set.small then
        -- minimised: one line of chest counts, keys and whether Auto is on
        local k = keys();
        imgui.TextColored({ 0.48, 0.81, 1.0, 1.0 }, 'Keys ' .. (k ~= nil and tostring(k) or '--'));
        imgui.SameLine(0, 10);
        imgui.TextColored(set.auto and { 0.55, 0.92, 0.55, 1 } or { 0.55, 0.57, 0.63, 1 }, set.auto and 'Auto' or 'Auto off');
        if run then imgui.SameLine(0, 10); imgui.TextColored({ 1.0, 0.85, 0.4, 1 }, 'opening...'); end
        return;
    end
    -- [3.80] one line: keys, Auto, Reset, Unstick and the chest list (the per-colour Open buttons
    -- are on Abyssea > Chests).
    local k = keys();
    imgui.TextColored({ 0.48, 0.81, 1.0, 1.0 }, 'Keys ' .. (k ~= nil and tostring(k) or '--'));
    imgui.SameLine(0, 12);
    if sty and sty.switch then
        if sty.switch('##pyx_mauto', set.auto, 'Auto: open chests by themselves (settings on Abyssea > Chests)') then
            set.auto = not set.auto; auto_hold = 0; save();
            if not set.auto and run and run.auto then stop_run('you turned Auto off'); end
        end
        imgui.SameLine(0, 4);
    end
    imgui.TextColored(set.auto and { 0.55, 0.92, 0.55, 1 } or { 0.55, 0.57, 0.63, 1 }, 'Auto');
    imgui.SameLine(0, 12);
    if imgui.SmallButton('Reset##pyx_mreset') then reset_all(); info('reset - every chest will be looked at again'); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Not opening chests? Click to forget every chest it has\ntried or skipped, stop anything stuck, and start again.\nSame as /py reset.'); end
    imgui.SameLine(0, 6);
    if imgui.SmallButton('Unstick##pyx_munstick') then
        if unstick() then info('unstick - closed the chest menu'); else info('unstick - no chest menu to close (zone if still frozen)'); end
    end
    if imgui.IsItemHovered() then imgui.SetTooltip('Frozen after clicking a chest? Click to close the chest menu\nwith the server so you can move again.\nSame as /py unstick.'); end
    -- The list: the last chests and what was in them, folds away with its own button.
    local dim = { 0.55, 0.57, 0.63, 1 };
    imgui.SameLine(0, 12);
    if imgui.SmallButton((set.list and 'v' or '>') .. '##pyx_list') then set.list = not set.list; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip(set.list and 'Hide the chest list' or 'Show the chest list'); end
    imgui.SameLine(0, 6);
    imgui.TextColored(dim, ('Chest list (%d)'):format(#st.log));
    if set.list then
        if #st.log == 0 then imgui.TextColored(dim, '  nothing opened yet'); end
        for _, l in ipairs(st.log) do
            local ago = os.time() - l.t;
            imgui.TextColored(dim, (ago < 60) and ('%2ds'):format(ago) or ('%2dm'):format(math.floor(ago / 60)));
            imgui.SameLine(0, 6);
            if l.col then
                imgui.TextColored(COL[l.col] or { 0.7, 0.7, 0.7, 1 }, LABEL[l.col] or '?');
                imgui.SameLine(0, 6);
            end
            imgui.TextColored(l.red and { 1.0, 0.40, 0.40, 1 } or { 0.80, 0.82, 0.88, 1 }, l.text);
        end
    end
    -- Augmented items: drawn here only when Happy Chests has its own window (in the shared Abyssea
    -- pop-out they sit beside the NM Tracker instead).
    local host = package.loaded['omni_abyssea'];
    if not (host and host.hosting_at and os.clock() - host.hosting_at < 1) then pcall(py.aug_body); end
end

-- For the shared Abyssea pop-out: shown? and its part of the window.
py.popout_visible = function ()
    if not set.show then return false; end
    local inside = false;
    pcall(function () inside = in_abyssea(); end);
    return inside;
end
py.popout_body = function ()
    if imgui.SmallButton('x##pyx_host_x') then set.show = false; save(); say('chests hidden - /py hud to show them again.'); return; end
    if imgui.IsItemHovered() then imgui.SetTooltip('Hide Happy Chests (/py hud brings it back)'); end
    imgui.SameLine(0, 6);
    imgui.TextColored({ 0.90, 0.78, 0.40, 1.0 }, 'Happy Chests');
    imgui.SameLine(0, 10);
    local ok, err = pcall(mini);
    if not ok then imgui.Text(tostring(err)); end
end

-- The little window, only inside Abyssea.
ashita.events.register('d3d_present', 'omni_pyxis_tick', function ()
    if peek and peek.fin and not run and os.clock() >= peek.till then finish_peek(nil); end
    if peek and not run and os.clock() >= peek.till then
        if peek.show then say('the chest didn\'t answer (it may not be your party\'s).'); dbg('no answer to /py peek'); end
        contents[peek.key] = false; peek = nil;
    end
    -- a wanted augment found: take it as soon as nothing else is talking to a chest
    if pending_take and not peek and not busy() then
        local pt = pending_take;
        pending_take = nil;
        local ac = aug_chests[pt.key];
        if ac and os.clock() - pt.at < 60 then
            peek = { chest = ac.chest, key = pt.key, till = os.clock() + 3, claim = 'take', slot = pt.slot, announce = pt };
            not_ours[ac.chest.server_id] = nil;
            if not pcall(send_peek, ac.chest) then peek = nil; end
        end
    end
    -- the big message in the middle of the screen
    if banner then
        if os.clock() > banner.till then banner = nil;
        else
            pcall(function ()
                local io_ = imgui.GetIO();
                local sw, sh = io_.DisplaySize.x, io_.DisplaySize.y;
                imgui.SetNextWindowPos({ sw / 2, sh * 0.30 }, ImGuiCond_Always, { 0.5, 0.5 });
                imgui.SetNextWindowBgAlpha(0.80);
                if imgui.Begin('##pyx_maxaug', true, bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_AlwaysAutoResize,
                    ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoInputs)) then
                    imgui.SetWindowFontScale(2.0);
                    local blink = math.floor(os.clock() * 2) % 2 == 0;
                    imgui.TextColored(blink and { 1.0, 0.84, 0.25, 1 } or { 1.0, 0.95, 0.6, 1 }, banner.text);
                    imgui.SetWindowFontScale(1.4);
                    imgui.TextColored({ 0.55, 0.85, 1.0, 1 }, banner.sub);
                    imgui.SetWindowFontScale(1.0);
                end
                imgui.End();
            end);
        end
    end
    pcall(auto_tick);
    pcall(run_tick);
    if not set.show then return; end
    local inside = false;
    pcall(function () inside = in_abyssea(); end);
    if not inside then return; end
    if os.clock() - st.last >= 0.25 then st.last = os.clock(); pcall(scan); end
    -- [3.74] drawn inside the one Abyssea pop-out (omni_abyssea) when that is running
    local host = package.loaded['omni_abyssea'];
    if host and host.hosting_at and os.clock() - host.hosting_at < 1 then return; end
    local sty = package.loaded['omni_style'];
    local ns = sty and sty.begin() or nil;
    imgui.SetNextWindowSize({ 0, 0 }, ImGuiCond_Always);
    win_open[1] = true;
    if imgui.Begin('Happy Chests###omni_pyxis', win_open, bit.bor(ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoCollapse)) then
        local ok, err = pcall(mini);
        if not ok then imgui.Text(tostring(err)); end
    end
    imgui.End();
    if sty then sty.finish(ns); end
    if not win_open[1] then set.show = false; save(); say('window hidden - /py hud to show it again.'); end
end);

-- Your own clicks on a chest (not omni's): note it, drop any look at that chest, and leave the chests
-- alone for a while.
ashita.events.register('packet_out', 'omni_pyxis_you', function (e)
    if e.injected or (e.id ~= 0x01A and e.id ~= 0x036) then return; end
    pcall(function ()
        local d = e.data;
        local id = u32(d, 0x04);
        local idx = (e.id == 0x01A) and u16(d, 0x08) or nil;
        local name = '';
        if idx then
            local ent = GetEntity(idx);
            name = (ent and ent.Name) or '';
        else
            -- a trade: the target's index sits after the 10 item slots; check by id instead
            for _, c in ipairs(st.nearby or {}) do if c.server_id == id then name = 'Sturdy Pyxis'; end end
        end
        if name:find('Pyxis', 1, true) then
            you.id, you.at = id, os.clock();
            not_ours[id] = nil;   -- you can use it, so it's yours
            if peek and peek.chest and peek.chest.server_id == id and not peek.got_menu then peek = nil; end
            dbg(('you clicked chest id %d yourself - omni leaves the chests alone for %ds'):format(id, HANDS_OFF));
        end
    end);
end);

ashita.events.register('command', 'omni_pyxis_cmd', function (e)
    local a = e.command:args();
    if #a == 0 then return; end
    local c0 = a[1]:lower();
    if c0 ~= '/py' and c0 ~= '/pyxis' then return; end
    e.blocked = true;
    local c = (a[2] or 'open'):lower();
    local m = (a[3] or ''):lower();
    if LABEL[c] then
        if m == 'on' then set[c] = true; elseif m == 'off' then set[c] = false; else set[c] = not set[c]; end
        save();
        say(LABEL[c] .. ' chests ' .. (set[c] and 'ON' or 'OFF') .. '.');
    elseif c == 'hud' or c == 'show' then
        if m == 'on' or m == 'show' then set.show = true; elseif m == 'off' or m == 'hide' then set.show = false; else set.show = not set.show; end
        save();
    elseif c == 'status' then
        scan();
        say(('within 5.9y: Blue %d (%s)  Gold %d (%s)  Red %d (%s)  other %d  |  keys %s'):format(
            st.counts.blue, set.blue and 'on' or 'off', st.counts.gold, set.gold and 'on' or 'off',
            st.counts.red, set.red and 'on' or 'off', st.counts.unknown, tostring(count_keys() or '--')));
    elseif c == 'all' then
        if LABEL[m] then py.open_all(m); else say('/py all blue|gold|red'); end
    elseif c == 'stop' then
        stop_run('you typed /py stop');
    elseif c == 'skip' then
        local hit = nil;
        for _, l in ipairs(LIGHTS) do if l:lower() == m then hit = l; end end
        if hit then
            local k = 'skip_' .. hit:lower();
            local v = (a[4] or ''):lower();
            if v == 'on' then set[k] = true; elseif v == 'off' then set[k] = false; else set[k] = not set[k]; end
            save();
            say(('Red chests with %s light: %s.'):format(hit, set[k] and 'SKIPPED' or 'opened'));
        else
            local on = {};
            for _, l in ipairs(LIGHTS) do if set['skip_' .. l:lower()] then on[#on + 1] = l; end end
            say('skipping Red chests with: ' .. (#on > 0 and table.concat(on, ', ') or 'nothing') .. '.  /py skip ruby|amber|azure|pearl|golden|silvery|ebon');
        end
    elseif c == 'auto' then
        if m == 'on' then set.auto = true; elseif m == 'off' then set.auto = false; else set.auto = not set.auto; end
        if not set.auto and run and run.auto then stop_run('you turned Auto off'); end
        auto_hold = 0;
        save();
        say('Auto ' .. (set.auto and 'ON - chests next to you are opened (colours switched off are ' .. (set.destroy and 'destroyed' or 'left') .. ').' or 'OFF.'));
    elseif c == 'temps' then
        -- /py temps <take|give> [on|off]
        if m == 'take' or m == 'give' then
            local k, v = 'temps_' .. m, (a[4] or ''):lower();
            if v == 'on' then set[k] = true; elseif v == 'off' then set[k] = false; else set[k] = not set[k]; end
            save();
        end
        say(('temp chests you take from: %s.  temp chests that give to everyone: %s.  (/py temps take|give on|off)'):format(
            set.temps_take and 'DESTROYED' or 'opened', set.temps_give and 'DESTROYED' or 'opened'));
    elseif c == 'kip' or c == 'kiparty' then
        if m == 'on' then set.ki_party = true; elseif m == 'off' then set.ki_party = false; else set.ki_party = not set.ki_party; end
        save();
        say('key item names ' .. (set.ki_party and 'will be said in party.' or 'stay in your own chat.'));
    elseif c == 'spoils' then
        if m == 'on' then set.spoils = true; elseif m == 'off' then set.spoils = false; else set.spoils = not set.spoils; end
        save();
        say('items will ' .. (set.spoils and 'go to the treasure pool by themselves.' or 'be left in the chest.'));
    elseif c == 'destroy' then
        if m == 'on' then set.destroy = true; elseif m == 'off' then set.destroy = false; else set.destroy = not set.destroy; end
        save();
        say('skipped Red chests will be ' .. (set.destroy and 'DESTROYED.' or 'left shut.'));
    elseif c == 'peek' or c == 'look' then
        scan();
        local c1 = st.nearby[1];
        if not c1 then say('no chest within 5.9 yalms.');
        else
            contents[ckey(c1)] = nil;
            peek = { chest = c1, key = ckey(c1), till = os.clock() + 3, show = true };
            if not pcall(send_peek, c1) then peek = nil; say('could not look.'); end
        end
    elseif c == 'unstick' then
        if unstick() then say('closed the chest menu - you should be able to move again.');
        else say('no chest menu to close (if you are still frozen, zone or log out and back in).'); end
    elseif c == 'reset' then
        reset_all();
        say('reset - every chest near you will be looked at again.');
    elseif c == 'open' then
        py.open();
    else
        say('/py  |  /py auto on|off  |  /py all blue|gold|red  |  /py stop  |  /py skip <light>  |  /py peek  |  /py blue|gold|red [on|off]  |  /py hud  |  /py status  |  /py reset');
    end
end);

return py;
