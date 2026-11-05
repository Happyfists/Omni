--[[
    omni_pouches.lua - Happy Pouches (Items > Pouches).

    Opens a whole stack of pouches (Silt Pouch, Bead Pouch, coffers, bags...) one after another:
        /pouches <item name>    use every one of that item in your main inventory
        /pouches stop           stop now (so does /heal, fighting, zoning, or a full inventory)
        /pouches                list the pouch-type items you have

    Based on the Windower addon "Pouches" by Omnys@Valefor (BSD licence, notice below).
    Changes for omni: Ashita v4 code, a page in Options with an "Open all" button per item, a
    delay you can set, it counts what is left after every use, and it stops by itself when the
    inventory is full.

    Copyright (c) 2016, Omnys of Valefor. All rights reserved.
    Redistribution and use in source and binary forms, with or without modification, are permitted
    provided that the following conditions are met:
      * Redistributions of source code must retain the above copyright notice, this list of
        conditions and the following disclaimer.
      * Redistributions in binary form must reproduce the above copyright notice, this list of
        conditions and the following disclaimer in the documentation and/or other materials
        provided with the distribution.
      * Neither the name of Pouches nor the names of its contributors may be used to endorse or
        promote products derived from this software without specific prior written permission.
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
    IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
    FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL OMNYS BE LIABLE FOR ANY
    DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
    LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
    BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
    SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]

local imgui = require('imgui');

local pouches = {};

-- Words that mark an item as a pouch-type item for the list (any usable item still works by name).
local WORDS = { 'pouch', 'bag', 'box', 'coffer', 'purse', 'quiver', 'case', 'kit', 'chest',
                'sack', 'crate', 'cache', 'packet', 'grab', 'satchel', 'cask', 'pack' };

local st = {
    running = false,
    name = nil,        -- item being used
    id = nil,
    used = 0,
    start_count = 0,
    next_at = 0,
    zone = -1,
    delay = { 3.0 },   -- seconds between uses (the original waited the item's use time + 2)
    show_all = { false },
    typed = { '' },
};

local function msg(t) print('\30\68[Happy Pouches]\30\01 ' .. t); end

local function zone_now()
    local z = 0;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    return z;
end

-- How many of item id are in the main inventory.
local function count_of(id)
    local n = 0;
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for slot = 1, (inv:GetContainerCountMax(0) or 80) do
            local it = inv:GetContainerItem(0, slot);
            if (it ~= nil and it.Id == id) then n = n + (tonumber(it.Count) or 1); end
        end
    end);
    return n;
end

-- Can it be used on yourself? (unknown = yes; the game says no if it can't)
local function self_usable(r)
    local ok, v = pcall(function () return r.ValidTargets or r.Targets; end);
    if (not ok or type(v) ~= 'number') then return true; end
    return bit.band(v, 0x01) ~= 0;
end

local function pouch_like(name)
    local low = name:lower();
    for _, w in ipairs(WORDS) do if low:find(w, 1, true) then return true; end end
    return false;
end

-- Items in the main inventory: { name, id, count }, pouch-type only unless show_all.
local function inventory_list()
    local by, list = {}, {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();
        for slot = 1, (inv:GetContainerCountMax(0) or 80) do
            local it = inv:GetContainerItem(0, slot);
            if (it ~= nil and it.Id ~= nil and it.Id ~= 0 and it.Id ~= 65535) then
                local r = res:GetItemById(it.Id);
                local name = r and r.Name and r.Name[1];
                if (name ~= nil and name ~= '' and self_usable(r) and (st.show_all[1] or pouch_like(name))) then
                    local e = by[it.Id];
                    if (e == nil) then
                        e = { name = name, id = it.Id, count = 0 };
                        by[it.Id] = e;
                        list[#list + 1] = e;
                    end
                    e.count = e.count + (tonumber(it.Count) or 1);
                end
            end
        end
    end);
    table.sort(list, function (a, b) return a.name:lower() < b.name:lower(); end);
    return list;
end

local function find_item(name)
    local found = nil;
    pcall(function ()
        local res = AshitaCore:GetResourceManager();
        for _, lang in ipairs({ 0, 2, 1 }) do
            local ok, r = pcall(function () return res:GetItemByName(name, lang); end);
            if (ok and r ~= nil and r.Id ~= nil and r.Id ~= 0) then found = r; return; end
        end
    end);
    -- Not an exact name: try the inventory, by start of name.
    if (found == nil) then
        local low = name:lower();
        for _, e in ipairs(inventory_list()) do
            if (e.name:lower():sub(1, #low) == low) then
                pcall(function () found = AshitaCore:GetResourceManager():GetItemById(e.id); end);
                break;
            end
        end
    end
    return found;
end

local function stop(why)
    if (not st.running) then return; end
    st.running = false;
    msg(('stopped - %s. Used %d %s.'):format(why, st.used, st.name or ''));
end

local function start(name)
    name = (name or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('^"(.*)"$', '%1');
    if (name == '') then msg('which item? e.g. /pouches silt pouch'); return; end
    local r = find_item(name);
    if (r == nil) then msg('No item called "' .. name .. '".'); return; end
    local n = count_of(r.Id);
    if (n == 0) then msg(r.Name[1] .. ' - none in your main inventory.'); return; end
    st.running, st.name, st.id = true, r.Name[1], r.Id;
    st.used, st.start_count, st.next_at, st.zone = 0, n, os.clock(), zone_now();
    msg(('found %d %s - using them. /pouches stop (or /heal) to stop.'):format(n, st.name));
end

-- Every frame: use the next one when it's time.
ashita.events.register('d3d_present', 'omni_pouches_tick', function ()
    if (not st.running) then return; end
    local now = os.clock();
    if (now < st.next_at) then return; end
    if (zone_now() ~= st.zone) then stop('you zoned'); return; end
    local status = 0;
    pcall(function () local p = GetPlayerEntity(); status = p and p.Status or 0; end);
    if (status ~= 0) then stop('you are resting or fighting'); return; end
    local left = count_of(st.id);
    if (left == 0) then
        st.running = false;
        msg(('done - used %d %s.'):format(st.used, st.name));
        return;
    end
    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/item "' .. st.name .. '" <me>'); end);
    st.used = st.used + 1;
    st.next_at = now + math.max(1.0, tonumber(st.delay[1]) or 3.0);
end);

-- The game's own "can't" lines stop it (inventory full, can't use it here...).
ashita.events.register('text_in', 'omni_pouches_text', function (e)
    if (not st.running or e.injected) then return; end
    pcall(function ()
        local m = (e.message or ''):gsub('[\30\31].', ''):gsub('\127.', ''):lower();
        if (m:find('inventory is full', 1, true) or m:find('cannot carry', 1, true)
            or m:find('cannot use', 1, true) or m:find('unable to use', 1, true)
            or m:find('cannot obtain', 1, true)) then
            stop('the game said: ' .. (e.message or ''):gsub('[\30\31].', ''):gsub('\127.', ''));
        end
    end);
end);

ashita.events.register('command', 'omni_pouches_cmd', function (e)
    local a = e.command:args();
    if (#a == 0 or a[1]:lower() ~= '/pouches') then return; end
    e.blocked = true;
    local rest = e.command:gsub('^%S+%s*', '');
    if (rest:lower() == 'stop') then
        if (st.running) then stop('you typed /pouches stop'); else msg('nothing running.'); end
    elseif (rest == '') then
        local list = inventory_list();
        if (#list == 0) then msg('no pouch-type items in your main inventory.'); return; end
        for _, it in ipairs(list) do msg(('%s x%d'):format(it.name, it.count)); end
        msg('/pouches <item name> to open them all (or Options > Pouches).');
    else
        start(rest);
    end
end);

----------------------------------------------------------------------------------------------------
-- Options > Pouches
----------------------------------------------------------------------------------------------------
local GOLD, DIM, TEXT = { 0.90, 0.78, 0.40, 1.0 }, { 0.62, 0.66, 0.80, 1.0 }, { 0.92, 0.92, 0.95, 1.0 };
local GREEN = { 0.45, 0.88, 0.45, 1.0 };

pouches.render = function ()
    if (st.running) then
        local left = count_of(st.id);
        imgui.TextColored(GREEN, ('Using %s - %d used, %d left'):format(st.name, st.used, left));
        imgui.SameLine(0, 10);
        if (imgui.Button('Stop##omni_pch_stop')) then stop('you pressed Stop'); end
        local total = math.max(1, st.used + left);
        imgui.ProgressBar(st.used / total, { -1, 14 }, ('%d / %d'):format(st.used, total));
    else
        imgui.TextColored(DIM, 'Open a whole stack of pouches, one after another.');
    end
    imgui.Separator();

    local list = inventory_list();
    if (#list == 0) then
        imgui.TextColored(DIM, st.show_all[1] and 'No usable items in your main inventory.'
            or 'No pouch-type items in your main inventory.');
    end
    for i, it in ipairs(list) do
        imgui.TextColored(TEXT, it.name);
        imgui.SameLine(220);
        imgui.TextColored(GOLD, 'x' .. it.count);
        imgui.SameLine(280);
        if (st.running) then
            imgui.TextDisabled('Open all');
        elseif (imgui.SmallButton('Open all##omni_pch_' .. i)) then
            start(it.name);
        end
    end
    imgui.Separator();

    imgui.PushItemWidth(200);
    imgui.InputTextWithHint('##omni_pch_name', 'Any item name', st.typed, 64);
    imgui.PopItemWidth();
    imgui.SameLine(0, 6);
    if (imgui.Button('Start##omni_pch_go') and not st.running) then start(st.typed[1]); end
    imgui.Checkbox('Show every usable item##omni_pch_all', st.show_all);
    if (imgui.IsItemHovered()) then imgui.SetTooltip('Off: only pouch-type items (pouch, bag, box, coffer...).\nOn: everything you can use on yourself - careful with food and medicine.'); end
    imgui.PushItemWidth(120);
    if (imgui.SliderFloat('Seconds between uses##omni_pch_delay', st.delay, 1.0, 8.0, '%.1f')) then
        st.delay[1] = math.max(1.0, math.min(8.0, st.delay[1]));
    end
    imgui.PopItemWidth();
    if (imgui.IsItemHovered()) then imgui.SetTooltip('Raise it if some uses get "You cannot use that yet" or are skipped.'); end
    imgui.TextColored(DIM, '/pouches <item>  -  /pouches stop  -  /heal also stops it');
    imgui.TextColored(DIM, 'Based on Pouches by Omnys@Valefor.');
end

pouches.running = function () return st.running; end
return pouches;
