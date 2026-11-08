--[[
    omni_party.lua - job pictures for your party and alliance, to sit beside the game's own lists.

    One see-through column per party (your party, and alliance parties 2 and 3), with a job
    picture for each member, top to bottom in party order. Drag each one next to its party list
    and it stays there; its bottom edge stays put and it grows upwards as people join, just like
    the game's lists. Picture size and the space between rows are set per party in the Options tab.
    Hover a picture for the member's name and jobs.
    TP: each party also gets a column of TP numbers (green from 1000), its own window - it starts
    just left of the pictures, and "Move TP" lets you drag it anywhere, apart from the pictures.

    Job pictures (assets/jobs/*.png, the FFXI artifact hats) from HXUI by Team HXUI
    (MIT, see HXUI_LICENSE).
]]

local imgui = require('imgui');
local ffi = require('ffi');
local d3d = require('d3d8');

local party = {};

local JOBS = { 'WAR', 'MNK', 'WHM', 'BLM', 'RDM', 'THF', 'PLD', 'DRK', 'BST', 'BRD', 'RNG', 'SAM',
    'NIN', 'DRG', 'SMN', 'BLU', 'COR', 'PUP', 'DNC', 'SCH', 'GEO', 'RUN' };

-- Each job's picture, loaded once.
pcall(ffi.cdef, [[
    HRESULT __stdcall D3DXCreateTextureFromFileA(IDirect3DDevice8* pDevice, const char* pSrcFile, IDirect3DTexture8** ppTexture);
]]);
local tex = {};        -- job id -> texture (or false if it could not load)
local function job_tex(j)
    if tex[j] ~= nil then return tex[j] or nil; end
    tex[j] = false;
    pcall(function ()
        local p = ffi.new('IDirect3DTexture8*[1]');
        local path = string.format('%s/assets/jobs/%s.png', addon.path, JOBS[j]:lower());
        if ffi.C.D3DXCreateTextureFromFileA(d3d.get_device(), path, p) == ffi.C.S_OK then
            tex[j] = d3d.gc_safe_release(ffi.new('IDirect3DTexture8*', p[0]));
        end
    end);
    return tex[j] or nil;
end

-- Members of one party: 1 = yours (slots 0-5), 2 and 3 = alliance (6-11, 12-17).
local function members(n)
    local out = {};
    pcall(function ()
        local p = AshitaCore:GetMemoryManager():GetParty();
        local myzone = p:GetMemberZone(0);
        for i = (n - 1) * 6, (n - 1) * 6 + 5 do
            if p:GetMemberIsActive(i) == 1 then
                local name = p:GetMemberName(i);
                if name and name ~= '' then
                    out[#out + 1] = {
                        name = name, job = p:GetMemberMainJob(i), lvl = p:GetMemberMainJobLevel(i),
                        sub = p:GetMemberSubJob(i), slvl = p:GetMemberSubJobLevel(i),
                        tp = p:GetMemberTP(i),
                        inzone = p:GetMemberZone(i) == myzone,
                    };
                end
            end
        end
    end);
    return out;
end

-- Saved position keys for each party (party 1 keeps the old names).
local KEYS = {
    { x = 'party_x',  y = 'party_y',  b = 'party_bottom',  dx = 40, dy = 300, size = 'party_icon_size',  gap = 'party_icon_gap' },
    { x = 'party2_x', y = 'party2_y', b = 'party2_bottom', dx = 40, dy = 160, size = 'party2_icon_size', gap = 'party2_icon_gap' },
    { x = 'party3_x', y = 'party3_y', b = 'party3_bottom', dx = 40, dy = 40,  size = 'party3_icon_size', gap = 'party3_icon_gap' },
};
local was_unlocked = {};

local function draw_column(n, list, opts)
    local S = opts.settings;
    local K = KEYS[n];
    -- Each party has its own picture size and row spacing (alliance parties start from party 1's).
    local size = S[K.size] or S.party_icon_size or 20;
    local gap = S[K.gap] or S.party_icon_gap or 22;          -- distance from one row to the next
    local unlocked = S.party_icons_unlocked == true;
    local W, H = size + 8, (#list - 1) * gap + size + 8;

    -- Bottom edge stays put; the column grows upwards as people join.
    if S[K.b] == nil then S[K.b] = (S[K.y] or K.dy) + H; end
    local x, y = S[K.x] or K.dx, S[K.b] - H;
    if not unlocked then
        imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
        was_unlocked[n] = false;
    elseif not was_unlocked[n] then
        imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);   -- once, then you can drag it
        was_unlocked[n] = true;
    end
    imgui.SetNextWindowSize({ W, H }, ImGuiCond_Always);
    -- See-through, except a faint frame while you are moving it.
    imgui.PushStyleColor(ImGuiCol_WindowBg, unlocked and { 0.06, 0.07, 0.12, 0.60 } or { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_Border, unlocked and { 0.90, 0.78, 0.40, 0.80 } or { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_BorderShadow, { 0, 0, 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 4, 4 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, unlocked and 1 or 0);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoBringToFrontOnFocus);
    if not unlocked then flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoBackground); end
    if imgui.Begin('Party ' .. n .. ' jobs##omni_party_icons' .. n, true, flags) then
        for i, m in ipairs(list) do
            local j = m.job or 0;
            if j >= 1 and j <= 22 then
                imgui.SetCursorPos({ 4, 4 + (i - 1) * gap });
                local tint = { 1, 1, 1, m.inzone and 1 or 0.4 };
                local t = job_tex(j);
                pcall(function ()
                    if t ~= nil then
                        imgui.Image(tonumber(ffi.cast('uint32_t', t)), { size, size }, { 0, 0 }, { 1, 1 }, tint, { 1, 1, 1, 0 });
                    elseif opts.icons ~= nil then
                        local u1 = (1.0 / 6.0) * math.fmod(j - 1.0, 6.0);
                        local v1 = 0.25 * math.floor((j - 1) / 6.0);
                        imgui.Image(tonumber(ffi.cast('uint32_t', opts.icons)), { size, size }, { u1, v1 },
                            { u1 + (1.0 / 12.0), v1 + 0.25 }, tint, { 1, 1, 1, 0 });
                    end
                end);
                if imgui.IsItemHovered() then
                    imgui.SetTooltip(string.format('%s  %s%s%s', m.name, JOBS[j] or '?', tostring(m.lvl or ''),
                        (m.sub and m.sub > 0) and ('/' .. (JOBS[m.sub] or '?') .. tostring(m.slvl or '')) or ''));
                end
            end
        end
        -- Remember where it was put.
        local wx, wy = imgui.GetWindowPos();
        if unlocked and type(wx) == 'number' and not imgui.IsMouseDown(0)
            and (math.floor(wx) ~= S[K.x] or math.floor(wy + H) ~= S[K.b]) then
            S[K.x], S[K.y], S[K.b] = math.floor(wx), math.floor(wy), math.floor(wy + H);
            if opts.save then pcall(opts.save); end
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
    imgui.PopStyleColor(3);
end

-- TP numbers: one column per party, its own window, so it can be moved apart from the pictures.
-- Saved as party_tp_x / party_tp_bottom (party2_tp_..., party3_tp_...); until it has been moved it
-- sits just left of that party's pictures. Rows use the same spacing as the pictures.
local tp_was_unlocked = {};
local function draw_tp(n, list, opts)
    local S = opts.settings;
    local K = KEYS[n];
    local pre = (n == 1) and 'party_' or ('party' .. n .. '_');
    local kx, kb = pre .. 'tp_x', pre .. 'tp_bottom';
    local size = S[K.size] or S.party_icon_size or 20;
    -- Its own text size (percent) and row spacing; the spacing starts as the pictures' spacing.
    local scale = (tonumber(S[pre .. 'tp_scale']) or 100) / 100;
    local gap = S[pre .. 'tp_gap'] or S[K.gap] or S.party_icon_gap or 22;
    local unlocked = S.party_tp_unlocked == true;   -- its own Move switch, apart from the pictures
    local base_lh = 16;
    local row_h = math.max(size, math.floor(base_lh * scale));
    local TPW = math.floor(44 * scale);
    local H = (#list - 1) * gap + row_h + 8;
    local px = S[K.x] or K.dx;
    local pb = S[K.b] or ((S[K.y] or K.dy) + H);
    local x, b = S[kx] or (px - TPW), S[kb] or pb;
    local y = b - H;
    if not unlocked then
        imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
        tp_was_unlocked[n] = false;
    elseif not tp_was_unlocked[n] then
        imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
        tp_was_unlocked[n] = true;
    end
    imgui.SetNextWindowSize({ TPW, H }, ImGuiCond_Always);
    imgui.PushStyleColor(ImGuiCol_WindowBg, unlocked and { 0.06, 0.07, 0.12, 0.60 } or { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_Border, unlocked and { 0.40, 0.90, 0.40, 0.80 } or { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_BorderShadow, { 0, 0, 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 4, 4 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, unlocked and 1 or 0);
    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoScrollbar,
        ImGuiWindowFlags_NoScrollWithMouse, ImGuiWindowFlags_NoCollapse, ImGuiWindowFlags_NoFocusOnAppearing,
        ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoBringToFrontOnFocus);
    if not unlocked then flags = bit.bor(flags, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoInputs); end
    if imgui.Begin('Party ' .. n .. ' TP##omni_party_tp' .. n, true, flags) then
        imgui.SetWindowFontScale(scale);
        local lh = imgui.GetTextLineHeight();
        for i, m in ipairs(list) do
            if m.tp ~= nil then
                local txt = tostring(m.tp);
                local tw = imgui.CalcTextSize(txt);
                imgui.SetCursorPos({ TPW - 4 - tw, 4 + (i - 1) * gap + math.max(0, (row_h - lh) / 2) });
                local col = (not m.inzone) and { 0.6, 0.6, 0.6, 0.6 }
                    or (m.tp >= 1000 and { 0.35, 1.0, 0.35, 1.0 } or { 1, 1, 1, 1 });
                imgui.TextColored(col, txt);
            end
        end
        local wx, wy = imgui.GetWindowPos();
        if unlocked and type(wx) == 'number' and not imgui.IsMouseDown(0)
            and (math.floor(wx) ~= S[kx] or math.floor(wy + H) ~= S[kb]) then
            S[kx], S[kb] = math.floor(wx), math.floor(wy + H);
            if opts.save then pcall(opts.save); end
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
    imgui.PopStyleColor(3);
end

-- opts = { settings, save, icons }
party.render = function (opts)
    local S = opts.settings or {};
    local pics, tps = S.party_icons ~= false, S.party_tp ~= false;
    if not pics and not tps then return; end
    opts.settings = S;
    for n = 1, 3 do
        local list = members(n);
        local show = #list > 0;
        if n == 1 and #list <= 1 and S.party_solo ~= true then show = false; end
        if show then
            if pics then draw_column(n, list, opts); end
            if tps then draw_tp(n, list, opts); end
        end
    end
end

return party;
