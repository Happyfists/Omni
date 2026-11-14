--[[
    omni_pops.lua - Happy Pops: HNM pop timer with window warnings.

    Type an HNM and its time of death (ToD). For every window it warns 2 min, 1 min, 30 sec and
    10 sec before, says when the window is OPEN, and says it closed 40 sec later (OPEN is called 4 sec early) - and counts the
    windows (1/7, 2/7 ... 7/7 = forced pop). A ToD is only ever set by you: type it, or press
    Killed. Seeing "<someone> defeats <HNM>" in chat (or it dying near you) just tells you the time.

    CatsEyeXI windows (bg-wiki, CatsEyeXI Content/HNMs):
      21h group: windows every 5 min from 21:00 after ToD, forced at 21:30 (7 windows)
      57h group: windows every 10 min from 57:00, forced at 58:00 (7 windows)
      81h group: windows every 10 min from 81:00, forced at 82:00 (7 windows)
      Wyrms (Jormungand, Tiamat, Vrtra): not on that page. 7 windows 10 min apart (Leon),
      first window at 81:00:16, forced at 82:00:16 (CatsEyeXI, checked in game 24 Oct).

    Commands
      /pops                        open omni's panel on the Happy Pops tab
      /pops add <hnm> [time]       start a timer; time = ToD as 21:35 or 21:35:10 (local clock),
                                   "now" or left out = now. A time later than now means yesterday.
                                   For older ToDs: "2d 21:35" = two days ago at 21:35.
      /pops kill <hnm>             it died now - new timer
      /pops del <hnm>              stop tracking it
      /pops list                   all timers in your chat (/pops list party = in party chat)
      /pops history <hnm>          the last 10 saved ToDs (config\addons\omni\tods\<HNM>.txt)

    Every ToD you set is saved to the tods folder.
]]

local imgui = require('imgui');

local pops = {};

----------------------------------------------------------------------------------------------------
-- The HNMs and their windows
----------------------------------------------------------------------------------------------------
-- CatsEyeXI: the 57h and 81h HNMs (Cerberus, Khimaira, Hydra, the ToAU kings and the wyrms) respawn
-- at the hours PLUS 16 seconds (57:00:16, 81:00:16). The 21h ones are on the hour.
local RESPAWN_EXTRA = 16;
local GROUPS = {
    h21 = { first = 21 * 3600,                 step = 5 * 60,  count = 7 },   -- no extra seconds
    h57 = { first = 57 * 3600 + RESPAWN_EXTRA, step = 10 * 60, count = 7 },   -- Cerberus, Khimaira, Hydra: 57:00:16
    h81 = { first = 81 * 3600 + RESPAWN_EXTRA, step = 10 * 60, count = 7 },   -- ToAU beastmen kings: 81:00:16
    -- Wyrms (Jormungand, Tiamat, Vrtra): 81:00:16 like the ToAU kings, 7 windows 10 min apart.
    wyrm = { first = 81 * 3600 + RESPAWN_EXTRA, step = 10 * 60, count = 7, label = '81h' },
};
local HNMS = {
    { 'Fafnir', 'h21' }, { 'Behemoth', 'h21' }, { 'Adamantoise', 'h21' }, { 'Argus', 'h21' },
    { 'King Arthro', 'h21' }, { 'Shikigami Weapon', 'h21' }, { 'Serket', 'h21' }, { 'Simurgh', 'h21' },
    { 'Roc', 'h21' }, { 'Lord of Onzozo', 'h21' },
    { 'Khimaira', 'h57' }, { 'Cerberus', 'h57' }, { 'Hydra', 'h57' },
    { 'Medusa', 'h81' }, { 'Gurfurlur the Menacing', 'h81' }, { 'Gulool Ja Ja', 'h81' },
    { 'Jormungand', 'wyrm' }, { 'Tiamat', 'wyrm' }, { 'Vrtra', 'wyrm' },
};
local GROUP_OF = {};
for _, h in ipairs(HNMS) do GROUP_OF[h[1]] = h[2]; end

-- The zone each HNM lives in. A kill is only taken as that HNM's ToD in its own zone, so a
-- same-named monster elsewhere (Nyzul Isle's floor bosses, Einherjar, Dynamis...) doesn't count.
local HNM_ZONE = {
    ['Fafnir'] = 154,            -- Dragon's Aery
    ['Behemoth'] = 127,          -- Behemoth's Dominion
    ['Adamantoise'] = 128,       -- Valley of Sorrows
    ['Argus'] = 198,             -- Maze of Shakhrami
    ['King Arthro'] = 104,       -- Jugner Forest
    ['Shikigami Weapon'] = 122,  -- Ro'Maeve
    ['Serket'] = 200,            -- Garlaige Citadel
    ['Simurgh'] = 110,           -- Rolanberry Fields
    ['Roc'] = 120,               -- Sauromugue Champaign
    ['Lord of Onzozo'] = 213,    -- Labyrinth of Onzozo
    ['Khimaira'] = 79,           -- Caedarva Mire
    ['Cerberus'] = 61,           -- Mount Zhayolm
    ['Hydra'] = 51,              -- Wajaom Woodlands
    ['Medusa'] = 54,             -- Arrapago Reef
    ['Gurfurlur the Menacing'] = 62, -- Halvung
    ['Gulool Ja Ja'] = 65,       -- Mamook
    ['Jormungand'] = 5,          -- Uleguerand Range
    ['Tiamat'] = 7,              -- Attohwa Chasm
    ['Vrtra'] = 190,             -- King Ranperre's Tomb
};
local function in_hnm_zone(name)
    local want = HNM_ZONE[name];
    if want == nil then return true; end
    local z = -1;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0); end);
    return z == want;
end

local function find_hnm(text)
    text = (text or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    if text == '' then return nil; end
    for _, h in ipairs(HNMS) do if h[1]:lower() == text then return h[1]; end end
    for _, h in ipairs(HNMS) do if h[1]:lower():sub(1, #text) == text then return h[1]; end end
    for _, h in ipairs(HNMS) do if h[1]:lower():find(text, 1, true) then return h[1]; end end
    return nil;
end

----------------------------------------------------------------------------------------------------
-- Saved state (shared by all characters): config\addons\omni\pops.txt
----------------------------------------------------------------------------------------------------
local st = { timers = {}, removed = {}, party = false, ls = true, warn = true, show = false, on = true,
             cols = { 262, 84, 150, 300, 190 } };   -- on: countdowns + warnings (off = ToDs are still saved); cols: column widths   -- removed[name] = ToD you pressed X on   -- timers[name] = { tod = os.time(), fired = {} }

local function path() return ('%s\\config\\addons\\omni\\pops.txt'):format(AshitaCore:GetInstallPath()); end

-- All your characters share pops.txt and each runs its own Happy Pops, so they keep in step through the
-- file: every save remembers what it wrote, and once a second each one re-reads the file - if another
-- character changed it (a ToD, X, lock, popped, tick boxes) it takes those changes in straight away.
local last_text = nil;
local function render()
    local o = {};
    local names = {};
    for name in pairs(st.timers) do names[#names + 1] = name; end
    table.sort(names);
    for _, name in ipairs(names) do o[#o + 1] = 'tod ' .. st.timers[name].tod .. ' ' .. name; end
    for _, name in ipairs(names) do if st.timers[name].locked then o[#o + 1] = 'lock ' .. name; end end
    for _, name in ipairs(names) do if st.timers[name].popped then o[#o + 1] = 'popped ' .. st.timers[name].popped .. ' ' .. name; end end
    for _, name in ipairs(names) do if st.timers[name].by then o[#o + 1] = 'by ' .. st.timers[name].by:gsub('%s', '_') .. ' ' .. name; end end
    local rn = {};
    for name in pairs(st.removed) do rn[#rn + 1] = name; end
    table.sort(rn);
    for _, name in ipairs(rn) do o[#o + 1] = 'removed ' .. st.removed[name] .. ' ' .. name; end
    return table.concat(o, '\n') .. '\n';
end
local function save()
    pcall(function ()
        local text = render();
        local f = io.open(path(), 'w');
        if f == nil then return; end
        f:write(text);
        f:close();
        last_text = text;
    end);
end
local function read_file()
    local f = io.open(path(), 'r');
    if f == nil then return nil; end
    local text = f:read('*a');
    f:close();
    return text;
end
-- Take in the file's contents. A timer whose ToD hasn't changed keeps the warnings it has already given.
local function read_settings(line)
    local v = line:match('^party (%d)$'); if v then st.party = (v == '1'); end
    local l = line:match('^ls (%d)$'); if l then st.ls = (l == '1'); end
    local w = line:match('^warn (%d)$'); if w then st.warn = (w == '1'); end
    local on = line:match('^on (%d)$'); if on then st.on = (on == '1'); end
    local cl = line:match('^cols ([%d ]+)$');
    if cl then
        local c = {};
        for n in cl:gmatch('%d+') do c[#c + 1] = math.max(30, tonumber(n)); end
        if #c == 5 then st.cols = c; end
    end
end
-- first: also take the switches from it (pops.txt held them before each character had its own)
local function apply(text, first)
    local timers, removed = {}, {};
    for raw in (text .. '\n'):gmatch('([^\n]*)\n') do
        local line = raw:gsub('[\r\n]+$', ''):gsub('%s+$', '');   -- Windows line ends
        if first then read_settings(line); end
        local rt, rn = line:match('^removed (%d+) (.+)$');
        if rt then removed[rn] = tonumber(rt); end
        local tod, name = line:match('^tod (%d+) (.+)$');
        if tod and GROUP_OF[name] then
            tod = tonumber(tod);
            local old = st.timers[name];
            if old and old.tod == tod then
                timers[name] = { tod = tod, fired = old.fired, loaded_skip = old.loaded_skip };
            else
                timers[name] = { tod = tod, fired = {}, loaded = true };
            end
        end
        local pt, pn = line:match('^popped (%d+) (.+)$');
        if pt and timers[pn] then timers[pn].popped = tonumber(pt); end
        local lk = line:match('^lock (.+)$');
        if lk and timers[lk] then timers[lk].locked = true; end
        local who, bn = line:match('^by (%S+) (.+)$');
        if who and timers[bn] then timers[bn].by = who:gsub('_', ' '); end
    end
    st.timers, st.removed = timers, removed;
end
local function load()
    pcall(function ()
        local text = read_file();
        if text == nil then return; end
        apply(text, true);
        last_text = text;
    end);
end

-- Each character's own switches (On/Off, warnings, party, linkshell, column widths):
-- config\addons\omni\pops_<character>.txt. Turning one character off leaves the others on.
local me, mine_loaded = nil, false;
local function my_name()
    local n = '';
    pcall(function () n = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0) or ''; end);
    return n;
end
local function mine_path() return ('%s\\config\\addons\\omni\\pops_%s.txt'):format(AshitaCore:GetInstallPath(), me); end
local function save_mine()
    if me == nil then return; end
    pcall(function ()
        local f = io.open(mine_path(), 'w');
        if f == nil then return; end
        f:write('on ', st.on and 1 or 0, '\n', 'warn ', st.warn and 1 or 0, '\n', 'party ', st.party and 1 or 0, '\n',
            'ls ', st.ls and 1 or 0, '\n', 'cols ', table.concat(st.cols, ' '), '\n');
        f:close();
    end);
end
-- Once you're logged in: read your own switches (or start them from the shared ones).
local function load_mine()
    if mine_loaded then return; end
    local n = my_name();
    if n == '' then return; end
    me, mine_loaded = n, true;
    local f = io.open(mine_path(), 'r');
    if f == nil then save_mine(); return; end
    for raw in f:lines() do read_settings((raw:gsub('[\r\n]+$', ''):gsub('%s+$', ''))); end
    f:close();
end
-- Picked up a change another character made?
local function sync()
    local ok, text = pcall(read_file);
    if not ok or text == nil or text == last_text or text == '' then return; end
    last_text = text;
    pcall(apply, text);
end
load();

----------------------------------------------------------------------------------------------------
-- Time helpers
----------------------------------------------------------------------------------------------------
local function clock(t) return os.date('%H:%M:%S', t); end
local function span(sec)
    sec = math.max(0, math.floor(sec + 0.5));
    local h, m, s = math.floor(sec / 3600), math.floor(sec / 60) % 60, sec % 60;
    if h > 0 then return ('%d:%02d:%02d'):format(h, m, s); end
    return ('%d:%02d'):format(m, s);
end

-- "21:35", "21:35:10", "now", "", "2d 21:35" -> a time, or nil
local function parse_tod(text)
    text = (text or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    local now = os.time();
    if text == '' or text == 'now' then return now; end
    local days, rest = text:match('^(%d+)d%s*(.*)$');
    if days then text = rest; end
    local h, m, s = text:match('^(%d%d?):(%d%d):?(%d?%d?)$');
    if h == nil then return nil; end
    h, m, s = tonumber(h), tonumber(m), tonumber(s) or 0;
    if h > 23 or m > 59 or s > 59 then return nil; end
    local d = os.date('*t', now);
    d.hour, d.min, d.sec = h, m, s;
    local t = os.time(d);
    if t > now + 60 then t = t - 86400; end           -- later than now: it was yesterday
    if days then t = t - tonumber(days) * 86400; end
    return t;
end

-- Where a timer is: returns a table describing the current/next window.
local status_raw;
-- A window is called OPEN 4 seconds before it opens and closed 40 s after it opens (44 s in all: 10 s after it closes).
local OPEN_EARLY, CLOSE_AT = 4, 40;
local function status(name, t, now)
    local s = status_raw(name, t, now);
    if s.phase == 'wait' and s.left <= OPEN_EARLY then
        return { phase = 'open', win = s.win, count = s.count, opened = s.next_open, left = s.left + CLOSE_AT };
    end
    return s;
end
status_raw = function (name, t, now)
    local g = GROUPS[GROUP_OF[name]];
    local first = t.tod + g.first;
    if t.popped then
        -- It has popped: which window it came in.
        local k = math.max(1, math.min(g.count, math.floor((t.popped - first) / g.step) + 1));
        return { phase = 'popped', at = t.popped, win = k, count = g.count };
    end
    local last = first + (g.count - 1) * g.step;
    if now < first then
        return { phase = 'wait', win = 1, count = g.count, next_open = first, left = first - now };
    end
    local k = math.min(g.count, math.floor((now - first) / g.step) + 1);
    local open_t = first + (k - 1) * g.step;
    if now < open_t + CLOSE_AT then
        return { phase = 'open', win = k, count = g.count, opened = open_t, left = open_t + CLOSE_AT - now };
    end
    if k < g.count then
        return { phase = 'wait', win = k + 1, count = g.count, next_open = open_t + g.step, left = open_t + g.step - now };
    end
    return { phase = 'done', win = g.count, count = g.count, since = now - last };
end

----------------------------------------------------------------------------------------------------
-- Alerts
----------------------------------------------------------------------------------------------------
local function msg(text) print('\30\68[Happy Pops]\30\01 ' .. text); end
local function sound(open)
    pcall(function ()
        local f = open and 'C:\\Windows\\Media\\Windows Notify Messaging.wav' or 'C:\\Windows\\Media\\Windows Notify System Generic.wav';
        ashita.misc.play_sound(f);
    end);
end
-- Only one of your characters posts each warning: the first to claim it (a lock file, made with an
-- atomic rename that fails if it exists) sends it; the others just show it in their own chat.
local function posted_dir() return ('%s\\config\\addons\\omni\\pops_posted\\'):format(AshitaCore:GetInstallPath()); end
local function claim(key)
    local ok, r = pcall(function ()
        local dir = posted_dir();
        local tmp = dir .. key .. '.' .. tostring(math.random(1, 1e9)) .. '.tmp';
        local f = io.open(tmp, 'w');
        if f == nil then
            pcall(function () ashita.fs.create_dir(dir:sub(1, -2)); end);
            f = io.open(tmp, 'w');
            if f == nil then return true; end
        end
        f:write(os.time()); f:close();
        local won = os.rename(tmp, dir .. key .. '.lock');
        if not won then os.remove(tmp); end
        return won and true or false;
    end);
    return (not ok) or r;
end
local function forget_posts(name, tod)
    pcall(function ()
        local base = posted_dir() .. name:gsub('%W', '_') .. '_' .. tostring(tod);
        for k = 1, 7 do
            for _, ev in ipairs({ 'w-120', 'w-60', 'w-30', 'w-10', 'ls1h', 'open', 'close' }) do
                os.remove(base .. '_' .. k .. '_' .. ev .. '.lock');
            end
        end
    end);
end
-- [3.89] Which party this character is in: the lowest server id among its party's members (slots 0-5),
-- or nil when it is on its own. Two of your characters in the same party get the same answer, so only
-- one of them posts each warning; characters in different parties each post to their own party; and a
-- character that isn't in a party never claims the post (it used to, and then nobody posted it).
local function party_group()
    local best, n = nil, 0;
    pcall(function ()
        local p = AshitaCore:GetMemoryManager():GetParty();
        for i = 0, 5 do
            if p:GetMemberIsActive(i) == 1 then
                local id = p:GetMemberServerId(i) or 0;
                if id ~= 0 then
                    n = n + 1;
                    if best == nil or id < best then best = id; end
                end
            end
        end
    end);
    if n < 2 then return nil; end
    return best;
end
local function party(text, call, key)
    if not st.party then return; end
    local grp = party_group();
    if grp == nil then return; end                      -- not in a party: leave it to one that is
    if key and not claim(key .. '_p' .. grp) then return; end
    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. text .. (call and ' <call14>' or '')); end);
end

-- The alerts for window k of a timer: { offset from the window opening, text, is_open }
local WARN = {
    { -120, 'in 2 minutes' }, { -60, 'in 1 minute' }, { -30, 'in 30 seconds' }, { -10, 'in 10 seconds' },
};

local function check(name, t, now)
    if t.popped then return; end   -- it's up: no more window countdown or warnings
    local g = GROUPS[GROUP_OF[name]];
    local first = t.tod + g.first;
    for k = 1, g.count do
        local open_t = first + (k - 1) * g.step;
        local tag = ('%d/%d'):format(k, g.count);
        local forced = (k == g.count) and g.forced ~= false;
        local events = {};
        for _, w in ipairs(WARN) do
            events[#events + 1] = { open_t + w[1], ('%s window %s %s'):format(name, tag, w[2]) .. (forced and ' (forced pop)' or ''), false, 'w' .. w[1] };
        end
        if k == 1 then
            -- One hour before the first window: told to the linkshell (tick box "1h warning to linkshell").
            events[#events + 1] = { open_t - 3600, ('%s window 1/%d in 1 hour (%s)'):format(name, g.count, os.date('%H:%M:%S', open_t)), false, 'ls1h', true };
        end
        events[#events + 1] = { open_t - OPEN_EARLY, ('%s window %s OPEN!'):format(name, tag) .. (forced and ' Forced pop - it should be up now!' or ''), true, 'open' };
        if k < g.count then
            events[#events + 1] = { open_t + CLOSE_AT, ('%s window %s closed - next window (%d/%d) in %s'):format(
                name, tag, k + 1, g.count, span(g.step - CLOSE_AT)), false, 'close' };
        elseif not forced then
            events[#events + 1] = { open_t + CLOSE_AT, ('%s last window (%s) closed - no pop. Check the camp.'):format(name, tag), false, 'close' };
        end
        for _, e in ipairs(events) do
            local key = k .. ':' .. e[4];
            local post_key = name:gsub('%W', '_') .. '_' .. t.tod .. '_' .. k .. '_' .. e[4];
            if not t.fired[key] and now >= e[1] then
                t.fired[key] = true;
                -- Only announce it if it is fresh (not when loading an old timer or catching up).
                if e[5] then
                    -- The 1-hour linkshell warning (fresh only: within 5 minutes of the hour mark).
                    if st.ls and now - e[1] <= 300 and not t.loaded_skip then
                        msg(e[2]);
                        if claim(post_key) then pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/l ' .. e[2]); end); end
                    end
                elseif st.warn and now - e[1] <= 5 and not t.loaded_skip then
                    msg(e[2]);
                    sound(e[3]);
                    party(e[2], e[3], post_key);
                end
            end
        end
    end
    t.loaded_skip = nil;
end

----------------------------------------------------------------------------------------------------
-- Starting / stopping timers
----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
-- ToD history: config\addons\omni\tods\<HNM>.txt, one line per kill.
----------------------------------------------------------------------------------------------------
local function tod_dir() return ('%s\\config\\addons\\omni\\tods\\'):format(AshitaCore:GetInstallPath()); end
local function tod_file(name) return tod_dir() .. name:gsub('[^%w ]', ''):gsub(' ', '_') .. '.txt'; end
local history = {};    -- history[name] = { {tod, how}, ... } newest last
local function read_history(name)
    if history[name] then return history[name]; end
    local h = {};
    pcall(function ()
        local f = io.open(tod_file(name), 'r');
        if f == nil then return; end
        for raw in f:lines() do
            local line = raw:gsub('%s+$', '');
            local t, how = line:match('^(%d+)%s+%S+%s+%S+%s+(%S+)');
            local by = line:match('%sby%s+(%S+)$');
            if t then h[#h + 1] = { tonumber(t), how, by }; end
        end
        f:close();
    end);
    history[name] = h;
    return h;
end

-- After a reload: any HNM whose last saved ToD (tods folder) is still in or before its windows
-- gets its timer back, even if pops.txt lost it. Ones you removed with X stay removed.
local function restore_from_tods()
    local n = 0;
    for _, hh in ipairs(HNMS) do
        local name = hh[1];
        if st.timers[name] == nil then
            local h = read_history(name);
            local last = h[#h];
            if last ~= nil and st.removed[name] ~= last[1] then
                local g = GROUPS[hh[2]];
                local ends = last[1] + g.first + (g.count - 1) * g.step + 3600;   -- keep it up to 1h after the last window
                if os.time() < ends then
                    st.timers[name] = { tod = last[1], fired = {}, loaded = true, by = last[3] };
                    n = n + 1;
                end
            end
        end
    end
    return n;
end
local function log_tod(name, tod, how, by)
    pcall(function ()
        local d = tod_dir();
        if not (ashita.fs and ashita.fs.exists and ashita.fs.exists(d)) then
            pcall(function () ashita.fs.create_directory(d); end);
            pcall(function () ashita.fs.create_dir(d); end);
        end
        local f = io.open(tod_file(name), 'a');
        if f == nil then return; end
        f:write(('%d  %s  %s%s\n'):format(tod, os.date('%Y-%m-%d %H:%M:%S', tod), how, by and ('  by ' .. by) or ''));
        f:close();
    end);
    history[name] = nil;    -- re-read from the file next time
end

pcall(function ()
    local n = restore_from_tods();
    if n > 0 then save(); print(('\30\68[Happy Pops]\30\01 %d timer%s brought back from the tods folder.'):format(n, n == 1 and '' or 's')); end
end);

-- by: who killed it (from "<Name> defeats the <HNM>", the claim when seen dying nearby, or typed).
local function start(name, tod, how, by)
    if st.timers[name] then forget_posts(name, st.timers[name].tod); end
    if by == '' then by = nil; end
    st.timers[name] = { tod = tod, fired = {}, by = by };
    st.removed[name] = nil;
    save();
    log_tod(name, tod, how or 'typed', by);
    local g = GROUPS[GROUP_OF[name]];
    msg(('%s ToD %s%s - first window %s (in %s), %d windows %d min apart.'):format(
        name, clock(tod), by and (' (killed by ' .. by .. ')') or '', clock(tod + g.first), span(tod + g.first - os.time()), g.count, g.step / 60));
end

-- Announce an HNM's ToD to a linkshell (only when you press its L1 / L2 button, or /pops ls <hnm>):
--   /l Fafnir ToD 13:03:12 - Repop at Thu 22 Oct 10:03:12 (7 windows, forced 10:33)
local function announce(name, chan)
    local t = st.timers[name];
    if t == nil then msg(name .. ' has no ToD to announce.'); return; end
    local g = GROUPS[GROUP_OF[name]];
    local first = t.tod + g.first;
    local last = first + (g.count - 1) * g.step;
    local tail = (g.forced == false) and ('until ' .. os.date('%a %d %b %H:%M', last)) or ('forced ' .. os.date('%H:%M', last));
    local line = ('%s ToD %s - Repop at %s (%d windows, %s)'):format(
        name, os.date('%H:%M:%S', t.tod), os.date('%a %d %b %H:%M:%S', first), g.count, tail);
    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, (chan or '/l') .. ' ' .. line); end);
end
-- Lock: some NMs share a name with ones you can pop yourself, and killing those would reset the
-- timer. A locked ToD can't be changed by an automatic kill until 30 minutes before its first window;
-- then the lock comes off by itself.
local LOCK_UNTIL = 30 * 60;
local function lock_ends(name)
    local t = st.timers[name];
    if t == nil then return nil; end
    return t.tod + GROUPS[GROUP_OF[name]].first - LOCK_UNTIL;
end
local function is_locked(name)
    local t = st.timers[name];
    if t == nil or not t.locked then return false; end
    if os.time() >= lock_ends(name) then t.locked = nil; save(); return false; end
    return true;
end
local function set_lock(name, on)
    local t = st.timers[name];
    if t == nil then msg(name .. ' has no ToD to lock.'); return; end
    if on and os.time() >= lock_ends(name) then msg(name .. ' is already within 30 min of its window - nothing to lock.'); return; end
    t.locked = on or nil;
    save();
    if on then
        msg(('%s ToD %s locked until %s (30 min before its first window).'):format(name, os.date('%H:%M:%S', t.tod), os.date('%a %d %b %H:%M', lock_ends(name))));
    else
        msg(name .. ' unlocked.');
    end
end

-- A kill seen in chat or nearby. The ToD is NOT set by itself any more - you type it (or press
-- Killed), so a wrong kill can never overwrite a good ToD. This only tells you, once per 10 min.
local seen_kill = {};
local function auto_kill(name, how, by)
    if not in_hnm_zone(name) then return; end   -- same name, wrong zone (e.g. a Nyzul Isle floor boss)
    local now = os.time();
    if seen_kill[name] ~= nil and now - seen_kill[name] <= 600 then return; end
    seen_kill[name] = now;
    msg(('%s died at %s%s - type its ToD (or press Killed) to start the timer.'):format(
        name, os.date('%H:%M:%S', now), by and (' (' .. by .. ')') or ''));
end
local function stop(name)
    if st.timers[name] then st.removed[name] = st.timers[name].tod; end
    st.timers[name] = nil;
    save();
    msg(name .. ' timer removed.');
end

pops.start = start;

-- A kill seen in chat starts a new timer for that HNM.
ashita.events.register('text_in', 'omni_pops_text', function (e)
    if e.injected then return; end
    pcall(function ()
        local m = (e.message_modified or e.message or ''):gsub('[\30\31].', ''):gsub('\x7F.', '');
        local low = m:lower();
        for _, h in ipairs(HNMS) do
            local n = h[1]:lower();
            if low:find('defeats the ' .. n, 1, true) or low:find('defeats ' .. n, 1, true)
               or low:find('the ' .. n .. ' falls to the ground', 1, true) or low:find(n .. ' falls to the ground', 1, true) then
                -- "[13:49:04] Paopao defeats the Hydra." -> Paopao (a timestamp in front is skipped)
                local by = m:match("([%a][%a'%-]*) defeats ");
                auto_kill(h[1], 'chat', by);
                return;
            end
        end
    end);
end);

-- It popped: the window countdown and warnings stop until it dies (Killed / a kill seen starts a new timer).
local function set_popped(name, when, how)
    local t = st.timers[name];
    if t == nil then return; end
    if when == nil then t.popped = nil; save(); msg(name .. ' back to counting windows.'); return; end
    t.popped = when;
    save();
    local s = status(name, t, when);
    local line = ('%s POPPED! (window %d/%d, %s)'):format(name, s.win, s.count, os.date('%H:%M:%S', when));
    msg(line .. ((how == 'nearby') and ' - seen near you.' or ''));
    sound(true);
    party(line, true);
end
pops.set_popped = set_popped;

-- Watch for the HNMs near you: when one you can see drops to 0% HP (or vanishes at low HP), that's the ToD.
local seen, last_scan, last_zone = {}, 0, -1;
local claimer = {};    -- claimer[HNM] = name of whoever had it claimed last time we looked
local function scan()
    local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    if zone ~= last_zone then seen = {}; last_zone = zone; end   -- zoning is not a kill
    local ent = AshitaCore:GetMemoryManager():GetEntity();
    local now_seen = {};
    for i = 0, 2303 do
        local name = ent:GetName(i);
        if name ~= nil and name ~= '' and GROUP_OF[name] and ent:GetRenderFlags0(i) ~= 0 then
            local hp = ent:GetHPPercent(i);
            now_seen[name] = hp;
            local was = seen[name];
            pcall(function ()
                local cid = bit.band(ent:GetClaimStatus(i) or 0, 0xFFFFFFFF);
                if cid ~= 0 then
                    for j = 0, 2303 do
                        if ent:GetServerId(j) == cid then
                            local cn = ent:GetName(j);
                            if cn and cn ~= '' then claimer[name] = cn; end
                            break;
                        end
                    end
                end
            end);
            if was ~= nil and was > 0 and hp == 0 then auto_kill(name, 'nearby', claimer[name]); end
            -- Seen alive in its own zone from 2 minutes before window 1 on: it has popped.
            local t = st.timers[name];
            if hp > 0 and t ~= nil and not t.popped and in_hnm_zone(name)
               and os.time() >= t.tod + GROUPS[GROUP_OF[name]].first - 120 then
                set_popped(name, os.time(), 'nearby');
            end
        end
    end
    for name, hp in pairs(seen) do
        if now_seen[name] == nil and hp <= 3 then auto_kill(name, 'nearby', claimer[name]); end
    end
    seen = now_seen;
end
ashita.events.register('d3d_present', 'omni_pops_watch', function ()
    local c = os.clock();
    if c - last_scan < 1 then return; end
    last_scan = c;
    pcall(scan);
end);

-- Checked every frame (cheap: a handful of timers).
local last_sync = 0;
ashita.events.register('d3d_present', 'omni_pops_tick', function ()
    local now = os.time();
    local c = os.clock();
    if c - last_sync >= 1 then last_sync = c; sync(); load_mine(); end
    for name, t in pairs(st.timers) do
        if t.loaded then t.loaded = nil; t.loaded_skip = true; end
        -- switched off: ToDs are still saved, but no countdown warnings (and none fire late when
        -- it's switched back on - check() marks them as given)
        if st.on then pcall(check, name, t, now); else t.loaded_skip = true; t.loaded = true; end
    end
end);

local function list(to_party)
    local now = os.time();
    local names = {};
    for name in pairs(st.timers) do names[#names + 1] = name; end
    table.sort(names, function (a, b) return st.timers[a].tod < st.timers[b].tod; end);
    if #names == 0 then msg('no timers. /pops add <hnm> [ToD]'); return; end
    for _, name in ipairs(names) do
        local s = status(name, st.timers[name], now);
        local line;
        if s.phase == 'wait' then line = ('%s: window %d/%d in %s (%s)'):format(name, s.win, s.count, span(s.left), clock(s.next_open));
        elseif s.phase == 'open' then line = ('%s: window %d/%d OPEN now'):format(name, s.win, s.count);
        elseif s.phase == 'popped' then line = ('%s: POPPED at %s (window %d/%d)'):format(name, os.date('%H:%M:%S', s.at), s.win, s.count);
        else line = ('%s: all windows passed - should be up (forced %s ago)'):format(name, span(s.since)); end
        if to_party then
            pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. line); end);
        else
            msg(line);
        end
    end
end

ashita.events.register('command', 'omni_pops_cmd', function (e)
    local a = e.command:args();
    if #a == 0 or (a[1]:lower() ~= '/pops' and a[1]:lower() ~= '/pop') then return; end
    e.blocked = true;
    local c = (a[2] or ''):lower();
    local rest = table.concat(a, ' ', 3);
    if c == '' then
        if pops.open_panel ~= nil then pops.open_panel(); end
    elseif c == 'add' or c == 'tod' then
        -- the name is everything up to the time; try the longest name first
        local words = {};
        for i = 3, #a do words[#words + 1] = a[i]; end
        for cut = #words, 1, -1 do
            local name = find_hnm(table.concat(words, ' ', 1, cut));
            if name then
                local when = table.concat(words, ' ', cut + 1);
                local by = nil;
                local w2, b2 = when:match('^(.-)%s*by%s+(%S+)$');
                if b2 then when, by = w2, b2; end
                local tod = parse_tod(when);
                if tod == nil then msg('Could not read that time. Use 21:35, 21:35:10, now, or 2d 21:35 (add "by Name" for who killed it).'); return; end
                start(name, tod, 'typed', by);
                return;
            end
        end
        msg('Which HNM? e.g. /pops add fafnir 21:35');
    elseif c == 'on' or c == 'off' then
        st.on = (c == 'on'); save_mine();
        msg('countdowns ' .. (st.on and 'ON.' or 'OFF - ToDs are still saved.'));
    elseif c == 'by' then
        -- /pops by <hnm> <Name>: who killed it, for the timer already running
        local who = a[#a];
        local name = (#a >= 4) and find_hnm(table.concat(a, ' ', 3, #a - 1)) or nil;
        if name == nil or st.timers[name] == nil then msg('Use /pops by <hnm> <Name>, e.g. /pops by hydra Paopao (needs a running timer).'); return; end
        st.timers[name].by = who;
        save();
        msg(name .. ' killed by ' .. who .. '.');
    elseif c == 'kill' or c == 'killed' then
        local name = find_hnm(rest);
        if name then start(name, os.time(), 'button'); else msg('Which HNM? e.g. /pops kill fafnir'); end
    elseif c == 'del' or c == 'remove' or c == 'stop' then
        local name = find_hnm(rest);
        if name and st.timers[name] then stop(name); else msg('No timer for that.'); end
    elseif c == 'history' or c == 'tods' then
        local name = find_hnm(rest);
        if name == nil then msg('Which HNM? e.g. /pops history fafnir'); return; end
        local h = read_history(name);
        if #h == 0 then msg('No ToDs saved for ' .. name .. ' yet.'); return; end
        for i = math.max(1, #h - 9), #h do msg(('%s ToD %s (%s)'):format(name, os.date('%a %d %b %H:%M:%S', h[i][1]), h[i][2] or '?')); end
    elseif c == 'list' then
        list((a[3] or ''):lower() == 'party' or (a[3] or ''):lower() == 'p');
    elseif c == 'warn' or c == 'warnings' then
        st.warn = not st.warn; save_mine();
        msg('Window warnings ' .. (st.warn and 'ON' or 'OFF') .. '.');
    elseif c == 'lock' or c == 'unlock' then
        local name = find_hnm(rest);
        if name == nil then msg('Which HNM? e.g. /pops lock khimaira'); return; end
        set_lock(name, c == 'lock');
    elseif c == 'up' or c == 'popped' or c == 'notup' then
        local name = find_hnm(rest);
        if name == nil or st.timers[name] == nil then msg('Which HNM (with a timer)? e.g. /pops up fafnir'); return; end
        set_popped(name, (c ~= 'notup') and os.time() or nil, 'typed');
    elseif c == 'ls1h' or c == 'hour' then
        st.ls = not st.ls; save_mine();
        msg('1 hour linkshell warning ' .. (st.ls and 'ON' or 'OFF') .. '.');
    elseif c == 'ls' or c == 'ls1' or c == 'linkshell' or c == 'ls2' or c == 'linkshell2' then
        local name = find_hnm(rest);
        if name == nil then msg('Which HNM? e.g. /pops ls fafnir  (or /pops ls2 fafnir)'); return; end
        announce(name, (c == 'ls2' or c == 'linkshell2') and '/l2' or '/l');
    elseif c == 'party' then
        st.party = not st.party; save_mine();
        msg('Party chat warnings ' .. (st.party and 'ON' or 'OFF') .. '.');
    else
        msg('/pops  |  /pops on|off  |  /pops add <hnm> [21:35] [by Name]  |  /pops by <hnm> <Name>  |  /pops kill <hnm>  |  /pops del <hnm>  |  /pops list [party]  |  /pops party  |  /pops ls <hnm>  |  /pops ls2 <hnm>  |  /pops lock|unlock <hnm>  |  /pops up|notup <hnm>');
    end
end);

----------------------------------------------------------------------------------------------------
-- The Happy Pops window
----------------------------------------------------------------------------------------------------
local C = {
    gold = { 0.90, 0.78, 0.40, 1.0 }, text = { 0.92, 0.92, 0.95, 1.0 }, dim = { 0.60, 0.62, 0.68, 1.0 },
    green = { 0.50, 0.88, 0.50, 1.0 }, red = { 1.0, 0.45, 0.40, 1.0 }, orange = { 1.0, 0.70, 0.30, 1.0 },
};
local pick = { 0 };
local tod_buf = { '' };
local W, H = 650, 200;
local open = { false };

local NAMES = {};
for i, h in ipairs(HNMS) do NAMES[i] = h[1] .. '  (' .. (GROUPS[h[2]].label or h[2]:sub(2) .. 'h') .. ')'; end
local NAMES_Z = table.concat(NAMES, '\0') .. '\0';

local function hist_tip(name, t)
    local lines = { name };
    if t then lines[#lines + 1] = 'ToD ' .. os.date('%a %d %b %H:%M:%S', t.tod); end
    if read_history ~= nil then
        local h = read_history(name);
        if #h > 0 then lines[#lines + 1] = 'Last ToDs:'; end
        for i = #h, math.max(1, #h - 5), -1 do
            lines[#lines + 1] = ('  %s  (%s%s)'):format(os.date('%a %d %b %H:%M:%S', h[i][1]), h[i][2] or '?', h[i][3] and (', ' .. h[i][3]) or '');
        end
    end
    lines[#lines + 1] = 'Click the name to pick it above.';
    imgui.SetTooltip(table.concat(lines, '\n'));
end

local function group_label(g) return GROUPS[g].label or (g:sub(2) .. 'h'); end

local function body()
    local now = os.time();
    local style = package.loaded['omni_style'];
    local th = style and style.theme and style.theme() or nil;
    local gold = (th and th.accent) or C.gold;

    -- The On/Off switch (same slider as Happy Healer's). Off = ToDs are still saved, no countdown.
    local clicked;
    local tip = 'On: countdowns and window warnings.\nOff: ToDs are still saved (kills in chat, seen nearby, Killed button)\nbut there is no countdown and no warnings.\nSame as /pops on and /pops off.';
    if style ~= nil and style.switch ~= nil then
        clicked = style.switch('##pops_master', st.on, tip);
    else
        clicked = imgui.Button((st.on and 'ON' or 'OFF') .. '##pops_master');
        if imgui.IsItemHovered() then imgui.SetTooltip(tip); end
    end
    if clicked then
        st.on = not st.on; save_mine();
        msg('countdowns ' .. (st.on and 'ON.' or 'OFF - ToDs are still saved.'));
    end
    imgui.SameLine(0, 6);
    imgui.TextColored(st.on and gold or C.dim, st.on and 'Happy Pops' or 'Happy Pops (off - saving ToDs only)');
    imgui.SameLine(0, 16);

    -- Add a timer: pick the HNM, type the ToD (blank = now), Start.
    imgui.PushItemWidth(200);
    imgui.Combo('##pops_pick', pick, NAMES_Z);
    imgui.PopItemWidth();
    imgui.SameLine(0, 6);
    imgui.PushItemWidth(110);
    imgui.InputTextWithHint('##pops_tod', 'ToD 21:35', tod_buf, 16);
    imgui.PopItemWidth();
    if imgui.IsItemHovered() then imgui.SetTooltip('Time of death on your clock: 21:35 or 21:35:10.\nLeave it empty for "now". "2d 21:35" = two days ago.'); end
    imgui.SameLine(0, 6);
    if imgui.Button('Start##pops_add', { -1, 0 }) then
        local name = HNMS[pick[1] + 1][1];
        local tod = parse_tod(tod_buf[1]);
        if tod then start(name, tod); tod_buf[1] = ''; else msg('Could not read that time. Use 21:35, 21:35:10 or leave it empty for now.'); end
    end
    imgui.Spacing();

    -- Active timers first (soonest on top), then everything not being tracked.
    local active, idle = {}, {};
    for i, h in ipairs(HNMS) do
        if st.timers[h[1]] then active[#active + 1] = h; else idle[#idle + 1] = h; end
    end
    local function key(h)
        local s = status(h[1], st.timers[h[1]], now);
        if s.phase == 'popped' then return -3; end
        if s.phase == 'open' then return -1; end
        if s.phase == 'done' then return -2; end
        return s.left;
    end
    table.sort(active, function (a, b) return key(a) < key(b); end);

    -- The table in omni's own colours: no striped rows; running timers get a soft tint of the theme's
    -- accent colour, the header uses the theme's bar colour and the lines are the theme's thin lines.
    local accent = gold;
    local line = (th and th.line) or { 0.22, 0.22, 0.24, 1.0 };
    local head = (th and th.bar) or { 0.10, 0.10, 0.11, 1.0 };
    imgui.PushStyleColor(ImGuiCol_TableHeaderBg, { head[1], head[2], head[3], 0.95 });
    imgui.PushStyleColor(ImGuiCol_TableBorderLight, { line[1], line[2], line[3], 0.55 });
    imgui.PushStyleColor(ImGuiCol_TableBorderStrong, { accent[1], accent[2], accent[3], 0.45 });
    imgui.PushStyleColor(ImGuiCol_TableRowBg, { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_TableRowBgAlt, { 0, 0, 0, 0 });
    -- Columns can be dragged wider or narrower by their edges (in the header); the widths are saved.
    local flags = bit.bor(ImGuiTableFlags_BordersInnerH, ImGuiTableFlags_BordersInnerV or 512, ImGuiTableFlags_SizingFixedFit, ImGuiTableFlags_Resizable or 1);
    if imgui.BeginTable('##pops_table', 5, flags) then
        local cw = st.cols;
        imgui.TableSetupColumn('HNM', ImGuiTableColumnFlags_WidthFixed, cw[1]);
        imgui.TableSetupColumn('ToD', ImGuiTableColumnFlags_WidthFixed, cw[2]);
        imgui.TableSetupColumn('Countdown', ImGuiTableColumnFlags_WidthFixed, cw[3]);
        imgui.TableSetupColumn('Pop date', ImGuiTableColumnFlags_WidthFixed, cw[4]);
        imgui.TableSetupColumn('##act', ImGuiTableColumnFlags_WidthFixed, cw[5]);
        imgui.TableHeadersRow();
        -- Read the widths back (a fixed column's room is its width) and save them once you let go.
        pcall(function ()
            local now_w, changed = {}, false;
            for ci = 0, 4 do
                imgui.TableSetColumnIndex(ci);
                local w = imgui.GetContentRegionAvail();
                if type(w) == 'table' then w = w[1] or w.x; end
                w = math.floor((tonumber(w) or cw[ci + 1]) + 0.5);
                now_w[ci + 1] = w;
                if math.abs(w - cw[ci + 1]) >= 1 then changed = true; end
            end
            if changed and not imgui.IsMouseDown(0) then st.cols = now_w; save_mine(); end
        end);

        local function name_cell(h, col)
            imgui.TableNextColumn();
            local nm = h[1];
            if st.timers[nm] ~= nil then
                -- Lock button: gold "Locked" while the ToD is locked in, dim "Lock" otherwise.
                local locked = is_locked(nm);
                local gold = { 0.95, 0.78, 0.30, 1.0 };
                imgui.PushStyleColor(ImGuiCol_Button, locked and { gold[1], gold[2], gold[3], 0.30 } or { line[1], line[2], line[3], 0.35 });
                imgui.PushStyleColor(ImGuiCol_Text, locked and gold or C.dim);
                if imgui.SmallButton((locked and 'Locked' or ' Lock ') .. '##pops_lock_' .. nm) then set_lock(nm, not locked); end
                imgui.PopStyleColor(2);
                if imgui.IsItemHovered() then
                    local le = lock_ends(nm);
                    imgui.SetTooltip(locked
                        and ('ToD locked in until %s (30 min before the first window).\nKills seen in chat or nearby can\'t change it till then.\nClick to unlock.'):format(os.date('%a %d %b %H:%M', le))
                        or ('Lock this ToD in until 30 min before the first window (%s),\nso killing a pop-able NM with the same name doesn\'t reset it.'):format(os.date('%a %d %b %H:%M', le)));
                end
                imgui.SameLine(0, 6);
            end
            imgui.TextColored(col, h[1]);
            if imgui.IsItemClicked() then
                for i, x in ipairs(HNMS) do if x[1] == h[1] then pick[1] = i - 1; end end
            end
            if imgui.IsItemHovered() then hist_tip(h[1], st.timers[h[1]]); end
            imgui.SameLine(0, 4);
            imgui.TextColored(C.dim, group_label(h[2]));
            -- small line under the name: who killed it and the full ToD
            local tm = st.timers[nm];
            if tm ~= nil then
                imgui.SetWindowFontScale(0.8);
                imgui.TextColored(C.dim, ('%s  -  ToD %s'):format(tm.by and ('Killed by ' .. tm.by) or 'Killer unknown',
                    os.date('%a %d %b %H:%M:%S', tm.tod)));
                imgui.SetWindowFontScale(1.0);
            end
        end

        for _, h in ipairs(active) do
            local name = h[1];
            local t = st.timers[name];
            local s = status(name, t, now);
            local g = GROUPS[h[2]];
            local last = t.tod + g.first + (g.count - 1) * g.step;
            imgui.TableNextRow();
            pcall(imgui.TableSetBgColor, ImGuiTableBgTarget_RowBg0, imgui.GetColorU32({ accent[1], accent[2], accent[3], 0.10 }));
            name_cell(h, accent);
            imgui.TableNextColumn();
            imgui.TextColored(C.text, os.date('%H:%M:%S', t.tod));
            imgui.TableNextColumn();
            if not st.on then
                imgui.TextColored(C.dim, 'off');
            elseif s.phase == 'popped' then
                imgui.TextColored(C.green, 'POPPED');
            elseif s.phase == 'open' then
                local blink = (math.floor(os.clock() * 2) % 2 == 0);
                imgui.TextColored(blink and C.green or C.text, ('OPEN  %ds'):format(math.ceil(s.left)));
            elseif s.phase == 'wait' then
                local col = (s.left <= 30) and C.red or ((s.left <= 120) and C.orange or accent);
                -- A bar that fills over the last hour before window 1 (or across the gap between windows).
                local span_total = (s.win == 1) and 3600 or g.step;
                local frac = math.max(0, math.min(1, 1 - s.left / span_total));
                imgui.PushStyleColor(ImGuiCol_PlotHistogram, { col[1], col[2], col[3], 0.55 });
                imgui.PushStyleColor(ImGuiCol_FrameBg, { line[1], line[2], line[3], 0.60 });
                imgui.ProgressBar(frac, { -1, 16 }, span(s.left));
                imgui.PopStyleColor(2);
            else
                imgui.TextColored(C.green, 'Should be up');
            end
            if imgui.IsItemHovered() then imgui.SetTooltip(('Window %d of %d.'):format(s.win, s.count)); end
            -- Pop date: the day and time of the next window, and of the last (forced) one.
            imgui.TableNextColumn();
            local tail = ((g.forced == false) and '(last %s)' or '(forced %s)'):format(os.date('%H:%M', last));
            if s.phase == 'popped' then
                imgui.TextColored(C.green, ('popped %s'):format(os.date('%a %d %b %H:%M:%S', s.at)));
                imgui.SameLine(0, 6);
                imgui.TextColored(C.dim, ('(window %d/%d)'):format(s.win, s.count));
            elseif s.phase == 'wait' then
                imgui.TextColored(C.text, os.date('%a %d %b %H:%M:%S', s.next_open));
                imgui.SameLine(0, 6);
                imgui.TextColored(C.dim, tail);
            elseif s.phase == 'open' then
                imgui.TextColored(C.green, 'open now');
                imgui.SameLine(0, 6);
                imgui.TextColored(C.dim, tail);
            else
                imgui.TextColored(C.green, 'should be up since ' .. os.date('%a %H:%M', last));
            end
            imgui.TableNextColumn();
            if imgui.SmallButton('Killed##pops_k_' .. name) then
                if is_locked(name) then msg(name .. ' ToD is locked - press Locked first if it really died again.');
                else start(name, os.time(), 'button'); end
            end
            if imgui.IsItemHovered() then imgui.SetTooltip(is_locked(name) and 'ToD is locked - unlock it first to change it.' or 'It died just now - start a new timer.'); end
            imgui.SameLine(0, 4);
            if imgui.SmallButton((t.popped and 'Not up' or 'Up') .. '##pops_up_' .. name) then set_popped(name, (not t.popped) and os.time() or nil, 'button'); end
            if imgui.IsItemHovered() then imgui.SetTooltip(t.popped and 'It wasn\'t really up - go back to counting the windows.' or 'It has popped - stop counting the windows.\n(Done by itself when it is seen near you in its zone.)'); end
            imgui.SameLine(0, 4);
            if imgui.SmallButton('L1##pops_l1_' .. name) then announce(name, '/l'); end
            if imgui.IsItemHovered() then imgui.SetTooltip('Announce this ToD to linkshell 1 (/l):\n' .. name .. ' ToD hh:mm:ss - Repop at <day date time> (7 windows, forced hh:mm)'); end
            imgui.SameLine(0, 4);
            if imgui.SmallButton('L2##pops_l2_' .. name) then announce(name, '/l2'); end
            if imgui.IsItemHovered() then imgui.SetTooltip('Announce this ToD to linkshell 2 (/l2).'); end
            imgui.SameLine(0, 4);
            if imgui.SmallButton('X##pops_x_' .. name) then stop(name); end
            if imgui.IsItemHovered() then imgui.SetTooltip('Stop tracking it.'); end
        end

        for _, h in ipairs(idle) do
            local name = h[1];
            imgui.TableNextRow();
            name_cell(h, C.text);
            imgui.TableNextColumn(); imgui.TextColored(C.dim, '-');
            imgui.TableNextColumn(); imgui.TextColored(C.dim, 'no timer');
            imgui.TableNextColumn(); imgui.TextColored(C.dim, '-');
            imgui.TableNextColumn();
            if imgui.SmallButton('Killed##pops_k_' .. name) then start(name, os.time(), 'button'); end
            if imgui.IsItemHovered() then imgui.SetTooltip('It died just now - start its timer from now.\nFor an older ToD, pick it above and type the time.'); end
        end
        imgui.EndTable();
    end
    imgui.PopStyleColor(5);

    imgui.Spacing();
    local wv = { st.warn };
    if imgui.Checkbox('Window warnings##pops_warn', wv) then st.warn = wv[1]; save_mine(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Warns you before every window: 2 min, 1 min, 30 sec, 10 sec,\nOPEN (with a sound), and when it closes. Same as /pops warn.'); end
    imgui.SameLine(0, 16);
    local pv = { st.party };
    if imgui.Checkbox('Warn the party too##pops_party', pv) then st.party = pv[1]; save_mine(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Posts every warning to party chat too\n(each OPEN with a <call14> sound). Same as /pops party.'); end
    imgui.SameLine(0, 16);
    local lv = { st.ls };
    if imgui.Checkbox('1h warning to linkshell##pops_ls1h', lv) then st.ls = lv[1]; save_mine(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('One hour before the first window of every timer, posts to /l:\n"Jormungand window 1/7 in 1 hour (22:18:49)"\nSame as /pops ls1h.'); end
    imgui.SameLine(0, 16);
    imgui.TextColored(C.dim, ('%d active'):format(#active));
end

-- Shown as its own tab in omni's drop-down panel (omni.lua adds the "Happy Pops" tab).
pops.render = function ()
    body();
end
pops.height = function () return H; end

-- omni sets this so /pops opens the panel on the Happy Pops tab.
pops.open_panel = nil;

return pops;
