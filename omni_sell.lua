--[[
    omni_sell.lua - "Sell It" box in the Sparks tab.

    Sells items with the server's /sellit command (e.g. "/sellit water crystal" sells every water
    crystal in your inventory). The command does one item at a time, so omni runs it for each
    item in turn: it sends the command, waits until that item has gone from your inventory, then
    moves on to the next.

    Also keeps a saved "sell list": items you always sell. "Sell it now" sells everything on it.
]]

local imgui = require('imgui');
local settings = require('settings');

local sell = {};

local SELL_GAP = 1.0;      -- pause between one item finishing and the next starting
local ITEM_TIMEOUT = 20;   -- give up on an item that has not gone after this many seconds
local GOLD   = { 0.79, 0.69, 0.42, 1.0 };
local GREEN  = { 0.45, 0.90, 0.45, 1.0 };
local RED    = { 1.00, 0.45, 0.45, 1.0 };
local YELLOW = { 1.00, 0.85, 0.35, 1.0 };

local saved = settings.load(T{ list = T{} }, 'omni_sell');
settings.register('omni_sell', 'omni_sell_update', function (s)
    if (s ~= nil) then saved = s; end
end);
local function save() pcall(function () settings.save('omni_sell'); end); end

local filter = { '' };
local add_name = { '' };
local queue = nil;          -- { names = { ... }, pos, current, sent_at, next_at, sold }
local status_text, status_col = nil, nil;

local function say(text, col)
    status_text, status_col = text, col or GOLD;
    print('\30\110[omni sell] ' .. text);
end

-- Sellable stacks in your inventory: { id, index, count, name }.
local function inventory()
    local out = {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();
        for i = 1, (inv:GetContainerCountMax(0) or 80) do
            local item = inv:GetContainerItem(0, i);
            if (item ~= nil and item.Id ~= nil and item.Id > 0 and item.Id ~= 65535) then
                local r = res:GetItemById(item.Id);
                if (r ~= nil and r.Name ~= nil and bit.band(r.Flags or 0, 0x1000) == 0) then
                    out[#out + 1] = { id = item.Id, index = item.Index, count = item.Count or 1, name = r.Name[1] };
                end
            end
        end
    end);
    return out;
end

local function in_list(name)
    for _, n in ipairs(saved.list) do
        if (n:lower() == name:lower()) then return true; end
    end
    return false;
end

local function add_to_list(name)
    name = tostring(name or ''):gsub('^%s+', ''):gsub('%s+$', '');
    if (name ~= '' and not in_list(name)) then
        saved.list[#saved.list + 1] = name;
        save();
    end
end

-- How many of an item (by name) are in your inventory.
local function held(name)
    local n = 0;
    for _, item in ipairs(inventory()) do
        if (item.name:lower() == name:lower()) then n = n + item.count; end
    end
    return n;
end

local function start(names, label)
    local list = {};
    for _, n in ipairs(names) do list[#list + 1] = n; end
    if (#list == 0) then
        say('Nothing to sell.', RED);
        return;
    end
    queue = { names = list, pos = 0, current = nil, next_at = os.clock(), sold = 0 };
    say('Selling ' .. label .. '...', YELLOW);
end

-- Called every frame: one /sellit at a time, waiting for each item to go before the next.
sell.tick = function ()
    if (queue == nil or os.clock() < queue.next_at) then
        return;
    end
    if (queue.current ~= nil) then
        -- Waiting for the current item to leave the inventory.
        local left = held(queue.current);
        if (left > 0 and os.clock() - queue.sent_at < ITEM_TIMEOUT) then
            queue.next_at = os.clock() + 0.5;
            return;
        end
        if (left == 0) then
            queue.sold = queue.sold + 1;
        else
            say(string.format('%s did not sell (still %d in your inventory) - skipping it.', queue.current, left), RED);
        end
        queue.current = nil;
        queue.next_at = os.clock() + SELL_GAP;
        return;
    end
    -- Next item on the list that you actually have.
    while (queue.pos < #queue.names) do
        queue.pos = queue.pos + 1;
        local name = queue.names[queue.pos];
        if (held(name) > 0) then
            queue.current = name;
            queue.sent_at = os.clock();
            say(string.format('Selling %s (%d of %d)...', name, queue.pos, #queue.names), YELLOW);
            pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/sellit ' .. name:lower()); end);
            queue.next_at = os.clock() + 1.0;
            return;
        end
    end
    local n = queue.sold;
    queue = nil;
    say(string.format('Done - sold %d item%s.', n, n == 1 and '' or 's'), GREEN);
end

-- Used by the Sparks tab's Acheron button: sell these names now, and whether a sale is running.
sell.sell_names = function (names, label) start(names, label); end
sell.busy = function () return queue ~= nil; end

sell.render = function (host)
    local ui = host.ui;
    imgui.Spacing();
    if (not ui.sectionHeader('Sell It', nil, 'sparks:sell')) then
        return;
    end

    imgui.TextColored(ui.color('dimmed'), 'Uses /sellit for each item, one after another.');
    imgui.Spacing();

    -- Your sell list (folds away like the other headings).
    local count = #saved.list;
    if (ui.sectionHeader(string.format('My sell list (%d)', count), nil, 'sparks:selllist')) then
        local remove = nil;
        for i, name in ipairs(saved.list) do
            imgui.SetCursorPosX(12);
            imgui.TextColored(ui.color('white'), name);
            imgui.SameLine(0, 10);
            if (imgui.SmallButton('Remove##sell_rm_' .. i)) then remove = i; end
        end
        if (remove ~= nil) then
            table.remove(saved.list, remove);
            save();
        end
        if (count == 0) then
            imgui.SetCursorPosX(12);
            imgui.TextColored(ui.color('dimmed'), 'Empty - add items below or with "+ List" next to an inventory item.');
        end
        imgui.SetCursorPosX(12);
        imgui.PushItemWidth(220);
        imgui.InputText('##sell_add', add_name, 64);
        imgui.PopItemWidth();
        imgui.SameLine(0, 6);
        if (imgui.SmallButton('Add to list##sell_add_btn')) then
            add_to_list(add_name[1]);
            add_name[1] = '';
        end
    end

    if (imgui.Button('Sell it now##sell_list_btn')) then
        start(saved.list, 'your sell list');
    end
    imgui.SameLine(0, 10);
    if (queue ~= nil) then
        if (imgui.Button('Stop selling##sell_stop')) then
            local n = queue.sold;
            queue = nil;
            say(string.format('Stopped - sold %d item%s.', n, n == 1 and '' or 's'), YELLOW);
        end
    end

    -- Your inventory, filtered: sell one item now, or add it to the list.
    imgui.Spacing();
    imgui.TextColored(ui.color('dimmed'), 'Inventory search:');
    imgui.SameLine(0, 6);
    imgui.PushItemWidth(220);
    imgui.InputText('##sell_filter', filter, 64);
    imgui.PopItemWidth();

    local q = tostring(filter[1] or ''):lower():gsub('^%s+', ''):gsub('%s+$', '');
    if (q ~= '') then
        -- Group stacks by name so each item shows once with its total.
        local totals, order = {}, {};
        for _, item in ipairs(inventory()) do
            if (item.name:lower():find(q, 1, true)) then
                if (totals[item.name] == nil) then
                    totals[item.name] = { id = item.id, count = 0 };
                    order[#order + 1] = item.name;
                end
                totals[item.name].count = totals[item.name].count + item.count;
            end
        end
        if (#order == 0) then
            imgui.TextColored(RED, 'Nothing sellable in your inventory matches that.');
        end
        local ww = imgui.GetWindowWidth();
        for i = 1, math.min(#order, 12) do
            local name = order[i];
            local y = imgui.GetCursorPosY();
            imgui.SetCursorPos({ 8, y });
            if (not host.renderIcon(totals[name].id, 20)) then imgui.Dummy({ 20, 20 }); end
            imgui.SetCursorPos({ 36, y + 2 });
            imgui.TextColored(in_list(name) and GOLD or ui.color('white'), string.format('%s  x%d', name, totals[name].count));
            imgui.SetCursorPos({ ww - 150, y });
            if (imgui.SmallButton('Sell##sell_one_' .. i)) then
                start({ name }, name);
            end
            imgui.SameLine(0, 8);
            if (not in_list(name) and imgui.SmallButton('+ List##sell_add_' .. i)) then
                add_to_list(name);
            end
            imgui.SetCursorPos({ 0, y + 24 });
        end
    end

    if (status_text ~= nil) then
        imgui.PushTextWrapPos(0);
        imgui.TextColored(status_col, status_text);
        imgui.PopTextWrapPos();
    end
end

return sell;
