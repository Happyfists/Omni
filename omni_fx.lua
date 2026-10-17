--[[
    omni_fx.lua - spell lines: targetlines-style lines between fighters, with an animation for
    each kind of action.

      * Melee: a dotted chain running from attacker to target (blue for your side, red for
        monsters), fading after a few seconds - like Jyouya's targetlines.
      * While a spell is being cast: a ring of the spell's colour turns round the caster.
      * Painted pictures for almost everything (assets/fx/, made with Canva's AI image generator);
        "AI art" in Options switches back to the drawn versions.
      * Spells, by element: Thunder - a lightning bolt; Fire - a fireball and a burst; Ice - ice shards that
        shatter; Water - a wave and a splash; Wind - wind blades; Earth - rocks thrown in an arc;
        Light - a golden beam with sparkles; Dark - purple tendrils.
      * Cures: green sparkles rising round the target. Raise: a golden halo floats down.
        Buffs: runes orbiting the target. Enfeebles: a curse sigil above the target.
        Songs: notes floating to the target.
      * Ranged attacks: a bullet tracer. Weapon skills: gold slashes (red for monster TP moves).

    Settings (Options tab): fx_on, fx_party (only fights with you, your party or alliance),
    fx_lines (all lines: the target chains between fighters and the thin caster-to-target lines), fx_art (the painted AI pictures; off = the drawn versions).

    The world-to-screen maths and the bone lookup come from Jyouya's targetlines (credited).
]]

local imgui = require('imgui');
local ffi   = require('ffi');
local d3d   = require('d3d8');
local C     = ffi.C;
local action = require('omni_action');

local atan2 = math.atan2 or math.atan;

local fx = {};
fx.settings = nil;

local function S() return fx.settings or {}; end
local function on(key, default) local v = S()[key]; if v == nil then return default; end return v == true; end
-- Lines: the target lines between fighters and the thin lines from caster to target (fx_lines).
local function lines_on() return on('fx_lines', true); end

----------------------------------------------------------------------------------------------------
-- Entities
----------------------------------------------------------------------------------------------------
local function index_from_id(id)
    local em = AshitaCore:GetMemoryManager():GetEntity();
    if bit.band(id, 0x1000000) ~= 0 then
        local index = bit.band(id, 0xFFF);
        if index >= 0x900 then index = index - 0x100; end
        if index < 0x900 and em:GetServerId(index) == id then return index; end
    end
    for i = 1, 0x8FF do
        if em:GetServerId(i) == id then return i; end
    end
    return 0;
end

local function is_mob(idx)
    local f = AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(idx) or 0;
    return bit.band(f, 0x10) ~= 0 and bit.band(f, 0x100) == 0;
end

-- Server ids of you, your party and alliance.
local function party_ids()
    local ids = {};
    pcall(function ()
        local p = AshitaCore:GetMemoryManager():GetParty();
        -- You always count, even if the party list says you are not in one (VanaCore can).
        local me = p:GetMemberServerId(0);
        if me and me ~= 0 then ids[me] = true; end
        for i = 0, 17 do
            local id = p:GetMemberServerId(i);
            if id and id ~= 0 and (p:GetMemberIsActive(i) ~= 0 or i == 0) then ids[id] = true; end
        end
    end);
    pcall(function ()
        local em = AshitaCore:GetMemoryManager():GetEntity();
        local idx = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
        local id = em:GetServerId(idx);
        if id and id ~= 0 then ids[id] = true; end
    end);
    return ids;
end

-- A point in the world at chest height (D3D order: x, height, z). From targetlines' bone lookup.
local function chest(idx)
    local x, y, z = nil, nil, nil;
    local ok = pcall(function ()
        local ptr = AshitaCore:GetMemoryManager():GetEntity():GetActorPointer(idx);
        if ptr == nil or ptr == 0 then error('no actor'); end
        local px = ashita.memory.read_float(ptr + 0x678);
        local feet = ashita.memory.read_float(ptr + 0x67C);
        local pz = ashita.memory.read_float(ptr + 0x680);
        local base = ashita.memory.read_uint32(ptr + 0x6B8);
        local off = ashita.memory.read_uint32(base + 0x0C);
        local sk = ashita.memory.read_uint32(off);
        local bones = ashita.memory.read_uint16(sk + 0x32);
        local gen = sk + 0x30 + 0x04 + 0x1E * bones + 4;
        local by = ashita.memory.read_float(gen + 2 * 0x1A + 0x0E + 0x4);
        x, y, z = px, feet + by / 2, pz;
    end);
    if ok and x then return x, y, z; end
    -- Fallback: feet position, raised a little (up is negative).
    pcall(function ()
        local em = AshitaCore:GetMemoryManager():GetEntity();
        x = em:GetLocalPositionX(idx);
        z = em:GetLocalPositionY(idx);
        y = em:GetLocalPositionZ(idx) - 0.9;
    end);
    return x, y, z;
end

----------------------------------------------------------------------------------------------------
-- Projection
----------------------------------------------------------------------------------------------------
local M = {};
local SW, SH = 1920, 1080;

local function load_frame()
    local dev = d3d.get_device();
    local _, V = dev:GetTransform(C.D3DTS_VIEW);
    local _, P = dev:GetTransform(C.D3DTS_PROJECTION);
    local v = { { V._11, V._12, V._13, V._14 }, { V._21, V._22, V._23, V._24 }, { V._31, V._32, V._33, V._34 }, { V._41, V._42, V._43, V._44 } };
    local p = { { P._11, P._12, P._13, P._14 }, { P._21, P._22, P._23, P._24 }, { P._31, P._32, P._33, P._34 }, { P._41, P._42, P._43, P._44 } };
    for r = 1, 4 do
        M[r] = M[r] or {};
        for c = 1, 4 do
            M[r][c] = v[r][1] * p[1][c] + v[r][2] * p[2][c] + v[r][3] * p[3][c] + v[r][4] * p[4][c];
        end
    end
    -- Screen size in ImGui's units.
    local ok = pcall(function ()
        local io = imgui.GetIO();
        local ds = io.DisplaySize;
        local w = ds.x or ds[1];
        local h = ds.y or ds[2];
        if w and h and w > 0 then SW, SH = w, h; else error('no size'); end
    end);
    if not ok then
        pcall(function () local _, vp = dev:GetViewport(); SW, SH = vp.Width, vp.Height; end);
    end
end

local function project(x, y, z)
    if x == nil then return nil; end
    local cx = x * M[1][1] + y * M[2][1] + z * M[3][1] + M[4][1];
    local cy = x * M[1][2] + y * M[2][2] + z * M[3][2] + M[4][2];
    local cw = x * M[1][4] + y * M[2][4] + z * M[3][4] + M[4][4];
    if cw < 0.2 then return nil; end
    return (cx / cw + 1) * 0.5 * SW, (1 - cy / cw) * 0.5 * SH, cw;
end

----------------------------------------------------------------------------------------------------
-- Drawing helpers
----------------------------------------------------------------------------------------------------
local dl = nil;
local function col(r, g, b, a) return imgui.GetColorU32({ r, g, b, math.max(0, math.min(1, a)) }); end
local function line(x1, y1, x2, y2, c, w) dl:AddLine({ x1, y1 }, { x2, y2 }, c, w or 1); end
local function dot(x, y, r, c) if r > 0.3 then dl:AddCircleFilled({ x, y }, r, c, 12); end end
local function ring(x, y, r, c, w) if r > 0.5 then dl:AddCircle({ x, y }, r, c, 24, w or 1.5); end end

-- A glowing line: wide faint halo, then a bright core.
local function glow(x1, y1, x2, y2, rgb, a, w)
    line(x1, y1, x2, y2, col(rgb[1], rgb[2], rgb[3], a * 0.18), w * 4);
    line(x1, y1, x2, y2, col(rgb[1], rgb[2], rgb[3], a * 0.40), w * 2);
    line(x1, y1, x2, y2, col(math.min(1, rgb[1] + 0.4), math.min(1, rgb[2] + 0.4), math.min(1, rgb[3] + 0.4), a), w);
end
local function glow_dot(x, y, r, rgb, a)
    dot(x, y, r * 2.2, col(rgb[1], rgb[2], rgb[3], a * 0.18));
    dot(x, y, r * 1.4, col(rgb[1], rgb[2], rgb[3], a * 0.45));
    dot(x, y, r, col(math.min(1, rgb[1] + 0.35), math.min(1, rgb[2] + 0.35), math.min(1, rgb[3] + 0.35), a));
end

-- Point on an arc from (x1,y1) to (x2,y2), lifted by `lift` of the distance.
local function arc_pt(x1, y1, x2, y2, s, lift)
    local d = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2);
    local cx, cy = (x1 + x2) / 2, (y1 + y2) / 2 - d * (lift or 0.25);
    local u = 1 - s;
    return u * u * x1 + 2 * u * s * cx + s * s * x2, u * u * y1 + 2 * u * s * cy + s * s * y2;
end

-- Draw the arc from s=a to s=b as a glowing line.
local function glow_arc(x1, y1, x2, y2, a, b, lift, rgb, alpha, w, steps)
    steps = steps or 16;
    local px, py = arc_pt(x1, y1, x2, y2, a, lift);
    for i = 1, steps do
        local s = a + (b - a) * i / steps;
        local qx, qy = arc_pt(x1, y1, x2, y2, s, lift);
        glow(px, py, qx, qy, rgb, alpha, w);
        px, py = qx, qy;
    end
end

-- Small seeded random, so an effect's jitter is steady between frames.
local function rnd(seed, i) local v = math.sin(seed * 12.9898 + i * 78.233) * 43758.5453; return v - math.floor(v); end

local function ease_out(t) return 1 - (1 - t) * (1 - t); end

----------------------------------------------------------------------------------------------------
-- The effects. Each gets the two screen points, progress u (0..1), age (s), and the effect.
----------------------------------------------------------------------------------------------------
local RGB = {
    fire = { 1.00, 0.45, 0.10 }, ice = { 0.55, 0.85, 1.00 }, wind = { 0.40, 0.95, 0.50 },
    earth = { 0.70, 0.50, 0.25 }, thunder = { 0.75, 0.70, 1.00 }, water = { 0.25, 0.55, 1.00 },
    light = { 1.00, 0.90, 0.50 }, dark = { 0.65, 0.30, 0.95 }, heal = { 0.45, 1.00, 0.55 },
    buff = { 0.50, 0.85, 1.00 }, hex = { 1.00, 0.40, 0.80 }, gold = { 1.00, 0.80, 0.30 },
    red = { 1.00, 0.25, 0.25 }, player = { 0.15, 0.55, 1.00 }, enemy = { 1.00, 0.15, 0.20 },
    song = { 1.00, 0.85, 0.95 },
};

local TRAVEL = 0.55;   -- part of the effect spent flying; the rest is the hit

-- Volleys of three: the progress (0..1) of shot j (0, 1, 2), each a little behind the last.
-- How many shots a spell fires: its tier (Fire 1, Fire II 2, Fire III 3 ...), kept in e.n.
local function shots(e) return math.max(1, math.min(6, (e and e.n) or 1)); end
-- Progress (0..1) of shot j of n, each a little behind the last; all have landed by T.
local function shot(u, T, j, n) return ease_out(math.max(0, math.min(1, u / T * (1 + 0.15 * (n - 1)) - j * 0.15))); end
-- Spread shot j of n between two arc heights, and to the sides.
local function lift(j, n, lo, hi) return lo + (hi - lo) * ((n > 1) and (j / (n - 1)) or 0.5); end
local function side(j, n) return j - (n - 1) / 2; end

local function burst(x, y, k, rgb, n, size, seed)
    local a = 1 - k;
    ring(x, y, size * (0.3 + k), col(rgb[1], rgb[2], rgb[3], a * 0.8), 2.5);
    for i = 1, n do
        local ang = (i / n) * math.pi * 2 + rnd(seed, i) * 0.5;
        local r1, r2 = size * 0.25 * (1 + k), size * (0.5 + k * 0.9);
        line(x + math.cos(ang) * r1, y + math.sin(ang) * r1, x + math.cos(ang) * r2, y + math.sin(ang) * r2,
            col(rgb[1], rgb[2], rgb[3], a), 2);
    end
end

----------------------------------------------------------------------------------------------------
-- Painted sprites (assets/fx/*.png, made with an AI image generator): loaded once, drawn turned
-- to face the way the spell flies.
----------------------------------------------------------------------------------------------------
pcall(ffi.cdef, [[
    HRESULT __stdcall D3DXCreateTextureFromFileA(IDirect3DDevice8* pDevice, const char* pSrcFile, IDirect3DTexture8** ppTexture);
]]);
local tex = {};          -- name -> { t = texture, h = handle } or false
local function sprite(name)
    local v = tex[name];
    if v ~= nil then return v and v.h or nil; end
    tex[name] = false;
    pcall(function ()
        local ptr = ffi.new('IDirect3DTexture8*[1]');
        local path = string.format('%s/assets/fx/%s.png', addon.path, name);
        if C.D3DXCreateTextureFromFileA(d3d.get_device(), path, ptr) ~= C.S_OK then return; end
        local t = ffi.new('IDirect3DTexture8*', ptr[0]);
        d3d.gc_safe_release(t);
        tex[name] = { t = t, h = tonumber(ffi.cast('uint32_t', t)) };
    end);
    return tex[name] and tex[name].h or nil;
end

-- Draw sprite `name` so that its point (ax, ay) (0..1 across the picture) sits at (x, y), w x h
-- pixels, turned by `ang` radians. Falls back to an unturned picture if quads are not available.
local quad_ok = nil;
local function art_on() return on('fx_art', false); end   -- off by default: the drawn look
local function draw_sprite(name, x, y, ax, ay, w, h, ang, alpha, flipv, tint)
    if not art_on() then return false; end
    local hnd = sprite(name);
    if hnd == nil then return false; end
    local cs, sn = math.cos(ang), math.sin(ang);
    local function pt(u, v)
        local lx, ly = (u - ax) * w, (v - ay) * h;
        return { x + lx * cs - ly * sn, y + lx * sn + ly * cs };
    end
    local col = imgui.GetColorU32({ tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1, math.max(0, math.min(1, alpha)) });
    local v0, v1 = 0, 1;
    if flipv then v0, v1 = 1, 0; end
    if quad_ok ~= false then
        local ok = pcall(function ()
            dl:AddImageQuad(hnd, pt(0, 0), pt(1, 0), pt(1, 1), pt(0, 1), { 0, v0 }, { 1, v0 }, { 1, v1 }, { 0, v1 }, col);
        end);
        if ok then quad_ok = true; return true; end
        quad_ok = false;
    end
    -- Unturned fallback: mirror it when flying left.
    local left = cs < 0;
    local px = left and (1 - ax) or ax;
    local x0, y0 = x - px * w, y - ay * h;
    pcall(function () dl:AddImage(hnd, { x0, y0 }, { x0 + w, y0 + h }, { left and 1 or 0, v0 }, { left and 0 or 1, v1 }, col); end);
    return true;
end

-- A circle or ellipse outline (part of one with a0..a1), as short lines.
local function ellipse(x, y, rx, ry, c, w, a0, a1, n)
    a0, a1, n = a0 or 0, a1 or math.pi * 2, n or 24;
    local px, py = x + math.cos(a0) * rx, y + math.sin(a0) * ry;
    for i = 1, n do
        local a = a0 + (a1 - a0) * i / n;
        local qx, qy = x + math.cos(a) * rx, y + math.sin(a) * ry;
        line(px, py, qx, qy, c, w);
        px, py = qx, qy;
    end
end

local DRAW = {};
local DRAW_PLAIN = {};

DRAW.thunder = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.7) and 1 or (1 - (u - 0.7) / 0.3);
    if math.floor(age * 30) % 4 == 3 then a = a * 0.45; end            -- flicker
    local d = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2);
    local ang = atan2(y2 - y1, x2 - x1);
    local h = math.max(22, math.min(70, d * 0.28));
    -- One bolt per tier (Thunder II: two), a moment apart, each jumping about on its own.
    local drawn = false;
    local n = shots(e);
    for j = 0, n - 1 do
        local aj = a * math.max(0, math.min(1, (u - j * 0.08) * 8));
        local flip = math.floor(age / 0.07 + j) % 2 == 1;
        local off = side(j, n) * 0.07;
        if aj > 0 and draw_sprite('thunder', x1, y1, 0.03, 0.5, d / 0.95, h, ang + off, aj, flip) then drawn = true; end
    end
    if not (art_on() and sprite('thunder')) then
        -- No picture: the drawn bolt.
        local seed = e.seed + math.floor(age / 0.06);
        local nx, ny = -(y2 - y1) / math.max(d, 1), (x2 - x1) / math.max(d, 1);
        local px, py = x1, y1;
        for i = 1, 10 do
            local off = (i == 10) and 0 or (rnd(seed, i) - 0.5) * d * 0.16;
            local qx, qy = x1 + (x2 - x1) * i / 10 + nx * off, y1 + (y2 - y1) * i / 10 + ny * off;
            glow(px, py, qx, qy, RGB.thunder, a, 2.2);
            px, py = qx, qy;
        end
    end
    glow_dot(x2, y2, 6 + 10 * a, { 1.0, 1.0, 0.7 }, a * 0.8);
end

DRAW.fire = function (x1, y1, x2, y2, u, age, e)
    if u < TRAVEL then
        local s = ease_out(u / TRAVEL);
        local hx, hy = arc_pt(x1, y1, x2, y2, s, 0.22);
        -- One fireball per tier, each on its own arc.
        local painted = false;
        local n = shots(e);
        for j = 0, n - 1 do
            local sj = shot(u, TRAVEL, j, n);
            local lj = lift(j, n, 0.12, 0.36);
            if sj > 0 and sj < 1 then
                local fx_, fy_ = arc_pt(x1, y1, x2, y2, sj, lj);
                local bx, by = arc_pt(x1, y1, x2, y2, math.max(0, sj - 0.04), lj);
                local ang = (sj < 0.04) and atan2(y2 - y1, x2 - x1) or atan2(fy_ - by, fx_ - bx);
                local wob = 1 + math.sin(age * 40 + j) * 0.04;
                local sc = (1 - 0.5 * sj) * wob;
                local big = math.max(64, 90 - (n - 1) * 7);
                if draw_sprite('fire', fx_, fy_, 0.66, 0.5, big * sc, big * 0.5 * sc, ang, math.min(1, sj * 12)) then painted = true; end
            elseif sj >= 1 then
                glow_dot(x2, y2, 5, RGB.fire, 0.8);
                painted = painted or art_on();
            end
        end
        if not (art_on() and sprite('fire')) then
            for i = 8, 1, -1 do
                local tx, ty = arc_pt(x1, y1, x2, y2, math.max(0, s - i * 0.035), 0.22);
                local k = i / 8;
                dot(tx, ty, 7 * (1 - k * 0.8), col(1.0, 0.75 - k * 0.6, 0.1, (1 - k) * 0.8));
            end
            glow_dot(hx, hy, 6, RGB.fire, 1);
        end
    else
        local k = (u - TRAVEL) / (1 - TRAVEL);
        local sz = 18 + 36 * ease_out(k);
        if not draw_sprite('boom', x2, y2, 0.5, 0.5, sz, sz, k * 0.6, (1 - k) * 1.2) then
            dot(x2, y2, 26 * ease_out(k), col(1.0, 0.55, 0.1, (1 - k) * 0.45));
            dot(x2, y2, 14 * ease_out(k), col(1.0, 0.9, 0.4, (1 - k) * 0.7));
            burst(x2, y2, k, RGB.fire, 10, 34, e.seed);
        end
    end
end

DRAW.ice = function (x1, y1, x2, y2, u, age, e)
    local d = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2);
    local dx, dy = (x2 - x1) / math.max(d, 1), (y2 - y1) / math.max(d, 1);
    if u < TRAVEL then
        local n = shots(e);
        for j = 0, n - 1 do
            local s = shot(u, TRAVEL, j, n);
            local hx, hy = arc_pt(x1, y1, x2, y2, s, lift(j, n, 0.1, 0.24));
            local L, W = 14, 4;
            dl:AddTriangleFilled({ hx + dx * L, hy + dy * L }, { hx - dy * W, hy + dx * W }, { hx + dy * W, hy - dx * W }, col(0.85, 0.97, 1.0, 0.95));
            dl:AddTriangleFilled({ hx - dx * L * 0.6, hy - dy * L * 0.6 }, { hx + dy * W, hy - dx * W }, { hx - dy * W, hy + dx * W }, col(0.45, 0.80, 1.0, 0.8));
            glow_dot(hx, hy, 3, RGB.ice, 0.6);
        end
    else
        local k = (u - TRAVEL) / (1 - TRAVEL);
        for i = 1, 6 do
            local ang = i / 6 * math.pi * 2;
            local r = 6 + 28 * ease_out(k);
            glow(x2, y2, x2 + math.cos(ang) * r, y2 + math.sin(ang) * r, RGB.ice, 1 - k, 1.5);
            local sx, sy = x2 + math.cos(ang + 0.5) * r * 0.8, y2 + math.sin(ang + 0.5) * r * 0.8;
            dot(sx, sy, 2.5, col(0.9, 1, 1, 1 - k));
        end
        ring(x2, y2, 10 + 20 * k, col(0.7, 0.95, 1, (1 - k) * 0.7), 2);
    end
end

DRAW.water = function (x1, y1, x2, y2, u, age, e)
    local d = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2);
    local nx, ny = -(y2 - y1) / math.max(d, 1), (x2 - x1) / math.max(d, 1);
    local head = math.min(1, u / TRAVEL);
    local fade = (u < TRAVEL) and 1 or (1 - (u - TRAVEL) / (1 - TRAVEL));
    local tail = math.max(0, head - 0.45);
    local steps = 18;
    local px, py = nil, nil;
    for i = 0, steps do
        local s = tail + (head - tail) * i / steps;
        local wv = math.sin(s * 18 - age * 14) * 7;
        local qx, qy = x1 + (x2 - x1) * s + nx * wv, y1 + (y2 - y1) * s + ny * wv;
        if px then glow(px, py, qx, qy, RGB.water, fade * (0.4 + 0.6 * i / steps), 2.5); end
        px, py = qx, qy;
    end
    if u >= TRAVEL then
        local k = (u - TRAVEL) / (1 - TRAVEL);
        for i = 1, 7 do
            local ang = -math.pi * (0.15 + 0.7 * i / 8);
            local sp = 30 + rnd(e.seed, i) * 20;
            local sx = x2 + math.cos(ang) * sp * k;
            local sy = y2 + math.sin(ang) * sp * k + 60 * k * k;
            dot(sx, sy, 3, col(0.6, 0.85, 1.0, 1 - k));
        end
        ring(x2, y2 + 6, 8 + 22 * k, col(0.4, 0.7, 1.0, (1 - k) * 0.8), 2);
    end
end

DRAW.wind = function (x1, y1, x2, y2, u, age, e)
    -- Wind blades: three green crescents slicing across, then a small burst.
    local ang = atan2(y2 - y1, x2 - x1);
    local nx, ny = -math.sin(ang), math.cos(ang);
    local n = shots(e);
    for j = 0, n - 1 do
        local s = math.max(0, math.min(1, u * 1.6 - j * 0.15));
        if s > 0 and s < 1 then
            local a = 1 - math.max(0, s - 0.8) * 5;
            local hx = x1 + (x2 - x1) * s + nx * side(j, n) * 10;
            local hy = y1 + (y2 - y1) * s + ny * side(j, n) * 10;
            ellipse(hx, hy, 11, 11, col(0.4, 0.95, 0.5, a * 0.35), 6, ang - 1.1, ang + 1.1, 10);
            ellipse(hx, hy, 11, 11, col(0.75, 1.0, 0.8, a), 2, ang - 1.1, ang + 1.1, 10);
        end
    end
    if u > 0.55 then burst(x2, y2, (u - 0.55) / 0.45, RGB.wind, 6, 20, e.seed); end
end

DRAW.earth = function (x1, y1, x2, y2, u, age, e)
    if u < TRAVEL then
        for j = 1, 4 do
            local s = ease_out(math.max(0, math.min(1, u / TRAVEL * 1.1 - j * 0.04)));
            local hx, hy = arc_pt(x1, y1, x2, y2, s, 0.35 + rnd(e.seed, j) * 0.1);
            local r = 4 + rnd(e.seed, j + 9) * 4;
            local t = age * 10 + j;
            local p = {};
            for q = 1, 4 do
                local ang = t + q * math.pi / 2;
                p[q] = { hx + math.cos(ang) * r, hy + math.sin(ang) * r * 0.8 };
            end
            dl:AddQuadFilled(p[1], p[2], p[3], p[4], col(0.55, 0.38, 0.20, 1));
            dl:AddQuad(p[1], p[2], p[3], p[4], col(0.85, 0.65, 0.35, 0.9), 1);
        end
    else
        local k = (u - TRAVEL) / (1 - TRAVEL);
        for i = 1, 6 do
            local dir = (i - 3.5) / 3;
            dot(x2 + dir * 34 * k, y2 + 10 - 6 * k, 8 + 10 * k, col(0.65, 0.50, 0.30, (1 - k) * 0.35));
        end
        for i = 1, 5 do
            local dir = (i - 3) / 2;
            local sx = x2 + dir * 26 * k;
            local sy = y2 - 30 * k + 50 * k * k;
            dl:AddQuadFilled({ sx - 3, sy }, { sx, sy - 3 }, { sx + 3, sy }, { sx, sy + 3 }, col(0.6, 0.42, 0.22, 1 - k));
        end
    end
end

DRAW.light = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.6) and math.min(1, u * 5) or (1 - (u - 0.6) / 0.4);
    -- A beam falls on the target from above, and a thin line from the caster.
    for w = 3, 1, -1 do
        dl:AddRectFilled({ x2 - 6 * w, y2 - 220 }, { x2 + 6 * w, y2 + 6 }, col(1.0, 0.92, 0.55, a * 0.12 * (4 - w)), 4);
    end
    if lines_on() then glow(x1, y1, x2, y2, RGB.light, a * 0.35, 1); end
    for i = 1, 8 do
        local ph = (age * 1.4 + rnd(e.seed, i)) % 1;
        local sx = x2 + (rnd(e.seed, i + 20) - 0.5) * 50;
        local sy = y2 + 10 - ph * 70;
        local r = 4 * (1 - ph);
        local c = col(1, 1, 0.8, a * (1 - ph));
        line(sx - r, sy, sx + r, sy, c, 1.5); line(sx, sy - r, sx, sy + r, c, 1.5);
    end
end

DRAW.dark = function (x1, y1, x2, y2, u, age, e)
    local d = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2);
    local nx, ny = -(y2 - y1) / math.max(d, 1), (x2 - x1) / math.max(d, 1);
    local head = math.min(1, u / TRAVEL);
    local fade = (u < TRAVEL) and 1 or (1 - (u - TRAVEL) / (1 - TRAVEL));
    for t = 1, 3 do
        local px, py = x1, y1;
        local steps = 16;
        for i = 1, steps do
            local s = head * i / steps;
            local wv = math.sin(s * 9 + age * 7 + t * 2.1) * 12 * math.sin(s * math.pi);
            local qx, qy = x1 + (x2 - x1) * s + nx * wv, y1 + (y2 - y1) * s + ny * wv;
            line(px, py, qx, qy, col(0.35, 0.10, 0.55, fade * 0.35), 6);
            line(px, py, qx, qy, col(0.75, 0.45, 1.0, fade * 0.9), 1.6);
            px, py = qx, qy;
        end
    end
    if u >= TRAVEL then
        local k = (u - TRAVEL) / (1 - TRAVEL);
        dot(x2, y2, 22 * (1 - k * 0.5), col(0.15, 0.0, 0.25, (1 - k) * 0.55));
        ring(x2, y2, 10 + 24 * k, col(0.75, 0.4, 1.0, 1 - k), 2);
    end
end

DRAW.heal = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.75) and 1 or (1 - (u - 0.75) / 0.25);
    if e.src ~= e.dst and lines_on() then glow(x1, y1, x2, y2, RGB.heal, a * 0.3 * math.max(0, 1 - u * 2), 1.2); end
    ring(x2, y2 + 18, 14 + 10 * math.sin(u * math.pi), col(0.5, 1.0, 0.6, a * 0.6), 2);
    for i = 1, 10 do
        local ph = (u * 1.3 + rnd(e.seed, i)) % 1;
        local ang = rnd(e.seed, i + 30) * math.pi * 2 + age * 2;
        local sx = x2 + math.cos(ang) * 18;
        local sy = y2 + 20 - ph * 60;
        local r = 4 * (1 - ph * 0.6);
        local c = col(0.8, 1.0, 0.8, a * (1 - ph));
        line(sx - r, sy, sx + r, sy, c, 1.5); line(sx, sy - r, sx, sy + r, c, 1.5);
        dot(sx, sy, 1.5, col(1, 1, 1, a * (1 - ph)));
    end
end

DRAW.buff = function (x1, y1, x2, y2, u, age, e)
    -- Orbit runes: four little diamonds circling the target.
    local a = (u < 0.2) and (u / 0.2) or (1 - (u - 0.2) / 0.8);
    if e.src ~= e.dst and lines_on() then glow(x1, y1, x2, y2, RGB.buff, a * 0.25 * math.max(0, 1 - u * 3), 1); end
    ellipse(x2, y2, 24, 9, col(0.5, 0.85, 1.0, a * 0.25), 1);
    for i = 0, 3 do
        local an = age * 2.5 + i * math.pi / 2;
        local rx, ry = x2 + math.cos(an) * 24, y2 + math.sin(an) * 9;
        local depth = 0.5 + math.sin(an) * 0.5;
        local r = 4;
        local c = col(0.75, 0.95, 1.0, a * (0.4 + depth * 0.6));
        line(rx, ry - r, rx + r, ry, c, 1.5); line(rx + r, ry, rx, ry + r, c, 1.5);
        line(rx, ry + r, rx - r, ry, c, 1.5); line(rx - r, ry, rx, ry - r, c, 1.5);
        glow_dot(rx, ry, 1.5, RGB.buff, a * 0.6);
    end
end

DRAW.hex = function (x1, y1, x2, y2, u, age, e)
    -- Curse sigil: a turning star in a ring above the target, dripping.
    local a = (u < 0.2) and (u / 0.2) or (1 - (u - 0.2) / 0.8);
    local cx, cy, r = x2, y2 - 40, 14;
    ring(cx, cy, r, col(1.0, 0.45, 0.85, a), 2);
    local px, py = nil, nil;
    for i = 0, 5 do
        local an = -math.pi / 2 + i * 4 * math.pi / 5 + age * 0.8;
        local qx, qy = cx + math.cos(an) * r, cy + math.sin(an) * r;
        if px then line(px, py, qx, qy, col(1.0, 0.75, 0.95, a), 1.5); end
        px, py = qx, qy;
    end
    for i = 0, 3 do
        local ph = (age + i / 4) % 1;
        dot(cx + (i - 1.5) * 6, cy + r + ph * 28, 2.2 * (1 - ph), col(1.0, 0.4, 0.8, a * (1 - ph)));
    end
end

DRAW.song = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.8) and 1 or (1 - (u - 0.8) / 0.2);
    for i = 1, 4 do
        local s = math.max(0, math.min(1, u * 1.4 - i * 0.1));
        local hx, hy = arc_pt(x1, y1, x2, y2, s, 0.2);
        hy = hy + math.sin(age * 8 + i) * 5;
        local c = col(1, 0.85, 0.95, a);
        dot(hx, hy, 3.5, c);
        line(hx + 3, hy, hx + 3, hy - 12, c, 1.5);
        line(hx + 3, hy - 12, hx + 8, hy - 9, c, 1.5);
    end
end

DRAW.arrow = function (x1, y1, x2, y2, u, age, e)
    -- Bullet tracer: a muzzle flash, a fast streak, sparks on the hit.
    if u < 0.12 then glow_dot(x1 + (x2 - x1) * 0.04, y1 + (y2 - y1) * 0.04, 7 * (1 - u / 0.12), { 1.0, 0.82, 0.47 }, 1); end
    local s = math.min(1, u / 0.18);
    local t0 = math.max(0, s - 0.35);
    local a = (u < 0.3) and 1 or math.max(0, 1 - (u - 0.3) / 0.3);
    glow(x1 + (x2 - x1) * t0, y1 + (y2 - y1) * t0, x1 + (x2 - x1) * s, y1 + (y2 - y1) * s, { 1.0, 0.86, 0.59 }, a, 1);
    if u > 0.18 and u < 0.6 then
        local k = (u - 0.18) / 0.42;
        local back = atan2(y1 - y2, x1 - x2);
        for i = 1, 6 do
            local an = back + (rnd(e.seed, i) - 0.5) * 1.6;
            line(x2, y2, x2 + math.cos(an) * 16 * k, y2 + math.sin(an) * 16 * k, col(1.0, 0.9, 0.6, 1 - k), 1.5);
        end
    end
end

DRAW.raise = function (x1, y1, x2, y2, u, age, e)
    -- Halo descent: a golden ring floats down onto the target, then sparkles.
    local a = (u < 0.85) and 1 or (1 - (u - 0.85) / 0.15);
    local y = (y2 - 140) + 114 * ease_out(math.min(1, u / 0.6));
    ellipse(x2, y, 15, 5, col(1.0, 0.84, 0.43, a), 2.5);
    ellipse(x2, y, 15, 5, col(1.0, 1.0, 0.9, a * 0.6), 1);
    glow_dot(x2, y, 3, RGB.gold, a * 0.4);
    if u > 0.6 then
        local k = (u - 0.6) / 0.4;
        glow_dot(x2, y2, 10 * k, RGB.gold, a * 0.6);
        for i = 1, 8 do
            local sx = x2 + (rnd(e.seed, i) - 0.5) * 44;
            local sy = y2 + 10 - k * 44 * rnd(e.seed, i + 3);
            local c = col(1, 1, 0.8, a * (1 - k));
            line(sx - 3, sy, sx + 3, sy, c, 1.2); line(sx, sy - 3, sx, sy + 3, c, 1.2);
        end
    end
end

local function slashes(x1, y1, x2, y2, u, age, e, rgb)
    -- A streak from the attacker, then three slashes across the target.
    if u < 0.3 then
        local s = u / 0.3;
        glow_arc(x1, y1, x2, y2, math.max(0, s - 0.3), s, 0.15, rgb, 0.8, 2, 8);
        return;
    end
    local k = (u - 0.3) / 0.7;
    for i = 1, 3 do
        local ki = math.max(0, math.min(1, k * 3 - (i - 1) * 0.5));
        if ki > 0 then
            local ang = -0.7 + i * 0.6 + rnd(e.seed, i) * 0.3;
            local L = 34;
            local ax, ay = x2 - math.cos(ang) * L, y2 - math.sin(ang) * L;
            local bx, by = x2 + math.cos(ang) * L, y2 + math.sin(ang) * L;
            local cx, cy = ax + (bx - ax) * math.min(1, ki * 2), ay + (by - ay) * math.min(1, ki * 2);
            glow(ax, ay, cx, cy, rgb, (1 - k), 2.5);
        end
    end
    glow_dot(x2, y2, 4 + 8 * (1 - k), rgb, (1 - k) * 0.6);
end
DRAW.ws = function (x1, y1, x2, y2, u, age, e) slashes(x1, y1, x2, y2, u, age, e, RGB.gold); end
DRAW.mobws = function (x1, y1, x2, y2, u, age, e) slashes(x1, y1, x2, y2, u, age, e, RGB.red); end

----------------------------------------------------------------------------------------------------
-- The painted versions. Each is used when "AI art" is on and its picture loaded; otherwise the
-- drawn version above plays.
----------------------------------------------------------------------------------------------------
local ART, NEED = {}, {};

NEED.ice = 'ice';
ART.ice = function (x1, y1, x2, y2, u, age, e)
    if u < TRAVEL then
        local n = shots(e);
        for j = 0, n - 1 do
            local s = shot(u, TRAVEL, j, n);
            local lj = lift(j, n, 0.1, 0.24);
            local hx, hy = arc_pt(x1, y1, x2, y2, s, lj);
            local bx, by = arc_pt(x1, y1, x2, y2, math.max(0, s - 0.03), lj);
            local ang = (s < 0.03) and atan2(y2 - y1, x2 - x1) or atan2(hy - by, hx - bx);
            draw_sprite('ice', hx, hy, 0.8, 0.5, 56 * (1 - 0.5 * s), 28 * (1 - 0.5 * s), ang, 1);
        end
    else
        local k = (u - TRAVEL) / (1 - TRAVEL);
        local sz = 14 + 34 * ease_out(k);
        if not draw_sprite('shatter', x2, y2, 0.5, 0.5, sz, sz, -k * 0.4, (1 - k) * 1.2) then
            DRAW_PLAIN.ice(x1, y1, x2, y2, u, age, e);   -- the drawn shatter
        end
    end
end

NEED.water = 'water';
ART.water = function (x1, y1, x2, y2, u, age, e)
    if u < TRAVEL then
        local n = shots(e);
        for j = 0, n - 1 do
            local sj = shot(u, TRAVEL, j, n);
            if sj > 0 and sj < 1 then
                local hx, hy = arc_pt(x1, y1, x2, y2, sj, lift(j, n, 0.12, 0.36));
                local sz = math.max(32, 46 - (n - 1) * 4) * (1 - 0.5 * sj);
                draw_sprite('water', hx, hy, 0.5, 0.5, sz, sz, age * 9 + j * 2, 1);
            end
        end
    else
        local k = (u - TRAVEL) / (1 - TRAVEL);
        draw_sprite('water', x2, y2, 0.5, 0.5, 25 + 25 * k, 25 + 25 * k, age * 9, 1 - k);
        DRAW_PLAIN.water(x1, y1, x2, y2, u, age, e);     -- the splash
    end
end

NEED.wind = 'windblade';
ART.wind = function (x1, y1, x2, y2, u, age, e)
    local ang = atan2(y2 - y1, x2 - x1);
    local nx, ny = -math.sin(ang), math.cos(ang);
    local n = shots(e);
    for j = 0, n - 1 do
        local s = math.max(0, math.min(1, u * 1.6 - j * 0.15));
        if s > 0 and s < 1 then
            local a = 1 - math.max(0, s - 0.8) * 5;
            draw_sprite('windblade', x1 + (x2 - x1) * s + nx * side(j, n) * 12, y1 + (y2 - y1) * s + ny * side(j, n) * 12, 0.5, 0.5, 40 * (1 - 0.5 * s), 40 * (1 - 0.5 * s), ang, a);
        end
    end
    if u > 0.55 then burst(x2, y2, (u - 0.55) / 0.45, RGB.wind, 6, 20, e.seed); end
end

NEED.earth = 'rock';
-- The rock picture's point faces up-right; this turns it so the point leads.
local ROCK_TURN = 0.904;
ART.earth = function (x1, y1, x2, y2, u, age, e)
    local T = 0.6;
    if u < T then
        -- One glowing stone per tier, hurled in high arcs, point first, smaller as they near the monster.
        local n = shots(e);
        for j = 0, n - 1 do
            local sj = shot(u, T, j, n);
            if sj > 0 and sj < 1 then
                local lj = lift(j, n, 0.26, 0.5);
                local hx, hy = arc_pt(x1, y1, x2, y2, sj, lj);
                local bx, by = arc_pt(x1, y1, x2, y2, math.max(0, sj - 0.03), lj);
                local ang = (sj < 0.03) and atan2(y2 - y1, x2 - x1) or atan2(hy - by, hx - bx);
                local sz = math.max(44, 70 - (n - 1) * 7) * (1 - 0.5 * sj);   -- one stone big, more stones a bit smaller
                draw_sprite('rock', hx, hy, 0.5, 0.5, sz, sz, ang + ROCK_TURN + math.sin(age * 9 + j) * 0.08, math.min(1, sj * 12));
            end
        end
    else
        -- Impact: the stone slams in and breaks; chunks fly out, the ground ripples, dust rises.
        local k = (u - T) / (1 - T);
        local a = 1 - k;
        if k < 0.25 then
            local kk = k / 0.25;
            draw_sprite('rock', x2, y2, 0.5, 0.5, 35 * (1 + kk * 0.2), 35 * (1 + kk * 0.2), atan2(y2 - y1, x2 - x1) + ROCK_TURN, 1 - kk);
            glow_dot(x2, y2, 14 * (1 - kk) + 4, { 1.0, 0.65, 0.25 }, 1 - kk);
        end
        for i = 0, 2 do
            local r = 18 + 70 * math.max(0, math.min(1, k * 1.4 - i * 0.18));
            ellipse(x2, y2 + 26, r, r * 0.28, col(0.85, 0.6, 0.3, a * (0.8 - i * 0.2)), 3 - i);
        end
        for i = 1, 8 do
            local dir = (i - 4.5) / 3.5;
            local sx = x2 + dir * 70 * k;
            local sy = y2 - 55 * k * (0.6 + rnd(e.seed, i) * 0.8) + 90 * k * k;
            local sz = 10 + rnd(e.seed, i + 3) * 8;
            draw_sprite('rock', sx, sy, 0.5, 0.5, sz, sz, age * 10 + i, a);
        end
        for i = 1, 7 do
            local dir = (i - 4) / 3;
            dot(x2 + dir * 50 * k, y2 + 18 - 14 * k, 10 + 16 * k, col(0.62, 0.48, 0.30, a * 0.3));
        end
    end
end

NEED.light = 'beam';
ART.light = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.6) and math.min(1, u * 5) or (1 - (u - 0.6) / 0.4);
    local wob = 1 + math.sin(age * 20) * 0.06;
    draw_sprite('beam', x2, y2 + 14, 0.5, 1.0, 46 * wob, 230, 0, a);
    for i = 1, 8 do
        local ph = (age * 1.4 + rnd(e.seed, i)) % 1;
        local sx = x2 + (rnd(e.seed, i + 20) - 0.5) * 50;
        local sy = y2 + 10 - ph * 70;
        draw_sprite('sparkle', sx, sy, 0.5, 0.5, 14 * (1 - ph), 14 * (1 - ph), 0, a * (1 - ph), false, { 1.0, 0.95, 0.6 });
    end
end

NEED.dark = 'dark';
ART.dark = function (x1, y1, x2, y2, u, age, e)
    local d = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2);
    local ang = atan2(y2 - y1, x2 - x1);
    local head = math.min(1, u / TRAVEL);
    local fade = (u < TRAVEL) and 1 or (1 - (u - TRAVEL) / (1 - TRAVEL));
    local n = shots(e);
    for t = 0, n - 1 do
        local hj = math.max(0, math.min(1, head * (1 + 0.1 * (n - 1)) - t * 0.1));
        if hj > 0 then
            draw_sprite('dark', x1, y1, 0.02, 0.5, math.max(4, d * hj / 0.95), 30, ang + side(t, n) * 0.1 * math.sin(age * 5 + t), fade, t % 2 == 1);
        end
    end
    if u >= TRAVEL then
        local k = (u - TRAVEL) / (1 - TRAVEL);
        dot(x2, y2, 22 * (1 - k * 0.5), col(0.15, 0.0, 0.25, (1 - k) * 0.55));
        ring(x2, y2, 10 + 24 * k, col(0.75, 0.4, 1.0, 1 - k), 2);
    end
end

NEED.heal = 'sparkle';
ART.heal = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.75) and 1 or (1 - (u - 0.75) / 0.25);
    if e.src ~= e.dst and lines_on() then glow(x1, y1, x2, y2, RGB.heal, a * 0.3 * math.max(0, 1 - u * 2), 1.2); end
    ring(x2, y2 + 18, 14 + 10 * math.sin(u * math.pi), col(0.5, 1.0, 0.6, a * 0.5), 2);
    for i = 1, 10 do
        local ph = (u * 1.3 + rnd(e.seed, i)) % 1;
        local ang = rnd(e.seed, i + 30) * math.pi * 2 + age * 2;
        local sz = 22 * (1 - ph * 0.6);
        draw_sprite('sparkle', x2 + math.cos(ang) * 18, y2 + 20 - ph * 60, 0.5, 0.5, sz, sz, 0, a * (1 - ph));
    end
end

NEED.raise = 'halo';
ART.raise = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.85) and 1 or (1 - (u - 0.85) / 0.15);
    local y = (y2 - 140) + 114 * ease_out(math.min(1, u / 0.6));
    draw_sprite('halo', x2, y, 0.5, 0.5, 56, 28, 0, a);
    if u > 0.6 then
        local k = (u - 0.6) / 0.4;
        glow_dot(x2, y2, 10 * k, RGB.gold, a * 0.6);
        for i = 1, 8 do
            local sz = 14 * (1 - k * 0.5);
            draw_sprite('sparkle', x2 + (rnd(e.seed, i) - 0.5) * 44, y2 + 10 - k * 44 * rnd(e.seed, i + 3), 0.5, 0.5, sz, sz, 0, a * (1 - k), false, { 1.0, 0.9, 0.5 });
        end
    end
end

NEED.buff = 'rune';
ART.buff = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.2) and (u / 0.2) or (1 - (u - 0.2) / 0.8);
    if e.src ~= e.dst and lines_on() then glow(x1, y1, x2, y2, RGB.buff, a * 0.25 * math.max(0, 1 - u * 3), 1); end
    ellipse(x2, y2, 24, 9, col(0.5, 0.85, 1.0, a * 0.25), 1);
    for i = 0, 3 do
        local an = age * 2.5 + i * math.pi / 2;
        local depth = 0.5 + math.sin(an) * 0.5;
        local sz = 16 + depth * 6;
        draw_sprite('rune', x2 + math.cos(an) * 24, y2 + math.sin(an) * 9, 0.5, 0.5, sz, sz, 0, a * (0.45 + depth * 0.55));
    end
end

NEED.hex = 'sigil';
ART.hex = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.2) and (u / 0.2) or (1 - (u - 0.2) / 0.8);
    local cy = y2 - 42;
    draw_sprite('sigil', x2, cy, 0.5, 0.5, 40, 40, age * 0.8, a);
    for i = 0, 3 do
        local ph = (age + i / 4) % 1;
        dot(x2 + (i - 1.5) * 6, cy + 18 + ph * 28, 2.2 * (1 - ph), col(1.0, 0.4, 0.8, a * (1 - ph)));
    end
end

NEED.song = 'note';
ART.song = function (x1, y1, x2, y2, u, age, e)
    local a = (u < 0.8) and 1 or (1 - (u - 0.8) / 0.2);
    for i = 1, 4 do
        local s = math.max(0, math.min(1, u * 1.4 - i * 0.1));
        local hx, hy = arc_pt(x1, y1, x2, y2, s, 0.2);
        hy = hy + math.sin(age * 8 + i) * 5;
        draw_sprite('note', hx, hy, 0.5, 0.5, 26 * (1 - 0.45 * s), 26 * (1 - 0.45 * s), math.sin(age * 4 + i) * 0.25, a);
    end
end

local function art_slashes(x1, y1, x2, y2, u, age, e, rgb, tint)
    if u < 0.3 then
        local s = u / 0.3;
        glow_arc(x1, y1, x2, y2, math.max(0, s - 0.3), s, 0.15, rgb, 0.8, 2, 8);
        return;
    end
    local k = (u - 0.3) / 0.7;
    for i = 1, 3 do
        local ki = math.max(0, math.min(1, k * 3 - (i - 1) * 0.5));
        if ki > 0 then
            local ang = -0.7 + i * 0.9 + rnd(e.seed, i) * 0.3;
            draw_sprite('slash', x2, y2, 0.5, 0.5, 50 + ki * 14, 50 + ki * 14, ang, (1 - k) * math.min(1, ki * 3), false, tint);
        end
    end
    glow_dot(x2, y2, 4 + 8 * (1 - k), rgb, (1 - k) * 0.6);
end
NEED.ws = 'slash';
ART.ws = function (x1, y1, x2, y2, u, age, e) art_slashes(x1, y1, x2, y2, u, age, e, RGB.gold, nil); end
NEED.mobws = 'slash';
ART.mobws = function (x1, y1, x2, y2, u, age, e) art_slashes(x1, y1, x2, y2, u, age, e, RGB.red, { 1.0, 0.35, 0.3 }); end

NEED.arrow = 'muzzle';
ART.arrow = function (x1, y1, x2, y2, u, age, e)
    local ang = atan2(y2 - y1, x2 - x1);
    if u < 0.2 then draw_sprite('muzzle', x1, y1, 0.3, 0.5, 64, 32, ang, 1 - u / 0.2); end
    DRAW_PLAIN.arrow(x1, y1, x2, y2, u, age, e);
end

-- Use the painted version when it can be.
for k, f in pairs(ART) do
    local plain = DRAW[k];
    DRAW_PLAIN[k] = plain;
    DRAW[k] = function (...)
        if art_on() and sprite(NEED[k]) ~= nil then return f(...); end
        return plain(...);
    end
end

local DURATION = {
    thunder = 0.8, fire = 1.0, ice = 1.0, water = 1.0, wind = 1.05, earth = 1.25, light = 1.1, dark = 1.25,
    heal = 1.3, raise = 1.8, buff = 1.4, hex = 1.6, song = 1.3, arrow = 0.6, ws = 0.9, mobws = 0.9,
};

----------------------------------------------------------------------------------------------------
-- Turning actions into effects
----------------------------------------------------------------------------------------------------
local ELEMENT = { [0] = 'fire', [1] = 'ice', [2] = 'wind', [3] = 'earth', [4] = 'thunder', [5] = 'water', [6] = 'light', [7] = 'dark' };

-- A spell's tier from its name: Fire 1, Fire II 2, Fire III 3, ... Firaja 5; Katon: Ichi 1, Ni 2, San 3.
local ROMAN = { II = 2, III = 3, IV = 4, V = 5, VI = 6 };
local function spell_tier(nm)
    nm = nm or '';
    local r = nm:match(' ([IV]+)$');
    if r and ROMAN[r] then return ROMAN[r]; end
    if nm:find(': San$') then return 3; elseif nm:find(': Ni$') then return 2; end
    if nm:find('ja$') then return 5; end
    return 1;
end

local function spell_kind(id)
    local kind, tier = nil, 1;
    pcall(function ()
        local r = AshitaCore:GetResourceManager():GetSpellById(id);
        if r == nil then return; end
        local skill, el = r.Skill, r.Element;
        local nm = '';
        pcall(function () nm = tostring(r.Name[1] or r.Name[0] or ''); end);
        tier = spell_tier(nm);
        if nm:find('Raise') or nm:find('Arise') then kind = 'raise';
        elseif skill == 33 then kind = 'heal';                 -- healing magic
        elseif skill == 34 then kind = 'buff';             -- enhancing
        elseif skill == 35 then kind = 'hex';              -- enfeebling
        elseif skill == 40 then kind = 'song';             -- singing
        elseif skill == 37 then kind = 'dark';             -- dark magic (Bio, Drain, Aspir)
        else kind = ELEMENT[el]; end
        if kind == nil then kind = 'buff'; end
    end);
    return kind or 'light', tier;
end

local effects = {};   -- { kind, src, dst, t0, dur, seed }
local lines = {};     -- melee: [src index] = { dst, t, enemy }
local LINE_TIME = 6;
local casting = {};   -- spells being cast: [caster index] = { kind, dst, t0 }

local function add(kind, src, dst, n)
    if #effects > 40 then table.remove(effects, 1); end
    effects[#effects + 1] = { kind = kind, src = src, dst = dst, t0 = os.clock(), dur = DURATION[kind] or 1, seed = math.random() * 100, n = n or 1 };
end

local function on_action(data)
    if not on('fx_on', true) then return; end
    local act = action.parse(data);
    if act == nil or act.targets == nil or #act.targets == 0 then return; end
    local cat = act.category;
    if not (cat == 1 or cat == 2 or cat == 3 or cat == 4 or cat == 8 or cat == 11) then return; end

    if on('fx_party', true) then
        local ids = party_ids();
        local hit = ids[act.actor_id];
        for _, t in ipairs(act.targets) do if ids[t.id] then hit = true; end end
        if not hit then return; end
    end

    local src = index_from_id(act.actor_id);
    if src == 0 then return; end
    -- Casting starts (8): the caster glows in the spell's colour until it lands or is interrupted.
    if cat == 8 then
        if act.param == 28787 then casting[src] = nil; return; end      -- interrupted
        local t = act.targets[1];
        local a = t and t.actions and t.actions[1];
        if a == nil then return; end
        local dst = index_from_id(t.id);
        casting[src] = { kind = spell_kind(a.param), dst = (dst ~= 0) and dst or src, t0 = os.clock() };
        return;
    end
    local kind, tier = nil, 1;
    if cat == 4 then casting[src] = nil; kind, tier = spell_kind(act.param);
    elseif cat == 2 then kind = 'arrow';
    elseif cat == 3 then kind = 'ws';
    elseif cat == 11 then kind = 'mobws'; end

    for i, t in ipairs(act.targets) do
        if i > 6 then break; end                   -- big area spells: a few lines is plenty
        local dst = index_from_id(t.id);
        if dst ~= 0 then
            if cat == 1 then
                if src ~= dst then lines[src] = { dst = dst, t = os.clock(), enemy = is_mob(src) }; end
            elseif kind then
                add(kind, src, dst, tier);
            end
        end
    end
end

local function on_death(data)
    -- A monster or player fell: drop its lines.
    local msg = struct.unpack('i2', data, 0x18 + 1);
    if msg == 6 or msg == 20 or msg == 97 or msg == 113 or msg == 406 or msg == 605 or msg == 646 then
        local target = struct.unpack('i2', data, 0x14 + 1);
        lines[target] = nil;
        for k, v in pairs(lines) do if v.dst == target then lines[k] = nil; end end
    end
end

ashita.events.register('packet_in', 'omni_fx_in', function (e)
    if e.id == 0x028 then
        local ok, err = pcall(on_action, e.data);
        if not ok and not fx.warned_in then fx.warned_in = true; print('[omni] spell lines (packet): ' .. tostring(err)); end
    elseif e.id == 0x029 then pcall(on_death, e.data);
    elseif e.id == 0x00A then effects, lines, casting = {}, {}, {}; end
end);

----------------------------------------------------------------------------------------------------
-- Every frame
----------------------------------------------------------------------------------------------------
local FLAGS = nil;
local function overlay_list()
    local ok, l = pcall(function () return imgui.GetBackgroundDrawList(); end);
    if ok and l then return l, false; end
    -- Fallback: an invisible full-screen window that ignores the mouse.
    if FLAGS == nil then
        FLAGS = 0;
        for _, n in ipairs({ 'ImGuiWindowFlags_NoDecoration', 'ImGuiWindowFlags_NoInputs', 'ImGuiWindowFlags_NoBackground',
            'ImGuiWindowFlags_NoSavedSettings', 'ImGuiWindowFlags_NoFocusOnAppearing', 'ImGuiWindowFlags_NoBringToFrontOnFocus',
            'ImGuiWindowFlags_NoNav' }) do
            local v = rawget(_G, n); if type(v) == 'number' then FLAGS = bit.bor(FLAGS, v); end
        end
    end
    imgui.SetNextWindowPos({ 0, 0 });
    imgui.SetNextWindowSize({ SW, SH });
    imgui.Begin('##omni_fx_overlay', true, FLAGS);
    return imgui.GetWindowDrawList(), true;
end

local function render()
    if not on('fx_on', true) then return; end
    local now = os.clock();
    local any_lines = lines_on() and next(lines) ~= nil;
    if #effects == 0 and not any_lines and next(casting) == nil then return; end
    load_frame();
    local list, window = overlay_list();
    dl = list;

    local cache = {};
    local function pos(idx)
        local p = cache[idx];
        if p == nil then
            local sx, sy = project(chest(idx));
            p = sx and { sx, sy } or false;
            cache[idx] = p;
        end
        return p;
    end

    -- Melee lines: a dotted chain running from attacker to target (blue your side, red monsters).
    if any_lines then
        for src, l in pairs(lines) do
            local age = now - l.t;
            if age > LINE_TIME then
                lines[src] = nil;
            else
                local a, b = pos(src), pos(l.dst);
                if a and b then
                    local alpha = math.min(1, age * 4) * math.min(1, (LINE_TIME - age) / 1.5) * 0.85;
                    local rgb = l.enemy and { 1.0, 0.47, 0.47 } or { 0.55, 0.78, 1.0 };
                    local lift = l.enemy and -0.1 or 0.15;
                    for i = 0, 17 do
                        local s = ((i / 18) + now * 0.25) % 1;
                        local px, py = arc_pt(a[1], a[2], b[1], b[2], s, lift);
                        dot(px, py, 1.8, col(rgb[1], rgb[2], rgb[3], alpha));
                    end
                end
            end
        end
    end

    -- Spells being cast: a glowing ring round the caster, sparks drawn in, a faint line to the target.
    for src, c in pairs(casting) do
        local age = now - c.t0;
        if age > 12 then
            casting[src] = nil;
        else
            local a = pos(src);
            if a then
                local rgb = RGB[c.kind] or RGB.light;
                local fade = math.min(1, age * 3);
                local r = 22 + math.sin(age * 6) * 2;
                if not draw_sprite('circle', a[1], a[2] + 16, 0.5, 0.5, 64, 24, 0, fade * (0.75 + math.sin(age * 6) * 0.25), math.floor(age * 4) % 2 == 1, { math.min(1, rgb[1] + 0.3), math.min(1, rgb[2] + 0.3), math.min(1, rgb[3] + 0.3) }) then
                    ring(a[1], a[2] + 10, r, col(rgb[1], rgb[2], rgb[3], fade * 0.55), 2);
                    ring(a[1], a[2] + 10, r * 0.6, col(rgb[1], rgb[2], rgb[3], fade * 0.30), 1.5);
                end
                for k = 1, 6 do
                    local ang = age * 3 + k * math.pi / 3;
                    glow_dot(a[1] + math.cos(ang) * r, a[2] + 10 + math.sin(ang) * r * 0.35, 2.2, rgb, fade);
                end
                for k = 1, 5 do
                    local ph = (age * 1.2 + k / 5) % 1;
                    local ang = k * 1.26 + c.t0;
                    local d = 40 * (1 - ph);
                    dot(a[1] + math.cos(ang) * d, a[2] + math.sin(ang) * d * 0.6, 2, col(rgb[1], rgb[2], rgb[3], fade * ph));
                end
                -- Stone spells: the rock forms above the caster while the spell is cast.
                -- Other elements form their own picture there the same way.
                if art_on() then
                    local g = math.min(1, age / 1.5);
                    local hx, hy = a[1], a[2] - 70 + math.sin(age * 3) * 4;
                    if c.kind == 'earth' then
                        local sz = 24 + 40 * g;
                        draw_sprite('rock', hx, hy, 0.5, 0.5, sz, sz, ROCK_TURN - math.pi / 2 + math.sin(age * 2) * 0.15, fade);
                    elseif c.kind == 'fire' then
                        local sz = 20 + 30 * g;
                        draw_sprite('boom', hx, hy, 0.5, 0.5, sz, sz, age * 2, fade * 0.95);
                    elseif c.kind == 'ice' then
                        local sz = 28 + 30 * g;
                        draw_sprite('ice', hx, hy, 0.5, 0.5, sz, sz * 0.5, -math.pi / 2 + math.sin(age * 2) * 0.1, fade);
                    elseif c.kind == 'water' then
                        local sz = 20 + 30 * g;
                        draw_sprite('water', hx, hy, 0.5, 0.5, sz, sz, age * 6, fade);
                    elseif c.kind == 'wind' then
                        local sz = 20 + 28 * g;
                        draw_sprite('windblade', hx, hy, 0.5, 0.5, sz, sz, age * 8, fade);
                    elseif c.kind == 'thunder' then
                        local sz = 18 + 26 * g;
                        draw_sprite('sparkle', hx, hy, 0.5, 0.5, sz * (0.85 + math.sin(age * 25) * 0.15), sz, age * 4, fade, false, { 0.75, 0.7, 1.0 });
                    end
                end
                if c.dst ~= src then
                    local b = pos(c.dst);
                    if b and lines_on() then glow_arc(a[1], a[2], b[1], b[2], 0, 1, 0.18, rgb, fade * 0.25, 1, 12); end
                end
            end
        end
    end

    -- Spell and skill effects.
    local i = 1;
    while i <= #effects do
        local e = effects[i];
        local age = now - e.t0;
        if age >= e.dur then
            table.remove(effects, i);
        else
            local a, b = pos(e.src), pos(e.dst);
            if a and b and DRAW[e.kind] then
                pcall(DRAW[e.kind], a[1], a[2], b[1], b[2], age / e.dur, age, e);
            end
            i = i + 1;
        end
    end

    if window then imgui.End(); end
    dl = nil;
end

ashita.events.register('d3d_present', 'omni_fx_draw', function ()
    local ok, err = pcall(render);
    if not ok and not fx.warned then fx.warned = true; print('[omni] spell lines: ' .. tostring(err)); end
end);

-- For testing: /omni fx <kind> plays an effect from you to your target.
fx.test = function (kind, n)
    local me = AshitaCore:GetMemoryManager():GetParty():GetMemberTargetIndex(0);
    local t = AshitaCore:GetMemoryManager():GetTarget():GetTargetIndex(0);
    if t == 0 then t = me; end
    if DRAW[kind] then add(kind, me, t, tonumber(n) or 1); return true; end
    return false;
end
fx.kinds = DURATION;
fx._draw = DRAW;
fx._setdl = function (l) dl = l; end

return fx;
