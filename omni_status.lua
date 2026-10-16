--[[
    omni_status.lua - buffs and debuffs for the target bar.

    Three sources, the same ones HXUI uses:
      * yourself         : your own buff list
      * a party member   : the party buff list the game keeps
      * anything else    : debuffs worked out by watching the battle messages,
                           with estimated durations (the game does not tell the
                           client what is on a monster)

    The debuff tracking is adapted from HXUI's debuffhandler (originally from
    mousseng's xitools, GPL), and the icon loading from statustimers by Heals.
]]

require('common');
local ffi   = require('ffi');
local d3d8  = require('d3d8');
local imgui = require('imgui');

local status = {};

----------------------------------------------------------------------------------------------------
-- Debuffs on monsters (tracked from action and message packets)
----------------------------------------------------------------------------------------------------
local function set(list)
    local out = {};
    for _, v in ipairs(list) do out[v] = true; end
    return out;
end

local STATUS_ON    = set { 160, 164, 166, 186, 194, 203, 205, 230, 236, 266, 267, 268, 269, 237, 271, 272, 277, 278, 279, 280, 319, 320, 375, 412, 645, 754, 755, 804 };
local STATUS_OFF   = set { 206, 64, 159, 168, 204, 321, 322, 341, 342, 343, 344, 350, 378, 531, 647, 805, 806 };
local DEATH        = set { 6, 20, 97, 113, 406, 605, 646 };
local SPELL_DAMAGE = set { 2, 252, 264, 265 };

-- Spell id -> how long its effect lasts, in seconds. Anything else is assumed to last 5 minutes.
local DURATION = {
    [58] = 120, [80] = 120,                             -- Paralyze
    [56] = 180, [79] = 180,                             -- Slow
    [216] = 120,                                        -- Gravity
    [254] = 180, [276] = 180,                           -- Blind
    [59] = 120, [359] = 120,                            -- Silence
    [253] = 90, [259] = 90, [273] = 90, [274] = 90,     -- Sleep
    [258] = 60, [362] = 60,                             -- Bind
    [252] = 5,                                          -- Stun
    [235] = 120, [236] = 120, [237] = 120, [238] = 120, [239] = 120, [240] = 120,   -- Burn .. Drown
};
for spell = 220, 229 do DURATION[spell] = 120; end      -- Poison

local enemies = {};     -- monster server id -> { [status id] = time it wears off }

-- act is an action packet as parsed by omni_action.lua.
status.on_action = function (act)
    local now = os.time();
    local spell = act.param;
    for _, target in ipairs(act.targets) do
        for _, a in ipairs(target.actions) do
            local list = enemies[target.id];
            if (list == nil) then
                list = {};
                enemies[target.id] = list;
            end

            if (act.category == 4 and SPELL_DAMAGE[a.message]) then
                -- Dia and Bio do damage, so they arrive as damage messages; they overwrite each other.
                local expiry = nil;
                if (spell == 23 or spell == 33 or spell == 230) then
                    expiry = now + 60;
                elseif (spell == 24 or spell == 231) then
                    expiry = now + 120;
                elseif (spell == 25 or spell == 232) then
                    expiry = now + 150;
                end
                if (spell == 23 or spell == 24 or spell == 25 or spell == 33) then
                    list[134] = expiry;
                    list[135] = nil;
                elseif (spell == 230 or spell == 231 or spell == 232) then
                    list[134] = nil;
                    list[135] = expiry;
                end
            elseif (STATUS_ON[a.message] and a.param ~= nil and a.param > 0) then
                -- "X receives the effect of Y": the parameter is the status id.
                list[a.param] = now + (DURATION[spell] or 300);
            end
        end
    end
end

-- data is the raw 0x029 message packet.
status.on_message = function (data)
    local target  = struct.unpack('i4', data, 0x08 + 1);
    local param   = struct.unpack('i4', data, 0x0C + 1);
    local message = struct.unpack('i2', data, 0x18 + 1);
    if (DEATH[message]) then
        enemies[target] = nil;
    elseif (STATUS_OFF[message] and enemies[target] ~= nil and param ~= nil) then
        enemies[target][param] = nil;
    end
end

status.on_zone = function ()
    enemies = {};
end

----------------------------------------------------------------------------------------------------
-- Buffs on party members (the game sends these in packet 0x076)
----------------------------------------------------------------------------------------------------
local party_buffs = {};     -- member server id -> list of status ids

pcall(function ()
    -- Pick up the list the game already has, so it works straight after loading.
    local base = ashita.memory.read_uint32(AshitaCore:GetPointerManager():Get('party.statusicons'));
    for member = 0, 4 do
        local ptr = base + (0x30 * member);
        local id = ashita.memory.read_uint32(ptr);
        if (id ~= 0) then
            local buffs = {};
            for i = 0, 31 do
                local high = ashita.memory.read_uint8(ptr + 8 + math.floor(i / 4));
                high = bit.lshift(bit.band(bit.rshift(high, math.fmod(i, 4) * 2), 0x03), 8);
                local buff = high + ashita.memory.read_uint8(ptr + 16 + i);
                if (buff == 255) then
                    break;
                end
                buffs[#buffs + 1] = buff;
            end
            party_buffs[id] = buffs;
        end
    end
end);

-- e is the packet event for 0x076.
status.on_party_buffs = function (e)
    local fresh = {};
    for member = 0, 4 do
        local offset = 0x04 + (0x30 * member) + 1;
        local id = struct.unpack('L', e.data, offset);
        if (id > 0) then
            local buffs = {};
            for i = 0, 31 do
                local high = bit.lshift(ashita.bits.unpack_be(e.data_raw, offset + 7, i * 2, 2), 8);
                local buff = high + struct.unpack('B', e.data, offset + 0x10 + i);
                if (buff == 255) then
                    break;
                end
                buffs[#buffs + 1] = buff;
            end
            fresh[id] = buffs;
        end
    end
    party_buffs = fresh;
end

----------------------------------------------------------------------------------------------------
-- What is on a given target
----------------------------------------------------------------------------------------------------
-- entity/index describe the target; returns a list of status ids (possibly empty).
status.ids_for = function (entity, index)
    local out = {};
    local party = AshitaCore:GetMemoryManager():GetParty();

    local server_id = entity.ServerId;

    if (index == party:GetMemberTargetIndex(0) or (server_id ~= nil and server_id ~= 0 and server_id == party:GetMemberServerId(0))) then
        -- Yourself.
        local buffs = AshitaCore:GetMemoryManager():GetPlayer():GetBuffs();
        if (buffs ~= nil) then
            for i = 0, 32 do
                local id = buffs[i];
                if (type(id) == 'number' and id >= 0 and id ~= 255) then
                    out[#out + 1] = id;
                end
            end
        end
        return out;
    end

    if (party_buffs[server_id] ~= nil) then
        return party_buffs[server_id];
    end

    local list = enemies[server_id];
    if (list ~= nil) then
        local now = os.time();
        for id, expiry in pairs(list) do
            if (expiry ~= nil and expiry > now) then
                out[#out + 1] = id;
            end
        end
        table.sort(out);
    end
    return out;
end

----------------------------------------------------------------------------------------------------
-- Icons (taken from the game's own status icons)
----------------------------------------------------------------------------------------------------
local icons = {};   -- status id -> { texture, handle } or false when there is none

local function icon_handle(id)
    local cached = icons[id];
    if (cached ~= nil) then
        return cached and cached.handle or nil;
    end
    icons[id] = false;
    if (id < 0 or id > 0x3FF) then
        return nil;
    end
    pcall(function ()
        local icon = AshitaCore:GetResourceManager():GetStatusIconByIndex(id);
        if (icon == nil) then
            return;
        end
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        if (ffi.C.D3DXCreateTextureFromFileInMemoryEx(d3d8.get_device(), icon.Bitmap, icon.ImageSize, 0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
                ffi.C.D3DFMT_A8R8G8B8, ffi.C.D3DPOOL_MANAGED, ffi.C.D3DX_DEFAULT, ffi.C.D3DX_DEFAULT, 0xFF000000, nil, nil, ptr) == ffi.C.S_OK) then
            local texture = d3d8.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
            icons[id] = { texture = texture, handle = tonumber(ffi.cast('uint32_t', texture)) };
        end
    end);
    return icons[id] and icons[id].handle or nil;
end

-- Name (and the game's description, when it has one) for a status, shown on hover.
local function show_tooltip(id)
    local res = AshitaCore:GetResourceManager();
    local name = res:GetString('buffs.names', id);
    if (name == nil or name == '') then
        name = string.format('Status %d', id);
    end
    imgui.BeginTooltip();
    imgui.Text((name:gsub('%%', '%%%%')));
    pcall(function ()
        local info = res:GetStatusIconByIndex(id);
        local text = info and info.Description and info.Description[1];
        if (text ~= nil and text ~= '') then
            imgui.Text((text:gsub('%%', '%%%%')));
        end
    end);
    imgui.EndTooltip();
end

-- Draw up to `max` icons in a row at the current cursor position.
-- Hovering an icon shows what it is.
status.draw = function (ids, size, max)
    local drawn = 0;
    for _, id in ipairs(ids) do
        if (drawn >= max) then
            break;
        end
        local handle = icon_handle(id);
        if (handle ~= nil) then
            if (drawn > 0) then
                imgui.SameLine(0, 2);
            end
            imgui.Image(handle, { size, size });
            if (imgui.IsItemHovered()) then
                show_tooltip(id);
            end
            drawn = drawn + 1;
        end
    end
    return drawn;
end

----------------------------------------------------------------------------------------------------
-- Your own buffs with time remaining (worked out the way the statustimers addon does)
----------------------------------------------------------------------------------------------------
local INFINITE = 0x7FFFFFFF;
local clock_ptr = nil;

-- The game's own clock, needed to turn a buff's end time into seconds left.
local function game_clock()
    if (clock_ptr == nil) then
        clock_ptr = ashita.memory.find('FFXiMain.dll', 0, '8B0D????????8B410C8B49108D04808D04808D04808D04C1C3', 2, 0) or 0;
    end
    if (clock_ptr == 0) then
        return nil;
    end
    local ptr = ashita.memory.read_uint32(clock_ptr);
    ptr = ashita.memory.read_uint32(ptr);
    return ashita.memory.read_uint32(ptr + 0x0C);
end

-- Seconds left for a raw timer value; -1 means it does not run out.
local function seconds_left(raw, now)
    if (raw == nil or raw == INFINITE or now == nil) then
        return -1;
    end
    local left = raw - (now - 0x3C307D70) * 60;
    while (left < -2147483648) do
        left = left + 0xFFFFFFFF;
    end
    if (left < 1) then
        return 0;
    end
    return math.ceil(left / 60);
end

-- Returns a list of { id, seconds } for your own status effects.
status.player_buffs = function ()
    local out = {};
    local player = AshitaCore:GetMemoryManager():GetPlayer();
    local icons = player:GetStatusIcons();
    local timers = player:GetStatusTimers();
    if (icons == nil) then
        return out;
    end
    local now = game_clock();
    for j = 1, 32 do
        local id = icons[j];
        if (type(id) == 'number' and id ~= 255 and id > 0) then
            out[#out + 1] = { id = id, seconds = seconds_left(timers and timers[j], now) };
        end
    end
    return out;
end

-- "2h", "29m", "45" (seconds), or nothing for effects that do not run out.
status.format_time = function (seconds)
    if (seconds == nil or seconds < 0) then
        return '';
    elseif (seconds > 3600) then
        return string.format('%dh', seconds / 3600);
    elseif (seconds >= 60) then
        return string.format('%dm', seconds / 60);
    end
    return string.format('%d', seconds);
end

-- Draw buffs in one line from window position (x, y): each icon with its time just to its right.
-- Stops before max_w pixels. Returns the width used.
status.draw_inline = function (buffs, x, y, size, max_w, text_scale)
    local dl = imgui.GetWindowDrawList();
    if (text_scale ~= nil) then imgui.SetWindowFontScale(text_scale); end
    local white = imgui.GetColorU32({ 1.0, 1.0, 1.0, 1.0 });
    local cx = x;
    local _, th = imgui.CalcTextSize('0');
    th = th or 12;
    for _, buff in ipairs(buffs) do
        local handle = icon_handle(buff.id);
        if (handle ~= nil) then
            local text = status.format_time(buff.seconds);
            local tw = (text ~= '') and (imgui.CalcTextSize(text) + 3) or 0;
            if (cx + size + tw - x > max_w) then break; end
            imgui.SetCursorPos({ cx, y });
            local sx, sy = imgui.GetCursorScreenPos();
            imgui.Image(handle, { size, size });
            if (imgui.IsItemHovered()) then
                show_tooltip(buff.id);
            end
            if (text ~= '') then
                dl:AddText({ sx + size + 2, sy + (size - th) / 2 }, white, text);
            end
            cx = cx + size + tw + 7;
        end
    end
    if (text_scale ~= nil) then imgui.SetWindowFontScale(1.0); end
    return cx - x;
end

-- Draw buffs in one line with each time UNDER its icon, packed close together.
-- (x, y) is the top of the icons; returns the width used.
-- text_dl / text_y (optional): draw the times with that draw list at that screen y instead
-- (used to put them just under the bar's frame line, outside the window).
status.draw_stacked = function (buffs, x, y, size, max_w, text_scale, gap, text_dl, text_y)
    local dl = imgui.GetWindowDrawList();
    if (text_scale ~= nil) then imgui.SetWindowFontScale(text_scale); end
    local white = imgui.GetColorU32({ 1.0, 1.0, 1.0, 1.0 });
    local shade = imgui.GetColorU32({ 0.0, 0.0, 0.0, 0.85 });
    gap = gap or 3;
    local cx = x;
    for _, buff in ipairs(buffs) do
        local handle = icon_handle(buff.id);
        if (handle ~= nil) then
            local text = status.format_time(buff.seconds);
            local tw = (text ~= '') and imgui.CalcTextSize(text) or 0;
            local cell = math.max(size, tw);
            if (cx + cell - x > max_w) then break; end
            imgui.SetCursorPos({ cx + math.floor((cell - size) / 2), y });
            local sx, sy = imgui.GetCursorScreenPos();
            imgui.Image(handle, { size, size });
            if (imgui.IsItemHovered()) then
                show_tooltip(buff.id);
            end
            if (text ~= '') then
                local tx = sx + math.floor((size - tw) / 2);
                local d, ty = text_dl or dl, text_y or (sy + size);
                d:AddText({ tx + 1, ty + 1 }, shade, text);
                d:AddText({ tx, ty }, white, text);
            end
            cx = cx + cell + gap;
        end
    end
    if (text_scale ~= nil) then imgui.SetWindowFontScale(1.0); end
    return cx - x;
end

----------------------------------------------------------------------------------------------------
-- Hiding the game's own buff icons (top-left of the screen)
--
-- Same technique as the statustimers addon: two small instructions in the game
-- decide whether to draw those icons, and blanking them switches the icons off.
-- The original instructions are kept and put back when omni unloads.
----------------------------------------------------------------------------------------------------
local native = { found = nil, ptr = { 0, 0 }, original = { 0, 0 } };

-- Safe to call repeatedly; it only acts when the icons are currently being drawn.
status.hide_native = function ()
    -- Find the two spots that draw the game's icons. Another addon (statustimers, HXUI...)
    -- may already have switched them off (90 90), so look for that form too, and keep
    -- looking until found - when that addon is unloaded it puts the jump back and omni
    -- then takes over.
    if (not native.found) then
        local rest = '55518B0D????????E8????????85C07F??8BDE';
        local function find(prefix, n) return ashita.memory.find('FFXiMain.dll', 0, prefix .. rest, 0, n) or 0; end
        local a, b = find('75??', 0), find('75??', 1);
        if (a == 0 or b == 0 or a == b) then
            local c, d = find('9090', 0), find('9090', 1);
            local list = {};
            for _, v in ipairs({ a, b, c, d }) do
                if (v ~= 0) then
                    local dup = false;
                    for _, w in ipairs(list) do if (w == v) then dup = true; end end
                    if (not dup) then list[#list + 1] = v; end
                end
            end
            a, b = list[1] or 0, list[2] or 0;
        end
        native.ptr[1], native.ptr[2] = a, b;
        native.found = (a ~= 0 and b ~= 0 and a ~= b);
    end
    if (not native.found) then
        return false;
    end
    for i = 1, 2 do
        local current = ashita.memory.read_uint16(native.ptr[i]);
        -- Only touch it if it still holds the instruction we expect (a short conditional jump).
        if (current ~= 0x9090 and bit.band(current, 0xFF) == 0x75) then
            native.original[i] = current;
            ashita.memory.write_uint16(native.ptr[i], 0x9090);
        end
    end
    return true;
end

status.restore_native = function ()
    if (not native.found) then
        return;
    end
    for i = 1, 2 do
        if (native.original[i] ~= 0) then
            ashita.memory.write_uint16(native.ptr[i], native.original[i]);
            native.original[i] = 0;
        end
    end
end

status.unload = function ()
    pcall(status.restore_native);
    icons = {};
end

return status;
