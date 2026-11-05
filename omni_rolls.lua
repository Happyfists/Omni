--[[
    omni_rolls.lua - Roll Tracker (Options > Roll Tracker): keeps the /random order for NM pops.

    Everyone types /random. Each roll is read from chat and the list sorts itself, highest first.
    Only a person's FIRST roll counts (re-rolls are shown but ignored). Ties are flagged; whoever
    rolled first goes first. After each pop, press "Next" and the arrow moves on.
    Saved to config\addons\omni\rollorder.txt, so it survives a reload or a crash.

    Commands: /rolls new | next | post | lock   (/rolls on its own says whose turn it is)

    Corsair rolls (3.90/3.91): every roll and Double-Up you do is said in party chat with the number
    rolled (and the new total for a Double-Up) and the roll's lucky / unlucky numbers, e.g.
    "Chaos Roll: rolled 3 - Lucky 4 / Unlucky 8 (Attack)", "Chaos Roll Double-Up: rolled 1, total 4 LUCKY! - ...".
    Tick box on this page, or /rolls cor on|off.  Lucky / unlucky numbers from the RollTracker addon
    by Daniel_H (Ashita v4 port by sippius / Lumaro).
]]

local imgui = require('imgui');

local rolls = {};

local st = { locked = false, turn = 1, rolls = {}, title = '', corp = true };   -- corp: say my Corsair rolls in /p

local function base() return string.format('%s\\config\\addons\\', AshitaCore:GetInstallPath()); end
local function path() return base() .. 'omni\\rollorder.txt'; end

local function save()
    pcall(function ()
        local f = io.open(path(), 'w');
        if f == nil then return; end
        f:write('turn ', st.turn, '\n');
        f:write('locked ', st.locked and 1 or 0, '\n');
        f:write('title ', st.title, '\n');
        f:write('corp ', st.corp and 1 or 0, '\n');
        for _, r in ipairs(st.rolls) do
            f:write(string.format('roll %s %d %d %d %d\n', r.name, r.value, r.t, r.order, r.rerolls or 0));
        end
        f:close();
    end);
end
local function read(file)
    local ok = false;
    pcall(function ()
        local f = io.open(file, 'r');
        if f == nil then return; end
        st.rolls = {};
        for line in f:lines() do
            local v = line:match('^turn (%d+)$'); if v then st.turn = tonumber(v); end
            v = line:match('^locked (%d)$'); if v then st.locked = (v == '1'); end
            v = line:match('^title (.*)$'); if v then st.title = v; end
            v = line:match('^corp (%d)$'); if v then st.corp = (v == '1'); end
            local n, val, t, o, rr = line:match('^roll (%S+) (%d+) (%d+) (%d+) (%d+)$');
            if n then st.rolls[#st.rolls + 1] = { name = n, value = tonumber(val), t = tonumber(t), order = tonumber(o), rerolls = tonumber(rr) }; end
        end
        f:close();
        ok = true;
    end);
    return ok;
end
-- Load ours; the first time, take over the list from the standalone Roll Tracker addon.
if not read(path()) then
    if read(base() .. 'rolltracker\\rolls.txt') then save(); end
end

local function sorted()
    local list = {};
    for _, r in ipairs(st.rolls) do list[#list + 1] = r; end
    table.sort(list, function (a, b)
        if a.value ~= b.value then return a.value > b.value; end
        return a.order < b.order;
    end);
    return list;
end
local function tied(list, i)
    local v = list[i].value;
    return (list[i - 1] and list[i - 1].value == v) or (list[i + 1] and list[i + 1].value == v);
end

local function msg(t) print('\30\68[Roll Tracker]\30\01 ' .. t); end

local function new_round()
    st.rolls, st.turn, st.locked = {}, 1, false;
    save();
    msg('new round - waiting for /random.');
end
local function say_turn()
    local list = sorted();
    if #list == 0 then msg('no rolls yet.');
    elseif list[st.turn] then msg(string.format('up now: %s (%d)', list[st.turn].name, list[st.turn].value));
    else msg('everyone has had a turn.'); end
end
local function next_turn()
    if #st.rolls == 0 then return; end
    st.turn = math.min(st.turn + 1, #st.rolls + 1);
    save();
    say_turn();
end
local function post()
    local list = sorted();
    if #list == 0 then msg('no rolls yet.'); return; end
    local lines, cur = {}, (st.title ~= '' and (st.title .. ' - ') or '') .. 'Roll order:';
    for i, r in ipairs(list) do
        local piece = string.format(' %d.%s(%d)', i, r.name, r.value);
        if #cur + #piece > 95 then lines[#lines + 1] = cur; cur = ' ' .. piece; else cur = cur .. piece; end
    end
    lines[#lines + 1] = cur;
    for _, l in ipairs(lines) do AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. l); end
end

-- Only the game's own /random line ("Dice roll! Name rolls 532!"), not someone typing it in chat.
local function read_roll(raw)
    local m = (raw or ''):gsub('[\30\31].', ''):gsub('\x7F.', ''):gsub('[%c]', ' ');
    m = m:gsub('^%s*%[%d+:%d+:?%d*%]%s*', ''):gsub('^%s*%d+:%d+:?%d*%s+', '');   -- timestamp addons: "[16:53:38] "
    local name, value = m:match('Dice roll!%s*(%a+) rolls (%d+)');
    if name == nil then name, value = m:match('^%s*(%a+) rolls (%d+)[!.]?%s*$'); end
    return name, value;
end
local function on_text(e)
    if st.locked then return; end
    -- Only the game's own /random line ("Dice roll! Name rolls 532!"), with or without a timestamp in front.
    local name, value = read_roll(e.message);
    if name == nil then name, value = read_roll(e.message_modified); end
    if name == nil then return; end
    value = tonumber(value);
    if value == nil or value < 0 or value > 999 then return; end
    for _, r in ipairs(st.rolls) do
        if r.name:lower() == name:lower() then r.rerolls = (r.rerolls or 0) + 1; save(); return; end
    end
    st.rolls[#st.rolls + 1] = { name = name, value = value, t = os.time(), order = #st.rolls + 1, rerolls = 0 };
    save();
end
ashita.events.register('text_in', 'omni_rolls_text', function (e) if not e.injected then pcall(on_text, e); end end);

----------------------------------------------------------------------------------------------------
-- Corsair rolls: say the roll and its lucky / unlucky numbers in party chat.
----------------------------------------------------------------------------------------------------
-- [job ability id] = { name, lucky, unlucky, what it boosts }
local COR_ROLLS = {
    [98] = { "Fighter's Roll", 5, 9, "Double Attack" },
    [99] = { "Monk's Roll", 3, 7, "Subtle Blow" },
    [100] = { "Healer's Roll", 3, 7, "Cure Potency" },
    [101] = { "Wizard's Roll", 5, 9, "Magic Attack Bonus" },
    [102] = { "Warlock's Roll", 4, 8, "Magic Accuracy" },
    [103] = { "Rogue's Roll", 5, 9, "Critical Hit Rate" },
    [104] = { "Gallant's Roll", 3, 7, "Defense" },
    [105] = { 'Chaos Roll', 4, 8, "Attack" },
    [106] = { 'Beast Roll', 4, 8, "Pet: Attack / Ranged Attack" },
    [107] = { 'Choral Roll', 2, 6, "Spell Interruption Rate down" },
    [108] = { "Hunter's Roll", 4, 8, "Accuracy" },
    [109] = { 'Samurai Roll', 2, 6, "Store TP" },
    [110] = { 'Ninja Roll', 4, 8, "Evasion" },
    [111] = { 'Drachen Roll', 4, 8, "Pet: Accuracy / Ranged Accuracy" },
    [112] = { "Evoker's Roll", 5, 9, "Refresh" },
    [113] = { "Magus's Roll", 2, 6, "Magic Defense Bonus" },
    [114] = { "Corsair's Roll", 5, 9, "Experience / Capacity Points" },
    [115] = { 'Puppet Roll', 3, 7, "Pet: Magic Accuracy / Magic Attack Bonus" },
    [116] = { "Dancer's Roll", 3, 7, "Regen" },
    [117] = { "Scholar's Roll", 2, 6, "Conserve MP" },
    [118] = { "Bolter's Roll", 3, 9, "Movement Speed" },
    [119] = { "Caster's Roll", 2, 7, "Fast Cast" },
    [120] = { "Courser's Roll", 3, 9, "Snapshot" },
    [121] = { "Blitzer's Roll", 4, 9, "Haste" },
    [122] = { "Tactician's Roll", 5, 8, "Regain" },
    [302] = { "Allies' Roll", 3, 10, "Skillchain Damage / Accuracy" },
    [303] = { "Miser's Roll", 5, 7, "Save TP" },
    [304] = { "Companion's Roll", 2, 10, "Pet: Regain / Regen" },
    [305] = { "Avenger's Roll", 4, 8, "Counter Rate" },
    [390] = { "Naturalist's Roll", 3, 7, "Enhancing Magic Duration" },
    [391] = { "Runeist's Roll", 4, 8, "Magic Evasion" },
};
local COR_BY_NAME = {};
for id, r in pairs(COR_ROLLS) do COR_BY_NAME[r[1]:lower()] = id; end

-- The roll an ability id stands for: our table first, then the game's own ability name (in case
-- CatsEyeXI numbers a roll differently).
local function cor_roll(id)
    if COR_ROLLS[id] then return COR_ROLLS[id]; end
    local found = nil;
    pcall(function ()
        local res = AshitaCore:GetResourceManager();
        for _, rid in ipairs({ id + 0x200, id }) do
            local a = res:GetAbilityById(rid);
            local n = a and a.Name and a.Name[1];
            if n and COR_BY_NAME[n:lower()] then found = COR_ROLLS[COR_BY_NAME[n:lower()]]; return; end
        end
    end);
    return found;
end

-- Every job ability you use goes to config\addons\omni\cor_debug.txt (id, number, roll found),
-- so a roll that doesn't post can be looked up.
local function cor_log(id, n, r)
    pcall(function ()
        local f = io.open(base() .. 'omni\\cor_debug.txt', 'a');
        if f == nil then return; end
        f:write(string.format('%s  ability %d  number %d  %s\n', os.date('%Y-%m-%d %H:%M:%S'), id, n or -1, r and r[1] or '(not a roll)'));
        f:close();
    end);
end

local cor_last, cor_zoning = '', false;
local cor_last_t = 0;
local cor_total = {};          -- cor_total[roll ability id] = { total, when }: for working out a Double-Up's die
local cor_dbl_at = -100;       -- when you last sent Double-Up (os.clock)
local DOUBLE_UP = 123;

local function tag(n, r)
    if n > 11 then return 'BUST'; end
    if n == 11 then return '11!'; end
    if n == r[2] then return n .. ' LUCKY!'; end
    if n == r[3] then return n .. ' (unlucky)'; end
    return tostring(n);
end

-- id: the roll's ability id. n: the roll total the game reports.
local function cor_post(id, n)
    local r = cor_roll(id);
    cor_log(id, n, r);
    if r == nil or n == nil then return; end
    local key = id .. ':' .. tostring(n);
    local now = os.clock();
    if key == cor_last and now - cor_last_t < 2 then return; end   -- the same packet seen twice
    cor_last, cor_last_t = key, now;
    local prev = cor_total[id];
    local is_double = (now - cor_dbl_at < 6) and prev ~= nil and (now - prev[2] < 60) and n > prev[1];
    local line;
    if n > 11 then
        line = string.format('%s%s: BUST - Lucky %d / Unlucky %d (%s)', r[1], is_double and ' Double-Up' or '', r[2], r[3], r[4]);
    elseif is_double then
        line = string.format('%s Double-Up: rolled %d, total %s - Lucky %d / Unlucky %d (%s)',
            r[1], n - prev[1], tag(n, r), r[2], r[3], r[4]);
    else
        line = string.format('%s: rolled %s - Lucky %d / Unlucky %d (%s)', r[1], tag(n, r), r[2], r[3], r[4]);
    end
    cor_total[id] = { n, now };
    cor_dbl_at = -100;
    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. line); end);
end
-- Your own commands: notice Double-Up (job ability action packet, category 9, param = ability id).
ashita.events.register('packet_out', 'omni_rolls_cor_out', function (e)
    if e.id ~= 0x01A or not st.corp then return; end
    pcall(function ()
        local cat = struct.unpack('H', e.data, 0x0A + 1);
        local param = struct.unpack('H', e.data, 0x0C + 1);
        if cat == 9 and param == DOUBLE_UP then cor_dbl_at = os.clock(); end
    end);
end);
ashita.events.register('packet_in', 'omni_rolls_cor', function (e)
    if e.id == 0x00B then cor_zoning = true; return; end
    if e.id == 0x00A then cor_zoning = false; return; end
    if e.id ~= 0x028 or cor_zoning or not st.corp then return; end
    pcall(function ()
        local actor = struct.unpack('I', e.data, 0x05 + 1);
        if actor ~= AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0) then return; end
        local category = ashita.bits.unpack_be(e.data_raw, 82, 4);
        if category ~= 6 then return; end               -- 6 = job ability used (a Double-Up comes as the roll it adds to)
        local id = ashita.bits.unpack_be(e.data_raw, 86, 10);
        local n = ashita.bits.unpack_be(e.data_raw, 213, 17);   -- the roll total
        cor_post(id, n);
    end);
end);
-- For checking: the game's own roll lines go into cor_debug.txt too.
ashita.events.register('text_in', 'omni_rolls_cor_text', function (e)
    if not st.corp then return; end
    pcall(function ()
        local m = (e.message or ''):gsub('[\30\31].', ''):gsub('\x7F.', '');
        if m:find('Roll', 1, true) or m:find('Double%-Up') or m:find('[Bb]ust') then
            local f = io.open(base() .. 'omni\\cor_debug.txt', 'a');
            if f then f:write(os.date('%Y-%m-%d %H:%M:%S'), '  chat: ', m, '\n'); f:close(); end
        end
    end);
end);

ashita.events.register('command', 'omni_rolls_cmd', function (e)
    local a = e.command:args();
    if #a == 0 or a[1]:lower() ~= '/rolls' then return; end
    e.blocked = true;
    local c = (a[2] or ''):lower();
    if c == 'new' or c == 'clear' then new_round();
    elseif c == 'next' then next_turn();
    elseif c == 'post' then post();
    elseif c == 'lock' then st.locked = not st.locked; save(); msg(st.locked and 'locked.' or 'taking rolls.');
    elseif c == 'cor' then
        local v = (a[3] or ''):lower();
        if v == 'on' then st.corp = true; elseif v == 'off' then st.corp = false; else st.corp = not st.corp; end
        save();
        msg('Corsair rolls in party chat: ' .. (st.corp and 'ON' or 'OFF') .. '.');
    elseif c == '' then say_turn();
    else msg('/rolls  |  /rolls new  |  /rolls next  |  /rolls post  |  /rolls lock  |  /rolls cor on|off   (window: omni Options > Roll Tracker)'); end
end);

----------------------------------------------------------------------------------------------------
-- Options > Roll Tracker
----------------------------------------------------------------------------------------------------
local GOLD, DIM, TEXT = { 0.90, 0.78, 0.40, 1.0 }, { 0.62, 0.66, 0.80, 1.0 }, { 0.92, 0.92, 0.95, 1.0 };
local GREEN, RED, FAINT = { 0.45, 0.88, 0.45, 1.0 }, { 1.0, 0.55, 0.45, 1.0 }, { 0.42, 0.44, 0.52, 1.0 };
local title_buf = { '' };

rolls.render = function ()
    local list = sorted();
    local W = math.floor(imgui.GetContentRegionAvail());
    local x0 = imgui.GetCursorPosX();

    title_buf[1] = st.title;
    imgui.PushItemWidth(math.min(W, 360));
    if imgui.InputTextWithHint('##omni_rt_title', 'What are we rolling for? (optional)', title_buf, 40) then
        st.title = title_buf[1]; save();
    end
    imgui.PopItemWidth();

    if #list == 0 then
        imgui.TextColored(DIM, st.locked and 'Locked - not taking rolls.' or 'Waiting for /random... everyone in the party rolls and the order fills in here.');
    else
        local cur = list[st.turn];
        imgui.TextColored(DIM, string.format('%d roll%s', #list, #list == 1 and '' or 's'));
        imgui.SameLine(0, 8);
        if cur then imgui.TextColored(GOLD, 'Up now: ' .. cur.name); else imgui.TextColored(GREEN, 'Everyone has had a turn.'); end
        if st.locked then imgui.SameLine(0, 8); imgui.TextColored(RED, '(locked)'); end
    end
    imgui.Separator();

    local cName, cRoll, cNote = x0 + 44, x0 + 200, x0 + 240;
    for i, r in ipairs(list) do
        local done, now = i < st.turn, i == st.turn;
        local col = done and FAINT or (now and GOLD or TEXT);
        if now then
            local sx, sy = imgui.GetCursorScreenPos();
            local _, lh = imgui.CalcTextSize('Ag');
            imgui.GetWindowDrawList():AddRectFilled({ sx, sy - 1 }, { sx + W, sy + lh + 1 }, imgui.GetColorU32({ 0.90, 0.78, 0.40, 0.14 }), 4);
        end
        imgui.SetCursorPosX(x0 + 4);
        imgui.TextColored(col, (done and '+' or (now and '>' or ' ')) .. string.format(' %2d.', i));
        imgui.SameLine(cName);
        imgui.PushStyleColor(ImGuiCol_Text, col);
        imgui.Selectable(r.name .. '##omni_rt_row' .. i, false, 0, { 150, 0 });
        imgui.PopStyleColor(1);
        if imgui.BeginPopupContextItem('##omni_rt_ctx' .. i) then
            imgui.TextColored(GOLD, r.name);
            imgui.Separator();
            if imgui.MenuItem('Make it their turn') then st.turn = i; save(); end
            if imgui.MenuItem('Remove from the list') then
                for j, x in ipairs(st.rolls) do if x == r then table.remove(st.rolls, j); break; end end
                if st.turn > i then st.turn = st.turn - 1; end
                save();
            end
            imgui.EndPopup();
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Right-click: make it their turn, or remove them.'); end
        imgui.SameLine(cRoll);
        imgui.TextColored(col, string.format('%3d', r.value));
        local notes = {};
        if tied(list, i) then notes[#notes + 1] = 'tie'; end
        if (r.rerolls or 0) > 0 then notes[#notes + 1] = 're-rolled'; end
        if #notes > 0 then
            imgui.SameLine(cNote);
            imgui.TextColored(RED, table.concat(notes, ', '));
            if imgui.IsItemHovered() then
                imgui.SetTooltip('tie: same number as someone else - whoever rolled first is placed first.\nre-rolled: rolled again; only the first roll counts.');
            end
        end
    end
    if #list > 0 then imgui.Separator(); end

    local bw = math.floor((math.min(W, 420) - 3 * 6) / 4);
    if imgui.Button('Next##omni_rt_next', { bw, 0 }) then next_turn(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('The NM is done - move to the next person.'); end
    imgui.SameLine(0, 6);
    if imgui.Button('Post /p##omni_rt_post', { bw, 0 }) then post(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Post the order to party chat.'); end
    imgui.SameLine(0, 6);
    if imgui.Button((st.locked and 'Unlock' or 'Lock') .. '##omni_rt_lock', { bw, 0 }) then st.locked = not st.locked; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Lock: stop taking new rolls (late /random is ignored).'); end
    imgui.SameLine(0, 6);
    if imgui.Button('New##omni_rt_new', { bw, 0 }) then new_round(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Start a new round - clears the list.'); end
    imgui.TextColored(DIM, '/rolls next  -  /rolls post  -  /rolls new  -  /rolls lock');

    imgui.Separator();
    local cv = { st.corp };
    if imgui.Checkbox('Say my Corsair rolls in party (roll, lucky / unlucky)##omni_rt_cor', cv) then st.corp = cv[1]; save(); end
    if imgui.IsItemHovered() then imgui.SetTooltip('Every roll and Double-Up you do goes to /p:\n  Chaos Roll: rolled 3 - Lucky 4 / Unlucky 8 (Attack)\n  Chaos Roll Double-Up: rolled 1, total 4 LUCKY! - ...\n/rolls cor on|off'); end
end

return rolls;
