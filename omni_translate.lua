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
      /translate window          show / hide the Happy Translate window (move it, resize it)
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
pcall(ffi.cdef, [[ unsigned long GetLastError(void); ]]);

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
        -- One-element arrays, so Windows gets proper pointers to the structs.
        local si = ffi.new('omni_tr_STARTUPINFOA[1]');
        si[0].cb = ffi.sizeof('omni_tr_STARTUPINFOA');
        local pi = ffi.new('omni_tr_PROCESS_INFORMATION[1]');
        local cmd = ffi.new('char[?]', #cmdline + 1);
        ffi.copy(cmd, cmdline);
        local r = ffi.C.CreateProcessA(nil, cmd, nil, nil, 0, CREATE_NO_WINDOW, nil, nil, si, pi);
        if r ~= 0 then
            ffi.C.CloseHandle(pi[0].hThread);
            ffi.C.CloseHandle(pi[0].hProcess);
            return true;
        end
        return 'Windows error ' .. tostring(ffi.C.GetLastError());
    end);
    if not ok then return false, tostring(res); end
    if res ~= true then return false, res; end
    return true;
end

----------------------------------------------------------------------------------------------------
-- Settings and files
----------------------------------------------------------------------------------------------------
local st = { master = true, on = true, zh = true, reply = false, win = false, chat_out = true, x = 60, y = 220, w = 520, h = 300,
             today = os.date('%Y-%m-%d'), chars = 0 };
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
        f:write('on ', st.on and 1 or 0, '\n', 'zh ', st.zh and 1 or 0, '\n', 'reply ', st.reply and 1 or 0, '\n', 'day ', st.today, '\n', 'chars ', st.chars, '\n');
        f:write('master ', st.master and 1 or 0, '\n');
        f:write('win ', st.win and 1 or 0, '\n', 'chat ', st.chat_out and 1 or 0, '\n', ('pos %d %d %d %d\n'):format(st.x, st.y, st.w, st.h));
        f:close();
    end);
end
pcall(function ()
    local f = io.open(cfg_path(), 'r');
    if f == nil then return; end
    for raw in f:lines() do
        local line = raw:gsub('%s+$', '');
        local v = line:match('^on (%d)$'); if v then st.on = (v == '1'); end
        local z = line:match('^zh (%d)$'); if z then st.zh = (z == '1'); end
        local r = line:match('^reply (%d)$'); if r then st.reply = (r == '1'); end
        local mv = line:match('^master (%d)$'); if mv then st.master = (mv == '1'); end
        local wv = line:match('^win (%d)$'); if wv then st.win = (wv == '1'); end
        local cv = line:match('^chat (%d)$'); if cv then st.chat_out = (cv == '1'); end
        local px, py, pw, ph = line:match('^pos (%-?%d+) (%-?%d+) (%d+) (%d+)$');
        if px then st.x, st.y, st.w, st.h = tonumber(px), tonumber(py), tonumber(pw), tonumber(ph); end
        local d = line:match('^day (%S+)$'); if d then st.today = d; end
        local c = line:match('^chars (%d+)$'); if c then st.chars = tonumber(c); end
    end
    f:close();
end);

local DAILY = 5000;   -- MyMemory's free allowance (characters a day, no key)

local function msg(t) tr.status = t; print('\30\68[Happy Translate]\30\01 ' .. t); end
-- Translations themselves are shown in pink (the game's Magenta chat colour).
local PINK_CHAT = '\30\05';
local function msg_pink(t) tr.status = t; print('\30\68[Happy Translate]\30\01 ' .. PINK_CHAT .. t .. '\30\01'); end

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
-- Pinyin (Chinese typed in English letters, no tones): spotting it, and turning Chinese into it.
----------------------------------------------------------------------------------------------------
local PY = nil;          -- pinyin -> "chars"   (omni_pinyin.lua)
local SYL = {};          -- set of every pinyin syllable
local CHAR_PY = nil;     -- utf8 char -> pinyin (built the first time it is needed)
do
    local ok, t = pcall(require, 'omni_pinyin');
    if ok and type(t) == 'table' then PY = t; for k in pairs(t) do SYL[k] = true; end end
end

-- Is this word made only of pinyin syllables? ("kanen" = kan+en, "guan" = guan)
local function is_pinyin_word(w)
    local n = #w;
    local okat = { [0] = true };
    for i = 1, n do
        for len = 1, 6 do
            local j = i - len;
            if j >= 0 and okat[j] and SYL[w:sub(j + 1, i)] then okat[i] = true; break; end
        end
    end
    return okat[n] == true;
end

-- Words that are pinyin AND everyday English: a line made only of these is treated as English.
local ENGLISH = {};
for w in ('a an he me you man can ban pan fan long hang bang sang tan ran die pie ten men hen dang gang lang bo '
       .. 'yo ha ma pa ping pong shi ok lol go so no'):gmatch('%S+') do ENGLISH[w] = true; end

local function looks_pinyin(text)
    if PY == nil then return false; end
    local words, good, eng = 0, 0, 0;
    for w in text:lower():gmatch('%a+') do
        words = words + 1;
        if is_pinyin_word(w) then good = good + 1; end
        if ENGLISH[w] then eng = eng + 1; end
    end
    if words < 2 then return false; end
    if words == 2 and eng > 0 then return false; end
    if good / words < 0.85 then return false; end
    if eng >= words - 1 then return false; end
    return true;
end

-- One UTF-8 character at a time.
local function utf8_chars(s)
    return s:gmatch('[%z\1-\127\194-\244][\128-\191]*');
end
local PUNCT = { ['，'] = ',', ['。'] = '.', ['？'] = '?', ['！'] = '!', ['：'] = ':', ['；'] = ';',
                ['、'] = ',', ['“'] = '"', ['”'] = '"', ['（'] = '(', ['）'] = ')' };
local function to_pinyin(zh)
    if CHAR_PY == nil then
        CHAR_PY = {};
        for py, chars in pairs(PY or {}) do
            for ch in utf8_chars(chars) do CHAR_PY[ch] = py; end
        end
    end
    local out = {};
    for ch in utf8_chars(zh) do
        local py = CHAR_PY[ch];
        if py then out[#out + 1] = ' ' .. py .. ' ';
        elseif PUNCT[ch] then out[#out + 1] = PUNCT[ch] .. ' ';
        elseif #ch == 1 then out[#out + 1] = ch; end
    end
    local r = table.concat(out):gsub('%s+([,%.%?!:;])', '%1'):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '');
    return r;
end

----------------------------------------------------------------------------------------------------
-- Other languages players type with English letters: Spanish, Portuguese, French, German.
-- A line counts when at least two of its words are common words of that language and it has
-- clearly fewer common English words.
----------------------------------------------------------------------------------------------------
local LANG_WORDS = {
    es = 'que el los las por para una pero como muy gracias hola tengo quiero vamos estoy eres esta este bien donde cuando nada todo tambien ahora porque necesito puedo hay soy aqui',
    pt = 'nao você voce obrigado obrigada tudo bem estou muito mas com isso aqui agora tem sim tambem vou estamos pode fazer obg vc',
    fr = 'je tu nous vous est pas oui merci bonjour salut avec pour dans une mais tres suis elle les des sont faire peux veux allez bien encore',
    de = 'ich du nicht und ist ja nein danke bitte wir ihr mit auf ein eine der das auch noch gut hallo schon mal habe bin kann wie',
};
local ENGLISH_WORDS = {};
for w in ('the and is it you i to a of in for on with that this have are be can will do not my me we just so what but if at up get go lol ok yes no all any one need pop thanks ty hi'):gmatch('%S+') do ENGLISH_WORDS[w] = true; end
local LANG_SET = {};
for code, words in pairs(LANG_WORDS) do
    LANG_SET[code] = {};
    for w in words:gmatch('%S+') do LANG_SET[code][w] = true; end
end
local function detect_lang(text)
    local words, en = {}, 0;
    for w in text:lower():gmatch("[%a']+") do
        words[#words + 1] = w;
        if ENGLISH_WORDS[w] then en = en + 1; end
    end
    if #words < 3 then return nil; end
    local best, best_n = nil, 0;
    for code, set in pairs(LANG_SET) do
        local n = 0;
        for _, w in ipairs(words) do if set[w] then n = n + 1; end end
        if n > best_n then best, best_n = code, n; end
    end
    if best_n >= 2 and best_n > en * 1.5 then return best; end
    return nil;
end

----------------------------------------------------------------------------------------------------
-- The queue: each job gets an id; the helper writes <id>.out when it has the answer.
----------------------------------------------------------------------------------------------------
local pending = {};      -- id -> { done = function(result), text, t, key }
local cache = {};        -- mode .. text -> result
local next_id = 1;
local session = tostring(os.time());

-- Everything translated, newest last, for the Happy Translate window.
local log = {};
local channel_of;   -- defined further down
local function add_log(e)
    e.time = os.date('%H:%M');
    log[#log + 1] = e;
    if #log > 200 then table.remove(log, 1); end
    tr.scroll = true;
end

local function show(prefix, english, original, inline)
    local ch, who = nil, nil;
    if channel_of then ch, who = channel_of(prefix); end
    add_log({ who = (prefix or ''):gsub('%s+$', ''), text = english, orig = original, chan = ch, tell = who });
    if ch then tr.last_chan, tr.last_tell = ch, who; tr.reply_chan = (ch == '/t' and who) and ('/t ' .. who) or ch; end
    if st.chat_out and not inline then
        local sj = utf8_to_sjis(english) or english:gsub('[\128-\255]', '?');
        msg_pink(prefix .. sj);
    end
end

-- mode: 'ja' (Japanese -> English), 'py' (pinyin -> English), 'zh' (English -> Chinese)
local function job(mode, u, done, fail)
    fail = fail or function () end;
    if u == nil or u:match('^%s*$') then fail(); return false; end
    local key = mode .. ':' .. u;
    if cache[key] then done(cache[key]); return true; end
    if os.date('%Y-%m-%d') ~= st.today then st.today = os.date('%Y-%m-%d'); st.chars = 0; st.warned = false; end
    if st.chars + #u > DAILY * 3 then
        if not st.warned then st.warned = true; msg('daily free translation limit reached - back tomorrow.'); end
        fail();
        return false;
    end
    ensure_dir();
    local id = session .. '_' .. next_id;
    next_id = next_id + 1;
    local base = work_dir() .. id;
    local f = io.open(base .. '.in', 'wb');
    if f == nil then msg('could not write ' .. base .. '.in'); fail(); return false; end
    f:write(u);
    f:close();
    local ps1 = addon_dir() .. 'omni_translate.ps1';
    local chk = io.open(ps1, 'r');
    if chk == nil then msg('helper missing: ' .. ps1); fail(); return false; end
    chk:close();
    local cmd = ('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%s" -Mode %s -In "%s.in" -Out "%s.out"'):format(ps1, mode, base, base);
    local started, why = run_hidden(cmd);
    if not started then msg('could not start the translate helper (PowerShell): ' .. tostring(why)); fail(); return false; end
    pending[id] = { done = done, fail = fail, t = os.clock(), key = key };
    st.chars = st.chars + #u;
    save();
    return true;
end

local function translate(prefix, sjis_text)          -- Japanese line
    job('ja', sjis_to_utf8(sjis_text), function (en) show(prefix, en); end);
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
                pcall(p.fail);
            elseif res ~= '' then
                cache[p.key] = res;
                pcall(p.done, res);
            end
        elseif os.clock() - p.t > 12 then   -- a held-back chat line should not wait long
            pending[id] = nil;
            os.remove(work_dir() .. id .. '.in');
            msg('no answer from the translation service (timed out).');
            pcall(p.fail);
        end
    end
end);

-- "(Name) ", "Name : ", "<Name> ", "[1]<Name> ", ">>Name : " - the part of a chat line before the words.
-- Which channel to answer on, from how the line starts.
channel_of = function (pre)
    pre = pre or '';
    if pre:match('^%s*%b()') then return '/p'; end
    if pre:match('^%s*%[2%]%b<>') then return '/l2'; end
    if pre:match('^%s*%[1%]%b<>') or pre:match('^%s*%b<>') then return '/l'; end
    local who = pre:match('^%s*([%w_]+)>>');
    if who then return '/t', who; end
    if pre:match('^%s*[%w_]+%s*:') then return '/s'; end
    return nil;
end

local function split_speaker(s)
    local pre, rest = s:match('^(%s*%b()%s*)(.*)$');
    if pre == nil then pre, rest = s:match('^(%s*%[%d%]%b<>%s*)(.*)$'); end
    if pre == nil then pre, rest = s:match('^(%s*%b<>%s*)(.*)$'); end
    if pre == nil then pre, rest = s:match('^(%s*[%w_]+>>%s*)(.*)$'); end
    if pre == nil then pre, rest = s:match('^(%s*>?>?[%w_]+%s*:%s*)(.*)$'); end
    if pre == nil then return '', s; end
    return pre, rest;
end

-- The original chat line is held back for the second or two the translation takes, then shown
-- again in its own channel with the English on the end, in pink:
--   [1]<Kennan> dou tong guan le rang gei mei tong guan de  >> Everyone has cleared it ...
-- If the translation fails, the line is shown as it was.
local function one_line(e, prefix, mode, text)
    -- The raw line (no timestamp): your timestamp addon adds its own when the line is put back.
    local line = (e.message or e.message_modified or ''):gsub('[\r\n\7]+$', '');
    local chat_mode = e.mode_modified or e.mode or 1;
    local function put(str)
        pcall(function () AshitaCore:GetChatManager():AddChatMessage(chat_mode, false, str); end);
    end
    e.blocked = true;
    job(mode, text, function (en)
        show(prefix, en, (mode ~= 'ja') and text or nil, true);
        local sj = utf8_to_sjis(en) or en:gsub('[\128-\255]', '?');
        put(line .. '  ' .. PINK_CHAT .. '>> ' .. sj .. '\30\01');
    end, function () put(line); end);
end

ashita.events.register('text_in', 'omni_translate_text', function (e)
    if e.injected or not st.master then return; end
    pcall(function ()
        local s = clean(e.message or '');
        -- Japanese (any line).
        local at = first_japanese(s);
        if at ~= nil then
            -- Keep the English part in front ("Name : ", "(Name) ") as it is; translate the rest.
            local prefix = s:sub(1, at - 1);
            if #prefix > 40 then prefix = ''; at = 1; end
            one_line(e, prefix, 'ja', sjis_to_utf8(s:sub(at)));
            return;
        end
        -- Player chat in English letters: pinyin, or Spanish / Portuguese / French / German.
        local pre, rest = split_speaker(s);
        if pre == '' then return; end
        if looks_pinyin(rest) then
            one_line(e, pre, 'py', rest);
            return;
        end
        local lang = detect_lang(rest);
        if lang ~= nil then
            one_line(e, pre, lang, rest);
        end
    end);
end);

----------------------------------------------------------------------------------------------------
-- Your replies: with "Reply in Chinese" on, /l /l2 /p /t /s /sh messages are sent as pinyin.
-- Start the message with = to send it as typed (e.g. /l =lol).
----------------------------------------------------------------------------------------------------
local CHANNELS = { ['/l'] = 0, ['/linkshell'] = 0, ['/l2'] = 0, ['/linkshell2'] = 0, ['/p'] = 0, ['/party'] = 0,
                   ['/s'] = 0, ['/say'] = 0, ['/sh'] = 0, ['/shout'] = 0, ['/t'] = 1, ['/tell'] = 1 };
local passthrough = {};   -- exact commands omni itself sends, so they are not translated again

-- Send `text` on channel `keep` ("/l", "/t Hush"): in pinyin when Reply in Chinese is on.
local function send_text(keep, text, force_english)
    local function send(out) passthrough[out] = true; AshitaCore:GetChatManager():QueueCommand(1, out); end
    if text:sub(1, 1) == '=' or force_english then
        send(keep .. ' ' .. (text:sub(1, 1) == '=' and text:sub(2) or text));
        return;
    end
    local en = sjis_to_utf8(text) or text;
    local function send_as_typed()
        msg('sent in English instead.');
        add_log({ who = 'you ' .. keep, text = text, mine = true });
        send(keep .. ' ' .. text);
    end
    tr.status = 'translating: ' .. text;
    if st.chat_out then msg('translating your message...'); end
    job('zh', en, function (zh)
        local py = to_pinyin(zh);
        if py == '' then msg('could not turn that into pinyin.'); send_as_typed(); return; end
        if #py > 110 then py = py:sub(1, 110); end
        tr.status = ('sent: %s'):format(py);
        if st.chat_out then msg_pink(('you: "%s" -> %s'):format(text, py)); end
        add_log({ who = 'you ' .. keep, text = text, orig = py, mine = true });
        send(keep .. ' ' .. py);
    end, send_as_typed);
end

local function reply(e)
    local cmdline = e.command;
    if passthrough[cmdline] then passthrough[cmdline] = nil; return false; end
    local a = e.command:args();
    local head = (a[1] or ''):lower();
    local extra = CHANNELS[head];
    if extra == nil then return false; end
    -- "/t Name message" keeps the name; everything after it is the message.
    local keep = head;
    if extra == 1 then
        if a[2] == nil then return false; end
        keep = a[1] .. ' ' .. a[2];
    end
    local text = cmdline:sub(#keep + 2);
    if text == nil or text:match('^%s*$') then return false; end
    if text:sub(1, 1) ~= '=' and (first_japanese(text) ~= nil or text:find('\253', 1, true)) then return false; end   -- not plain English
    e.blocked = true;
    send_text(keep, text);
    return true;
end

ashita.events.register('command', 'omni_translate_cmd', function (e)
    local a = e.command:args();
    if #a == 0 then return; end
    local c0 = a[1]:lower();
    -- /zl /zl2 /zp /zs /zsh text, /zt Name text, /zr text: always translated, sent as pinyin.
    local ZCH = { ['/zl'] = '/l', ['/zl2'] = '/l2', ['/zp'] = '/p', ['/zs'] = '/s', ['/zsh'] = '/sh' };
    if ZCH[c0] or c0 == '/zt' or c0 == '/zr' then
        e.blocked = true;
        local keep, text;
        if ZCH[c0] then
            keep, text = ZCH[c0], e.command:sub(#a[1] + 2);
        elseif c0 == '/zt' then
            if a[2] == nil then msg('/zt <name> <message>'); return; end
            keep, text = '/t ' .. a[2], e.command:sub(#a[1] + #a[2] + 3);
        else
            local ch = tr.reply_chan or '/l';
            keep, text = ch, e.command:sub(#a[1] + 2);
        end
        if text == nil or text:match('^%s*$') then msg(c0 .. ' <message>'); return; end
        local ok, err = pcall(send_text, keep, text, false);
        if not ok then msg('error: ' .. tostring(err)); end
        return;
    end
    if c0 ~= '/translate' and c0 ~= '/tr' then
        if st.reply then pcall(reply, e); end
        return;
    end
    e.blocked = true;
    local c = (a[2] or ''):lower();
    if c == '' or c == 'on' or c == 'off' then
        if c == '' then st.master = not st.master; else st.master = (c == 'on'); end
        save();
        msg('chat translation ' .. (st.master and 'ON' or 'OFF') .. '.');
    elseif c == 'chinese' or c == 'zh' or c == 'pinyin' then
        st.zh = not st.zh; save();
        msg('Pinyin (Chinese) chat translation ' .. (st.zh and 'ON' or 'OFF') .. '.');
    elseif c == 'window' or c == 'win' or c == 'w' then
        st.win = not st.win; save();
    elseif c == 'reply' then
        st.reply = not st.reply; save();
        msg('Reply in Chinese ' .. (st.reply and 'ON - your /l /p /t /s /sh messages are sent as pinyin. Start a message with = to send it as typed.' or 'OFF'));
    elseif c == 'test' then
        local text = table.concat(a, ' ', 3);
        if text == '' then msg('/translate test <text>'); return; end
        if first_japanese(text) then translate('test: ', text);
        elseif looks_pinyin(text) then job('py', text, function (en) show('test: ', en); end);
        else job('zh', text, function (zh) msg('test: ' .. to_pinyin(zh)); end); end
    elseif c == 'status' then
        msg(('Japanese %s, pinyin %s, reply in Chinese %s. Sent today: about %d of %d characters. Waiting for: %d.'):format(
            st.on and 'ON' or 'OFF', st.zh and 'ON' or 'OFF', st.reply and 'ON' or 'OFF',
            math.floor(st.chars / 3), DAILY, (function () local n = 0; for _ in pairs(pending) do n = n + 1; end return n; end)()));
    else
        msg('/translate window | /translate (Japanese on/off) | /translate chinese (pinyin on/off) | /translate reply (answer in pinyin) | /translate test <text> | /translate status');
    end
end);

----------------------------------------------------------------------------------------------------
-- The Happy Translate window: move it by its title bar, resize it from the corner, the arrow
-- folds it up. Where you leave it is remembered.
----------------------------------------------------------------------------------------------------
local imgui = require('imgui');
local GOLD, DIM, TEXT, MINE = { 0.90, 0.78, 0.40, 1.0 }, { 0.60, 0.62, 0.68, 1.0 }, { 0.93, 0.93, 0.96, 1.0 }, { 0.55, 0.80, 1.00, 1.0 };
local PINK = { 1.00, 0.45, 0.85, 1.0 };
local CHAN = { '/l', '/l2', '/p', '/s', '/sh', '/t' };
local CHAN_Z = 'LS\0LS2\0Party\0Say\0Shout\0Tell\0';
local chan_i, tell_buf, in_buf = { 0 }, { '' }, { '' };
local function pick_chan(ch, who)
    for i, c in ipairs(CHAN) do if c == ch then chan_i[1] = i - 1; end end
    if ch == '/t' and who then tell_buf[1] = who; end
end
local save_at = nil;

local function check(label, val, tip, set)
    local v = { val };
    if imgui.Checkbox(label, v) then set(v[1]); save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip(tip); end
end

-- The page: switches, the translated lines, and the reply box. Used by the window and the tab.
local function body(in_tab)
    -- The one switch: reading and translating chat, on or off (the same slider as Happy Healer's).
    local style = package.loaded['omni_style'];
    local tip = 'Reads every chat channel and translates lines that are not English:\nJapanese, Chinese pinyin, Spanish, Portuguese, French, German.\nSame as /translate on and /translate off.';
    local clicked;
    if style ~= nil and style.switch ~= nil then
        clicked = style.switch(in_tab and '##trt_master' or '##trw_master', st.master, tip);
    else
        clicked = imgui.Button((st.master and 'ON' or 'OFF') .. (in_tab and '##trt_master' or '##trw_master'));
    end
    if clicked then
        st.master = not st.master; save();
        msg('chat translation ' .. (st.master and 'ON' or 'OFF') .. '.');
    end
    imgui.SameLine(0, 6);
    imgui.TextColored(st.master and GOLD or DIM, st.master and 'Translate' or 'Translate (off)');
    imgui.SameLine(0, 16);
    if imgui.SmallButton((st.win and 'Close pop-out' or 'Pop out') .. (in_tab and '##trt_pop' or '##trw_pop')) then st.win = not st.win; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('A window you can move and resize with the same lines and reply box.'); end

    -- A new translated line: answer on its channel.
    if tr.last_chan then pick_chan(tr.last_chan, tr.last_tell); tr.last_chan, tr.last_tell = nil, nil; end

    -- The lines
    imgui.BeginChild(in_tab and '##trt_log' or '##trw_log', { 0, in_tab and 260 or -52 }, true);
    if #log == 0 then
        imgui.TextColored(DIM, st.master and 'Nothing translated yet. Lines in other languages from any chat show up here.' or 'Translation is OFF - press the switch to turn it on.');
    end
    for _, e in ipairs(log) do
        imgui.TextColored(DIM, e.time);
        imgui.SameLine(0, 6);
        imgui.TextColored(e.mine and MINE or GOLD, e.who ~= '' and e.who or '?');
        if e.chan and imgui.IsItemClicked() then pick_chan(e.chan, e.tell); end
        if e.chan and imgui.IsItemHovered() then imgui.SetTooltip('Click to reply on ' .. e.chan .. (e.tell and (' ' .. e.tell) or '')); end
        imgui.SameLine(0, 6);
        imgui.PushTextWrapPos(0);
        imgui.TextColored(e.mine and TEXT or PINK, (e.text:gsub('%%', '%%%%')));
        if e.orig ~= nil and not e.orig:find('[\128-\255]') then
            imgui.TextColored(e.mine and PINK or DIM, ((e.mine and 'sent: ' or '') .. e.orig):gsub('%%', '%%%%'));
        end
        imgui.PopTextWrapPos();
    end
    if tr.scroll then imgui.SetScrollHereY(1.0); tr.scroll = false; end
    imgui.EndChild();

    -- Reply box: channel, (name for a tell), message, Enter or Send.
    imgui.PushItemWidth(66);
    imgui.Combo('##trw_chan', chan_i, CHAN_Z);
    imgui.PopItemWidth();
    local keep = CHAN[chan_i[1] + 1];
    if keep == '/t' then
        imgui.SameLine(0, 4);
        imgui.PushItemWidth(90);
        imgui.InputTextWithHint('##trw_tell', 'name', tell_buf, 20);
        imgui.PopItemWidth();
        keep = '/t ' .. tell_buf[1];
    end
    imgui.SameLine(0, 4);
    imgui.PushItemWidth(-54);
    local hint = 'type in English, then click Send - it goes out as pinyin';
    imgui.InputTextWithHint('##trw_in', hint, in_buf, 200);
    local entered = false;   -- only the Send button sends (Leon's choice); Enter does nothing here
    imgui.PopItemWidth();
    imgui.SameLine(0, 4);
    local clicked = imgui.Button('Send##trw_send', { -1, 0 });
    if (entered or clicked) and not in_buf[1]:match('^%s*$') then
        local text = in_buf[1]:gsub('^%s+', '');
        in_buf[1] = '';
        local ok, err = pcall(function ()
        if text:sub(1, 1) == '/' then
            -- A whole command (/l2 hi, /p hi): run it like the chat line would.
            AshitaCore:GetChatManager():QueueCommand(1, text);
        elseif keep == '/t ' then
            msg('type a name for the tell first.');
        else
            -- The box always translates (that is what it is for); = in front sends it as typed.
            send_text(keep, text, false);
        end
        end);
        if not ok then msg('error: ' .. tostring(err)); end
        imgui.SetKeyboardFocusHere(-1);
    end
    if tr.status then
        imgui.TextColored(DIM, (tr.status:gsub('%%', '%%%%')));
    end

end
tr.render = function ()
    body(true);
end

local function window()
    imgui.SetNextWindowPos({ st.x, st.y }, ImGuiCond_FirstUseEver);
    imgui.SetNextWindowSize({ st.w, st.h }, ImGuiCond_FirstUseEver);
    pcall(imgui.SetNextWindowSizeConstraints, { 340, 170 }, { 1600, 1100 });
    local style = package.loaded['omni_style'];
    local ns = style and style.begin() or nil;
    local open = { true };
    if imgui.Begin('Happy Translate###omni_translate_win', open, ImGuiWindowFlags_NoScrollbar) then
        body(false);

        -- Remember where it is and how big.
        pcall(function ()
            local x, y = imgui.GetWindowPos();
            local w, h = imgui.GetWindowSize();
            if type(x) == 'table' then x, y = x[1], x[2]; end
            if type(w) == 'table' then w, h = w[1], w[2]; end
            if w == nil then w, h = imgui.GetWindowWidth(), imgui.GetWindowHeight(); end
            x, y, w, h = math.floor(x), math.floor(y), math.floor(w), math.floor(h);
            if x ~= st.x or y ~= st.y or w ~= st.w or h ~= st.h then
                st.x, st.y, st.w, st.h = x, y, w, h;
                save_at = os.clock() + 1;
            end
        end);
    end
    imgui.End();
    if style then style.finish(ns); end
    if not open[1] then st.win = false; save(); end
    if save_at and os.clock() > save_at then save_at = nil; save(); end
end

ashita.events.register('d3d_present', 'omni_translate_window', function ()
    if st.win then window(); end
end);

tr.enabled = function () return st.master; end
tr.set = function (on) st.master = (on == true); save(); end
tr.first_japanese = first_japanese;
tr.looks_pinyin = looks_pinyin;
tr.to_pinyin = to_pinyin;
tr.split_speaker = split_speaker;
tr.zh_enabled = function () return st.zh; end
tr.set_zh = function (on) st.zh = (on == true); save(); end
tr.reply_enabled = function () return st.reply; end
tr.set_reply = function (on) st.reply = (on == true); save(); end
tr.win_shown = function () return st.win; end
tr.set_win = function (on) st.win = (on == true); save(); end

return tr;
