--[[
    omni_sparks.lua - the "Sparks" tab: search the Sparks of Eminence shop, then buy one item,
    a set amount, or as many as you can afford / carry.

    The buying works the same way as the 'Sparks' addon (Brax, Sammeh, Towbes, Winter Solstice):
    it talks to the sparks NPC you are standing next to, picks the item in the shop menu for you
    (the menu never opens on screen), buys one every couple of seconds, then closes the menu.
    The shop list (plugins/data/sparks_map.lua) comes from that addon too.
]]

local imgui = require('imgui');

local sparks = {};
local sell = require('omni_sell');
sparks.sell = sell;
sparks.height = 300;

-- The sparks NPC in each town and the shop menu they open.
local NPCS = {
    [230] = { npc = 'Rolandienne',    menu = 995,  town = "Southern San d'Oria" },
    [235] = { npc = 'Isakoth',        menu = 26,   town = 'Bastok Markets' },
    [241] = { npc = 'Fhelm Jobeizat', menu = 850,  town = 'Windurst Woods' },
    [256] = { npc = 'Eternal Flame',  menu = 5081, town = 'Western Adoulin' },
};

local BUY_GAP = 1.6;        -- seconds between purchases
local GOLD  = { 0.79, 0.69, 0.42, 1.0 };
local GREEN = { 0.45, 0.90, 0.45, 1.0 };
local RED   = { 1.00, 0.45, 0.45, 1.0 };
local YELLOW = { 1.00, 0.85, 0.35, 1.0 };

----------------------------------------------------------------------------------------------------
-- Shop list
----------------------------------------------------------------------------------------------------
local ITEMS = {};
do
    local ok, map = pcall(require, 'plugins/data/sparks_map');
    if (ok and type(map) == 'table') then
        for id, v in pairs(map) do
            -- Escha temporary items and key items use a different shop; leave them out.
            if (v.TempItem == nil and v.Cost ~= nil and v.Cost > 0) then
                ITEMS[#ITEMS + 1] = { id = id, name = v.Name, cost = v.Cost, option = v.Option, index = v.Index };
            end
        end
        table.sort(ITEMS, function (a, b) return a.name:lower() < b.name:lower(); end);
    end
end

----------------------------------------------------------------------------------------------------
-- State
----------------------------------------------------------------------------------------------------
local search = { '' };
local amount = { 1 };
local selected = nil;       -- entry from ITEMS
local balance = nil;        -- sparks, from the currency packet
local asked_at = -100;

local job = nil;            -- the purchase in progress
local balance_at = 0;       -- when the sparks balance last came in
local last_failed = false;  -- the last purchase ended with an error
local loop_tick;            -- the Acheron loop's step (further down)
local status_text, status_col = nil, nil;

local function say(text, col)
    status_text, status_col = text, col or GOLD;
    print('\30\110[omni sparks] ' .. text);
end

local function free_slots()
    local inv = AshitaCore:GetMemoryManager():GetInventory();
    local max = inv:GetContainerCountMax(0) or 0;
    local used = 0;
    for i = 1, max do
        local item = inv:GetContainerItem(0, i);
        if (item ~= nil and item.Id ~= 0 and item.Id ~= 65535) then
            used = used + 1;
        end
    end
    return max - used;
end

-- The sparks NPC near you, or nil and the reason why not.
local function find_npc()
    local zone = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0);
    local where = NPCS[zone];
    if (where == nil) then
        return nil, 'You are not in a town with a sparks NPC.';
    end
    for i = 0, 2303 do
        local e = GetEntity(i);
        if (e ~= nil and e.WarpPointer ~= 0 and e.Name == where.npc) then
            if (math.sqrt(e.Distance or 0) > 6) then
                return nil, string.format('Stand next to %s first (you are %.1f away).', where.npc, math.sqrt(e.Distance or 0));
            end
            return { id = e.ServerId, index = e.TargetIndex, zone = zone, menu = where.menu, name = where.npc };
        end
    end
    return nil, string.format('%s is not in range.', where.npc);
end

local function menu_packet(option, index, auto)
    return struct.pack('bbbbihhhbbhh', 0x05B, 0x05, 0x00, 0x00, job.npc.id, option, index, job.npc.index, auto, 0, job.npc.zone, job.npc.menu):totable();
end

local function finish(text, col)
    if (job ~= nil and job.in_menu) then
        pcall(function ()
            local pm = AshitaCore:GetPacketManager();
            pm:AddOutgoingPacket(0x05B, menu_packet(0, 16384, 0));
            pm:AddOutgoingPacket(0x016, struct.pack('bbbbhh', 0x016, 0x02, 0x00, 0x00, GetPlayerEntity().TargetIndex, 0):totable());
        end);
    end
    job = nil;
    last_failed = (col == RED);
    say(text, col);
    asked_at = -100;    -- refresh the sparks balance
end

local function start(item, count)
    if (job ~= nil) then
        say('Already buying - wait for it to finish or press Stop.', RED);
        return;
    end
    if (count < 1) then
        say('Nothing to buy.', RED);
        return;
    end
    local npc, why = find_npc();
    if (npc == nil) then
        say(why, RED);
        return;
    end
    job = { item = item, total = count, left = count, npc = npc, in_menu = false, next_at = 0, started = os.clock() };
    say(string.format('Buying %d x %s from %s...', count, item.name, npc.name), YELLOW);
    -- Talk to the NPC; the shop menu reply is caught in on_packet.
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x01A,
        struct.pack('bbbbihhhhfff', 0x01A, 0x07, 0, 0, npc.id, npc.index, 0, 0, 0, 0, 0, 0):totable());
end

----------------------------------------------------------------------------------------------------
-- Packets (called from omni.lua). Returns true if the packet should be hidden from the game.
----------------------------------------------------------------------------------------------------
sparks.on_packet = function (e)
    if (e.id == 0x113) then
        balance = struct.unpack('I', e.data, 0x74 + 1);
        balance_at = os.clock();
        return false;
    end
    if (e.id == 0x110) then
        balance = struct.unpack('I', e.data, 0x04 + 1);
        balance_at = os.clock();
        return false;
    end
    if ((e.id == 0x032 or e.id == 0x034) and job ~= nil and not job.in_menu) then
        job.in_menu = true;
        job.next_at = os.clock() + 0.5;
        return true;    -- keep the shop menu off screen; omni picks the item itself
    end
    return false;
end

-- Called every frame: sends the next purchase when it is due.
sparks.tick = function ()
    pcall(loop_tick);
    if (job == nil) then
        return;
    end
    if (not job.in_menu) then
        if (os.clock() - job.started > 8) then
            finish('The NPC did not answer. Nothing was bought.', RED);
        end
        return;
    end
    if (os.clock() < job.next_at) then
        return;
    end
    if (job.left <= 0) then
        finish(string.format('Done - bought %d x %s.', job.total, job.item.name), GREEN);
        return;
    end
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x05B, menu_packet(job.item.option, job.item.index, 1));
    job.left = job.left - 1;
    job.next_at = os.clock() + BUY_GAP + math.random() * 0.5;
end

----------------------------------------------------------------------------------------------------
-- Acheron Shield loop: buy as many as you can carry or afford, /sellit them, again, until the
-- sparks run out. One click; Stop ends it after the current step.
----------------------------------------------------------------------------------------------------
local ACHERON = nil;
for _, it in ipairs(ITEMS) do if (it.name == 'Acheron Shield') then ACHERON = it; end end

local loop = nil;   -- { phase = 'check' | 'buying' | 'selling', wait_until, asked, rounds, sold }

local function held_acheron()
    local n = 0;
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for i = 1, (inv:GetContainerCountMax(0) or 80) do
            local it = inv:GetContainerItem(0, i);
            if (it ~= nil and ACHERON ~= nil and it.Id == ACHERON.id) then n = n + (it.Count or 1); end
        end
    end);
    return n;
end

local function loop_end(text, col)
    loop = nil;
    say(text, col);
end

local function ask_balance()
    pcall(function () AshitaCore:GetPacketManager():AddOutgoingPacket(0x10F, { 0x00, 0x00, 0x00, 0x00 }); end);
end

loop_tick = function ()
    if (loop == nil or os.clock() < (loop.wait_until or 0)) then return; end
    if (loop.phase == 'check') then
        -- Fresh sparks balance first.
        if (balance_at < loop.asked) then
            if (os.clock() - loop.asked > 6) then return loop_end('Could not read your sparks - stopped.', RED); end
            loop.wait_until = os.clock() + 0.3;
            return;
        end
        local slots = 0;
        pcall(function () slots = free_slots(); end);
        local afford = math.floor((balance or 0) / ACHERON.cost);
        if (afford < 1) then
            if (held_acheron() > 0) then
                loop.phase = 'selling'; loop.last = true; loop.sell_started = false;
                return;
            end
            return loop_end(string.format('Done - out of sparks after %d round%s (%d sold).', loop.rounds, loop.rounds == 1 and '' or 's', loop.sold), GREEN);
        end
        if (slots < 1) then
            if (held_acheron() > 0) then
                loop.phase = 'selling'; loop.sell_started = false;
                return;
            end
            return loop_end('Your bag is full of other things - make some room and try again.', RED);
        end
        loop.rounds = loop.rounds + 1;
        loop.before = held_acheron();
        loop.phase = 'buying';
        start(ACHERON, math.min(afford, slots));
        if (job == nil) then return loop_end('Could not start buying - stopped.', RED); end
    elseif (loop.phase == 'buying') then
        if (job ~= nil) then return; end
        if (last_failed) then return loop_end('Buying stopped - see the message above.', RED); end
        local got = held_acheron() - (loop.before or 0);
        if (got <= 0) then
            -- Bought nothing: maybe the shop said no. Sell what's there, then stop.
            loop.last = true;
        end
        loop.phase = 'selling';
        loop.wait_until = os.clock() + 1.5;   -- let the last shield land in the bag
        loop.sell_started = false;
    elseif (loop.phase == 'selling') then
        if (not loop.sell_started) then
            loop.sell_started = true;
            loop.sell_count = held_acheron();
            if (loop.sell_count > 0) then sell.sell_names({ 'Acheron Shield' }, 'Acheron Shields'); end
            loop.wait_until = os.clock() + 0.5;
            return;
        end
        if (sell.busy()) then return; end
        loop.sold = loop.sold + math.max(0, (loop.sell_count or 0) - held_acheron());
        if (loop.last) then
            return loop_end(string.format('Done - sold %d Acheron Shield%s in %d round%s.', loop.sold, loop.sold == 1 and '' or 's', loop.rounds, loop.rounds == 1 and '' or 's'), GREEN);
        end
        loop.phase = 'check';
        loop.sell_started = false;
        loop.asked = os.clock();
        ask_balance();
        loop.wait_until = os.clock() + 0.5;
    end
end

local function loop_start()
    if (ACHERON == nil) then return say('Acheron Shield is not in the sparks list.', RED); end
    if (job ~= nil or loop ~= nil or sell.busy()) then return say('Busy - wait for the current buy or sell to finish.', RED); end
    local npc, why = find_npc();
    if (npc == nil) then return say(why, RED); end
    loop = { phase = 'check', asked = os.clock(), rounds = 0, sold = 0, sell_started = false };
    ask_balance();
    say('Acheron Shields: buying and selling until your sparks run out...', YELLOW);
end

----------------------------------------------------------------------------------------------------
-- Drawing
----------------------------------------------------------------------------------------------------
local function commas(n)
    local s = tostring(math.floor(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse();
    return (s:gsub('^,', ''));
end

sparks.render = function (host)
    local ui = host.ui;

    -- Ask the game for the sparks balance now and then while the tab is open.
    if (os.clock() - asked_at > 20 and job == nil) then
        asked_at = os.clock();
        pcall(function () AshitaCore:GetPacketManager():AddOutgoingPacket(0x10F, { 0x00, 0x00, 0x00, 0x00 }); end);
    end

    -- Disclaimer.
    imgui.PushTextWrapPos(0);
    imgui.TextColored(YELLOW, 'You must be standing next to a sparks NPC: Rolandienne (Southern San d\'Oria), Isakoth (Bastok Markets), Fhelm Jobeizat (Windurst Woods) or Eternal Flame (Western Adoulin). Do not move or open menus while it is buying.');
    imgui.PopTextWrapPos();
    imgui.Spacing();

    local slots = 0;
    pcall(function () slots = free_slots(); end);
    imgui.TextColored(ui.color('dimmed'), 'Sparks:');
    imgui.SameLine(0, 6);
    imgui.TextColored(ui.color('white'), balance and commas(balance) or '...');
    imgui.SameLine(0, 24);
    imgui.TextColored(ui.color('dimmed'), 'Free inventory slots:');
    imgui.SameLine(0, 6);
    imgui.TextColored((slots > 0) and ui.color('white') or RED, tostring(slots));

    -- One click: Acheron Shields bought and sold until the sparks run out.
    if (ACHERON ~= nil) then
        imgui.Spacing();
        if (loop == nil) then
            imgui.PushStyleColor(ImGuiCol_Button, { 0.80, 0.62, 0.22, 1.0 });
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.88, 0.70, 0.28, 1.0 });
            imgui.PushStyleColor(ImGuiCol_Text, { 0.10, 0.08, 0.03, 1.0 });
            if (imgui.Button('Acheron Shield: buy + sell till out of sparks##sparks_acheron')) then loop_start(); end
            imgui.PopStyleColor(3);
            if (imgui.IsItemHovered()) then
                imgui.SetTooltip(string.format('%s sparks each. Buys as many as you can carry or afford,\n/sellit acheron shield, then again until your sparks run out.', commas(ACHERON.cost)));
            end
        else
            local step = (loop.phase == 'buying') and 'buying' or ((loop.phase == 'selling') and 'selling' or 'checking sparks');
            imgui.TextColored(YELLOW, string.format('Acheron round %d: %s  (%d sold so far)', loop.rounds, step, loop.sold));
            imgui.SameLine(0, 12);
            if (imgui.SmallButton('Stop##sparks_acheron_stop')) then
                if (job ~= nil) then finish('Stopped.', YELLOW); end
                loop_end(string.format('Stopped - sold %d Acheron Shield%s.', loop.sold, loop.sold == 1 and '' or 's'), YELLOW);
            end
        end
    end

    -- Search.
    imgui.Spacing();
    imgui.TextColored(ui.color('dimmed'), 'Search:');
    imgui.SameLine(0, 6);
    imgui.PushItemWidth(260);
    imgui.InputText('##sparks_search', search, 64);
    imgui.PopItemWidth();

    local q = tostring(search[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    local matches, shown_max = {}, 12;
    if (q ~= '') then
        for _, item in ipairs(ITEMS) do
            if (item.name:lower():find(q, 1, true)) then
                matches[#matches + 1] = item;
            end
        end
    end

    -- Results: click one to pick it.
    if (q == '') then
        imgui.TextColored(ui.color('dimmed'), 'Type part of an item name, e.g. "scale".');
    elseif (#matches == 0) then
        imgui.TextColored(RED, 'No sparks item matches that.');
    else
        local ww = imgui.GetWindowWidth();
        for i = 1, math.min(#matches, shown_max) do
            local item = matches[i];
            local y = imgui.GetCursorPosY();
            if (imgui.Selectable('##sparks_pick_' .. item.id, selected == item, 0, { 0, 22 })) then
                selected = item;
                amount[1] = 1;
            end
            imgui.SetCursorPos({ 8, y });
            if (not host.renderIcon(item.id, 20)) then imgui.Dummy({ 20, 20 }); end
            imgui.SetCursorPos({ 36, y + 2 });
            imgui.TextColored(ui.color('white'), item.name);
            local cost = commas(item.cost) .. ' sparks';
            imgui.SetCursorPos({ ww - imgui.CalcTextSize(cost) - 16, y + 2 });
            imgui.TextColored(GOLD, cost);
            imgui.SetCursorPos({ 0, y + 24 });
        end
        if (#matches > shown_max) then
            imgui.TextColored(ui.color('dimmed'), string.format('...and %d more - type more of the name.', #matches - shown_max));
        end
    end

    -- The picked item: amount, Buy, Buy all.
    if (selected ~= nil) then
        imgui.Spacing();
        imgui.Separator();
        imgui.Spacing();
        if (not host.renderIcon(selected.id, 24)) then imgui.Dummy({ 24, 24 }); end
        imgui.SameLine(0, 8);
        imgui.TextColored(GOLD, string.format('%s  (%s sparks each)', selected.name, commas(selected.cost)));

        local afford = balance and math.floor(balance / selected.cost) or 0;
        local most = math.min(afford, slots);

        imgui.TextColored(ui.color('dimmed'), 'Amount:');
        imgui.SameLine(0, 6);
        imgui.PushItemWidth(110);
        imgui.InputInt('##sparks_amount', amount);
        imgui.PopItemWidth();
        amount[1] = math.max(1, math.min(999, math.floor(tonumber(amount[1]) or 1)));
        imgui.SameLine(0, 10);
        if (imgui.Button(string.format('Buy %d##sparks_buy', amount[1]))) then
            start(selected, amount[1]);
        end
        imgui.SameLine(0, 10);
        if (imgui.Button(string.format('Buy all (%d)##sparks_buyall', most))) then
            start(selected, most);
        end

        local cost_all = amount[1] * selected.cost;
        local col = (balance == nil or cost_all <= balance) and ui.color('dimmed') or RED;
        imgui.TextColored(col, string.format('%d will cost %s sparks.', amount[1], commas(cost_all)));
        if (amount[1] > slots) then
            imgui.TextColored(RED, string.format('You only have %d free inventory slots (items that do not stack need one each).', slots));
        end
        imgui.TextColored(ui.color('dimmed'), string.format('Buy all = as many as you can afford (%d) and carry (%d free slots).', afford, slots));
    end

    -- Progress / last result.
    imgui.Spacing();
    if (job ~= nil) then
        local done = job.total - job.left;
        imgui.TextColored(YELLOW, string.format('Buying %s: %d / %d', job.item.name, done, job.total));
        imgui.SameLine(0, 12);
        if (imgui.SmallButton('Stop##sparks_stop')) then
            finish(string.format('Stopped - bought %d x %s.', done, job.item.name), YELLOW);
        end
    elseif (status_text ~= nil) then
        imgui.PushTextWrapPos(0);
        imgui.TextColored(status_col, status_text);
        imgui.PopTextWrapPos();
    end

    -- Sell It box and the saved sell list (omni_sell.lua).
    pcall(sell.render, host);

    sparks.height = imgui.GetCursorPosY() + 8;
end

return sparks;
