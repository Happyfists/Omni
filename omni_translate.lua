--[[
    omni_translate.lua - Happy Translate: Japanese chat lines get an English line underneath.

    How: any chat line with Japanese in it (say, shout, yell, tell, party, linkshell...) is converted
    from the game's Shift-JIS to UTF-8 and handed to a hidden PowerShell helper (omni_translate.ps1),
    which asks the free MyMemory translation service (api.mymemory.translated.net) and writes the
    English back to a file. omni checks for the answer each frame, so the game never waits.
    No console window opens (the helper is started with CREATE_NO_WINDOW).

    Only lines with Japanese are sent - English chat never leaves your PC. MyMemory's free limit is
    about 5000 characters a day; repeated lines are remembered and not sent twice.

    Commands
      /translate                 on / off  (also /tr)
      /translate test <text>     translate some text (type Japanese with the game's IME)
      /translate status          how many lines translated today, and the limit
]]

local ffi = require('ffi');

local tr = {};

----------------------------------------------------------------------------------------------------
-- Windows calls: Shift-JIS <-> UTF-8 and starting the hidden helper.
----------------------------------------------------------------------------------------------------
pcall(ffi.cdef, [[
    int MultiByteToWideChar(unsigned int CodePage, unsigned long dwFlags, const char* lpMultiByteStr, int cbMultiByte, wchar_t* lpWideCharStr, int cchWideChar);
]]);
pcall(ffi.cdef, [[
    int WideCharToMultiByte(unsigned int CodePage, unsigned long dwFlags, const wchar_t* lpWideCharStr, int cchWideChar, char* lpMultiByteStr, int cbMultiByte, const char* lpDefaultChar, int* lpUsedDefaultChar);
]]);
pcall(ffi.cdef, [[
    typedef struct {
        unsigned long cb; char* lpReserved; char* lpDesktop; char* lpTitle;
        unsigned long dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        unsigned short wShowWindow, cbReserved2; unsigned char* lpReserved2;
        void* hStdInput; void* hStdOutput; void* hStdError;
    } omni_tr_STARTUPINFOA;
    typedef struct { void* hProcess; void* hThread; unsigned long dwProcessId; unsigned long dwThreadId; } omni_tr_PROCESS_INFORMATION;
]]);
pcall(ffi.cdef, [[
    int CreateProcessA(const char* app, char* cmd, void* pa, void* ta, int inherit, unsigned long flags, void* env, const char* dir, void* si, void* pi);
]]);
pcall(ffi.cdef, [[ int CloseHandle(void* h); ]]);

local function convert(text, from_cp, to_cp)
    local ok, out = pcall(function ()
        local n = ffi.C.MultiByteToWideChar(from_cp, 0, text, #text, nil, 0);
        if n <= 0 then return nil; end
        local w = ffi.new('wchar_t[?]', n);
        ffi.C.MultiByteToWideChar(from_cp, 0, text, #text, w, n);
        local m = ffi.C.WideCharToMultiByte(to_cp, 0, w, n, nil, 0, nil, nil);
        if m <= 0 then return nil; end
        local b = ffi.new('char[?]', m);
        ffi.C.WideCharToMultiByte(to_cp, 0, w, n, b, m, nil, nil);
        return ffi.string(b, m);
    end);
    return ok and out or nil;
end
local function sjis_to_utf8(s) return convert(s, 932, 65001); end
local function utf8_to_sjis(s) return convert(s, 65001, 932); end

local CREATE_NO_WINDOW = 0x08000000;
local function run_hidden(cmdline)
    local ok, res = pcall(function ()
        local si = ffi.new('omni_tr_STARTUPINFOA');
        si.cb = ffi.sizeof(si);
        local pi = ffi.new('omni_tr_PROCESS_INFORMATION');
        local cmd = ffi.new('char[?]', #cmdline + 1);
        ffi.copy(cmd, cmdline);
        local r = ffi.C.CreateProcessA(nil, cmd, nil, nil, 0, CREATE_NO_WINDOW, nil, nil, si, pi);
        if r ~= 0 then
            ffi.C.CloseHandle(pi.hThread);
            ffi.C.CloseHandle(pi.hProcess);
            return true;
        end
        return false;
    end);
    return ok and res;
end

----------------------------------------------------------------------------------------------------
-- Settings and files
----------------------------------------------------------------------------------------------------
local st = { on = true, today = os.date('%Y-%m-%d'), chars = 0 };
local function addon_dir()
    -- Ashita sets addon.path to omni's own folder (wherever it is installed).
    local p = (addon ~= nil and type(addon.path) == 'string' and addon.path ~= '') and addon.path
        or ('%s\\addons\\omni\\'):format(AshitaCore:GetInstallPath());
    if p:sub(-1) ~= '\\' and p:sub(-1) ~= '/' then p = p .. '\\'; end
    return p;
end
local function work_dir() return ('%s\\config\\addons\\omni\\translate\\'):format(AshitaCore:GetInstallPath()); end
local function cfg_path() return work_dir() .. 'settings.txt'; end

local function ensure_dir()
    pcall(function () ashita.fs.create_directory(work_dir()); end);
    pcall(function () ashita.fs.create_dir(work_dir()); end);
end
local function save()
    pcall(function ()
        ensure_dir();
        local f = io.open(cfg_path(), 'w');
        if f == nil then return; end
        f:write('on ', st.on and 1 or 0, '\n', 'day ', st.today, '\n', 'chars ', st.chars, '\n');
        f:close();
    end);
end
pcall(function ()
    local f = io.open(cfg_path(), 'r');
    if f == nil then return; end
    for raw in f:lines() do
        local line = raw:gsub('%s+$', '');
        local v = line:match('^on (%d)$'); if v then st.on = (v == '1'); end
        local d = line:match('^day (%S+)$'); if d then st.today = d; end
        local c = line:match('^chars (%d+)$'); if c then st.chars = tonumber(c); end
    end
    f:close();
end);

local DAILY = 5000;   -- MyMemory's free allowance (characters a day, no key)

local function msg(t) print('\30\68[Happy Translate]\30\01 ' .. t); end

----------------------------------------------------------------------------------------------------
-- Spotting Japanese and cleaning a chat line
----------------------------------------------------------------------------------------------------
-- Shift-JIS lead bytes for kana and kanji (0x82-0x84 = hiragana/katakana/fullwidth, 0x88-0x9F and
-- 0xE0-0xEA = kanji). 0x81 is left out: English players' symbols (arrows, stars) use it too.
local function first_japanese(s)
    local i, n = 1, #s;
    while i <= n do
        local b = s:byte(i);
        if (b >= 0x82 and b <= 0x84) or (b >= 0x88 and b <= 0x9F) or (b >= 0xE0 and b <= 0xEA) then
            local t = s:byte(i + 1);
            if t ~= nil and t >= 0x40 and t <= 0xFC and t ~= 0x7F then return i; end
        end
        if (b >= 0x81 and b <= 0x9F) or (b >= 0xE0 and b <= 0xFC) then i = i + 2; else i = i + 1; end
    end
    return nil;
end

local function clean(s)
    -- Auto-translate phrases ({Hello!}) become plain text in your language first.
    local ok, parsed = pcall(function () return AshitaCore:GetChatManager():ParseAutoTranslate(s, true); end);
    if ok and type(parsed) == 'string' and parsed ~= '' then s = parsed; end
    s = s:gsub('\30.', ''):gsub('\31.', ''):gsub('\127.', ''):gsub('[\r\n]', ' ');
    return s;
end

----------------------------------------------------------------------------------------------------
-- The queue: each line gets an id; the helper writes <id>.out when it has the English.
----------------------------------------------------------------------------------------------------
local pending = {};      -- id -> { prefix, text, t }
local cache = {};        -- utf8 text -> english
local next_id = 1;
local session = tostring(os.time());

local function show(prefix, english)
    local sj = utf8_to_sjis(english) or english:gsub('[\128-\255]', '?');
    msg(prefix .. sj);
end

local function translate(prefix, sjis_text)
    local u = sjis_to_utf8(sjis_text);
    if u == nil or u:match('^%s*$') then return; end
    if cache[u] then show(prefix, cache[u]); return; end
    if os.date('%Y-%m-%d') ~= st.today then st.today = os.date('%Y-%m-%d'); st.chars = 0; end
    if st.chars + #u > DAILY * 3 then   -- utf8 Japanese is 3 bytes a character
        if not st.warned then st.warned = true; msg('daily free translation limit reached - back tomorrow.'); end
        return;
    end
    ensure_dir();
    local id = session .. '_' .. next_id;
    next_id = next_id + 1;
    local base = work_dir() .. id;
    local f = io.open(base .. '.in', 'wb');
    if f == nil then msg('could not write ' .. base .. '.in'); return; end
    f:write(u);
    f:close();
    local ps1 = addon_dir() .. 'omni_translate.ps1';
    local cmd = ('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%s" -In "%s.in" -Out "%s.out"'):format(ps1, base, base);
    local chk = io.open(ps1, 'r');
    if chk == nil then msg('helper missing: ' .. ps1); return; end
    chk:close();
    if not run_hidden(cmd) then msg('could not start the translate helper (PowerShell).'); return; end
    pending[id] = { prefix = prefix, text = u, t = os.clock() };
    st.chars = st.chars + #u;
    save();
end

local last_poll = 0;
ashita.events.register('d3d_present', 'omni_translate_poll', function ()
    if next(pending) == nil then return; end
    if os.clock() - last_poll < 0.25 then return; end
    last_poll = os.clock();
    for id, p in pairs(pending) do
        local out = work_dir() .. id .. '.out';
        local f = io.open(out, 'rb');
        if f ~= nil then
            local res = f:read('*a') or '';
            f:close();
            pending[id] = nil;
            os.remove(out);
            os.remove(work_dir() .. id .. '.in');
            res = res:gsub('^\239\187\191', ''):gsub('%s+$', '');
            if res:sub(1, 1) == '!' then
                msg('translation failed: ' .. res:sub(2, 120));
            elseif res ~= '' then
                cache[p.text] = res;
                show(p.prefix, res);
            end
        elseif os.clock() - p.t > 20 then
            pending[id] = nil;
            os.remove(work_dir() .. id .. '.in');
            msg('no answer from the translation service (timed out).');
        end
    end
end);

ashita.events.register('text_in', 'omni_translate_text', function (e)
    if not st.on or e.injected then return; end
    pcall(function ()
        local s = clean(e.message or '');
        local at = first_japanese(s);
        if at == nil then return; end
        -- Keep the English part in front ("Name : ", "(Name) ") as it is; translate the rest.
        local prefix = s:sub(1, at - 1);
        if #prefix > 40 then prefix = ''; at = 1; end
        translate(prefix, s:sub(at));
    end);
end);

ashita.events.register('command', 'omni_translate_cmd', function (e)
    local a = e.command:args();
    if #a == 0 then return; end
    local c0 = a[1]:lower();
    if c0 ~= '/translate' and c0 ~= '/tr' then return; end
    e.blocked = true;
    local c = (a[2] or ''):lower();
    if c == '' or c == 'on' or c == 'off' then
        if c == '' then st.on = not st.on; else st.on = (c == 'on'); end
        save();
        msg('Japanese chat translation ' .. (st.on and 'ON' or 'OFF') .. '.');
    elseif c == 'test' then
        local text = table.concat(a, ' ', 3);
        if text == '' then msg('/translate test <text>'); return; end
        translate('test: ', text);
    elseif c == 'status' then
        msg(('%s. Sent today: about %d of %d characters. Waiting for: %d.'):format(
            st.on and 'ON' or 'OFF', math.floor(st.chars / 3), DAILY, (function () local n = 0; for _ in pairs(pending) do n = n + 1; end return n; end)()));
    else
        msg('/translate  (on/off)  |  /translate test <text>  |  /translate status');
    end
end);

tr.enabled = function () return st.on; end
tr.set = function (on) st.on = (on == true); save(); end
tr.first_japanese = first_japanese;

return tr;
