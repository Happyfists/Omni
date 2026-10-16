--[[
* omni/trove_host.lua
*
* Runs a set of Trove screens inside omni's drop-down panel, so omni does
* not need the trove addon loaded.
*
* The first part of this file is Trove's shared core (item helpers, icon
* textures, tooltips), taken from trove.lua by Loxley (MIT licence, see
* TROVE_LICENSE). The screens themselves are Trove's own plugin files,
* copied unchanged into core/, plugins/, utils/ and themes/.
*
* The second part ("omni host") is the glue: it loads those plugins,
* feeds them packets, and draws them inside omni's tabs instead of in
* their own windows.
]]--

require('common');
local ffi   = require('ffi');
local d3d   = require('d3d8');
local imgui = require('imgui');

local C       = ffi.C;
local d3d8dev = d3d.get_device();

pcall(ffi.cdef, [[
    HRESULT __stdcall D3DXCreateTextureFromFileA(IDirect3DDevice8* pDevice, const char* pSrcFile, IDirect3DTexture8** ppTexture);
]]);

local trove_ui       = require('utils/ui');
local trove_pkt      = require('utils/packet');

------------------------------------------------------------
-- Theme (change to load a custom theme from themes/)
------------------------------------------------------------
local THEME = 'omni';     -- omni's navy-and-gold recolour; falls back to Trove's default
if not trove_ui.applyTheme(THEME) then
    trove_ui.applyTheme('default');
end

------------------------------------------------------------
-- Packet protocol (shared module)
------------------------------------------------------------
local PACKET_ID = trove_pkt.PACKET_ID;
local C2S       = trove_pkt.C2S;
local S2C       = trove_pkt.S2C;

-- Keybind. Ashita uses caret-prefix modifiers: ^ = ctrl, ! = alt, + = shift.

------------------------------------------------------------
-- AH Category display names
------------------------------------------------------------
local AH_NAMES = {
    [1]  = 'H2H',           [2]  = 'Dagger',        [3]  = 'Sword',
    [4]  = 'Greatsword',    [5]  = 'Axe',           [6]  = 'Greataxe',
    [7]  = 'Scythe',        [8]  = 'Polearm',       [9]  = 'Katana',
    [10] = 'Greatkatana',   [11] = 'Club',          [12] = 'Staff',
    [13] = 'Bow',           [14] = 'Instruments',   [15] = 'Ammunition',
    [16] = 'Shield',        [17] = 'Head',          [18] = 'Body',
    [19] = 'Hands',         [20] = 'Legs',          [21] = 'Feet',
    [22] = 'Neck',          [23] = 'Waist',         [24] = 'Earrings',
    [25] = 'Rings',         [26] = 'Back',
    [28] = 'White Magic',   [29] = 'Black Magic',   [30] = 'Summoning',
    [31] = 'Ninjutsu',      [32] = 'Songs',         [33] = 'Medicines',
    [34] = 'Furnishings',   [35] = 'Crystals',      [36] = 'Cards',
    [37] = 'Cursed Items',  [38] = 'Smithing',      [39] = 'Goldsmithing',
    [40] = 'Clothcraft',    [41] = 'Leathercraft',  [42] = 'Bonecraft',
    [43] = 'Woodworking',   [44] = 'Alchemy',       [45] = 'Geomancy',
    [46] = 'Misc',          [47] = 'Fishing Gear',  [48] = 'Pet Items',
    [49] = 'Ninja Tools',   [50] = 'Beast-made',    [51] = 'Fish',
    [52] = 'Meat & Eggs',   [53] = 'Seafood',       [54] = 'Vegetables',
    [55] = 'Soups',         [56] = 'Breads & Rice', [57] = 'Sweets',
    [58] = 'Drinks',        [59] = 'Ingredients',   [60] = 'Dice',
    [61] = 'Automaton',     [62] = 'Grips',         [63] = 'Alchemy 2',
    [64] = 'Misc 2',        [65] = 'Misc 3',
    [100] = 'Incursion',    [101] = 'Spawners',     [102] = 'Abyssea',
    [103] = 'Limbus',       [104] = 'Ventures',
    [255] = 'Other',
};

local CUSTOM_ORDER = {
    [100] = 1, [101] = 2, [102] = 3, [103] = 4, [104] = 5,
};

------------------------------------------------------------
-- Colors (proxy to active theme — changes when theme switches)
-- Maps old key names to theme keys where they differ.
------------------------------------------------------------
local COLOR_ALIASES = {
    btnWithdraw = 'btnPrimary',
    btnHover    = 'btnPrimaryHover',
    btnActive   = 'btnPrimaryActive',
    btnFeatureH = 'btnFeatureHover',
    btnFeatureA = 'btnFeatureActive',
    btnStoreH   = 'btnPositiveHover',
    btnStoreA   = 'btnPositiveActive',
    btnStore    = 'btnPositive',
    btnBackH    = 'btnBackHover',
    btnBackA    = 'btnBackActive',
};

local COLORS = setmetatable({}, {
    __index = function(_, key)
        local themeKey = COLOR_ALIASES[key] or key;
        return trove_ui.color(themeKey);
    end,
});


-- renderPluginEntry defined after renderIcon/renderFileIcon (forward ref)

-- Cached alternating row backgrounds (rebuilt on theme change to avoid per-row allocations)
local rowBgCache = { version = -1, alt = nil, normal = nil };
local function getRowBg(isAlt)
    local v = trove_ui.getThemeVersion();
    if rowBgCache.version ~= v then
        local base = COLORS.childBg;
        rowBgCache.alt    = { base[1], base[2], base[3], 0.35 };
        rowBgCache.normal = { base[1], base[2], base[3], 0.20 };
        rowBgCache.version = v;
    end
    return isAlt and rowBgCache.alt or rowBgCache.normal;
end

------------------------------------------------------------
-- Item flag constants
------------------------------------------------------------
local FLAG_RARE = 0x8000;
local FLAG_EX   = 0x4000;

------------------------------------------------------------
-- Lookup tables
------------------------------------------------------------
local JOB_ABBR = {
    'WAR','MNK','WHM','BLM','RDM','THF','PLD','DRK','BST','BRD',
    'RNG','SAM','NIN','DRG','SMN','BLU','COR','PUP','DNC','SCH',
    'GEO','RUN',
};

local SLOT_NAMES = {
    [0x0001] = 'Main',  [0x0002] = 'Sub',    [0x0004] = 'Range',
    [0x0008] = 'Ammo',  [0x0010] = 'Head',   [0x0020] = 'Body',
    [0x0040] = 'Hands', [0x0080] = 'Legs',   [0x0100] = 'Feet',
    [0x0200] = 'Neck',  [0x0400] = 'Waist',  [0x0800] = 'L.Ear',
    [0x1000] = 'R.Ear', [0x2000] = 'L.Ring', [0x4000] = 'R.Ring',
    [0x8000] = 'Back',
};

local WEAPON_SKILLS = {
    [1] = 'Hand-to-Hand', [2] = 'Dagger',     [3] = 'Sword',
    [4] = 'Great Sword',  [5] = 'Axe',        [6] = 'Great Axe',
    [7] = 'Scythe',       [8] = 'Polearm',    [9] = 'Katana',
    [10] = 'Great Katana', [11] = 'Club',      [12] = 'Staff',
    [25] = 'Archery',     [26] = 'Marksmanship', [27] = 'Throwing',
};

local QTY_BUTTONS = {
    { label = 'x1',  qty = 1  },
    { label = 'x3',  qty = 3  },
    { label = 'x6',  qty = 6  },
    { label = 'x12', qty = 12 },
    { label = 'x99', qty = 99 },
    { label = '...',  qty = 0  },
};

------------------------------------------------------------
-- Item helpers
------------------------------------------------------------
local function getSlotName(slots)
    if slots == nil or slots == 0 then return nil; end
    for mask, name in pairs(SLOT_NAMES) do
        if bit.band(slots, mask) ~= 0 then return name; end
    end
    return nil;
end

local function getJobList(jobs)
    if jobs == nil or jobs == 0 then return nil; end
    -- Ashita's resource Jobs field follows the DAT convention: bit N = job N,
    -- i.e. bit 1 = WAR, bit 2 = MNK, ..., bit 22 = RUN (bit 0 is NONE). This
    -- differs from the server's packed form and from how `1 << (job-1)` is
    -- used server-side. All-jobs here is bits 1..22 = 0x7FFFFE.
    if bit.band(jobs, 0x7FFFFE) == 0x7FFFFE then return 'All Jobs'; end
    local list = {};
    for i = 1, 22 do
        if bit.band(jobs, bit.lshift(1, i)) ~= 0 then
            table.insert(list, JOB_ABBR[i]);
        end
    end
    return table.concat(list, '/');
end

local function getItemRes(itemId)
    if itemId == nil or itemId == 0 then return nil; end
    return AshitaCore:GetResourceManager():GetItemById(itemId);
end

pcall(ffi.cdef, [[
    int MultiByteToWideChar(uint32_t CodePage, uint32_t dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);
    int WideCharToMultiByte(uint32_t CodePage, uint32_t dwFlags, const wchar_t* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, int* lpUsedDefaultChar);
]]);

-- FFXI item descriptions use a custom font that maps certain invalid-
-- ShiftJIS byte pairs to element icons. MultiByteToWideChar doesn't know
-- about them and emits "?". We translate each `0xEF <idx>` pair to a
-- sentinel `0x01 <idx>` so the description still encodes the element
-- position; the renderer later turns those into colored "●" glyphs.
-- `0x01` (ASCII SOH) is a control character that won't appear in normal
-- item text and survives the ShiftJIS → UTF-8 round-trip unchanged.
local ELEMENT_COLORS = {
    [0x1F] = { 1.00, 0.45, 0.25, 1.00 },  -- Fire: orange-red
    [0x20] = { 0.55, 0.85, 1.00, 1.00 },  -- Ice: light cyan
    [0x21] = { 0.55, 1.00, 0.55, 1.00 },  -- Wind: green
    [0x22] = { 0.90, 0.75, 0.45, 1.00 },  -- Earth: tan
    [0x23] = { 1.00, 0.90, 0.30, 1.00 },  -- Thunder: yellow
    [0x24] = { 0.45, 0.60, 1.00, 1.00 },  -- Water: blue
    [0x25] = { 1.00, 1.00, 0.85, 1.00 },  -- Light: pale
    [0x26] = { 0.75, 0.45, 1.00, 1.00 },  -- Dark: purple
};

local ELEMENT_MARK = 0x01;  -- sentinel byte before a colored-element index

local function replaceElementGlyphs(s)
    if s:find('\xEF', 1, true) == nil then return s; end
    local out, i, n = {}, 1, #s;
    while i <= n do
        local b = s:byte(i);
        if b == 0xEF and i < n and ELEMENT_COLORS[s:byte(i + 1)] ~= nil then
            out[#out + 1] = string.char(ELEMENT_MARK, s:byte(i + 1));
            i = i + 2;
        else
            out[#out + 1] = s:sub(i, i);
            i = i + 1;
        end
    end
    return table.concat(out);
end

-- Reusable FFI buffers for ShiftJIS → UTF-8 conversion. Previously these
-- were allocated inside shiftjis_to_utf8 (12 KB per call, every tooltip
-- frame at 60 fps → heavy GC pressure and eventual OOM after hours).
local sjis_buf  = ffi.new('char[4096]');
local sjis_wbuf = ffi.new('wchar_t[4096]');

local function shiftjis_to_utf8(input)
    if input == nil then return nil; end
    input = replaceElementGlyphs(input);
    ffi.copy(sjis_buf, input);
    ffi.C.MultiByteToWideChar(932, 0, sjis_buf, -1, sjis_wbuf, 4096);
    ffi.C.WideCharToMultiByte(65001, 0, sjis_wbuf, -1, sjis_buf, 4096, nil, nil);
    return ffi.string(sjis_buf);
end

local function getItemString(res, field, index)
    if res == nil then return nil; end
    local val = res[field][index or 1];
    if val == nil then return nil; end
    return shiftjis_to_utf8(val);
end

-- Render an item description that may contain ELEMENT_MARK sentinels for
-- per-element coloured dots. Text flows inline with `SameLine(0, 0)` and
-- wraps at segment boundaries when the accumulated line would exceed the
-- current content width. `\n` in the description forces a new line.
--
-- Element dots are drawn on the window's drawlist as filled circles
-- instead of using a Unicode glyph — the default imgui font doesn't
-- include U+25CF (BLACK CIRCLE) and falls back to "?" for it.
local DOT_WIDTH  = 10;  -- total horizontal slot reserved for a dot
local DOT_RADIUS = 3;

local function renderColoredDescription(desc, defaultColor)
    if desc == nil or #desc == 0 then return; end

    local wrapWidth = imgui.GetContentRegionAvail();
    local lineW    = 0;
    local rendered = false;

    local function preRender(w)
        if rendered and (lineW + w > wrapWidth) then
            -- The previous widget already advanced to the next row; skip
            -- SameLine so this segment starts fresh on that row.
            lineW = 0;
        elseif rendered then
            imgui.SameLine(0, 0);
        end
    end

    local function emitText(text, color, escape)
        local w = imgui.CalcTextSize(text);
        preRender(w);
        if escape then text = text:gsub('%%', '%%%%'); end
        imgui.TextColored(color, text);
        lineW = lineW + w;
        rendered = true;
    end

    local function emitDot(color)
        preRender(DOT_WIDTH);
        local dl = imgui.GetWindowDrawList();
        local sx, sy = imgui.GetCursorScreenPos();
        local lineH = imgui.GetTextLineHeight();
        dl:AddCircleFilled(
            { sx + DOT_WIDTH / 2, sy + lineH / 2 },
            DOT_RADIUS,
            imgui.GetColorU32(color));
        imgui.Dummy({ DOT_WIDTH, lineH });
        lineW = lineW + DOT_WIDTH;
        rendered = true;
    end

    local i, n = 1, #desc;
    while i <= n do
        local b = desc:byte(i);
        if b == 0x0A then
            if not rendered then imgui.Text(''); end
            lineW, rendered = 0, false;
            i = i + 1;
        elseif b == ELEMENT_MARK and i < n then
            local color = ELEMENT_COLORS[desc:byte(i + 1)];
            if color ~= nil then
                emitDot(color);
                i = i + 2;
            else
                i = i + 1;
            end
        else
            local start = i;
            while i <= n do
                local bb = desc:byte(i);
                if bb == 0x0A or bb == ELEMENT_MARK then break; end
                i = i + 1;
            end
            if i > start then
                emitText(desc:sub(start, i - 1), defaultColor, true);
            end
        end
    end
end

------------------------------------------------------------
-- Texture cache (game item icons + file-based images)
------------------------------------------------------------
local textureCache      = {};
local fileTextures      = {};  -- filename -> texture
local textureHandles    = {};  -- itemId|filename -> tonumber(uint32) for imgui.Image
local textureLRU        = {};  -- LRU queue of item IDs for eviction
local TEXTURE_CACHE_MAX = 512;

-- Explicitly release a D3D texture: disarm the GC-release first, then
-- call Release() ourselves so VRAM is freed immediately.
local function releaseTexture(tex)
    if tex == nil then return; end
    pcall(function()
        ffi.gc(tex, nil);   -- disarm GC Release
        tex:Release();      -- immediate D3D Release
    end);
end

local function loadItemTexture(itemId)
    if textureCache[itemId] ~= nil then return textureCache[itemId]; end
    if itemId == nil or itemId == 0 then textureCache[itemId] = false; return false; end

    local item = getItemRes(itemId);
    if item == nil or item.ImageSize == 0 then textureCache[itemId] = false; return false; end

    -- Evict oldest texture if cache is full — explicitly release D3D resource
    if #textureLRU >= TEXTURE_CACHE_MAX then
        local evict = table.remove(textureLRU, 1);
        releaseTexture(textureCache[evict]);
        textureCache[evict]   = nil;
        textureHandles[evict] = nil;
    end

    local ptr = ffi.new('IDirect3DTexture8*[1]');
    if (C.D3DXCreateTextureFromFileInMemoryEx(
        d3d8dev, item.Bitmap, item.ImageSize,
        0xFFFFFFFF, 0xFFFFFFFF, 1, 0,
        C.D3DFMT_A8R8G8B8, C.D3DPOOL_MANAGED,
        C.D3DX_DEFAULT, C.D3DX_DEFAULT,
        0xFF000000, nil, nil, ptr) ~= C.S_OK) then
        textureCache[itemId] = false; return false;
    end

    local tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
    textureCache[itemId] = tex;
    textureHandles[itemId] = tonumber(ffi.cast('uint32_t', tex));
    textureLRU[#textureLRU + 1] = itemId;
    return tex;
end

local function loadFileTexture(filename)
    if fileTextures[filename] ~= nil then return fileTextures[filename]; end
    -- Search: addon images/ first, then plugins/images/ fallback
    local path = string.format('%s/images/%s', addon.path, filename);
    local ptr = ffi.new('IDirect3DTexture8*[1]');
    if C.D3DXCreateTextureFromFileA(d3d8dev, path, ptr) ~= C.S_OK then
        -- Try plugins/images/
        path = string.format('%s/plugins/images/%s', addon.path, filename);
        if C.D3DXCreateTextureFromFileA(d3d8dev, path, ptr) ~= C.S_OK then
            fileTextures[filename] = false;
            return false;
        end
    end
    -- CRITICAL: store the gc_safe_release return value, not the raw pointer.
    -- Previously the wrapper was created then discarded — when GC collected
    -- it, Release() was called on the D3D texture while the addon still held
    -- a dangling raw pointer. Next render → use-after-free → crash.
    local tex = d3d.gc_safe_release(ffi.cast('IDirect3DTexture8*', ptr[0]));
    fileTextures[filename] = tex;
    textureHandles[filename] = tonumber(ffi.cast('uint32_t', tex));
    return tex;
end

------------------------------------------------------------
-- Packet helpers (delegate to shared module)
------------------------------------------------------------
local addCommas = trove_pkt.addCommas;

------------------------------------------------------------
-- State
------------------------------------------------------------

-- State — core only. Plugin-specific state lives in each plugin.
local state = {
    -- Active tab (plugins set this when their tab activates)
    activeTab      = nil,
    pendingRequest = nil,

    -- Status (shared — plugins can call setStatus)
    statusMsg     = '',
    statusIsErr   = false,
    statusUntil   = 0,
};

local ui = {
    isOpen      = { false },
    keybindDone = false,
};

local function setStatus(msg, isErr)
    state.statusMsg   = msg or '';
    state.statusIsErr = isErr or false;
    state.statusUntil = os.clock() + 4;
end

-- View transitions, tab activation, and data fetching are now
-- handled by each plugin via ensureData/invalidate hooks.

------------------------------------------------------------
-- Groupings for display
------------------------------------------------------------
-- Render helpers (icons, badges, tooltips, item rows)
------------------------------------------------------------
local function renderIcon(itemId, size)
    local tex = loadItemTexture(itemId);
    local handle = textureHandles[itemId];
    if tex and tex ~= false and handle ~= nil then
        imgui.Image(handle, { size, size });
        return true;
    end
    return false;
end

-- Forward declaration (defined below, needed by initPlugins)
local renderTooltip;

-- Render a file-based texture from images/ directory
local function renderFileIcon(filename, size)
    local tex = loadFileTexture(filename);
    local handle = textureHandles[filename];
    if tex and tex ~= false and handle ~= nil then
        imgui.Image(handle, { size, size });
        return true;
    end
    return false;
end

-- Get raw texture handle for an item icon (for drawlist rendering)
local function getIconHandle(itemId)
    local tex = loadItemTexture(itemId);
    return textureHandles[itemId];
end

-- Render a file-based texture at arbitrary width/height
local function renderFileImage(filename, w, h)
    local tex = loadFileTexture(filename);
    local handle = textureHandles[filename];
    if tex and tex ~= false and handle ~= nil then
        imgui.Image(handle, { w, h });
        return true;
    end
    return false;
end

-- Plugin menu entry renderer (defined once, avoids per-frame closure)
local function renderPluginEntry(plugin)
    local win = plugin.window;
    if win.icon then
        if type(win.icon) == 'string' then
            renderFileIcon(win.icon, 16);
        else
            renderIcon(win.icon, 16);
        end
        imgui.SameLine(0, 6);
    end
    local label = win.label or plugin.name;
    if plugin.hasAlert and plugin.hasAlert() then label = label .. ' (!)'; end
    if imgui.Selectable(label, win.isOpen[1]) then
        win.isOpen[1] = not win.isOpen[1];
    end
end

-- Forward declarations for functions defined after pluginCtx
local renderBadges;
local renderItemDetail;

-- Shared context passed to all plugins via init. Contains every helper
-- function a plugin might need so the init signature doesn't keep growing.
local pluginCtx = {
    renderIcon    = function(...) return renderIcon(...); end,
    getItemRes    = getItemRes,
    renderTooltip = function(...) return renderTooltip(...); end,
    renderFileIcon  = function(...) return renderFileIcon(...); end,
    renderFileImage = function(...) return renderFileImage(...); end,
    getIconHandle   = getIconHandle,
    getItemString   = getItemString,
    getSlotName     = getSlotName,
    getJobList      = getJobList,
    addCommas       = addCommas,
    getRowBg        = getRowBg,
    setStatus       = setStatus,
    renderBadges    = function(...) return renderBadges(...); end,
    renderItemDetail = function(...) return renderItemDetail(...); end,
    renderColoredDescription = function(...) return renderColoredDescription(...); end,
    -- Constants
    AH_NAMES     = AH_NAMES,
    CUSTOM_ORDER = CUSTOM_ORDER,
    FLAG_RARE    = FLAG_RARE,
    FLAG_EX      = FLAG_EX,
    SLOT_NAMES   = SLOT_NAMES,
    WEAPON_SKILLS = WEAPON_SKILLS,
    QTY_BUTTONS  = QTY_BUTTONS,
};

renderBadges = function(flags)
    if flags == nil or flags == 0 then return; end
    local isRare = bit.band(flags, FLAG_RARE) ~= 0;
    local isEx   = bit.band(flags, FLAG_EX) ~= 0;
    if not isRare and not isEx then return; end

    if isRare then
        imgui.PushStyleColor(ImGuiCol_Button, COLORS.rareBg);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, COLORS.rareBg);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, COLORS.rareBg);
        imgui.PushStyleColor(ImGuiCol_Text, COLORS.rare);
        imgui.SmallButton('Rare');
        imgui.PopStyleColor(4);
    end
    if isEx then
        if isRare then imgui.SameLine(0, 4); end
        imgui.PushStyleColor(ImGuiCol_Button, COLORS.exBg);
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, COLORS.exBg);
        imgui.PushStyleColor(ImGuiCol_ButtonActive, COLORS.exBg);
        imgui.PushStyleColor(ImGuiCol_Text, COLORS.ex);
        imgui.SmallButton('Ex');
        imgui.PopStyleColor(4);
    end
end

renderItemDetail = function(res, storedQty)
    if res == nil then return; end

    local isEquip  = (res.Level > 0 or res.Jobs > 0 or res.Slots > 0);
    local isWeapon = (res.Damage > 0 and res.Delay > 0 and res.Skill > 0);

    if storedQty ~= nil then
        imgui.TextColored(COLORS.dimmed, 'Stored:');
        imgui.SameLine();
        local qc = (storedQty <= 5) and COLORS.qtyLow or COLORS.qty;
        imgui.TextColored(qc, tostring(storedQty));
    end

    renderBadges(res.Flags);

    if res.StackSize > 1 then
        imgui.TextColored(COLORS.dimmed, string.format('Stack: %d', res.StackSize));
    end

    if isEquip then
        if isWeapon then
            local skill = WEAPON_SKILLS[res.Skill] or 'Unknown';
            imgui.TextColored(COLORS.slotText, string.format('(%s)', skill));
        elseif res.Slots > 0 then
            local slot = getSlotName(res.Slots);
            if slot then imgui.TextColored(COLORS.slotText, string.format('[%s]', slot)); end
        end

        if isWeapon then
            imgui.TextColored(COLORS.yellow, string.format('DMG:%d  Delay:%d', res.Damage, res.Delay));
        end
    end

    local desc = getItemString(res, 'Description', 1);
    if desc ~= nil and #desc > 0 then
        -- Weapons have "DMG:N Delay:N" at the start of the description, which
        -- we already render in yellow above. Strip it so it's not duplicated.
        -- Hand-to-Hand weapons use "DMG:+N" / "Delay:+N" (signed), so allow
        -- a leading + or -. The trailing class stays whitespace-only so any
        -- other stats that share the line (e.g. "... HP+35 STR+4") survive.
        if isWeapon then
            desc = desc:gsub("^%s*DMG:%s*[%+%-]?%d+%s*Delay:%s*[%+%-]?%d+%s*[\r\n]*", "")
        end
        if #desc > 0 then
            imgui.Spacing();
            -- renderColoredDescription wraps at segment boundaries itself
            -- (it measures each piece against GetContentRegionAvail), and
            -- already escapes "%" so printf format specifiers don't crash
            -- imgui. The segment pipeline also turns the ELEMENT_MARK
            -- sentinels into coloured "●" glyphs inline with the text.
            renderColoredDescription(desc, COLORS.desc);
        end
    end

    -- Level / jobs line sits beneath the description on equipment so the
    -- requirement info reads as a footer rather than a header.
    if isEquip and (res.Level > 0 or res.Jobs > 0) then
        local jobStr = getJobList(res.Jobs) or '';
        local lvlStr = '';
        if res.Level > 0 then
            lvlStr = string.format('Lv%d ', res.Level);
        end
        imgui.Spacing();
        imgui.TextColored(COLORS.jobText, lvlStr .. jobStr);
    end
end

renderTooltip = function(item)
    imgui.SetNextWindowSize({ 400, -1 }, ImGuiCond_Always);
    imgui.BeginTooltip();
    imgui.PushTextWrapPos(380);

    local tex = loadItemTexture(item.id);
    local handle = textureHandles[item.id];
    if tex and tex ~= false and handle ~= nil then
        imgui.Image(handle, { 32, 32 });
        imgui.SameLine();
    end

    imgui.TextColored(COLORS.header, item.name);
    imgui.Separator();

    local res = getItemRes(item.id);
    renderItemDetail(res, item.qty);

    imgui.PopTextWrapPos();
    imgui.EndTooltip();
end



------------------------------------------------------------
-- omni host
------------------------------------------------------------
local host = {};

-- Screens to show, in tab order.
--   kind 'tab'    : the plugin draws straight into Trove's tab area
--   kind 'subtab' : the plugin registers itself as a tab of Trove's Quests window
--   kind 'window' : the plugin normally opens its own window
-- width/height are the size the drop-down panel gives that screen.
host.sections = {
    { label = 'Currency', module = 'core/currency',        kind = 'tab',    width = 380, height = 620 },
    -- Shown inside the Currency tab (Currency / Points), not as a tab of its own.
    { label = 'Points',   module = 'core/points',          kind = 'tab',    width = 380, height = 620, hidden = true },
    { label = 'Dailies',  module = 'plugins/dailies',      kind = 'subtab', width = 400, height = 440, sub = 'Dailies' },
    { label = 'Codex',    module = 'plugins/odious_codex', kind = 'window', width = 680, height = 700 },
    -- Shown inside the Character tab (as its Magic page), not as a tab of its own.
    { label = 'Magic',    module = 'plugins/scrolls',      kind = 'window', width = 440, height = 600, hidden = true },
    { label = 'Sea',      module = 'plugins/lumoria',      kind = 'window', width = 680, height = 640 },
    { label = 'Character', module = 'plugins/profile',     kind = 'window', width = 560, height = 650 },
    -- Shown inside the Ventures tab, not as a tab of its own.
    { label = 'VNM Armor', module = 'plugins/vnm',         kind = 'window', width = 760, height = 300, hidden = true },
};

-- Plugins that open their own window call imgui.Begin/End. This stand-in
-- for imgui turns those two calls into nothing, so the plugin's content
-- lands in whatever omni already has open (its tab). Window size requests
-- made just before Begin are dropped for the same reason.
local embed = { inside = true };
local imgui_proxy = setmetatable({}, {
    __index = function(t, k)
        local v = imgui[k];
        rawset(t, k, v);
        return v;
    end,
});
imgui_proxy.Begin = function() embed.inside = true; return true; end
imgui_proxy.End   = function() embed.inside = false; end
for _, name in ipairs({ 'SetNextWindowSize', 'SetNextWindowSizeConstraints', 'SetNextWindowPos' }) do
    imgui_proxy[name] = function(...)
        if embed.inside then return imgui[name](...); end
    end
end

-- Dailies adds itself to Trove's Quests window; catch that registration here.
local subTabs = {};
package.preload['core/quest'] = function()
    return {
        name = 'Quests',
        registerSubTab = function(name, renderFn) subTabs[name] = renderFn; end,
    };
end
-- Trove's settings screen is not included; this keeps the shared UI code
-- from searching for it every frame.
package.preload['core/settings'] = function() return {}; end

state.isOpen = { true };

local isLoaded = false;

-- Extra rows for the Points tab, supplied by omni. Kept here until the tab has loaded.
local pointsExtras = nil;

local function applyPointsExtras()
    if pointsExtras == nil then return; end
    for _, section in ipairs(host.sections) do
        if section.module == 'core/points' and section.plugin and section.plugin.setExtras then
            section.plugin.setExtras(pointsExtras);
        end
    end
end

-- Draw a picture from images/ (used by omni's own tabs).
host.image = function(filename, w, h) return renderFileImage(filename, w, h); end

host.set_points_extras = function(fn)
    pointsExtras = fn;
    applyPointsExtras();
end


host.load = function()
    if isLoaded then return; end
    isLoaded = true;

    -- Load the plugin files with the stand-in imgui.
    package.loaded['imgui'] = imgui_proxy;
    for _, section in ipairs(host.sections) do
        local ok, result = pcall(require, section.module);
        if ok and type(result) == 'table' then
            section.plugin = result;
        else
            section.error = string.format('Could not load %s: %s', section.module, tostring(result));
            print('[omni] ' .. section.error);
        end
    end
    package.loaded['imgui'] = imgui;

    for _, section in ipairs(host.sections) do
        local plugin = section.plugin;
        if plugin then
            if plugin.onLoad then pcall(plugin.onLoad); end
            if plugin.init then
                local ok, err = pcall(plugin.init, renderIcon, getItemRes, trove_ui, renderTooltip, renderFileIcon, renderFileImage, getIconHandle);
                if not ok then
                    section.error = string.format('%s failed to start: %s', section.label, tostring(err));
                    print('[omni] ' .. section.error);
                end
            end
            if plugin.setContext then pcall(plugin.setContext, pluginCtx); end
        end
    end
    applyPointsExtras();
end

local ERROR_COLOR = { 1.0, 0.3, 0.3, 1.0 };

-- Draw one screen into the current imgui window.
host.render = function(section)
    if section.error then
        imgui.TextColored(ERROR_COLOR, section.error);
        return;
    end
    local plugin = section.plugin;
    if not plugin then
        imgui.Text('Loading...');
        return;
    end

    local ok, err = true, nil;
    if section.kind == 'window' then
        plugin.window.isOpen[1] = true;
        embed.inside = false;
        ok, err = pcall(plugin.window.render);
        embed.inside = true;
    else
        local fn = (section.kind == 'tab') and plugin.tab.render or subTabs[section.sub];
        if fn == nil then
            imgui.TextColored(ERROR_COLOR, section.label .. ' is not available.');
            return;
        end
        embed.inside = true;
        local pushed = trove_ui.pushWindowStyle();
        ok, err = pcall(fn, state);
        trove_ui.popWindowStyle(pushed);
    end
    if not ok then
        imgui.TextColored(ERROR_COLOR, 'Error: ' .. tostring(err));
    end
end

-- Call once per frame with the screen being shown (or nil if none).
-- omni: a picture from images/ as an ImGui texture handle (nil if it can't be loaded).
host.fileHandle = function(filename)
    local tex = loadFileTexture(filename);
    if tex and tex ~= false then return textureHandles[filename]; end
    return nil;
end

-- omni: switch the screens' colours with omni's Look ('crystal' or 'omni' = Classic).
host.setLook = function(name)
    if trove_ui._themeName ~= name then
        if not trove_ui.applyTheme(name) then trove_ui.applyTheme('omni'); end
    end
end

host.frame = function(activeSection)
    for _, section in ipairs(host.sections) do
        local plugin = section.plugin;
        if plugin then
            -- A screen that is not showing counts as closed, so it refreshes when reopened.
            if section.kind == 'window' and section ~= activeSection then
                plugin.window.isOpen[1] = false;
            end
            if plugin.onRender then pcall(plugin.onRender, state); end
        end
    end
end

host.packet_in = function(e)
    if not isLoaded then return; end
    for _, section in ipairs(host.sections) do
        local plugin = section.plugin;
        if plugin and plugin.onPacketIn then
            pcall(plugin.onPacketIn, e, state);
        end
    end

    -- Trove's own server packet: keep it away from the game client, and
    -- hand "plugin data" replies to the plugin that asked for them.
    if e.id ~= PACKET_ID then return; end
    e.blocked = true;
    pcall(function()
        local action = struct.unpack('B', e.data_modified, 0x04 + 1);
        if action == S2C.PLUGIN_DATA then
            local pluginId = struct.unpack('B', e.data_modified, 0x05 + 1);
            for _, section in ipairs(host.sections) do
                local plugin = section.plugin;
                if plugin and plugin.pluginId == pluginId and plugin.onPluginData then
                    pcall(plugin.onPluginData, e.data_modified, state);
                    return;
                end
            end
        end
    end);
end

-- Ask every screen to fetch fresh data next time it is shown.
host.refresh = function()
    for _, section in ipairs(host.sections) do
        if section.plugin and section.plugin.invalidate then
            pcall(section.plugin.invalidate);
        end
    end
end

host.unload = function()
    for _, section in ipairs(host.sections) do
        if section.plugin and section.plugin.onUnload then
            pcall(section.plugin.onUnload);
        end
    end
    for _, tex in pairs(textureCache) do
        if tex and tex ~= false then releaseTexture(tex); end
    end
    for _, tex in pairs(fileTextures) do
        if tex and tex ~= false then releaseTexture(tex); end
    end
    textureCache, fileTextures, textureHandles, textureLRU = {}, {}, {}, {};
end

-- Shared pieces for omni's own tabs (the Sky tab uses these).
host.ui         = trove_ui;
host.renderIcon = function(itemId, size) return renderIcon(itemId, size); end

return host;
