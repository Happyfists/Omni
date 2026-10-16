--[[
    omni_th.lua - Treasure Hunter helper.

    Watches the action packets (0x028) your party and alliance send. When someone's hit
    raises Treasure Hunter on a monster ("Additional effect: Treasure Hunter effectiveness
    against <mob> increases to N", message 603) it:
      * remembers the level for that monster (shown in the TH tab and on omni's target bar),
      * can announce it in party chat: "Happyfists lands TH5 on Ogre Beetle".
    Defeated monsters (0x029 message 6 / 20) move to a short history with their final TH.

    Idea from easyTH by Arielfy; omni's own code.
]]

local imgui = require('imgui');
local action = require('omni_action');

local th = {};
th.height = 300;

local mobs = {};        -- server id -> { name, level, by, at, first }
local history = {};     -- newest first: { name, level, by, at }
local MAX_HISTORY = 12;

----------------------------------------------------------------------------------------------------
-- Party / alliance
----------------------------------------------------------------------------------------------------
local roster, roster_at = {}, -10;
local thf = {};         -- server id -> true for party members who are THF main or sub
local function party_names()
    if os.clock() - roster_at < 2 then return roster; end
    roster_at, roster, thf = os.clock(), {}, {};
    pcall(function ()
        local p = AshitaCore:GetMemoryManager():GetParty();
        for i = 0, 17 do
            if p:GetMemberIsActive(i) == 1 then
                local id = p:GetMemberServerId(i);
                if id and id ~= 0 then
                    roster[id] = p:GetMemberName(i);
                    if p:GetMemberMainJob(i) == 6 or p:GetMemberSubJob(i) == 6 then thf[id] = true; end
                end
            end
        end
    end);
    return roster;
end

local function my_id()
    local id = 0;
    pcall(function () id = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0); end);
    return id;
end

-- Anyone else in your party? (Checks the active flag, and the name / id too, in case the
-- client reports the flag differently.)
local function in_party()
    local n = 0;
    pcall(function ()
        local p = AshitaCore:GetMemoryManager():GetParty();
        for i = 1, 5 do
            local active = p:GetMemberIsActive(i);
            local name = p:GetMemberName(i);
            local id = p:GetMemberServerId(i);
            if active == 1 or active == true or (name ~= nil and name ~= '' and id ~= nil and id ~= 0) then n = n + 1; end
        end
    end);
    return n > 0;
end

local function mob_name(id)
    if type(id) ~= 'number' then return nil; end
    local name = nil;
    pcall(function ()
        local em = AshitaCore:GetMemoryManager():GetEntity();
        local function try(i)
            if em:GetServerId(i) == id then
                local n = em:GetName(i);
                if n and n ~= '' then name = n; return true; end
            end
            return false;
        end
        -- Monsters' server ids carry their target index in the low 12 bits; else look through them all.
        if try(id % 0x1000) then return; end
        for i = 0, 2303 do if try(i) then return; end end
    end);
    if name == nil then
        -- Last try: your own target, if it is that monster.
        pcall(function ()
            local t = AshitaCore:GetMemoryManager():GetTarget();
            local idx = t:GetTargetIndex(0);
            local em = AshitaCore:GetMemoryManager():GetEntity();
            if em:GetServerId(idx) == id then name = em:GetName(idx); end
        end);
    end
    if name == '' then name = nil; end
    return name;
end

----------------------------------------------------------------------------------------------------
-- Settings (kept in omni's settings table, passed in by omni)
----------------------------------------------------------------------------------------------------
th.settings = {};
local function S() return th.settings or {}; end
-- announce: 'anyone' (default), 'mine' (only your own procs) or 'off'.
local function announce_mode() return S().th_announce or 'anyone'; end

local function announce(line)
    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/p ' .. line); end);
end

local function my_name()
    local n = nil;
    pcall(function () n = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
    return n;
end

----------------------------------------------------------------------------------------------------
-- A monster's TH went up: remember it, tell the party (once per level).
----------------------------------------------------------------------------------------------------
local pending = {};
local function raise(id, name, lvl, who, actor_id)
    local m = mobs[id];
    if m == nil then
        m = { name = name or 'Monster', level = 0, first = os.time() };
        mobs[id] = m;
    end
    if name and (m.name == nil or m.name == 'Monster') then m.name = name; end
    if lvl <= (m.level or 0) then return; end
    who = who or m.last_hit or 'someone';
    m.level, m.by, m.at = lvl, who, os.time();
    -- Said a moment later, so the game's own chat line can fill in the name if it was missing.
    pending[#pending + 1] = { id = id, lvl = lvl, who = who, actor_id = actor_id, due = os.clock() + 0.4 };
end

local function say(p)
    local m = mobs[p.id];
    local name = (m and m.name) or 'Monster';
    if name == 'Monster' then name = mob_name(p.id) or 'the monster'; end
    local line = string.format('%s lands TH%d on %s', p.who, p.lvl, name);
    -- Party chat by default. (Party detection is not trusted to say "solo" any more: under VanaCore
    -- it reported no party while in one, so the line always goes to /p unless announcing is Off.)
    local mode = announce_mode();
    local mine = (p.actor_id ~= nil and p.actor_id == my_id()) or (p.who ~= nil and p.who == my_name());
    if mode == 'anyone' or (mode == 'mine' and mine) then
        announce(line);
    else
        print('\30\81[omni]\30\01 ' .. line);
    end
end

ashita.events.register('d3d_present', 'omni_th_say', function ()
    if #pending == 0 then return; end
    local now = os.clock();
    local i = 1;
    while i <= #pending do
        if now >= pending[i].due then
            local p = table.remove(pending, i);
            pcall(say, p);
        else
            i = i + 1;
        end
    end
end);

----------------------------------------------------------------------------------------------------
-- Packets
----------------------------------------------------------------------------------------------------
local function on_action(data)
    local act = action.parse(data);
    local names = party_names();
    local who = names[act.actor_id];
    if who == nil then return; end                       -- not someone in your party / alliance
    for _, t in ipairs(act.targets) do
        for _, a in ipairs(t.actions) do
            -- 603: "Additional effect: Treasure Hunter effectiveness ... increases to N" (melee / ranged)
            if a.add and a.add.message == 603 then
                raise(t.id, mob_name(t.id), a.add.param or 0, who, act.actor_id);
            end
            -- 608: "<user> uses <ability>. Treasure Hunter effectiveness ... increases to N."
            if a.message == 608 then
                raise(t.id, mob_name(t.id), a.param or 0, who, act.actor_id);
            end
        end
        -- First hit from the party: start tracking the monster even before any proc.
        if act.category == 1 or act.category == 3 then
            if mobs[t.id] == nil then
                mobs[t.id] = { name = mob_name(t.id) or 'Monster', level = 0, first = os.time() };
            end
            -- A thief (main or sub) has hit it: the base Treasure Hunter from their gear/trait is on.
            if thf[act.actor_id] then mobs[t.id].base = true; end
        end
        -- Who last hit it (so the chat back-up can name them).
        if mobs[t.id] then mobs[t.id].last_hit = who; end
    end
end

local function on_message(data)
    if #data < 0x1C then return; end
    local function u32(o) local a, b, c, d = data:byte(o + 1, o + 4); return a + b * 256 + c * 65536 + d * 16777216; end
    local function u16(o) local a, b = data:byte(o + 1, o + 2); return a + b * 256; end
    local target = u32(0x08);
    local msg = u16(0x18) % 0x8000;
    if (msg == 6 or msg == 20) and mobs[target] then
        local m = mobs[target];
        if (m.level or 0) > 0 then
            table.insert(history, 1, { name = m.name, level = m.level, by = m.by, at = os.time() });
            while #history > MAX_HISTORY do table.remove(history); end
        end
        mobs[target] = nil;
    end
end

-- Back-up: the game's own chat line, in case the packet reading missed it.
local function on_text(msg)
    if type(msg) ~= 'string' then return; end
    local t = msg:gsub('[\30\31].', '');
    local name, lvl = t:match('Treasure Hunter effectiveness against (.-) increases to (%d+)');
    if name == nil then return; end
    name = name:gsub('^[Tt]he ', '');
    lvl = tonumber(lvl);
    -- Find that monster among the ones being fought (by name).
    for id, m in pairs(mobs) do
        if m.name == name then raise(id, name, lvl, nil, nil); return; end
    end
    -- A monster we could not name yet, raised to this level just now: that's the one.
    for id, m in pairs(mobs) do
        if m.name == 'Monster' and (m.level or 0) == lvl then m.name = name; return; end
    end
    raise('name:' .. name, name, lvl, nil, nil);
end

ashita.events.register('text_in', 'omni_th_text', function (e)
    pcall(on_text, e.message);
end);

ashita.events.register('packet_in', 'omni_th_in', function (e)
    if e.id == 0x028 then
        pcall(on_action, e.data);
    elseif e.id == 0x029 then
        pcall(on_message, e.data);
    elseif e.id == 0x00A then
        mobs = {};          -- zoned: monsters are gone
    end
end);

-- TH on a monster (by server id), or nil if none recorded.
th.level_for = function (server_id)
    local m = mobs[server_id];
    if m and (m.level or 0) > 0 then return m.level; end
    return nil;
end

-- Short label for the target bar, like easyTH: 'TH3' once it has procced, 'TH Base' when a
-- thief has hit it, 'TH -' when the party is fighting it without a thief; nil if not fought.
th.label_for = function (server_id)
    local m = mobs[server_id];
    if m == nil then return nil; end
    if (m.level or 0) > 0 then return 'TH' .. m.level, true; end
    if m.base then return 'TH Base', false; end
    return 'TH -', false;
end

----------------------------------------------------------------------------------------------------
-- The tab
----------------------------------------------------------------------------------------------------
local C = {
    gold = { 0.90, 0.78, 0.40, 1.0 }, text = { 0.92, 0.92, 0.95, 1.0 }, dim = { 0.62, 0.66, 0.80, 1.0 },
    faint = { 0.42, 0.44, 0.52, 1.0 }, green = { 0.45, 0.88, 0.45, 1.0 }, panel = { 0.07, 0.08, 0.13, 0.70 },
};

local function ago(t)
    local s = os.time() - (t or os.time());
    if s < 60 then return s .. 's ago'; end
    if s < 3600 then return math.floor(s / 60) .. 'm ago'; end
    return math.floor(s / 3600) .. 'h ago';
end

local function u32(c) return imgui.GetColorU32(c); end

-- A small On / Off pill, like Happy Healer's switch. Returns true when clicked.
local function switch(id, on, h)
    local x, y = imgui.GetCursorScreenPos();
    local w = h * 2;
    local clicked = imgui.InvisibleButton(id, { w, h });
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(on and { 0.24, 0.62, 0.30, 1.0 } or { 0.22, 0.23, 0.32, 1.0 }), h / 2);
    local cx = on and (x + w - h / 2) or (x + h / 2);
    dl:AddCircleFilled({ cx, y + h / 2 }, h / 2 - 2, u32({ 0.95, 0.95, 0.97, 1.0 }), 16);
    return clicked;
end

-- A little TH badge: gold-edged box, green once it is TH2 or more.
local function badge(level, base)
    local txt = (level and level > 0) and ('TH' .. level) or (base and 'Base' or 'TH -');
    local tw, th_ = imgui.CalcTextSize(txt);
    local x, y = imgui.GetCursorScreenPos();
    local w, h = tw + 12, (th_ or 14) + 2;
    local good = (level or 0) >= 2;
    local dl = imgui.GetWindowDrawList();
    dl:AddRectFilled({ x, y }, { x + w, y + h }, u32(good and { 0.12, 0.30, 0.16, 0.95 } or { 0.12, 0.13, 0.20, 0.95 }), 3);
    dl:AddRect({ x, y }, { x + w, y + h }, u32(good and { 0.45, 0.88, 0.45, 0.70 } or { 0.90, 0.78, 0.40, 0.35 }), 3);
    dl:AddText({ x + 6, y + 1 }, u32(good and C.green or C.dim), txt);
    imgui.Dummy({ w, h });
    return w;
end

-- One row: monster name, TH badge, who raised it and when (right).
local function mob_row(W, name, level, by, at, base, faded)
    local x0 = imgui.GetCursorPosX();
    local y = imgui.GetCursorPosY();
    local right = by and (by .. '  ' .. ago(at)) or '';
    local rw = imgui.CalcTextSize(right);
    local col = W - rw - 58;                          -- where the badge sits
    -- Trim long names so nothing overlaps.
    local nm = name or 'Monster';
    while #nm > 3 and imgui.CalcTextSize(nm) > col - 10 do nm = nm:sub(1, -2); end
    if nm ~= name then nm = nm:sub(1, -3) .. '..'; end
    imgui.TextColored(faded and C.dim or C.text, nm);
    imgui.SetCursorPos({ x0 + col, y - 1 });
    badge(level, base);
    imgui.SetCursorPos({ x0 + W - rw, y });
    imgui.TextColored(C.faint, right);
end

local function heading(text, W, right)
    local x0 = imgui.GetCursorPosX();
    imgui.TextColored(C.gold, text);
    if right then imgui.SameLine(x0 + W - imgui.CalcTextSize(right)); imgui.TextColored(C.faint, right); end
    local x, y = imgui.GetCursorScreenPos();
    imgui.GetWindowDrawList():AddLine({ x, y - 2 }, { x + W, y - 2 }, u32({ 0.90, 0.78, 0.40, 0.25 }), 1);
    imgui.Dummy({ 1, 1 });
end

th.render = function (opts)
    th.settings = opts.settings or th.settings;
    local s = S();
    local W = math.floor(imgui.GetContentRegionAvail());
    local _, lh = imgui.CalcTextSize('Ag'); lh = math.floor(lh or 14);

    -- Your target, one line.
    local tname, tlevel, tby, tat, tbase = nil, nil, nil, nil, nil;
    pcall(function ()
        local t = AshitaCore:GetMemoryManager():GetTarget();
        local e = GetEntity(t:GetTargetIndex(0));
        if e and e.Name and e.Name ~= '' then
            tname = e.Name;
            local m = mobs[e.ServerId];
            if m then tlevel, tby, tat, tbase = m.level, m.by, m.at, m.base; end
        end
    end);
    heading('Target', W);
    if tname then
        mob_row(W, tname, tlevel, tby, tat, tbase, false);
    else
        imgui.TextColored(C.faint, 'No target.');
    end
    imgui.Dummy({ 1, 3 });

    -- Monsters being fought (most TH first), then recently defeated.
    local list = {};
    for _, m in pairs(mobs) do list[#list + 1] = m; end
    table.sort(list, function (a, b) return (a.level or 0) > (b.level or 0); end);
    heading('Fighting', W, tostring(#list));
    for i, m in ipairs(list) do if i <= 6 then mob_row(W, m.name, m.level, m.by, m.at, m.base, false); end end
    if #list == 0 then imgui.TextColored(C.faint, 'Nothing yet.'); end
    imgui.Dummy({ 1, 3 });
    heading('Defeated', W, 'final TH');
    for i, h in ipairs(history) do if i <= 5 then mob_row(W, h.name, h.level, h.by, h.at, nil, true); end end
    if #history == 0 then imgui.TextColored(C.faint, 'None yet.'); end
    imgui.Dummy({ 1, 5 });

    -- Announce to party: one switch (on by default), plus "only mine" when it is on.
    local mode = announce_mode();
    local on = mode ~= 'off';
    local sh = lh;
    local ax = imgui.GetCursorPosX();
    if switch('##th_ann_sw', on, sh) then
        if on then s.th_announce_was = mode; s.th_announce = 'off';
        else s.th_announce = s.th_announce_was or 'anyone'; end
        if opts.save then pcall(opts.save); end
    end
    imgui.SameLine(0, 8);
    imgui.TextColored(on and C.text or C.dim, 'Announce to party (/p)');
    if on then
        imgui.SameLine(0, 16);
        local mine = mode == 'mine';
        if switch('##th_mine_sw', mine, sh) then
            s.th_announce = mine and 'anyone' or 'mine';
            if opts.save then pcall(opts.save); end
        end
        imgui.SameLine(0, 8);
        imgui.TextColored(mine and C.text or C.dim, 'Only mine');
    end
    -- Clear, on the right.
    local cw = imgui.CalcTextSize('Clear') + 8;
    imgui.SameLine(ax + W - cw);
    if imgui.SmallButton('Clear##th_clear') then mobs, history = {}, {}; end
    if imgui.IsItemHovered() then imgui.SetTooltip('Clear both lists'); end

    th.height = imgui.GetCursorPosY() + 8;
end

return th;
