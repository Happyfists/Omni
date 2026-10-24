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
local st = { master = true, on = true, zh = true,
             -- Which languages are translated; all off until you tick them.
             langs = { zh = false, ja = false, fr = false, de = false, es = false, pt = false },
             reply_lang = 'zh',   -- what your replies are translated into
             reply = false, win = false, chat_out = true, x = 60, y = 220, w = 520, h = 300,
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
        f:write('master ', st.master and 1 or 0, '\n', 'rlang ', st.reply_lang, '\n');
        for code, on in pairs(st.langs) do f:write('lang ', code, ' ', on and 1 or 0, '\n'); end
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
        local rl = line:match('^rlang (%a+)$'); if rl then st.reply_lang = rl; end
        local lc, lv = line:match('^lang (%a+) (%d)$'); if lc and st.langs[lc] ~= nil then st.langs[lc] = (lv == '1'); end
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
-- With an email address in translate\email.txt MyMemory allows 50000 a day. The address is read from
-- that file only (never stored in the code) and is sent only to MyMemory, with each request.
local EMAIL = nil;
pcall(function ()
    local f = io.open(work_dir() .. 'email.txt', 'r');
    if f == nil then return; end
    local e = (f:read('*l') or ''):gsub('%s+', '');
    f:close();
    if e:match('^[%w%._%+%-]+@[%w%.%-]+%.%a+$') then EMAIL = e; DAILY = 50000; end
end);

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

-- How many real Japanese letters (hiragana, katakana, kanji) a line has. Faces like "ω .`)/" or
-- "┗(｀O ´)┛" use symbols, Greek and box lines, and aren't sent to the translator.
local function japanese_count(s)
    local i, n, c = 1, #s, 0;
    while i <= n do
        local b, t = s:byte(i), s:byte(i + 1) or 0;
        if (b == 0x82 and t >= 0x9F and t <= 0xF1) or (b == 0x83 and t >= 0x40 and t <= 0x96)
           or (((b >= 0x88 and b <= 0x9F) or (b >= 0xE0 and b <= 0xEA)) and t >= 0x40 and t <= 0xFC and t ~= 0x7F) then
            c = c + 1;
        end
        if (b >= 0x81 and b <= 0x9F) or (b >= 0xE0 and b <= 0xFC) then i = i + 2; else i = i + 1; end
    end
    return c;
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

-- Everyday words Chinese players often type joined up; never taken as a name.
local JOINED_WORDS = {};
for w in ('women nimen tamen xiexie haode haoba haole pengyou zhege nage zheli nali nage shenme zenme weishenme keyi meiyou xianzai yiqi dajia laoban laoda dage meimei jiejie gege didi duibuqi meishi meiwenti mashang dengdeng deng yixia yihui jintian mingtian zuotian wanshang zaoshang zhidao bushi buyao buhao zaijian nihao laile zoule zouba kuaidian xiaxian shangxian'):gmatch('%S+') do JOINED_WORDS[w] = true; end

-- Fewest pinyin syllables a word can be split into ("dapangtou" = 3, "zu" = 1; 0 = not pinyin).
local function syllables(w)
    local n = #w;
    local best = { [0] = 0 };
    for i = 1, n do
        for len = 1, 6 do
            local j = i - len;
            if j >= 0 and best[j] and SYL[w:sub(j + 1, i)] and (best[i] == nil or best[j] + 1 < best[i]) then
                best[i] = best[j] + 1;
            end
        end
    end
    return best[n] or 0;
end

-- Everyday English words that can also be read as pinyin ("nice" = ni+ce, "sure" = su+re). Made from
-- the 6000 most common English words, minus everyday Chinese ones (wo, ni, men, hao, de, le ...).
local ENGLISH = {};
for w in ([[a abuse ace adam again age agenda ai aim aka alabama alan ali alice alien alike alone along alongside am america american an anger angle animation anime ann anna anne announce annoying anti anyone are area arena asia asian aside ate awake aware balance ban bang banner bare base beijing ben bike bin binding bite bone boom boxing buying ca cabin cage cake came camera cameron can canada canadian candidate canon care career case casino ceo chain champion chance change chase cheating cheese china chinese cia cinema citizen counting cousin cuba cure cute dam damage damn dan dance danger dare data database date dating dealing dean debate decade decide deciding decision deer defence defending defense delete demanding denver depending desire di dialogue die dining dinner disease du dude due duke e ease easier eaten eating editing edition education eliminate elite em emma emotion empire en ending engage ensure entire era eye fa face fake fame fan fashion fate fence footage forum foundation fun funding future ga gain gaining game gaming gang gate gen gene generate generation genre guarantee guidance guide gun ha haha ham hammer hang hate he heading healing heating hehe helen hence here heritage hmm hong house huge human hunting jim juan julia jumping june kate keen keeping ken kenya kong lake landing lane language late latin laying leading league lean lease lee leo license lie like line lion lisa loan location long longer loose lose luke m machine made magazine main maine maintain maintaining maintenance make male mama man manage manner maria marie marijuana marine mario mate mature maximum me mean meaning measure media medication medicine medium meeting mention menu mere mexican mi miami michigan mike mile min mine mini minimum mining minute mixing mm mo mobile mode mom moon moore more motion mountain mouse mum n name nasa nation nature nazi nba nice nigeria nine no non none nonsense noon nose note notice notion o obama ocean on once one online ontario open opinion orange pa pace page pain painting palace pan patience paying pen pension piano pie piece pile pin poem pole police politician population position pure putin queen quote ran range re reading realise realize reduce refuse regulation relate relating relation release remain remaining remote reputation residence resume retain rice ride riding rio rise route routine rude ruin rule ruling run runner running sa sake sale sam same santa saying se sea sean secure see seem seen semi senate sending sense sentence sequence shade shake shame share she shine side silence silver simon sin since singapore site situation size song sue suicide suite sum summer sun sunshine sure susan take taken tale taxi tea team teen teenage ten tension tie tier tim time timeline timing tune wa wage waiting wake wanna wanting woke woman women won wooden wore xi ya ye yea yo yoga you]]):gmatch('%S+') do ENGLISH[w] = true; end

-- Take out what is not words: auto-translate phrases ({Ru'Aun Gardens}), map grids (I-5, K12),
-- numbers and punctuation. What is left is what we judge.
local function words_only(text)
    text = text:gsub('%b{}', ' '):gsub('\239[\39\40]', ' ');
    text = text:lower():gsub("%f[%w]%a%-?%d+%f[%W]", ' '):gsub('%d+', ' '):gsub("[^%a%s']", ' ');
    return (text:gsub('%s+', ' '):gsub('^ ', ''):gsub(' $', ''));
end

-- Chat shorthand Chinese players type, written out before anything is checked or translated.
-- Game names Chinese players use, swapped for the English name before a line goes to the
-- translator so it can't turn them into something else ("bai men" = white gate = Whitegate).
local GLOSSARY = {
    ['bai men'] = 'Whitegate', ['bai hu'] = 'Byakko', ['qing long'] = 'Seiryu', ['zhu que'] = 'Suzaku',
    ['xuan wu'] = 'Genbu', ['ba ha mu te'] = 'Bahamut', ['bahamute'] = 'Bahamut', ['jue dui mei de'] = 'Absolute Virtue',
};

local SHORT = {
    sm = 'shen me', zm = 'zen me', wsm = 'wei shen me', zms = 'zen me shuo', sms = 'shen me shi', dd = 'deng deng',
};
local function expand_short(text)
    return (text:gsub('%f[%w](%w+)%f[%W]', function (w)
        if w == 'l' then return 'le'; end   -- "zuo l ma" = zuo le ma (only a small l)
        local x = SHORT[w:lower()];
        if x ~= nil then return x; end
        return w;
    end));
end

-- Player names in a line ("Quixy zu wo"): a capitalised word that is not pinyin is a name.
-- They are taken out before judging, and put in front of a built-in translation.
-- Every player name seen talking in chat is kept in translate\names.txt (lowercase -> as written).
-- Any of those names inside a line is taken out before translating and put back in front.
local KNOWN_NAMES = {};
-- The Happy Translate box: the game's own chat line also gets what you type there, so pressing Enter
-- would send your English straight out. While the box has the keyboard (and just after), and for
-- anything matching what was in it, that line is stopped.
local box = { active_t = -10, text = '', sent_text = '', sent_t = -10 };
local recent_out = {};   -- lines you sent through Happy Translate (lowercase) -> os.clock()
local quick_inline;   -- set further down

local function split_names(text)
    local names, kept = {}, {};
    local first = true;
    for w in text:gmatch('%S+') do
        local word = w:gsub("[^%a']", '');
        local known = KNOWN_NAMES[word:lower()];
        -- A name: one from the names list, or the first word of the line / any capitalised word
        -- that is not pinyin.
        local is_name = word ~= '' and (known ~= nil or (not is_pinyin_word(word:lower()) and (first or word:match('^%u') ~= nil)));
        if word ~= '' then first = false; end
        if is_name then
            names[#names + 1] = known or word;
        else
            kept[#kept + 1] = w;
        end
    end
    -- A lowercase first word only counts as a name if at least two words are left ("quixy zu wo");
    -- otherwise "thanks hao" or "thx lai" would be taken as name + Chinese.
    if #names > 0 and not names[1]:match('^%u') and #kept < 2 then
        return {}, text;
    end
    -- A nickname made of pinyin written as one word, in front of spaced-out Chinese:
    -- "dapangtou tui zu" = Dapangtou + "tui zu" (Chinese players space every syllable, names are joined).
    if #names == 0 and #kept >= 3 then
        local w1 = kept[1]:gsub("[^%a]", ''):lower();
        local rest_single = true;
        for i = 2, #kept do
            local w = kept[i]:gsub("[^%a]", ''):lower();
            if w ~= '' and not SYL[w] then rest_single = false; break; end
        end
        local n = syllables(w1);
        if rest_single and not ENGLISH[w1] and not JOINED_WORDS[w1] and (n >= 3 or (n == 2 and #kept >= 4)) then
            local nm = w1:sub(1, 1):upper() .. w1:sub(2);
            table.remove(kept, 1);
            return { nm }, table.concat(kept, ' ');
        end
    end
    return names, table.concat(kept, ' ');
end

-- Game words Chinese players type in English inside a Chinese line; they do not count either way.
local GAME_EN = {};
-- ...unless they follow one of these words, then they are Chinese: ji lv / gai lv = chance.
local ZH_AFTER = { lv = { ji = true, gai = true, xiao = true, bi = true } };
for w in ('pop nm hnm boss ws tp mp hp lv exp xp gil ok pt ls ki item drop sky sea av ja job sub key keys'):gmatch('%S+') do GAME_EN[w] = true; end

local function looks_pinyin(text)
    if PY == nil then return false; end
    -- A shout in capitals ("DANG!", "GG") is English.
    local letters = text:gsub('[^%a]', '');
    if #letters >= 2 and letters == letters:upper() then return false; end
    local words, good, eng = 0, 0, 0;
    for w in words_only(text):gmatch('%a+') do
        if not GAME_EN[w] then
            words = words + 1;
            if is_pinyin_word(w) then good = good + 1; end
            if ENGLISH[w] then eng = eng + 1; end
        end
    end
    if words == 0 then return false; end
    if words <= 2 then
        -- Short lines ("hao", "zu wo", "kuai lai"): every word one pinyin syllable, none of them English.
        if eng > 0 then return false; end
        for w in words_only(text):gmatch('%a+') do if not SYL[w] and not GAME_EN[w] then return false; end end
        return true;
    end
    if good / words < 0.85 then return false; end
    if eng * 2 >= words then return false; end   -- half or more everyday English: it is English
    return true;
end

-- Common game Chinese (pinyin, no tones) -> English. Used first: instant, and no daily allowance.
local GAME_PY = {
    ['tui zu'] = 'leave the party', ['tui dui'] = 'leave the party', ['wo tui zu'] = "I'm leaving the party",
    ['wo tui le'] = "I'm leaving the party", ['tui le'] = 'left (the party)',
    ['ti wo'] = 'kick me', ['ti le'] = 'kicked', ['jie san'] = 'disband the party',
    ['san le'] = 'party disbanded', ['dui zhang'] = 'party leader', ['gei wo dui zhang'] = 'give me party leader',
    ['ren wu'] = 'missions', ['bai men ren wu'] = 'Whitegate missions', ['bai men'] = 'Whitegate',
    ['zuo le'] = 'done', ['zuo le ma'] = 'done it?', ['zuo wan le'] = 'finished', ['ka zhu le'] = "I'm stuck",
    ['ka le'] = 'stuck', ['zuo dao'] = 'got up to', ['bang wo'] = 'help me', ['bang mang'] = 'help',
    ['ni bai men ren wu zuo le ma'] = 'have you done the Whitegate missions?',
    ['shui ba lan men guan le'] = "who closed the blue door?",
    ['jie san jiu xing la'] = "just disband it",
    ['mei wei zi la'] = "no spots left (party full)",
    ['mei wei zi le'] = "no spots left (party full)",
    ['hai you wei zi ma'] = "any spots left?",
    ['hai you wei zhi ma'] = "any spots left?",
    ['hai you wei zhi me'] = "any spots left?",
    ['wo da yi chang'] = "I'll do one run",
    ['ni men da wo kan kan'] = "you fight, I'll watch",
    ['ni you bu mai gei wo'] = "and you won't sell it to me",
    ['huo dong gao qi'] = "let's get the event going",
    ['gu ji shi de'] = "probably, yes",
    ['da bu guo le a'] = "can't beat it?",
    ['da bu guo'] = "can't beat it",
    ['gei wo jia xue'] = "heal me",
    ['mei qu guo'] = "haven't been there",
    ['chuan song'] = "teleport",
    ['wo shuo wo mei guo bu neng chuan song ba'] = "I said I haven't been there, so I can't teleport",
    ['na fei ba'] = "then fly (teleport) there",
    ['wo dai ni pao'] = "I'll run you there",
    ['ke yi tui'] = "can leave the party",
    ['wo ke yi tui'] = "I can leave the party",
    ['ni tui'] = "you leave the party",
    ['shui yao zu'] = "who wants an invite?",
    ['da dian sha'] = "what shall we fight?",
    ['yao chuan hui qu yi xia ba'] = "need to teleport back for a bit",
    ['fa zai qun li le'] = "posted it in the group chat",
    ['zu ni gan ma'] = "why would I invite you?",
    ['bu da le'] = "not fighting any more?",
    ['rao ban tian ye mei rao guo qu'] = "went round for ages and still couldn't get past",
    ['rao ban tian ye mei rao guoqu'] = "went round for ages and still couldn't get past",
    ['lian meng'] = "alliance",
    ['lian men'] = "alliance",
    ['lian men wo'] = "alliance me",
    ['lian meng wo'] = "alliance me",
    ['lian men dui zhang'] = "alliance leader",
    ['lian meng dui zhang'] = "alliance leader",
    ['ni mei zhan ji'] = "you don't have the points",
    ['ni mei zhan ji ba'] = "you don't have the points, right?",
    ['wo you zhan ji'] = "I have the points",
    ['ren ne'] = "where are they?",
    ['chi fan qu le'] = "gone to eat",
    ['jin'] = "come in",
    ['ni men na zu'] = "which party are you in?",
    ['hai yao ren bu'] = "still need people?",
    ['bu neng'] = "can't",
    ['dou gei'] = "give it all",
    ['wo huan'] = "I'll swap",
    ['ni ganjin de dengni le'] = "hurry up, we're waiting for you",
    ['ni gan jin de deng ni le'] = "hurry up, we're waiting for you",
    ['bie chou re nao a'] = "don't join in just for fun",
    ['mei man de'] = "anyone not capped",
    ['man le'] = "capped (full)",
    ['ni neng jin bu'] = "can you get in?",
    ['ni neng jin ma'] = "can you get in?",
    ['ni hui da ming ling ma'] = "do you know how to type commands?",
    ['ni da ming ling'] = "you type the command",
    ['dai dai wo'] = "take me along",
    ['gan shen me'] = "what for?",
    ['ni men xian da yi ge ran hou wo zai lai'] = "you fight one first, then I'll come",
    ['xian bie jiao yi'] = "don't trade yet",
    ['wo dao le a'] = "I'm here",
    ['wo zai'] = "I'm here",
    ['wo you wo lai le'] = "I have it, I'm coming",
    ['ni zhe nao dai'] = "you airhead",
    ['jiao ni yi zhao'] = "let me teach you a trick",
    ['chuan bu liao'] = "can't wear it",
    ['suo yi chuan bu liao'] = "so I can't wear it",
    ['shi tou chou qi le'] = "got all the stones",
    ['wo bu zhi dao qu na da'] = "I don't know where to fight",
    ['qu na'] = "where to?",
    ['shui yao'] = "who wants it?",
    ['ni you bu li wo'] = "you're ignoring me again",
    ['za mei'] = "why not?",
    ['lai ren a'] = "somebody help!",
    ['ta shi hun zi'] = "he's a jerk",
    ['bie a'] = "don't!",
    ['shi ni de hao ma'] = "is that your alt?",
    ['shi tou'] = 'stones', ['shi tou chou qi le ma'] = 'got all the stones yet?', ['shi tou qi le ma'] = 'got all the stones yet?',
    ['chou qi le'] = 'got the full set', ['chou qi le ma'] = 'got them all yet?', ['qi le'] = 'got them all',
    ['qi le ma'] = 'got them all yet?', ['hai cha'] = 'still missing', ['hai cha ji ge'] = 'how many still missing?',
    ['bao le'] = 'it dropped', ['bao yi fu le'] = 'body piece dropped', ['bao ku zi le'] = 'legs dropped',
    ['bao xie zi le'] = 'feet dropped', ['bao shou tao le'] = 'hands dropped', ['bao tou le'] = 'head dropped',
    ['yi fu'] = 'body (armour)', ['ku zi'] = 'legs', ['xie zi'] = 'feet', ['shou tao'] = 'hands', ['tou kui'] = 'head',
    ['mao zi'] = 'head', ['xiang zi'] = 'chest', ['kai xiang zi'] = 'open the chest', ['mei bao'] = 'nothing dropped',
    ['shui jiao'] = 'asleep (AFK)', ['shui jiao de'] = 'the one who was asleep (AFK)',
    ['shui jiao yi de bao yi fu le'] = 'the one who was asleep (AFK) got the body piece',
    ['ji lv ting da'] = 'the chance is pretty good', ['ji lv di'] = 'low chance', ['ji lv gao'] = 'high chance',
    ['hai shui mei zu'] = "anyone still not in the party?", ['shui mei zu'] = "who isn't in the party?",
    ['hai you shui'] = 'anyone else?', ['shui hai mei zu'] = "anyone still not in the party?", ['mei zu'] = 'not in the party',
    ['rang'] = 'let', ['zu ta'] = 'invite them', ['zu ni'] = 'invite you', ['wo zu'] = "I'll invite",
    ['yi bian wan qu'] = 'go play somewhere else (get lost)', ['yi bian qu'] = 'go away', ['yi bian wan'] = 'go play somewhere else',
    ['gun'] = 'get lost', ['gun kai'] = 'get lost', ['zu wo'] = 'invite me', ['zu'] = 'invite', ['zu ren'] = 'looking for members', ['zu dui'] = 'form a party',
    ['jia wo'] = 'add me', ['la wo'] = 'invite me', ['yao ren'] = 'need people', ['que ren'] = 'need people',
    ['hai que'] = 'still need', ['ji ge ren'] = 'how many people', ['ji ge'] = 'how many',
    ['lai'] = 'come', ['kuai lai'] = 'come quickly', ['jin lai'] = 'come in', ['guo lai'] = 'come over',
    ['lai le'] = 'coming', ['wo lai le'] = "I'm coming", ['ma shang'] = 'right away', ['ma shang lai'] = 'coming right away',
    ['deng'] = 'wait', ['deng wo'] = 'wait for me', ['deng yi xia'] = 'wait a moment', ['deng xia'] = 'wait a moment',
    ['deng deng'] = 'wait', ['shao deng'] = 'wait a moment', ['zou'] = "let's go", ['zou ba'] = "let's go",
    ['zou le'] = 'leaving', ['wo zou le'] = "I'm off", ['qu'] = 'go', ['hui lai'] = 'back', ['hui qu'] = 'go back',
    ['dao le'] = 'arrived', ['zai na'] = 'where', ['zai nar'] = 'where', ['na li'] = 'where', ['zhe li'] = 'here',
    ['hao'] = 'ok', ['hao de'] = 'okay', ['hao le'] = 'done', ['ke yi'] = 'sure', ['bu ke yi'] = "can't",
    ['xing'] = 'ok', ['bu xing'] = 'no good', ['dui'] = 'right', ['bu dui'] = 'wrong', ['shi'] = 'yes',
    ['shi de'] = 'yes', ['bu shi'] = 'no', ['mei you'] = "don't have", ['xie xie'] = 'thanks', ['xie xie ni'] = 'thank you',
    ['xie le'] = 'thanks', ['duo xie'] = 'many thanks', ['bu ke qi'] = "you're welcome", ['bu yong xie'] = "you're welcome",
    ['mei shi'] = 'no problem', ['mei wen ti'] = 'no problem', ['dui bu qi'] = 'sorry', ['bu hao yi si'] = 'sorry',
    ['ni hao'] = 'hello', ['da jia hao'] = 'hello everyone', ['zai jian'] = 'bye', ['bai bai'] = 'bye bye',
    ['wan an'] = 'good night', ['zao'] = 'morning', ['zao shang hao'] = 'good morning',
    ['zhun bei'] = 'get ready', ['zhun bei hao le'] = 'ready', ['kai shi'] = 'start', ['kai'] = 'start',
    ['jie shu'] = 'finished', ['wan le'] = 'done', ['si le'] = 'died', ['qi lai'] = 'get up', ['fu huo'] = 'raise',
    ['jia xue'] = 'heal', ['bu xue'] = 'heal', ['chao feng'] = 'provoke', ['la guai'] = 'pull', ['guai'] = 'mob',
    ['diao le'] = 'it dropped', ['shua'] = 'farm', ['da'] = 'fight', ['sha'] = 'kill', ['gei wo'] = 'give me',
    ['gei ni'] = 'for you', ['wo ye'] = 'me too', ['duo shao'] = 'how much', ['duo shao qian'] = 'how much money',
    ['jin bi'] = 'gil', ['shang xian'] = 'online', ['xia xian'] = 'logging off', ['gong hui'] = 'linkshell',
    ['huo tian qi chu lai le'] = 'fire weather is up', ['chu lai le'] = 'is up', ['tian qi'] = 'weather',
    ['huo tian qi'] = 'fire weather', ['shui tian qi'] = 'water weather', ['feng tian qi'] = 'wind weather',
    ['lei tian qi'] = 'thunder weather', ['bing tian qi'] = 'ice weather', ['tu tian qi'] = 'earth weather',
    ['guang tian qi'] = 'light weather', ['an tian qi'] = 'dark weather', ['xue tian qi'] = 'snow weather',
    ['you mei ren yao lai de'] = 'anyone want to come?', ['you mei you ren'] = 'anyone?', ['you mei ren'] = 'anyone',
    ['yao lai de'] = 'who wants to come', ['you ren ma'] = 'anyone?', ['shei yao'] = 'who wants it', ['shei lai'] = 'who is coming',
    ['zao shang hao'] = 'good morning', ['da jia zao'] = 'morning all',
    ['mei xu jiu pao hui lai'] = "if you don't need it, just run back", ['mei xu'] = "don't need it",
    ['mei xu yao'] = "don't need it", ['bu xu yao'] = "don't need it", ['xu yao'] = 'need', ['pao hui lai'] = 'run back',
    ['pao'] = 'run', ['jiu'] = 'then', ['hui lai le'] = 'back now', ['bi zu'] = 'must have', ['wo men bi xu da ma'] = 'do we have to fight it?', ['bi xu da ma'] = 'do we have to fight it?', ['bi xu'] = 'must',
    ['yao da ma'] = 'are we fighting it?', ['da bu da'] = 'fight or not?', ['da ma'] = 'fight it?', ['bu yong'] = 'no need',
    ['bu yong de'] = 'no need', ['mei tong guan de'] = "haven't cleared it", ['tong guan le ma'] = 'cleared it?',
    ['zhe shi shen me'] = 'what is this', ['na shi shen me'] = 'what is that', ['zhe shi'] = 'this is', ['na shi'] = 'that is',
    ['zhe ge'] = 'this', ['na ge'] = 'that', ['shi shen me'] = 'what is it',
    ['cai liao'] = 'materials', ['pop cai liao'] = 'pop items', ['wo hai you'] = 'I still have',
    ['tong guan'] = 'cleared it', ['tong guan le'] = 'cleared it', ['shen me'] = 'what', ['zen me'] = 'how',
    ['wei shen me'] = 'why', ['zen me ban'] = 'what do we do', ['zai da'] = 'fighting', ['da shen me'] = 'fighting what',
    ['wo'] = 'me', ['ni'] = 'you', ['ni men'] = 'you all', ['wo men'] = 'we', ['ta'] = 'them', ['ma'] = '?',
};

-- Game names Chinese players use (pinyin of the Chinese name -> the English name).
local GAME_NAMES = {
    ['qilin'] = 'Kirin', ['qinlin'] = 'Kirin', ['qi lin'] = 'Kirin', ['qin lin'] = 'Kirin',
    ['xuanwu'] = 'Genbu', ['xuan wu'] = 'Genbu', ['qinglong'] = 'Seiryu', ['qing long'] = 'Seiryu',
    ['baihu'] = 'Byakko', ['bai hu'] = 'Byakko', ['zhuque'] = 'Suzaku', ['zhu que'] = 'Suzaku',
    ['fafuna'] = 'Fafnir', ['fa fu na'] = 'Fafnir', ['jing tun'] = 'Behemoth', ['bei xi mo si'] = 'Behemoth',
    ['jue dui mei de'] = 'Absolute Virtue',
};
for k, v in pairs(GAME_NAMES) do
    GAME_PY[k] = v;
    GAME_PY['da ' .. k] = 'fighting ' .. v;          -- "da qilin" = fighting Kirin
    GAME_PY['qu da ' .. k] = 'going to fight ' .. v;
end

-- Every word covered by the list (longest phrase first)? Then that is the translation.
local function game_phrase(text)
    -- Lines with numbers ("zuo dao 18 ka zhu le") go to the translator, so the number is kept.
    if text:find('%d') then return nil; end
    local w = {};
    for x in words_only(text):gmatch('%a+') do w[#w + 1] = x; end
    if #w == 0 then return nil; end
    local out, i = {}, 1;
    while i <= #w do
        local hit = nil;
        for n = math.min(7, #w - i + 1), 1, -1 do
            local ph = table.concat(w, ' ', i, i + n - 1);
            if GAME_PY[ph] then hit = n; out[#out + 1] = GAME_PY[ph]; break; end
        end
        if hit == nil then return nil; end
        i = i + hit;
    end
    local r = table.concat(out, ', '):gsub(', %?', '?'):gsub('%?, ', '? ');
    if text:find('?', 1, true) and r:sub(-1) ~= '?' then r = r .. '?'; end
    return r;
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
        if not st.langs[code] then goto next_lang; end
        local n = 0;
        for _, w in ipairs(words) do if set[w] then n = n + 1; end end
        if n > best_n then best, best_n = code, n; end
        ::next_lang::
    end
    if best_n >= 2 and best_n > en * 1.5 then return best; end
    return nil;
end

----------------------------------------------------------------------------------------------------
-- The queue: each job gets an id; the helper writes <id>.out when it has the answer.
----------------------------------------------------------------------------------------------------
local pending = {};      -- id -> { done = function(result), text, t, key }
local cache = {};        -- mode .. text -> result

----------------------------------------------------------------------------------------------------
-- The database: everything translated is kept in config\addons\omni\translate\memory.txt, so the same
-- line is never sent twice (not even after a reload). phrases.txt holds your own "pinyin = English"
-- lines; they are used before anything is sent. /translate learn <pinyin> = <English> adds one.
----------------------------------------------------------------------------------------------------
local mem_count = 0;
local function memory_path() return work_dir() .. 'memory.txt'; end
local function phrases_path() return work_dir() .. 'phrases.txt'; end
pcall(function ()
    local f = io.open(memory_path(), 'rb');
    if f == nil then return; end
    for raw in f:lines() do
        local k, v = raw:gsub('\r$', ''):match('^(.-)\t(.+)$');
        -- Skip "translations" that are just the same words back (they were never translated).
        local src = k and k:match('^[%w_]+:(.*)$');
        local same = src and (src:lower():gsub('[%s%p]', '') == v:lower():gsub('[%s%p]', ''));
        if k and v and not same then
            if cache[k] == nil then mem_count = mem_count + 1; end
            cache[k] = v;
        end
    end
    f:close();
end);
local function remember(key, res)
    mem_count = mem_count + 1;
    pcall(function ()
        ensure_dir();
        local f = io.open(memory_path(), 'ab');
        if f == nil then return; end
        f:write((key:gsub('[\t\r\n]', ' ')), '\t', (res:gsub('[\t\r\n]', ' ')), '\n');
        f:close();
    end);
end

local PHRASES_HEADER = [[
# Happy Translate - your own phrase list (pinyin = English). One per line, # for notes.
# These are used straight away, before anything is sent to the translator, so they cost nothing.
# Add more here, or in game: /translate learn zu wo = invite me
]];
local my_phrases = 0;
local function load_phrases()
    local f = io.open(phrases_path(), 'r');
    if f == nil then
        pcall(function ()
            ensure_dir();
            local w = io.open(phrases_path(), 'w');
            if w ~= nil then w:write(PHRASES_HEADER); w:close(); end
        end);
        return;
    end
    for raw in f:lines() do
        local line = raw:gsub('%s+$', '');
        if not line:match('^%s*#') then
            local k, v = line:match('^%s*(.-)%s*=%s*(.-)%s*$');
            if k and v and k ~= '' and v ~= '' then
                GAME_PY[words_only(k)] = v;
                my_phrases = my_phrases + 1;
            end
        end
    end
    f:close();
end
pcall(load_phrases);
local function learn(k, v)
    k = words_only(k);
    if k == '' or v == '' then return false; end
    GAME_PY[k] = v;
    my_phrases = my_phrases + 1;
    pcall(function ()
        ensure_dir();
        local f = io.open(phrases_path(), 'a');
        if f ~= nil then f:write(k, ' = ', v, '\n'); f:close(); end
    end);
    return true;
end

-- The names list (translate\names.txt): one name per line. Filled by itself from everyone who talks
-- in chat; /translate name <Name> adds one, /translate unname <Name> takes one out.
local function names_path() return work_dir() .. 'names.txt'; end
local name_count = 0;
local NAMES_HEADER = '# Happy Translate - player names (one per line). Names in this list are never translated.\n';
pcall(function ()
    local f = io.open(names_path(), 'r');
    if f == nil then return; end
    for raw in f:lines() do
        local n = raw:gsub('%s+', '');
        if n ~= '' and not n:match('^#') and KNOWN_NAMES[n:lower()] == nil then
            KNOWN_NAMES[n:lower()] = n; name_count = name_count + 1;
        end
    end
    f:close();
end);
local function write_names()
    pcall(function ()
        ensure_dir();
        local list = {};
        for _, n in pairs(KNOWN_NAMES) do list[#list + 1] = n; end
        table.sort(list, function (a, b) return a:lower() < b:lower(); end);
        local f = io.open(names_path(), 'w');
        if f == nil then return; end
        f:write(NAMES_HEADER);
        for _, n in ipairs(list) do f:write(n, '\n'); end
        f:close();
    end);
end
-- auto = seen talking in chat. Then a name that is also a short everyday Chinese word ("Hao", "Lai",
-- "Women") is not added by itself, so it never stops those words being translated.
local function add_name(n, auto)
    n = (n or ''):gsub('[^%w_]', '');
    if #n < 2 or KNOWN_NAMES[n:lower()] ~= nil then return false; end
    if auto then
        local l = n:lower();
        if SYL[l] or JOINED_WORDS[l] or GAME_PY[l] or GAME_EN[l] then return false; end
    end
    KNOWN_NAMES[n:lower()] = n; name_count = name_count + 1;
    pcall(function ()
        ensure_dir();
        local new = io.open(names_path(), 'r') == nil;
        local f = io.open(names_path(), 'a');
        if f == nil then return; end
        if new then f:write(NAMES_HEADER); end
        f:write(n, '\n'); f:close();
    end);
    return true;
end
local function remove_name(n)
    n = (n or ''):gsub('[^%w_]', ''):lower();
    if KNOWN_NAMES[n] == nil then return false; end
    KNOWN_NAMES[n] = nil; name_count = name_count - 1;
    write_names();
    return true;
end
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
-- One helper (PowerShell) stays running and answers every line, instead of a new PowerShell for
-- each line (starting PowerShell is what made the game hitch). It closes itself after 30 idle
-- minutes, and when translation is turned off or omni is unloaded (a "stop" file).
local worker_at, last_job = nil, 0;
local function stop_worker()
    pcall(function ()
        local f = io.open(work_dir() .. 'stop', 'w');
        if f then f:write('stop'); f:close(); end
    end);
    worker_at = nil;
end
local function ensure_worker()
    -- Running, and used in the last 25 minutes (it gives up after 30 idle): nothing to do.
    if worker_at ~= nil and os.time() - math.max(worker_at, last_job) < 1500 then return true; end
    local ps1 = addon_dir() .. 'omni_translate.ps1';
    local chk = io.open(ps1, 'r');
    if chk == nil then msg('helper missing: ' .. ps1); return false; end
    chk:close();
    os.remove(work_dir() .. 'stop');
    local dir = work_dir():gsub('\\$', '');   -- no trailing \ (it would swallow the closing quote)
    local cmd = ('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%s" -Serve "%s"'):format(ps1, dir);
    if EMAIL ~= nil then cmd = cmd .. (' -Email "%s"'):format(EMAIL); end
    local started, why = run_hidden(cmd);
    if not started then msg('could not start the translate helper (PowerShell): ' .. tostring(why)); return false; end
    worker_at = os.time();
    return true;
end

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
    if not ensure_worker() then fail(); return false; end
    local id = session .. '_' .. next_id;
    next_id = next_id + 1;
    -- The helper picks up "<id>.<mode>.in" and writes "<id>.out".
    local f = io.open(work_dir() .. id .. '.' .. mode .. '.in.tmp', 'wb');
    if f == nil then msg('could not write to ' .. work_dir()); fail(); return false; end
    f:write(u);
    f:close();
    os.rename(work_dir() .. id .. '.' .. mode .. '.in.tmp', work_dir() .. id .. '.' .. mode .. '.in');
    last_job = os.time();
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
            res = res:gsub('^\239\187\191', ''):gsub('%s+$', '');
            if res:sub(1, 1) == '!' then
                msg('translation failed: ' .. res:sub(2, 120));
                pcall(p.fail);
            elseif res ~= '' then
                cache[p.key] = res;
                local src = p.key:match('^[%w_]+:(.*)$') or '';
                if src:lower():gsub('[%s%p]', '') ~= res:lower():gsub('[%s%p]', '') then remember(p.key, res); end
                pcall(p.done, res);
            end
        elseif os.clock() - p.t > 12 then   -- a held-back chat line should not wait long
            pending[id] = nil;
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
-- The day log: every line translated and every reply you send, one file a day in
-- config\addons\omni\translate\log_YYYY-MM-DD.txt. Send the files to Claude to check a batch at once.
local function file_log(kind, where, original, result, extra)
    if st.keep_log == false then return; end
    pcall(function ()
        ensure_dir();
        local f = io.open(work_dir() .. 'log_' .. os.date('%Y-%m-%d') .. '.txt', 'a');
        if f == nil then return; end
        local function tidy(x) return ((x or ''):gsub('[\30\31].', ''):gsub('\127.', ''):gsub('[\r\n\t]', ' ')); end
        f:write(os.date('%H:%M:%S'), '  ', kind, '  ', tidy(where), '  ', tidy(original), '   >>   ', tidy(result));
        if extra and extra ~= '' then f:write('   [', tidy(extra), ']'); end
        f:write('\n');
        f:close();
    end);
end

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
        local orig = sjis_to_utf8(line) or line;
        file_log('IN ', '', orig, en, (mode ~= 'ja') and ('sent as: ' .. text) or 'ja');
    end, function ()
        put(line);
        file_log('IN ', '', sjis_to_utf8(line) or line, '(no translation)', mode);
    end);
end

-- Names inside a line keep their place: "qiutian zu wujing" = "Qiutian, invite Wujing".
-- A name is one from the names list, a capitalised word that is not pinyin, the joined-up first word
-- (see split_names), or a joined-up word straight after invite/kick/wait for/give ("zu wujing").
local AFTER_NAME = { zu = true, la = true, ti = true, jia = true, deng = true, gei = true, zhao = true };
quick_inline = function (text)
    local words = {};
    for w in text:gmatch('%S+') do words[#words + 1] = w; end
    if #words < 2 then return nil; end
    local lead, core1 = split_names(words[1] .. ' ' .. table.concat(words, ' ', 2));
    local function letters(w) return (w:gsub('[^%a]', '')); end
    -- Leading names: as split_names found them, but only those at the start of the line.
    local i, lead_out = 1, {};
    while i <= #words and #lead_out < #lead and letters(words[i]) ~= '' do
        local l = letters(words[i]);
        local hit = false;
        for _, n in ipairs(lead) do if n:lower() == l:lower() then hit = true; lead_out[#lead_out + 1] = n; break; end end
        if not hit then break; end
        i = i + 1;
    end
    local out, run, inline = {}, {}, 0;
    local function flush()
        if #run == 0 then return true; end
        local t = game_phrase(table.concat(run, ' '));
        if t == nil then return false; end
        out[#out + 1] = t; run = {};
        return true;
    end
    local prev = nil;
    for j = i, #words do
        local w = words[j];
        local l = letters(w):lower();
        local known = KNOWN_NAMES[l];
        local is_name = known ~= nil
            or (l ~= '' and w:match('^%u') and not is_pinyin_word(l))
            or (prev ~= nil and AFTER_NAME[prev] and not SYL[l] and not JOINED_WORDS[l] and syllables(l) >= 2);
        if is_name and l ~= '' then
            if not flush() then return nil; end
            out[#out + 1] = known or (l:sub(1, 1):upper() .. l:sub(2));
            inline = inline + 1;
        else
            run[#run + 1] = w;
        end
        prev = l;
    end
    if inline == 0 or not flush() or #out == 0 then return nil; end
    local res = table.concat(out, ' ');
    if #lead_out > 0 then res = table.concat(lead_out, ' ') .. ', ' .. res;
    else res = res:sub(1, 1):upper() .. res:sub(2); end
    return res;
end

ashita.events.register('text_in', 'omni_translate_text', function (e)
    if e.injected or not st.master then return; end
    pcall(function ()
        local s = clean(e.message or '');
        -- Japanese (any line).
        local at = first_japanese(s);
        if at ~= nil then
            if not st.langs.ja then return; end
            if japanese_count(s) < 2 then return; end   -- a face / symbols, not Japanese words
            -- Keep the English part in front ("Name : ", "(Name) ") as it is; translate the rest.
            local prefix = s:sub(1, at - 1);
            if #prefix > 40 then prefix = ''; at = 1; end
            one_line(e, prefix, 'ja', sjis_to_utf8(s:sub(at)));
            return;
        end
        -- Player chat in English letters: pinyin, or Spanish / Portuguese / French / German.
        local pre, rest = split_speaker(s);
        if pre == '' then return; end
        -- Your own lines are not translated back to you.
        local me = '';
        pcall(function () me = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or ''; end);
        if me ~= '' and pre:find(me, 1, true) then return; end
        -- Remember who is talking ("[1]<Huli>", "(Huli)", "Huli : ") for the names list.
        local who = pre:gsub('%[%d%]', ''):match('(%a[%w_]+)');
        if who then add_name(who, true); end
        -- Your own translated line coming back (the game wraps names in codes, so the name check can miss it).
        local mine_key = rest:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' '):lower();
        local sent_at = recent_out[mine_key];
        if sent_at ~= nil and os.clock() - sent_at < 120 then return; end
        local rest_x = expand_short(rest);   -- "da sm de" -> "da shen me de"
        local names, core = split_names(rest_x);   -- "Quixy zu wo" -> Quixy + "zu wo"
        if st.langs.zh and core ~= '' and (looks_pinyin(core) or game_phrase(core) ~= nil) then
            -- Common game phrases are answered from the phrase lists (instant, no allowance used).
            local quick = quick_inline(rest_x);   -- "qiutian zu wujing" -> "Qiutian, invite Wujing"
            if quick == nil then
                quick = game_phrase(core);
                if quick ~= nil and #names > 0 then quick = table.concat(names, ' ') .. ', ' .. quick; end
            end
            if quick ~= nil then
                cache['py:' .. core .. '|' .. table.concat(names, ' ')] = quick;
                one_line(e, pre, 'py', core .. '|' .. table.concat(names, ' '));
            else
                -- English words and numbers inside a Chinese line ("2 ge pop cai liao") are marked
                -- |like this| so the helper keeps them as they are instead of reading them as pinyin.
                local parts = {};
                for _, n in ipairs(names) do parts[#parts + 1] = '|' .. n .. '|'; end
                local prev = '';
                local cw = {};
                for w in core:gmatch('%S+') do cw[#cw + 1] = w; end
                local k = 1;
                while k <= #cw do
                    -- Game names from the glossary go over as English.
                    local hit = nil;
                    for n = math.min(4, #cw - k + 1), 1, -1 do
                        local ph = words_only(table.concat(cw, ' ', k, k + n - 1));
                        if GLOSSARY[ph] then hit = n; parts[#parts + 1] = '|' .. GLOSSARY[ph] .. '|'; break; end
                    end
                    if hit then k = k + hit; prev = ''; else
                    local w = cw[k]:gsub('\239[\39\40]', ''); k = k + 1;   -- auto-translate brackets
                    local letters = w:lower():gsub('[^%a]', '');
                    -- A game word that is Chinese after certain words: "ji lv" / "gai lv" = chance (not "level").
                    local zh_here = GAME_EN[letters] and ZH_AFTER[letters] and ZH_AFTER[letters][prev];
                    prev = letters;
                    if letters ~= '' and is_pinyin_word(letters) and (zh_here or not GAME_EN[letters]) then parts[#parts + 1] = w;
                    elseif letters == '' and not w:match('%d') then parts[#parts + 1] = w;
                    else parts[#parts + 1] = '|' .. w .. '|'; end
                    end
                end
                -- Mostly English words (an item list with one pinyin-looking word): leave it alone.
                local lit, all = 0, 0;
                for _, p in ipairs(parts) do all = all + 1; if p:sub(1, 1) == '|' then lit = lit + 1; end end
                if all > 0 and lit * 2 > all then return; end
                one_line(e, pre, 'py', table.concat(parts, ' '));
            end
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
-- French / German / Spanish / Portuguese letters the game cannot show, as plain letters.
local FOLD = {
    ['à']='a',['á']='a',['â']='a',['ã']='a',['ä']='a',['å']='a',['À']='A',['Á']='A',['Â']='A',['Ã']='A',['Ä']='A',
    ['ç']='c',['Ç']='C',['è']='e',['é']='e',['ê']='e',['ë']='e',['È']='E',['É']='E',['Ê']='E',['Ë']='E',
    ['ì']='i',['í']='i',['î']='i',['ï']='i',['Í']='I',['Î']='I',['ñ']='n',['Ñ']='N',
    ['ò']='o',['ó']='o',['ô']='o',['õ']='o',['ö']='o',['Ó']='O',['Ô']='O',['Õ']='O',['Ö']='O',
    ['ù']='u',['ú']='u',['û']='u',['ü']='u',['Ú']='U',['Û']='U',['Ü']='U',['ý']='y',['ÿ']='y',
    ['ß']='ss',['œ']='oe',['æ']='ae',['«']='"',['»']='"',['‘']="'",['’']="'",['“']='"',['”']='"',['¿']='',['¡']='',
};
local function fold_ascii(u)
    local out = {};
    for ch in u:gmatch('[%z\1-\127\194-\244][\128-\191]*') do
        if #ch == 1 then out[#out + 1] = ch; else out[#out + 1] = FOLD[ch] or ''; end
    end
    return table.concat(out);
end

local REPLY_LANGS = { { 'zh', 'Chinese (pinyin)' }, { 'ja', 'Japanese' }, { 'fr', 'French' }, { 'de', 'German' }, { 'es', 'Spanish' }, { 'pt', 'Portuguese' } };

-- Send `text` on channel `keep` ("/l", "/t Hush"), translated into the chosen reply language.
-- Game words stay in English in your replies, the way Chinese and Japanese players type them
-- ("pop", "NM", "AV" ...). Each one is swapped for a number the translator leaves alone, then put back.
local KEEP_EN = {
    pop = 'pop', pops = 'pop', nm = 'NM', nms = 'NM', hnm = 'HNM', hnms = 'HNM', av = 'AV', ws = 'WS',
    tp = 'TP', mp = 'MP', hp = 'HP', ki = 'KI', kis = 'KI', gil = 'gil', ls = 'LS', exp = 'exp', xp = 'exp',
    ja = 'JA', sp = 'SP', lv = 'lv', lvl = 'lv', pt = 'PT', ah = 'AH', lol = 'lol', xd = 'XD', dkp = 'DKP',
    ap = 'AP', cp = 'CP', jp = 'JP', whm = 'WHM', rdm = 'RDM', brd = 'BRD', blm = 'BLM', sch = 'SCH', cor = 'COR',
    geo = 'GEO', pld = 'PLD', sam = 'SAM', nin = 'NIN', drk = 'DRK', drg = 'DRG', smn = 'SMN', thf = 'THF',
    mnk = 'MNK', rng = 'RNG', bst = 'BST', blu = 'BLU', pup = 'PUP', dnc = 'DNC',
};
-- Chat shorthand spelled out so the translator understands it ("ill stay" = "I'll stay", not "sick").
local SHORTHAND = {
    ill = "I'll", im = "I'm", ive = "I've", dont = "don't", cant = "can't", wont = "won't",
    didnt = "didn't", doesnt = "doesn't", isnt = "isn't", wasnt = "wasn't", arent = "aren't", thats = "that's",
    whats = "what's", u = 'you', ur = 'your', r = 'are', pls = 'please', plz = 'please', thx = 'thanks',
    ty = 'thank you', np = 'no problem', cap = 'max out', capped = 'maxed out', caps = 'maxes out', ppl = 'people', ssent = 'sent', iss = 'is', gonna = 'going to', wanna = 'want to',
};
local function tidy_english(text)
    return (text:gsub("%f[%w]([%a']+)%f[^%w']", function (w)
        local x = SHORTHAND[w:lower()];
        if x == nil then return w; end
        if w:sub(1, 1):match('%u') then x = x:sub(1, 1):upper() .. x:sub(2); end
        return x;
    end));
end

-- "happy" for Happyfists, "assume" for Assumemygender: 5+ letters that start a known player's name.
local function short_name(w)
    local l = w:lower();
    if #l < 5 then return nil; end
    for k in pairs(KNOWN_NAMES) do
        if #k > #l and k:sub(1, #l) == l then return KNOWN_NAMES[k]; end   -- sent as the full name
    end
    return nil;
end

-- Player names (from the names list) stay as they are too.
local function protect_words(text)
    local map, n = {}, 0;
    local out = text:gsub('%f[%w](%w+)%f[%W]', function (w)
        local keepw = KEEP_EN[w:lower()] or KNOWN_NAMES[w:lower()] or short_name(w);
        if keepw == nil then return w; end
        n = n + 1;
        local tag = tostring(7300 + n);
        map[#map + 1] = { tag = tag, word = keepw };
        return tag;
    end);
    return out, map;
end
local function restore_words(text, map)
    if text == nil or #map == 0 then return text; end
    -- Full-width digits (Japanese) back to plain ones first.
    text = text:gsub('\239\188([\144-\153])', function (c) return string.char(c:byte() - 144 + 48); end);
    local missing = {};
    for _, m in ipairs(map) do
        local found = false;
        text = text:gsub(m.tag, function () found = true; return ' ' .. m.word .. ' '; end);
        if not found then missing[#missing + 1] = m.word; end
    end
    text = text:gsub('  +', ' '):gsub(' ([,%.%?!])', '%1'):gsub('^ ', ''):gsub(' $', '');
    if #missing > 0 then text = text .. ' (' .. table.concat(missing, ' ') .. ')'; end
    return text;
end

local function send_text(keep, text, force_english)
    local function send(out)
        passthrough[out] = true;
        recent_out[(out:gsub('^%S+%s+', ''):gsub('%s+', ' '):lower())] = os.clock();   -- so our own line isn't translated back
        AshitaCore:GetChatManager():QueueCommand(1, out);
    end
    if text:sub(1, 1) == '=' or force_english then
        send(keep .. ' ' .. (text:sub(1, 1) == '=' and text:sub(2) or text));
        return;
    end
    -- An emote or game command (/yawn, /wave, /check) goes as typed.
    if text:match('^%s*/') then send(keep .. ' ' .. text); return; end
    local en = sjis_to_utf8(text) or text;
    en = tidy_english(en);
    local function send_as_typed()
        msg('sent in English instead.');
        file_log('OUT', keep, text, '(sent in English - translator failed)', lang);
        add_log({ who = 'you ' .. keep, text = text, mine = true });
        send(keep .. ' ' .. text);
    end
    local lang = st.reply_lang or 'zh';
    tr.status = 'translating: ' .. text;
    if st.chat_out then msg('translating your message...'); end
    local function done_with(out_text, shown)
        if out_text == nil or out_text:match('^%s*$') then send_as_typed(); return; end
        -- Nothing was translated (the same words came back): say so instead of pretending.
        local same = function (a, b) return a:lower():gsub('[%s%p]', '') == b:lower():gsub('[%s%p]', ''); end
        if same(out_text, en) then
            msg("couldn't translate that - sent in English.");
            file_log('OUT', keep, text, '(sent in English - not translated)', lang);
            add_log({ who = 'you ' .. keep, text = text, mine = true });
            send(keep .. ' ' .. text);
            return;
        end
        if #out_text > 110 then out_text = out_text:sub(1, 110); end
        tr.status = ('sent: %s'):format(shown or out_text);
        if st.chat_out then msg_pink(('you: "%s" -> %s'):format(text, shown or out_text)); end
        add_log({ who = 'you ' .. keep, text = text, orig = shown or out_text, mine = true });
        file_log('OUT', keep, text, shown or out_text, lang);
        send(keep .. ' ' .. out_text);
    end
    local en_p, words = protect_words(en);
    if lang == 'zh' then
        job('zh', en_p, function (zh)
            if not zh:find('[\228-\233]') then done_with(en); return; end   -- no Chinese characters came back
            done_with(restore_words(to_pinyin(zh), words));
        end, send_as_typed);
    elseif lang == 'ja' then
        -- Japanese goes out in Japanese characters (the game shows kana and kanji).
        job('to_ja', en_p, function (ja)
            ja = restore_words(ja, words);
            done_with(utf8_to_sjis(ja) or fold_ascii(ja), fold_ascii(ja) ~= '' and fold_ascii(ja) or '(Japanese)');
        end, send_as_typed);
    else
        job('to_' .. lang, en_p, function (t) done_with(fold_ascii(restore_words(t, words))); end, send_as_typed);
    end
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
    -- A chat line the game is sending because you pressed Enter while typing in the Happy Translate box.
    if not e.injected and not passthrough[e.command] then
        local norm = function (x) return (x or ''):gsub('^/%a+%d?%s+', ''):gsub('^%s+', ''):gsub('%s+$', ''):lower(); end
        local line = norm(e.command);
        local now = os.clock();
        local typed_in_box = (now - box.active_t < 0.6)
            or (line ~= '' and (line == norm(box.text) or (now - box.sent_t < 15 and line == norm(box.sent_text))));
        if typed_in_box and not e.command:lower():match('^/z') and not e.command:lower():match('^/translate') then
            e.blocked = true;
            msg('that was typed in the Happy Translate box - not sent as it was. Press Send to translate it.');
            return;
        end
    end
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
        if not st.master then stop_worker(); end
        save();
        msg('chat translation ' .. (st.master and 'ON' or 'OFF') .. '.');
    elseif ({ chinese = 'zh', zh = 'zh', pinyin = 'zh', japanese = 'ja', ja = 'ja', french = 'fr', fr = 'fr',
              german = 'de', de = 'de', spanish = 'es', es = 'es', portuguese = 'pt', pt = 'pt' })[c] then
        local code = ({ chinese = 'zh', zh = 'zh', pinyin = 'zh', japanese = 'ja', ja = 'ja', french = 'fr', fr = 'fr',
              german = 'de', de = 'de', spanish = 'es', es = 'es', portuguese = 'pt', pt = 'pt' })[c];
        st.langs[code] = not st.langs[code]; save();
        msg(a[2] .. ' ' .. (st.langs[code] and 'ON' or 'OFF') .. '.');
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
    elseif c == 'email' then
        local addr = (a[3] or ''):gsub('%s+', '');
        if addr == 'off' or addr == 'none' then
            os.remove(work_dir() .. 'email.txt'); EMAIL = nil; DAILY = 5000;
            msg('email removed - free limit back to 5000 characters a day.');
        elseif addr:match('^[%w%._%+%-]+@[%w%.%-]+%.%a+$') then
            ensure_dir();
            local f = io.open(work_dir() .. 'email.txt', 'w');
            if f then f:write(addr, '\n'); f:close(); end
            EMAIL = addr; DAILY = 50000;
            msg('email set - free limit is now 50000 characters a day.');
        else
            msg('/translate email you@example.com   (or /translate email off)');
        end
    elseif c == 'learn' then
        local rest = e.command:match('^%S+%s+%S+%s+(.*)$') or '';
        local k, v = rest:match('^(.-)%s*=%s*(.-)%s*$');
        if k and v and learn(k, v) then msg(('learned: %s = %s'):format(words_only(k), v));
        else msg('/translate learn <pinyin> = <English>   e.g. /translate learn zu wo = invite me'); end
    elseif c == 'name' then
        local n = a[3] or '';
        if n == '' then msg('/translate name <Name>   (adds a player name so it is never translated)');
        elseif add_name(n, false) then msg('name added: ' .. n .. '  (' .. name_count .. ' names)');
        else msg(n .. ' is already in the names list.'); end
    elseif c == 'unname' then
        local n = a[3] or '';
        if remove_name(n) then msg('name taken out: ' .. n .. '  (' .. name_count .. ' names)');
        else msg('/translate unname <Name>   (' .. (n ~= '' and (n .. ' is not in the list') or 'takes a name out of the list') .. ')'); end
    elseif c == 'log' then
        if a[3] == 'off' then st.keep_log = false; msg('day log OFF.');
        elseif a[3] == 'on' then st.keep_log = true; msg('day log ON.');
        else msg(('day log %s - today: %slog_%s.txt   (/translate log on|off)'):format(st.keep_log == false and 'OFF' or 'ON', work_dir(), os.date('%Y-%m-%d'))); end
    elseif c == 'names' then
        local list = {};
        for _, n in pairs(KNOWN_NAMES) do list[#list + 1] = n; end
        table.sort(list, function (x, y) return x:lower() < y:lower(); end);
        msg(('%d names (translate\\names.txt): %s'):format(#list, table.concat(list, ', ', 1, math.min(#list, 60)) .. (#list > 60 and ' ...' or '')));
    elseif c == 'status' then
        msg(('Remembered translations: %d. Your phrases: %d (translate\\phrases.txt). Names: %d (translate\\names.txt).'):format(mem_count, my_phrases, name_count));
        msg(('Japanese %s, pinyin %s, reply in Chinese %s. Sent today: about %d of %d characters. Waiting for: %d.'):format(
            st.on and 'ON' or 'OFF', st.zh and 'ON' or 'OFF', st.reply and 'ON' or 'OFF',
            math.floor(st.chars / 3), DAILY, (function () local n = 0; for _ in pairs(pending) do n = n + 1; end return n; end)()));
    else
        msg('/translate window | /translate (Japanese on/off) | /translate chinese (pinyin on/off) | /translate reply (answer in pinyin) | /translate test <text> | /translate status | /translate names | /translate name <Name> | /translate unname <Name>');
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
        if not st.master then stop_worker(); end
        msg('chat translation ' .. (st.master and 'ON' or 'OFF') .. '.');
    end
    imgui.SameLine(0, 6);
    imgui.TextColored(st.master and GOLD or DIM, st.master and 'Translate' or 'Translate (off)');
    imgui.SameLine(0, 16);
    if imgui.SmallButton((st.win and 'Close pop-out' or 'Pop out') .. (in_tab and '##trt_pop' or '##trw_pop')) then st.win = not st.win; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('A window you can move and resize with the same lines and reply box.'); end

    -- Which languages: all off until ticked.
    local LANG_LABEL = { { 'zh', 'Chinese' }, { 'ja', 'Japanese' }, { 'fr', 'French' }, { 'de', 'German' }, { 'es', 'Spanish' }, { 'pt', 'Portuguese' } };
    imgui.TextColored(DIM, 'Read:');
    for i, l in ipairs(LANG_LABEL) do
        imgui.SameLine(0, i == 1 and 6 or 12);
        local v = { st.langs[l[1]] == true };
        if imgui.Checkbox(l[2] .. (in_tab and '##trt_l_' or '##trw_l_') .. l[1], v) then st.langs[l[1]] = v[1]; save(); end
        if imgui.IsItemHovered() then
            imgui.SetTooltip(l[1] == 'zh' and 'Chinese typed in English letters (pinyin), e.g. "zu wo", "kuai lai".'
                or (l[1] == 'ja' and 'Lines with Japanese characters.' or ('Lines written in ' .. l[2] .. '.')));
        end
    end
    imgui.SameLine(0, 12);
    if imgui.SmallButton(in_tab and 'All##trt_all' or 'All##trw_all') then
        local any_off = false;
        for _, l in ipairs(LANG_LABEL) do if not st.langs[l[1]] then any_off = true; end end
        for _, l in ipairs(LANG_LABEL) do st.langs[l[1]] = any_off; end
        save();
    end
    if imgui.IsItemHovered() then imgui.SetTooltip('Tick them all (or untick them all).'); end

    -- A new translated line: answer on its channel.
    if tr.last_chan then pick_chan(tr.last_chan, tr.last_tell); tr.last_chan, tr.last_tell = nil, nil; end

    -- The lines
    imgui.BeginChild(in_tab and '##trt_log' or '##trw_log', { 0, in_tab and 260 or -52 }, true);
    if #log == 0 then
        imgui.TextColored(DIM, st.master and 'Nothing translated yet. Tick the languages you want above; those lines from any chat show up here.' or 'Translation is OFF - press the switch to turn it on.');
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

    -- Reply box: reply language, channel, (name for a tell), message, Send.
    local ri = { 0 };
    for i, l in ipairs(REPLY_LANGS) do if l[1] == st.reply_lang then ri[1] = i - 1; end end
    imgui.PushItemWidth(128);
    if imgui.Combo(in_tab and '##trt_rlang' or '##trw_rlang', ri, 'Chinese (pinyin)\0Japanese\0French\0German\0Spanish\0Portuguese\0') then
        st.reply_lang = REPLY_LANGS[ri[1] + 1][1]; save();
    end
    imgui.PopItemWidth();
    if imgui.IsItemHovered() then imgui.SetTooltip('Reply in: what you type here (and with /zl /zp /zt ...) is translated into this.'); end
    imgui.SameLine(0, 4);
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
    local hint = 'type in English, then click Send - it goes out in the language on the left';
    imgui.InputTextWithHint('##trw_in', hint, in_buf, 200);
    if imgui.IsItemActive() then box.active_t = os.clock(); end
    if not in_buf[1]:match('^%s*$') then box.text = in_buf[1]; end
    local entered = false;   -- only the Send button sends (Leon's choice); Enter does nothing here
    imgui.PopItemWidth();
    imgui.SameLine(0, 4);
    local clicked = imgui.Button('Send##trw_send', { -1, 0 });
    if (entered or clicked) and not in_buf[1]:match('^%s*$') then
        local text = in_buf[1]:gsub('^%s+', '');
        in_buf[1] = '';
        box.sent_text, box.sent_t = text, os.clock();
        local ok, err = pcall(function ()
        if text:sub(1, 1) == '/' then
            -- A whole command (/l2 hi, /p hi): run it like the chat line would.
            passthrough[text] = true;
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
tr.set = function (on) st.master = (on == true); save(); if not st.master then stop_worker(); end end

-- omni unloaded or reloaded: close the helper too.
ashita.events.register('unload', 'omni_translate_unload', function () stop_worker(); end);
tr.first_japanese = first_japanese;
tr.japanese_count = japanese_count;
tr.looks_pinyin = looks_pinyin;
tr.game_phrase = game_phrase;
tr.split_names = split_names;
tr.add_name = add_name;
tr.file_log = file_log;
tr.protect_words = protect_words;
tr.restore_words = restore_words;
tr.quick_inline = function (t) return quick_inline(t); end
tr.to_pinyin = to_pinyin;
tr.split_speaker = split_speaker;
tr.zh_enabled = function () return st.zh; end
tr.set_zh = function (on) st.zh = (on == true); save(); end
tr.reply_enabled = function () return st.reply; end
tr.set_reply = function (on) st.reply = (on == true); save(); end
tr.win_shown = function () return st.win; end
tr.set_win = function (on) st.win = (on == true); save(); end

return tr;
