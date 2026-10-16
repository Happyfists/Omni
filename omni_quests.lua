--[[
    omni_quests.lua - the Quests tab.

    Three pages:
      * Journey   - what you are doing right now: every quest in progress, the mission you are
                    on in each storyline, and how far through each region / storyline you are.
      * Quests    - pick a region on the left, search and filter on the right; click a quest to
                    open its card (where, who, what you need, reward, walkthrough).
      * Missions  - pick a storyline on the left; its missions run top to bottom with the one
                    you are on opened up.

    Progress comes from the quest / mission log the server sends when you zone (packet 0x056).
    It is saved per character, so the tab is filled in straight after a reload.

    Quest and mission data (qdata/) and the storyline pictures (images/covers/) are from
    FFXI Journal by AndreYMods (MIT, see JOURNAL_LICENSE), which credits Lexia (Mission,
    XiQlog), Jintawk (Chronicle) and BG-Wiki. The tracker and screens here are omni's own.
]]

local imgui = require('imgui');

local qs = {};
qs.height = 600;

----------------------------------------------------------------------------------------------------
-- Data
----------------------------------------------------------------------------------------------------
local QUESTS, MISSIONS = {}, {};
local data_error = nil;
do
    local ok, q = pcall(require, 'qdata.quests');
    if ok then QUESTS = q.QUESTS or {}; else data_error = tostring(q); end
    local ok2, m = pcall(require, 'qdata.missions');
    if ok2 then MISSIONS = m.MISSIONS or {}; else data_error = data_error or tostring(m); end
end

local REGIONS = {
    { key = 'sandoria',    name = "San d'Oria" },
    { key = 'bastok',      name = 'Bastok' },
    { key = 'windurst',    name = 'Windurst' },
    { key = 'jeuno',       name = 'Jeuno' },
    { key = 'outlands',    name = 'Outlands' },
    { key = 'other',       name = 'Other Areas' },
    { key = 'whitegate',   name = 'Aht Urhgan' },
    { key = 'crystal_war', name = 'Crystal War' },
};

local STORIES = {
    { key = 'sandoria', name = "San d'Oria",              cover = 'Sandorian_Iconv2.png' },
    { key = 'bastok',   name = 'Bastok',                  cover = 'Bastok_Iconv2.png' },
    { key = 'windurst', name = 'Windurst',                cover = 'Windurst_Iconv2.png' },
    { key = 'zilart',   name = 'Rise of the Zilart',      cover = 'Zilart_Icon.png' },
    { key = 'cop',      name = 'Chains of Promathia',     cover = 'Chainsofpromathia_Icon.png' },
    { key = 'toau',     name = 'Treasures of Aht Urhgan', cover = 'AhtUrghan_Icon.png' },
    { key = 'wotg',     name = 'Wings of the Goddess',    cover = 'Wingsofthegoddess_Icon.png' },
    { key = 'acp',      name = 'Crystalline Prophecy',    cover = 'CrystallineProphecy_Icon.png' },
    { key = 'mkd',      name = "Moogle Kupo d'Etat",      cover = 'Mooglekupodetat_Icon.png' },
    { key = 'asa',      name = 'Shantotto Ascension',     cover = 'ShantottoAscension_Icon.png' },
    { key = 'assault',  name = 'Assault',                 cover = 'Assault_Icon.png' },
    { key = 'campaign', name = 'Campaign',                cover = 'Campaign_Iconv2.png' },
    { key = 'abyssea',  name = 'Abyssea',                 cover = 'Abyssea_Icon.png' },
    { key = 'adoulin',  name = 'Seekers of Adoulin',      cover = 'Seekersofadoulin_Icon.png' },
    { key = 'rov',      name = 'Rhapsodies of Vana\'diel', cover = 'Rhapsodies_Icon.png' },
    { key = 'tvr',      name = 'The Voracious Resurgence', cover = 'VoraciousResurgence_Icon.png' },
};

----------------------------------------------------------------------------------------------------
-- The log, as the server sent it (saved per character)
----------------------------------------------------------------------------------------------------
-- quest.cur[area] / quest.done[area] : { [id] = true }
-- mis.done[area] : { [id] = true }   mis.cur[area] : number or { [id] = true }   mis.f : extra fields
local log = { quest = { cur = {}, done = {} }, mis = { cur = {}, done = {}, f = {} } };
local log_owner, log_seen, log_at = nil, false, nil;
local dirty_at = nil;
local revision = 0;

local function my_name()
    local n = nil;
    pcall(function () n = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
    if n == nil or n == '' then return nil; end
    return n;
end

local function save_path(name)
    local dir = string.format('%s\\config\\addons\\omni\\', AshitaCore:GetInstallPath());
    for _, fn in ipairs({ 'create_dir', 'create_directory' }) do
        if ashita and ashita.fs and ashita.fs[fn] then pcall(ashita.fs[fn], dir); end
    end
    return dir .. 'quests_' .. name .. '.lua';
end

local function ser(v, out)
    local t = type(v);
    if t == 'number' then out[#out + 1] = tostring(v);
    elseif t == 'boolean' then out[#out + 1] = v and 'true' or 'false';
    elseif t == 'string' then out[#out + 1] = string.format('%q', v);
    elseif t == 'table' then
        out[#out + 1] = '{';
        for k, x in pairs(v) do
            out[#out + 1] = (type(k) == 'number') and ('[' .. k .. ']=') or ('[' .. string.format('%q', k) .. ']=');
            ser(x, out);
            out[#out + 1] = ',';
        end
        out[#out + 1] = '}';
    else out[#out + 1] = 'nil'; end
end

local function save_log()
    local name = my_name();
    if name == nil then return; end
    pcall(function ()
        local out = { 'return ' };
        ser({ log = log, at = log_at }, out);
        local f = io.open(save_path(name), 'w');
        if f then f:write(table.concat(out)); f:close(); end
    end);
end

local function load_log()
    local name = my_name();
    if name == nil or name == log_owner then return; end
    log_owner, log_seen, log_at = name, false, nil;
    log = { quest = { cur = {}, done = {} }, mis = { cur = {}, done = {}, f = {} } };
    pcall(function ()
        local fn = loadfile(save_path(name));
        if fn == nil then return; end
        local t = fn();
        if type(t) == 'table' and type(t.log) == 'table' then
            log = t.log;
            log.quest = log.quest or { cur = {}, done = {} };
            log.mis = log.mis or { cur = {}, done = {}, f = {} };
            log.mis.f = log.mis.f or {};
            log_at = t.at;
        end
    end);
    revision = revision + 1;
end

----------------------------------------------------------------------------------------------------
-- Reading packet 0x056
----------------------------------------------------------------------------------------------------
local function u32(d, o)
    local a, b, c, e = d:byte(o + 1, o + 4);
    if not e then return nil; end
    return a + b * 0x100 + c * 0x10000 + e * 0x1000000;
end
local function i32(d, o)
    local v = u32(d, o);
    if v and v >= 0x80000000 then v = v - 0x100000000; end
    return v;
end
local function bits(d, o, n)
    local set = {};
    for i = 0, n * 8 - 1 do
        local byte = d:byte(o + math.floor(i / 8) + 1);
        if byte and math.floor(byte / 2 ^ (i % 8)) % 2 == 1 then set[i] = true; end
    end
    return set;
end

-- Which list each block of the log fills.
local BLOCKS = {
    [0x50] = { 'quest', 'cur', 'sandoria' },  [0x90] = { 'quest', 'done', 'sandoria' },
    [0x58] = { 'quest', 'cur', 'bastok' },    [0x98] = { 'quest', 'done', 'bastok' },
    [0x60] = { 'quest', 'cur', 'windurst' },  [0xA0] = { 'quest', 'done', 'windurst' },
    [0x68] = { 'quest', 'cur', 'jeuno' },     [0xA8] = { 'quest', 'done', 'jeuno' },
    [0x70] = { 'quest', 'cur', 'other' },     [0xB0] = { 'quest', 'done', 'other' },
    [0x78] = { 'quest', 'cur', 'outlands' },  [0xB8] = { 'quest', 'done', 'outlands' },
    [0x88] = { 'quest', 'cur', 'wotg' },      [0xC8] = { 'quest', 'done', 'wotg' },
    [0xE0] = { 'quest', 'cur', 'abyssea' },   [0xE8] = { 'quest', 'done', 'abyssea' },
    [0xF0] = { 'quest', 'cur', 'adoulin' },   [0xF8] = { 'quest', 'done', 'adoulin' },
    [0x100] = { 'quest', 'cur', 'coalition' }, [0x108] = { 'quest', 'done', 'coalition' },
    [0x110] = { 'quest', 'cur', 'acp' },      [0x118] = { 'quest', 'done', 'acp' },
    [0x120] = { 'quest', 'cur', 'mkd' },      [0x128] = { 'quest', 'done', 'mkd' },
    [0x130] = { 'quest', 'cur', 'asa' },      [0x138] = { 'quest', 'done', 'asa' },
    [0x30] = { 'mis', 'done', 'campaign' },   [0x38] = { 'mis', 'done', 'campaign_2' },
};

local function on_log(d)
    local kind = u32(d, 0x24);
    if kind == nil then return; end
    local q, m = log.quest, log.mis;
    local b = BLOCKS[kind];
    if b then
        log[b[1]][b[2]][b[3]] = bits(d, 0x04, 32);
    elseif kind == 0x80 then
        q.cur.toau = bits(d, 0x04, 16);
        m.cur.assault, m.cur.toau, m.cur.wotg, m.cur.campaign = i32(d, 0x14), i32(d, 0x18), i32(d, 0x1C), i32(d, 0x20);
    elseif kind == 0xC0 then
        q.done.toau = bits(d, 0x04, 16);
        m.done.assault = bits(d, 0x14, 16);
    elseif kind == 0xD0 then
        m.done.sandoria, m.done.bastok = bits(d, 0x04, 8), bits(d, 0x0C, 8);
        m.done.windurst, m.done.zilart = bits(d, 0x14, 8), bits(d, 0x1C, 8);
    elseif kind == 0xD8 then
        m.done.toau, m.done.wotg = bits(d, 0x04, 8), bits(d, 0x0C, 8);
    elseif kind == 0xFFFE then
        m.cur.tvr = i32(d, 0x04);
    elseif kind == 0xFFFF then
        m.f.nation = i32(d, 0x04);
        m.f.nation_cur = i32(d, 0x08);
        m.cur.zilart, m.cur.cop = i32(d, 0x0C), i32(d, 0x10);
        local b1, b2 = d:byte(0x18 + 1), d:byte(0x19 + 1);
        if b1 then m.cur.acp, m.cur.mkd = b1 % 16, math.floor(b1 / 16); end
        if b2 then m.cur.asa = b2 % 16; end
        m.cur.adoulin, m.cur.rov = i32(d, 0x1C), i32(d, 0x20);
    else
        return;
    end
    log_seen = true;
    log_at = os.time();
    revision = revision + 1;
    dirty_at = os.clock() + 2;   -- save once the burst of log packets has finished
end

ashita.events.register('packet_in', 'omni_quests_log', function (e)
    if e.id == 0x056 and e.data ~= nil and #e.data >= 40 then
        load_log();
        pcall(on_log, e.data);
    end
end);

ashita.events.register('d3d_present', 'omni_quests_save', function ()
    if dirty_at ~= nil and os.clock() >= dirty_at then
        dirty_at = nil;
        save_log();
    end
end);

----------------------------------------------------------------------------------------------------
-- Status of a quest / mission: 'done', 'active', 'todo', 'untracked' (quests) or 'hidden' (missions)
----------------------------------------------------------------------------------------------------
local function quest_status(q)
    if q.trackable == false or q.tracker_area == nil or q.tracker_id == nil then return 'untracked'; end
    local id = tonumber(q.tracker_id);
    if id == nil then return 'untracked'; end
    local done = log.quest.done[q.tracker_area];
    local cur = log.quest.cur[q.tracker_area];
    if done and done[id] then return 'done'; end
    if cur and cur[id] then return 'active'; end
    return 'todo';
end

-- Storylines where the server only says which mission you are on (everything before it is done).
local LINEAR = { cop = true, adoulin = true, rov = true, acp = true, mkd = true, asa = true, tvr = true, assault = true };

-- Missions the log counts but that are not real steps (branches you never see).
local HIDE = {
    sandoria = { [6] = 1, [7] = 1, [8] = 1, [9] = 1 },
    bastok   = { [6] = 1, [7] = 1, [8] = 1, [9] = 1 },
    windurst = { [6] = 1, [7] = 1, [8] = 1, [9] = 1 },
    zilart   = { [2] = 1 },
    cop      = { [101] = 1, [137] = 1, [257] = 1, [330] = 1, [331] = 1, [335] = 1, [339] = 1, [340] = 1, [341] = 1,
                 [345] = 1, [349] = 1, [367] = 1, [447] = 1, [540] = 1, [542] = 1, [543] = 1, [546] = 1, [549] = 1,
                 [550] = 1, [552] = 1, [553] = 1, [556] = 1, [559] = 1, [560] = 1, [562] = 1, [564] = 1, [568] = 1,
                 [577] = 1, [647] = 1, [758] = 1 },
    wotg     = { [53] = 1 },
    adoulin  = { [999] = 1 },
};
-- The last mission of these storylines stays "current" once the story is finished.
local FINAL = { cop = 850, acp = 11, mkd = 14, asa = 14, adoulin = 368, rov = 334, tvr = 642, toau = 47 };

local sorted_ids = {};
local function ids_of(area)
    if sorted_ids[area] then return sorted_ids[area]; end
    local t = {};
    for id in pairs(MISSIONS[area] or {}) do if tonumber(id) then t[#t + 1] = tonumber(id); end end
    table.sort(t);
    sorted_ids[area] = t;
    return t;
end

local function mission_status(area, id)
    if HIDE[area] and HIDE[area][id] then return 'hidden'; end
    local m = log.mis;
    local done_set = (area == 'abyssea') and (log.quest.done.abyssea or {}) or (m.done[area] or {});
    local is_done, is_cur = done_set[id] == true, false;

    if LINEAR[area] then
        local v = tonumber(m.cur[area]);
        if v ~= nil then
            local none = v < 0;
            if none then v = v + 2147483648; end
            local active = nil;
            local ids = ids_of(area);
            for i = #ids, 1, -1 do if ids[i] <= v and v > 0 then active = ids[i]; break; end end
            if active then
                if id < active then is_done = true; end
                if id == active and not none then is_cur = true; end
            end
        end
    elseif area == 'campaign' then
        if id >= 256 then return (m.done.campaign_2 or {})[id - 256] and 'done' or 'todo'; end
        return (m.done.campaign or {})[id] and 'done' or 'todo';
    elseif area == 'abyssea' then
        is_cur = (log.quest.cur.abyssea or {})[id] == true;
    else
        local cur = m.cur[area];
        if type(cur) == 'number' then is_cur = cur == id;
        elseif type(cur) == 'table' then is_cur = cur[id] == true; end
        local nations = { [0] = 'sandoria', [1] = 'bastok', [2] = 'windurst' };
        if nations[m.f.nation] == area and m.f.nation_cur == id then is_cur = true; end
    end

    -- Special cases.
    if FINAL[area] == id and (is_done or is_cur) then return 'done'; end
    if (area == 'sandoria' or area == 'bastok' or area == 'windurst') and id == 5 then
        for s = 6, 9 do if done_set[s] then return 'done'; end end
    end
    if area == 'zilart' and id == 31 and not is_done and tonumber(m.cur.cop or 0) >= 850 then return 'done'; end

    if is_done then return 'done'; end
    if is_cur then return 'active'; end
    return 'todo';
end

----------------------------------------------------------------------------------------------------
-- Cached views (rebuilt when the log changes)
----------------------------------------------------------------------------------------------------
local cache_rev = -1;
local region_view, story_view = {}, {};

local function rebuild()
    if cache_rev == revision then return; end
    cache_rev = revision;
    region_view, story_view = {}, {};
    for _, r in ipairs(REGIONS) do
        local list, done, total, active = {}, 0, 0, 0;
        for _, q in ipairs(QUESTS[r.key] or {}) do
            local st = quest_status(q);
            list[#list + 1] = { q = q, st = st };
            if st ~= 'untracked' then total = total + 1; end
            if st == 'done' then done = done + 1; end
            if st == 'active' then active = active + 1; end
        end
        region_view[r.key] = { list = list, done = done, total = total, active = active };
    end
    for _, s in ipairs(STORIES) do
        local list, done, cur = {}, 0, nil;
        for _, id in ipairs(ids_of(s.key)) do
            local st = mission_status(s.key, id);
            if st ~= 'hidden' then
                local m = MISSIONS[s.key][id];
                list[#list + 1] = { id = id, name = m.name or ('Mission ' .. id), steps = m.steps, st = st };
                if st == 'done' then done = done + 1; end
                if st == 'active' then cur = #list; end
            end
        end
        -- Nothing marked current? The first mission not yet done is the next one.
        local next_i = cur;
        if next_i == nil then
            for i, e in ipairs(list) do if e.st ~= 'done' then next_i = i; break; end end
        end
        story_view[s.key] = { list = list, done = done, total = #list, cur = cur, next_i = next_i };
    end
end

----------------------------------------------------------------------------------------------------
-- Drawing helpers
----------------------------------------------------------------------------------------------------
local C = {
    gold   = { 0.90, 0.78, 0.40, 1.0 },
    green  = { 0.45, 0.85, 0.50, 1.0 },
    amber  = { 1.00, 0.72, 0.30, 1.0 },
    text   = { 0.92, 0.92, 0.95, 1.0 },
    dim    = { 0.60, 0.63, 0.74, 1.0 },
    faint  = { 0.42, 0.44, 0.52, 1.0 },
    red    = { 1.00, 0.45, 0.45, 1.0 },
    panel  = { 0.07, 0.08, 0.13, 0.70 },
    card   = { 0.11, 0.12, 0.19, 0.95 },
};

local STATUS = {
    done      = { 'Done',    C.green },
    active    = { 'Active',  C.amber },
    todo      = { 'To do',   C.faint },
    untracked = { 'No log',  C.faint },
};

local fileImage = nil;   -- set from omni (trove host image loader)

local function u32c(c) return imgui.GetColorU32(c); end
local function pct(a, b) if b == 0 then return 0; end return a / b; end

-- A rounded progress bar at the cursor.
local function bar(frac, w, h, col)
    frac = math.max(0, math.min(1, frac or 0));
    local x, y = imgui.GetCursorScreenPos();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32c({ 1, 1, 1, 0.07 }), h / 2);
    if frac > 0 then
        dl:AddRectFilled({ x, y }, { x + math.max(h, w * frac), y + h }, u32c(col or C.gold), h / 2);
    end
    imgui.Dummy({ w, h });
end

-- Cut text to fit a width, ending in "...".
local function fit(text, width)
    text = tostring(text or '');
    if width <= 0 then return ''; end
    if imgui.CalcTextSize(text) <= width then return text; end
    local n = #text;
    while n > 1 and imgui.CalcTextSize(text:sub(1, n) .. '...') > width do n = n - 1; end
    return text:sub(1, n) .. '...';
end

-- Text placed so it ends at x_right.
local function text_right(col, text, x_right)
    imgui.SameLine(x_right - imgui.CalcTextSize(text));
    imgui.TextColored(col, text);
end

-- A small coloured pill with a word in it (status tags).
local PILL_W = 52;
local function pill(text, col)
    if not qs.pill_measured then
        qs.pill_measured = true;
        local m = 0;
        for _, t in pairs(STATUS) do m = math.max(m, imgui.CalcTextSize(t[1])); end
        PILL_W = math.floor(m + 14);
    end
    local x, y = imgui.GetCursorScreenPos();
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y + 1 }, { x + PILL_W, y + 16 }, u32c({ col[1], col[2], col[3], 0.16 }), 7);
    local tw = imgui.CalcTextSize(text);
    imgui.SetCursorScreenPos({ x + math.floor((PILL_W - tw) / 2), y });
    imgui.TextColored(col, text);
end

-- Every other row gets a faint stripe; the chosen row a gold wash.
local function row_bg(i, h, width, on)
    local x, y = imgui.GetCursorScreenPos();
    local dl = imgui.GetWindowDrawList();
    if on then
        dl:AddRectFilled({ x, y }, { x + width, y + h }, u32c({ 0.90, 0.78, 0.40, 0.14 }), 4);
        dl:AddRectFilled({ x, y }, { x + 3, y + h }, u32c(C.gold), 2);
    elseif i % 2 == 0 then
        dl:AddRectFilled({ x, y }, { x + width, y + h }, u32c({ 1, 1, 1, 0.03 }), 4);
    end
end

-- A framed panel with a title line (and an optional count on the right).
local function card_begin(id, w, h, title, right)
    imgui.PushStyleColor(ImGuiCol_ChildBg, C.panel);
    imgui.PushStyleColor(ImGuiCol_Border, { 0.90, 0.78, 0.40, 0.22 });
    imgui.PushStyleVar(ImGuiStyleVar_ChildRounding, 6);
    imgui.BeginChild(id, { w, h }, true, ImGuiWindowFlags_NoScrollbar);
    -- Inner width, measured (the theme's padding decides it), less room for a scroll bar.
    local inner = math.floor(imgui.GetContentRegionAvail());
    local x0 = imgui.GetCursorPosX();
    -- The title comes first; the note on the right gets what is left.
    local tw = math.min(imgui.CalcTextSize(title), right and math.floor(inner * 0.6) or inner);
    imgui.TextColored(C.gold, fit(title, tw));
    if right then
        local r = fit(right, inner - tw - 16);
        if r ~= '' then text_right(C.dim, r, x0 + inner); end
    end
    local x, y = imgui.GetCursorScreenPos();
    imgui.GetWindowDrawList():AddLine({ x, y }, { x + inner, y }, u32c({ 0.90, 0.78, 0.40, 0.25 }), 1);
    imgui.Dummy({ 1, 4 });
    return inner;
end

-- The scrolling area inside a card: fills the rest of it, rows sized to fit inside.
local function list_begin(id)
    imgui.BeginChild(id, { 0, 0 }, false);
    return math.floor(imgui.GetContentRegionAvail()) - 12;
end
local function card_end()
    imgui.EndChild();
    imgui.PopStyleVar(1);
    imgui.PopStyleColor(2);
end

local function wrap_text(col, text)
    imgui.PushTextWrapPos(0);
    imgui.TextColored(col, text);
    imgui.PopTextWrapPos();
end

local function blank(s) return s == nil or s == '' or s == 'None' or s == '-'; end

local function field(label, value, x)
    if blank(value) then return; end
    local x0 = imgui.GetCursorPosX();
    imgui.TextColored(C.dim, label);
    imgui.SameLine(x0 + (x or 72));
    wrap_text(C.text, tostring(value));
end

local function real_steps(steps)
    if type(steps) ~= 'table' or #steps == 0 then return nil; end
    if #steps == 1 and tostring(steps[1]):find('not added', 1, true) then return nil; end
    return steps;
end

-- Names in the walkthroughs sometimes end in a full stop, leaving "..": tidy those.
local function tidy(s)
    s = tostring(s);
    s = s:gsub('([^%.])%.%.(%s)', '%1.%2'):gsub('([^%.])%.%.$', '%1.'):gsub('%)%. (%l)', ') %1');
    return s;
end

-- Numbered steps with a thin gold rule down the left.
local function steps_block(steps)
    steps = real_steps(steps);
    local x, y0 = imgui.GetCursorScreenPos();
    imgui.Dummy({ 1, 2 });
    if steps == nil then
        imgui.TextColored(C.faint, 'No walkthrough for this one yet.');
    else
        for i, s in ipairs(steps) do
            imgui.TextColored(C.gold, string.format('%d.', i));
            imgui.SameLine(imgui.GetCursorPosX() + 22);
            wrap_text(C.text, tidy(s));
        end
    end
    local _, y1 = imgui.GetCursorScreenPos();
    imgui.GetWindowDrawList():AddLine({ x - 10, y0 + 2 }, { x - 10, y1 - 2 }, u32c({ 0.90, 0.78, 0.40, 0.45 }), 2);
    imgui.Dummy({ 1, 6 });
end

local function quest_card(q, st)
    imgui.Indent(30);
    local x, y0 = imgui.GetCursorScreenPos();
    imgui.Dummy({ 1, 2 });
    field('Where', q.loc or q.zone);
    field('Start', q.npc);
    field('Needs', q.req);
    field('First do', q.prereq);
    field('Bring', q.items);
    field('Reward', q.reward);
    if st == 'untracked' then
        imgui.TextColored(C.faint, 'The game log does not record this quest, so its progress cannot be shown.');
    end
    imgui.Dummy({ 1, 2 });
    imgui.TextColored(C.gold, 'Walkthrough');
    local _, y1 = imgui.GetCursorScreenPos();
    imgui.GetWindowDrawList():AddLine({ x - 10, y0 + 2 }, { x - 10, y1 - 2 }, u32c({ 0.90, 0.78, 0.40, 0.45 }), 2);
    imgui.Indent(10);
    steps_block(q.steps);
    imgui.Unindent(10);
    imgui.Unindent(30);
end

-- One list row: arrow, number, status pill, name, and a dim note on the right.
local ROW_H = 22;
local function row(i, id, open, st, name, note, width, here)
    local x0, y0 = imgui.GetCursorPos();
    row_bg(i, ROW_H, width, here);
    local clicked = imgui.Selectable('##' .. id, false, 0, { width, ROW_H });
    local hovered = imgui.IsItemHovered();
    local ty = y0 + 3;
    imgui.SetCursorPos({ x0 + 8, ty });
    imgui.TextColored(open and C.gold or C.faint, open and 'v' or '>');
    imgui.SetCursorPos({ x0 + 24, ty });
    local tag = STATUS[st] or STATUS.todo;
    pill(tag[1], tag[2]);
    local nx = x0 + 24 + PILL_W + 10;
    local noteW = (note and note ~= '') and math.min(imgui.CalcTextSize(note), math.floor(width * 0.32)) or 0;
    imgui.SetCursorPos({ nx, ty });
    local col = (st == 'done') and C.dim or ((hovered or here) and C.gold or C.text);
    imgui.TextColored(col, fit(name, width - (nx - x0) - noteW - 20));
    if noteW > 0 then
        imgui.SetCursorPos({ x0 + width - noteW - 8, ty });
        imgui.TextColored(here and C.amber or C.faint, fit(note, noteW));
    end
    imgui.SetCursorPos({ x0, y0 + ROW_H });
    return clicked;
end

----------------------------------------------------------------------------------------------------
-- Page state
----------------------------------------------------------------------------------------------------
local page = 1;              -- 1 Journey, 2 Quests, 3 Missions
local region = 'sandoria';
local story = nil;
local search = { '' };
local filter = 'all';        -- all / active / todo / done
local open_quest = {};       -- quest id -> open
local open_mission = {};     -- area:id -> open

local function go_quest(key, id)
    page, region, filter = 2, key, 'all';
    if id then open_quest[tostring(id)] = true; end
end
local function go_story(key)
    page, story = 3, key;
end

local function story_of(key)
    for _, s in ipairs(STORIES) do if s.key == key then return s; end end
end

----------------------------------------------------------------------------------------------------
-- Page 1: Journey
----------------------------------------------------------------------------------------------------
-- A row with a picture (or dot), a name, and dim text on the right.
local function journey_row(i, id, w, pic, dotcol, name, right)
    local x0, y0 = imgui.GetCursorPos();
    row_bg(i, ROW_H, w, false);
    local clicked = imgui.Selectable('##' .. id, false, 0, { w, ROW_H });
    local hovered = imgui.IsItemHovered();
    imgui.SetCursorPos({ x0 + 6, y0 + 2 });
    if pic and fileImage and fileImage('covers/' .. pic, 18, 18) then
    else
        local sx, sy = imgui.GetCursorScreenPos();
        imgui.GetWindowDrawList():AddCircleFilled({ sx + 9, sy + 9 }, 4, u32c(dotcol or C.gold));
        imgui.Dummy({ 18, 18 });
    end
    local rw = math.min(imgui.CalcTextSize(right or ''), math.floor(w * 0.38));
    imgui.SetCursorPos({ x0 + 32, y0 + 3 });
    imgui.TextColored(hovered and C.gold or C.text, fit(name, w - 32 - rw - 22));
    if right then
        imgui.SetCursorPos({ x0 + w - rw - 8, y0 + 3 });
        imgui.TextColored(C.faint, fit(right, rw));
    end
    imgui.SetCursorPos({ x0, y0 + ROW_H });
    return clicked;
end

-- Width of the longest of some names, plus a gap (never more than half the row).
local function label_w(names, row_w)
    local m = 0;
    for _, n in ipairs(names) do m = math.max(m, imgui.CalcTextSize(n)); end
    return math.floor(math.min(m + 18, row_w / 2));
end

-- Name, bar and count on one line, for the progress cards.
local function progress_row(i, id, w, labelW, name, done, total, col)
    local x0, y0 = imgui.GetCursorPos();
    row_bg(i, 20, w, false);
    local clicked = imgui.Selectable('##' .. id, false, 0, { w, 20 });
    local hovered = imgui.IsItemHovered();
    local full = total > 0 and done >= total;
    imgui.SetCursorPos({ x0 + 6, y0 + 2 });
    imgui.TextColored(hovered and C.gold or (full and C.green or C.text), fit(name, labelW - 10));
    local countW = imgui.CalcTextSize('000 / 000') + 10;
    local pctW = imgui.CalcTextSize('100%') + 10;
    imgui.SetCursorPos({ x0 + labelW, y0 + 7 });
    bar(pct(done, total), math.max(20, w - labelW - countW - pctW - 8), 7, full and C.green or col);
    local p = string.format('%d%%', math.floor(pct(done, total) * 100 + 0.5));
    imgui.SetCursorPos({ x0 + w - countW - imgui.CalcTextSize(p) - 6, y0 + 2 });
    imgui.TextColored(C.faint, p);
    local c = string.format('%d / %d', done, total);
    imgui.SetCursorPos({ x0 + w - imgui.CalcTextSize(c) - 6, y0 + 2 });
    imgui.TextColored(C.dim, c);
    imgui.SetCursorPos({ x0, y0 + 20 });
    return clicked;
end

local function draw_journey(w)
    local half = math.floor((w - 12) / 2);

    -- Left: what you are doing now.
    local missions, quests = {}, {};
    for _, s in ipairs(STORIES) do
        local v = story_view[s.key];
        if v and v.done > 0 and v.done < v.total and v.next_i and v.list[v.next_i] then
            missions[#missions + 1] = { s = s, e = v.list[v.next_i] };
        end
    end
    for _, r in ipairs(REGIONS) do
        for _, it in ipairs(region_view[r.key].list) do
            if it.st == 'active' then quests[#quests + 1] = { r = r, q = it.q }; end
        end
    end

    card_begin('##qj_left', half, qs.body_h, 'In progress', string.format('%d missions  -  %d quests', #missions, #quests));
    local iw = list_begin('##qj_left_list');
    imgui.TextColored(C.amber, 'Missions');
    for i, m in ipairs(missions) do
        if journey_row(i, 'qjs_' .. m.s.key, iw, m.s.cover, nil, m.e.name, m.s.name) then go_story(m.s.key); end
    end
    if #missions == 0 then imgui.TextColored(C.faint, 'No storyline under way.'); end
    imgui.Dummy({ 1, 6 });
    imgui.TextColored(C.amber, 'Quests');
    for i, it in ipairs(quests) do
        if journey_row(i, 'qja_' .. tostring(it.q.id), iw, nil, C.amber, it.q.name or '?', it.r.name) then go_quest(it.r.key, it.q.id); end
    end
    if #quests == 0 then imgui.TextColored(C.faint, 'No quests in progress.'); end
    imgui.EndChild();
    card_end();

    imgui.SameLine(0, 12);

    -- Right: progress everywhere.
    imgui.BeginGroup();
    local tdone, ttotal = 0, 0;
    for _, r in ipairs(REGIONS) do tdone, ttotal = tdone + region_view[r.key].done, ttotal + region_view[r.key].total; end
    local qh = 44 + #REGIONS * 20;
    local qiw = card_begin('##qj_quests', half, qh, 'Quests', string.format('%d of %d done', tdone, ttotal));
    local rnames = {};
    for _, r in ipairs(REGIONS) do rnames[#rnames + 1] = r.name; end
    local rlw = label_w(rnames, qiw);
    for i, r in ipairs(REGIONS) do
        local v = region_view[r.key];
        if progress_row(i, 'qjr_' .. r.key, qiw, rlw, r.name, v.done, v.total, C.green) then go_quest(r.key); end
    end
    card_end();
    imgui.Dummy({ 1, 2 });
    local shown = {};
    local sdone = 0;
    for _, s in ipairs(STORIES) do
        local v = story_view[s.key];
        if v and v.total > 0 then
            shown[#shown + 1] = s;
            if v.done >= v.total then sdone = sdone + 1; end
        end
    end
    card_begin('##qj_stories', half, qs.body_h - qh - 6, 'Storylines', string.format('%d of %d finished', sdone, #shown));
    local siw = list_begin('##qj_stories_list');
    local snames = {};
    for _, s in ipairs(shown) do snames[#snames + 1] = s.name; end
    local slw = label_w(snames, siw);
    for i, s in ipairs(shown) do
        local v = story_view[s.key];
        if progress_row(i, 'qjm_' .. s.key, siw, slw, s.name, v.done, v.total, C.gold) then go_story(s.key); end
    end
    imgui.EndChild();
    card_end();
    imgui.EndGroup();
end

----------------------------------------------------------------------------------------------------
-- Page 2: Quests
----------------------------------------------------------------------------------------------------
local FILTERS = { { 'all', 'All' }, { 'active', 'Active' }, { 'todo', 'To do' }, { 'done', 'Done' } };

local function draw_quests(w)
    local leftW = 220;

    card_begin('##qq_left', leftW, qs.body_h, 'Regions');
    local iw = list_begin('##qq_left_list');
    for i, r in ipairs(REGIONS) do
        local v = region_view[r.key];
        local sel = region == r.key;
        local x0, y = imgui.GetCursorPos();
        row_bg(i, 40, iw, sel);
        if imgui.Selectable('##qqr_' .. r.key, false, 0, { iw, 40 }) then region = r.key; end
        local hovered = imgui.IsItemHovered();
        local t = nil;
        if v.active > 0 then
            t = v.active .. ' active';
            if imgui.CalcTextSize(r.name) + imgui.CalcTextSize(t) + 30 > iw then t = tostring(v.active); end
        end
        local tw = t and (imgui.CalcTextSize(t) + 12) or 0;
        imgui.SetCursorPos({ x0 + 10, y + 3 });
        imgui.TextColored((sel or hovered) and C.gold or C.text, fit(r.name, iw - 16 - tw));
        if t then
            imgui.SetCursorPos({ x0 + iw - imgui.CalcTextSize(t) - 6, y + 3 });
            imgui.TextColored(C.amber, t);
        end
        local c = string.format('%d/%d', v.done, v.total);
        local cw = imgui.CalcTextSize(c);
        imgui.SetCursorPos({ x0 + 10, y + 25 });
        bar(pct(v.done, v.total), math.max(20, iw - cw - 26), 6, C.green);
        imgui.SetCursorPos({ x0 + iw - cw - 6, y + 20 });
        imgui.TextColored(C.faint, c);
        imgui.SetCursorPos({ x0, y + 42 });
    end
    imgui.EndChild();
    card_end();

    imgui.SameLine(0, 10);
    local rw = w - leftW - 10;
    local v = region_view[region];
    local rname = '';
    for _, r in ipairs(REGIONS) do if r.key == region then rname = r.name; end end
    local iw2 = card_begin('##qq_right', rw, qs.body_h, rname .. ' quests', string.format('%d done  -  %d active  -  %d in all', v.done, v.active, #v.list));

    -- Search and filter bar.
    local fw = 0;
    for _, f in ipairs(FILTERS) do fw = fw + math.max(62, imgui.CalcTextSize(f[2]) + 22) + 4; end
    imgui.PushItemWidth(iw2 - fw - 4);
    if imgui.InputTextWithHint then
        imgui.InputTextWithHint('##qq_search', 'Search quests, NPCs, zones, rewards...', search, 64);
    else
        imgui.InputText('##qq_search', search, 64);
    end
    imgui.PopItemWidth();
    for _, f in ipairs(FILTERS) do
        imgui.SameLine(0, 4);
        local on = filter == f[1];
        imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
        imgui.PushStyleColor(ImGuiCol_Text, on and { 1, 0.96, 0.85, 1 } or C.dim);
        if imgui.Button(f[2] .. '##qqf', { math.max(62, imgui.CalcTextSize(f[2]) + 22), 0 }) then filter = f[1]; end
        imgui.PopStyleColor(2);
    end
    imgui.Dummy({ 1, 2 });

    local needle = search[1]:lower();
    local shown = 0;
    local lw = list_begin('##qq_list');
    for _, it in ipairs(v.list) do
        local q, st = it.q, it.st;
        local pass = (filter == 'all') or (filter == st) or (filter == 'todo' and st == 'untracked');
        if pass and needle ~= '' then
            local hay = ((q.name or '') .. ' ' .. (q.zone or '') .. ' ' .. (q.npc or '') .. ' ' .. (q.reward or '') .. ' ' .. (q.items or '')):lower();
            pass = hay:find(needle, 1, true) ~= nil;
        end
        if pass then
            shown = shown + 1;
            local id = tostring(q.id);
            if row(shown, 'qq_' .. id, open_quest[id] == true, st, q.name or '?', q.zone, lw, open_quest[id] == true) then
                open_quest[id] = not open_quest[id] or nil;
            end
            if open_quest[id] then quest_card(q, st); end
        end
    end
    if shown == 0 then imgui.TextColored(C.faint, 'No quests match.'); end
    imgui.EndChild();
    card_end();
end

----------------------------------------------------------------------------------------------------
-- Page 3: Missions
----------------------------------------------------------------------------------------------------
local function draw_missions(w)
    local leftW = 270;
    if story == nil then
        story = 'sandoria';
        local nat = ({ [0] = 'sandoria', [1] = 'bastok', [2] = 'windurst' })[log.mis.f.nation];
        if nat then story = nat; end
    end

    card_begin('##qm_left', leftW, qs.body_h, 'Storylines');
    local iw = list_begin('##qm_left_list');
    local i = 0;
    for _, s in ipairs(STORIES) do
        local v = story_view[s.key];
        if v and v.total > 0 then
            i = i + 1;
            local sel = story == s.key;
            local x0, y = imgui.GetCursorPos();
            row_bg(i, 36, iw, sel);
            if imgui.Selectable('##qms_' .. s.key, false, 0, { iw, 36 }) then story = s.key; end
            local hovered = imgui.IsItemHovered();
            imgui.SetCursorPos({ x0 + 6, y + 3 });
            if not (fileImage and fileImage('covers/' .. s.cover, 30, 30)) then imgui.Dummy({ 30, 30 }); end
            local full = v.done >= v.total;
            local c = string.format('%d/%d', v.done, v.total);
            local cw = imgui.CalcTextSize(c);
            imgui.SetCursorPos({ x0 + 44, y + 2 });
            imgui.TextColored((sel or hovered) and C.gold or (full and C.green or C.text), fit(s.name, iw - 44 - cw - 14));
            imgui.SetCursorPos({ x0 + iw - cw - 6, y + 2 });
            imgui.TextColored(full and C.green or C.faint, c);
            imgui.SetCursorPos({ x0 + 44, y + 22 });
            bar(pct(v.done, v.total), iw - 52, 5, full and C.green or C.gold);
            imgui.SetCursorPos({ x0, y + 38 });
        end
    end
    imgui.EndChild();
    card_end();

    imgui.SameLine(0, 10);
    local rw = w - leftW - 10;
    local s = story_of(story);
    local v = story_view[story];
    if s and v then
        local full = v.done >= v.total;
        local iw2 = card_begin('##qm_right', rw, qs.body_h, s.name, string.format('%d of %d done', v.done, v.total));
        -- Picture, then where you are.
        local x0, y0 = imgui.GetCursorPos();
        if not (fileImage and fileImage('covers/' .. s.cover, 52, 52)) then imgui.Dummy({ 52, 52 }); end
        local tx = x0 + 64;
        local cur = v.next_i and v.list[v.next_i];
        imgui.SetCursorPos({ tx, y0 + 2 });
        if full then
            imgui.TextColored(C.green, 'Storyline complete.');
        elseif cur then
            local lead = (v.done > 0) and 'You are on' or 'Starts with';
            imgui.TextColored(C.dim, lead);
            imgui.SameLine(0, 6);
            imgui.TextColored(C.amber, fit(cur.name, iw2 - 64 - imgui.CalcTextSize(lead) - 12));
        end
        imgui.SetCursorPos({ tx, y0 + 24 });
        bar(pct(v.done, v.total), iw2 - 64 - 50, 9, full and C.green or C.gold);
        imgui.SameLine(0, 8);
        imgui.SetCursorPosY(y0 + 20);
        imgui.TextColored(C.dim, string.format('%d%%', math.floor(pct(v.done, v.total) * 100 + 0.5)));
        imgui.SetCursorPos({ x0, y0 + 60 });

        local lw = list_begin('##qm_list');
        for n, e in ipairs(v.list) do
            local key = story .. ':' .. e.id;
            local is_next = (n == v.next_i) and not full;
            local open = open_mission[key];
            if open == nil then open = is_next; end
            local st = e.st;
            if is_next and st == 'todo' and v.done > 0 then st = 'active'; end
            if row(n, 'qm_' .. key, open, st, string.format('%d.  %s', n, e.name), is_next and 'you are here' or nil, lw, is_next) then
                open_mission[key] = not open;
            end
            if open then
                imgui.Indent(40);
                steps_block(e.steps);
                imgui.Unindent(40);
            end
        end
        imgui.EndChild();
        card_end();
    end
end

----------------------------------------------------------------------------------------------------
-- The tab
----------------------------------------------------------------------------------------------------
local PAGES = { 'Journey', 'Quests', 'Missions' };

qs.render = function (host_image)
    fileImage = host_image;
    load_log();
    rebuild();
    local w = math.floor(imgui.GetContentRegionAvail()) - 4;

    if data_error then
        imgui.TextColored(C.red, 'Quest data could not load: ' .. data_error);
        return;
    end

    -- Quiet gold selection colours and slim scroll bars for the whole tab.
    imgui.PushStyleColor(ImGuiCol_Header, { 0.90, 0.78, 0.40, 0.00 });
    imgui.PushStyleColor(ImGuiCol_HeaderHovered, { 0.90, 0.78, 0.40, 0.10 });
    imgui.PushStyleColor(ImGuiCol_HeaderActive, { 0.90, 0.78, 0.40, 0.20 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarBg, { 0, 0, 0, 0 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrab, { 0.90, 0.78, 0.40, 0.30 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabHovered, { 0.90, 0.78, 0.40, 0.50 });
    imgui.PushStyleColor(ImGuiCol_ScrollbarGrabActive, { 0.90, 0.78, 0.40, 0.70 });
    imgui.PushStyleVar(ImGuiStyleVar_ScrollbarSize, 7);

    -- Page buttons, then where the progress came from.
    for i, name in ipairs(PAGES) do
        if i > 1 then imgui.SameLine(0, 4); end
        local on = page == i;
        imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
        imgui.PushStyleColor(ImGuiCol_Text, on and { 1, 0.96, 0.85, 1 } or C.dim);
        if imgui.Button(name .. '##qpage', { 110, 24 }) then page = i; end
        imgui.PopStyleColor(2);
    end
    local status, scol;
    if log_seen then status, scol = 'Log up to date', C.green;
    elseif log_at then status, scol = 'Saved log from ' .. os.date('%d %b %H:%M', log_at) .. ' - zone to refresh', C.dim;
    else status, scol = 'Zone once so the server sends your quest log', C.amber; end
    imgui.SameLine(w - imgui.CalcTextSize(status));
    imgui.SetCursorPosY(imgui.GetCursorPosY() + 4);
    imgui.TextColored(scol, status);
    imgui.Dummy({ 1, 2 });

    qs.body_h = 580;
    if page == 1 then draw_journey(w);
    elseif page == 2 then draw_quests(w);
    else draw_missions(w); end

    imgui.PopStyleVar(1);
    imgui.PopStyleColor(7);
    qs.height = imgui.GetCursorPosY() + 8;
end

return qs;
