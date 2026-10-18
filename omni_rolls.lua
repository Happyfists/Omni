--[[
    omni_rolls.lua - Roll Tracker (Options > Roll Tracker): keeps the /random order for NM pops.

    Everyone types /random. Each roll is read from chat and the list sorts itself, highest first.
    Only a person's FIRST roll counts (re-rolls are shown but ignored). Ties are flagged; whoever
    rolled first goes first. After each pop, press "Next" and the arrow moves on.
    Saved to config\addons\omni\rollorder.txt, so it survives a reload or a crash.

    Commands: /rolls new | next | post | lock   (/rolls on its own says whose turn it is)
]]

local imgui = require('imgui');

local rolls = {};

local st = { locked = false, turn = 1, rolls = {}, title = '' };

local function base() return string.format('%s\\config\\addons\\', AshitaCore:GetInstallPath()); end
local function path() return base() .. 'omni\\rollorder.txt'; end

local function save()
    pcall(function ()
        local f = io.open(path(), 'w');
        if f == nil then return; end
        f:write('turn ', st.turn, '\n');
        f:write('locked ', st.locked and 1 or 0, '\n');
        f:write('title ', st.title, '\n');
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
local function on_text(e)
    if st.locked then return; end
    local m = (e.message_modified or e.message or ''):gsub('[\30\31].', ''):gsub('\x7F.', '');
    local name, value = m:match('^%s*Dice roll!%s*(%a+) rolls (%d+)');
    if name == nil then name, value = m:match('^%s*(%a+) rolls (%d+)[!.]?%s*$'); end
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

ashita.events.register('command', 'omni_rolls_cmd', function (e)
    local a = e.command:args();
    if #a == 0 or a[1]:lower() ~= '/rolls' then return; end
    e.blocked = true;
    local c = (a[2] or ''):lower();
    if c == 'new' or c == 'clear' then new_round();
    elseif c == 'next' then next_turn();
    elseif c == 'post' then post();
    elseif c == 'lock' then st.locked = not st.locked; save(); msg(st.locked and 'locked.' or 'taking rolls.');
    elseif c == '' then say_turn();
    else msg('/rolls  |  /rolls new  |  /rolls next  |  /rolls post  |  /rolls lock   (window: omni Options > Roll Tracker)'); end
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
end

return rolls;
