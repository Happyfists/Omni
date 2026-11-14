--[[
    omni_loot.lua - Happy Loot (Items > Loot): lots or passes what drops, by profile.

    A profile is a named list - "Dynamis - Jeuno", "Ores & ingots" - of items to Lot and items to
    Pass, plus what to do with anything that isn't on either list (leave it, lot it or pass it).
    Click a profile to load it; each character remembers its own. Items go on a list by name
    (Find shows matches) or straight from the treasure pool with one click.

    Every drop is remembered for the zone it fell in ("Seen drops"), so each Dynamis builds its
    own list of what drops there, to add to Lot / Pass with one click.

    Happy Loot watches the pool the way Lootwhore does (the server's "item found" / "lot" packets),
    so it knows about drops from the moment it's loaded. Lots and passes go out one at a time,
    a moment after the drop, and are tried again if the server doesn't answer.

        /loot                 open the page
        /loot on | off        switch it on or off (this character)
        /loot profile <name>  load a profile
        /loot lot | pass      lot / pass everything in the pool now

    Saved to config\addons\omni\loot.txt (shared by every character):
        profile<TAB>Name<TAB>leave|lot|pass
        item<TAB>Profile<TAB>lot|pass<TAB>item id (0 if not known yet)<TAB>Item Name<TAB>1|0 (ticked)
        use<TAB>Character<TAB>Profile<TAB>1|0
]]

local imgui = require('imgui');

local loot = {};

local function msg(t) print('\30\81[Happy Loot]\30\01 ' .. t); end

-- ============================================================================ data
local data = { order = {}, profiles = {}, use = {} };
-- profiles[name] = { name, default = 'leave'|'lot'|'pass', items = { { id, name, action }, ... } }
-- use[char] = { profile = name, on = bool }

local function base() return string.format('%s\\config\\addons\\omni\\', AshitaCore:GetInstallPath()); end
local function path() return base() .. 'loot.txt'; end

local function me()
    local ok, n = pcall(function () return AshitaCore:GetMemoryManager():GetParty():GetMemberName(0); end);
    return (ok and n ~= nil and n ~= '') and n or nil;
end

local function new_profile(name, default)
    if data.profiles[name] == nil then
        data.profiles[name] = { name = name, default = default or 'leave', items = {} };
        data.order[#data.order + 1] = name;
    end
    return data.profiles[name];
end

local function save()
    pcall(function ()
        local f = io.open(path(), 'w');
        if f == nil then return; end
        for _, n in ipairs(data.order) do
            local p = data.profiles[n];
            if p then
                f:write('profile\t', p.name, '\t', p.default, '\n');
                for _, it in ipairs(p.items) do
                    f:write('item\t', p.name, '\t', it.action, '\t', tostring(it.id or 0), '\t', it.name, '\t', (it.on == false) and '0' or '1', '\n');
                end
            end
        end
        for c, u in pairs(data.use) do
            f:write('use\t', c, '\t', u.profile or '', '\t', u.on and '1' or '0', '\n');
        end
        f:close();
    end);
end

-- Starter profiles: your Lootwhore ore list, and a Dynamis set that lots the currency.
local ORES = {
    { 640, "Copper Ore" },
    { 641, "Tin Ore" },
    { 642, "Zinc Ore" },
    { 643, "Iron Ore" },
    { 644, "Mythril Ore" },
    { 645, "Darksteel Ore" },
    { 646, "Adaman Ore" },
    { 647, "Molybdenum Ore" },
    { 648, "Copper Ingot" },
    { 649, "Bronze Ingot" },
    { 650, "Brass Ingot" },
    { 651, "Iron Ingot" },
    { 652, "Steel Ingot" },
    { 653, "Mythril Ingot" },
    { 654, "Darksteel Ingot" },
    { 655, "Adaman Ingot" },
    { 658, "Damascus Ingot" },
    { 659, "Tin Ingot" },
    { 678, "Aluminum Ore" },
    { 679, "Aluminum Ingot" },
    { 685, "Khroma Ore" },
    { 686, "Imperial Wootz Ingot" },
    { 687, "Scarletite Ingot" },
    { 734, "Thokcha Ore" },
    { 735, "Thokcha Ingot" },
    { 736, "Silver Ore" },
    { 737, "Gold Ore" },
    { 738, "Platinum Ore" },
    { 739, "Orichalcum Ore" },
    { 740, "Phrygian Ore" },
    { 741, "Palladian Brass Ore" },
    { 742, "Palladian Brass Ingot" },
    { 743, "Phrygian Gold Ingot" },
    { 744, "Silver Ingot" },
    { 745, "Gold Ingot" },
    { 746, "Platinum Ingot" },
    { 747, "Orichalcum Ingot" },
    { 756, "Durium Ore" },
    { 757, "Durium Ingot" },
    { 766, "Ormolu Ingot" },
    { 1255, "Fire Ore" },
    { 1256, "Ice Ore" },
    { 1257, "Wind Ore" },
    { 1258, "Earth Ore" },
    { 1259, "Lightning Ore" },
    { 1260, "Water Ore" },
    { 1261, "Light Ore" },
    { 1262, "Dark Ore" },
    { 1461, "Wootz Ingot" },
    { 1469, "Wootz Ore" },
    { 1635, "Paktong Ingot" },
    { 1650, "Kopparnickel Ore" },
    { 1670, "Spirit Orichalcum Ingot" },
    { 1674, "Indurated Gold Ingot" },
    { 1675, "Neutralizing Silver Ingot" },
    { 1676, "Frigid Orichalcum Ingot" },
    { 1677, "Aqueous Orichalcum Ingot" },
    { 1678, "Rogues Silver Ingot" },
    { 1679, "Bewitched Gold Ingot" },
    { 1681, "Light Steel Ingot" },
    { 1682, "Royal Treasury Gold Ingot" },
    { 1696, "Magicked Steel Ingot" },
    { 1703, "Kunwu Ore" },
    { 1711, "Molybdenum Ingot" },
    { 1738, "Shakudo Ingot" },
    { 1835, "Vivified Mythril Ingot" },
    { 1858, "Moblumin Ingot" },
    { 1879, "Vivio Platinum Ingot" },
    { 1933, "Ancient Brass Ingot" },
    { 1944, "Dark Orichalcum Ingot" },
    { 1989, "Dark Bronze Ingot" },
    { 2000, "Dark Adaman Ingot" },
    { 2134, "Lucent Iron Ingot" },
    { 2135, "Lucent Steel Ingot" },
    { 2228, "Luminium Ore" },
    { 2275, "Scintillant Ingot" },
    { 2302, "Troll Bronze Ingot" },
    { 2418, "Aht Urhgan Brass Ingot" },
    { 2536, "Electrum Ingot" },
    { 2763, "Swamp Ore" },
    { 2764, "Dweomer Steel Ingot" },
    { 2765, "Fools Gold Ore" },
    { 2766, "Oberons Gold Ingot" },
    { 2823, "Iridium Ingot" },
    { 2841, "Quadav Silver Ingot" },
    { 2844, "Penumbral Brass Ingot" },
    { 2850, "Sahagin Gold Ingot" },
    { 2852, "Tenebrium Ingot" },
    { 2858, "Wolfram Steel Ingot" },
    { 2859, "Cobalt Ore" },
    { 2876, "Muculent Ingot" },
    { 2877, "Befouled Silver Ingot" },
    { 2886, "Mildewy Ingot" },
    { 2887, "Decayed Ingot" },
    { 2995, "Warped Ingot" },
    { 3003, "Gilt Ingot" },
    { 3892, "Fulgent Ore" },
    { 3918, "Midrium Ore" },
    { 3919, "Midrium Ingot" },
    { 3920, "Vanadium Ore" },
    { 3922, "Rhodium Ore" },
    { 3923, "Rhodium Ingot" },
    { 4020, "Titanium Ore" },
    { 4021, "Titanium Ingot" },
    { 4023, "Snowsteel Ore" },
    { 4042, "Acuex Ore" },
    { 4046, "Corroded Ore" },
    { 4058, "Bismuth Ore" },
    { 8704, "Bismuth Ingot" },
    { 8721, "Hepatizon Ore" },
    { 8722, "Hepatizon Ingot" },
    { 8723, "Beryllium Ore" },
    { 8724, "Beryllium Ingot" },
    { 8747, "Rakaznar Ore" },
    { 8748, "Rakaznar Ingot" },
    { 8974, "Hugemaw Harolds Red Ore" },
    { 9058, "Specters Ore" },
    { 9075, "Vulcanite Ore" },
    { 9130, "Eschite Ore" },
    { 9247, "Niobium Ore" },
    { 9248, "Niobium Ingot" },
    { 9249, "Ruthenium Ore" },
    { 9250, "Ruthenium Ingot" },
    { 10011, "Tellurium Ingot" },
};
local DYNA_CURRENCY = { 'Ordelle Bronzepiece', 'Montiont Silverpiece', 'Ranperre Goldpiece',
    'Tukuku Whiteshell', 'Lungo-Nango Jadeshell', 'Rimilala Stripeshell',
    'One Byne Bill', 'One Hundred Byne Bill', 'Ten Thousand Byne Bill' };
local DYNA_ZONES = { 'Jeuno', "San d'Oria", 'Bastok', 'Windurst', 'Beaucedine', 'Xarcabard',
    'Valkurm', 'Buburimu', 'Qufim', 'Tavnazia' };

local function starter()
    local p = new_profile('Ores & ingots (from Lootwhore)', 'leave');
    for _, o in ipairs(ORES) do p.items[#p.items + 1] = { id = o[1], name = o[2], action = 'lot' }; end
    for _, z in ipairs(DYNA_ZONES) do
        local d = new_profile('Dynamis - ' .. z, 'leave');
        for _, c in ipairs(DYNA_CURRENCY) do d.items[#d.items + 1] = { id = 0, name = c, action = 'lot' }; end
    end
    save();
end

local function load()
    local f = io.open(path(), 'r');
    if f == nil then starter(); return; end
    for raw in f:lines() do
        local line = raw:gsub('\r$', '');
        local cols = {};
        for c in (line .. '\t'):gmatch('([^\t]*)\t') do cols[#cols + 1] = c; end
        if cols[1] == 'profile' and cols[2] and cols[2] ~= '' then
            new_profile(cols[2], cols[3]);
        elseif cols[1] == 'item' and cols[2] and cols[5] then
            local p = new_profile(cols[2]);
            p.items[#p.items + 1] = { id = tonumber(cols[4]) or 0, name = cols[5], action = (cols[3] == 'pass') and 'pass' or 'lot', on = (cols[6] ~= '0') };
        elseif cols[1] == 'use' and cols[2] then
            data.use[cols[2]] = { profile = cols[3], on = cols[4] == '1' };
        end
    end
    f:close();
    if #data.order == 0 then starter(); end
end
pcall(load);

local function my_use()
    local c = me() or '?';
    data.use[c] = data.use[c] or { profile = nil, on = false };
    return data.use[c];
end
local function active() local u = my_use(); return u.profile and data.profiles[u.profile] or nil; end

-- ============================================================================ items
local function item_name(id)
    local ok, n = pcall(function ()
        local it = AshitaCore:GetResourceManager():GetItemById(id);
        return it and it.Name and it.Name[1];
    end);
    return (ok and n ~= nil and n ~= '') and n or ('item #' .. tostring(id));
end

-- Every item name, lower-cased, for Find (built the first time it's needed).
local index = nil;
local function build_index()
    index = {};
    local res = AshitaCore:GetResourceManager();
    for id = 1, 65535 do
        local ok, it = pcall(function () return res:GetItemById(id); end);
        if ok and it ~= nil and it.Name ~= nil then
            local n = it.Name[1];
            if n ~= nil and n ~= '' and n ~= '.' then index[#index + 1] = { id = id, name = n, low = n:lower() }; end
        end
    end
end
local function find(text, max)
    if index == nil then pcall(build_index); end
    local q = text:lower():gsub('^%s+', ''):gsub('%s+$', '');
    local exact, starts, has = {}, {}, {};
    if q == '' or index == nil then return {}; end
    local num = tonumber(q);
    for _, e in ipairs(index) do
        if (num ~= nil and e.id == num) or e.low == q then exact[#exact + 1] = e;
        elseif e.low:sub(1, #q) == q then starts[#starts + 1] = e;
        elseif e.low:find(q, 1, true) then has[#has + 1] = e; end
    end
    local out, seen = {}, {};
    for _, list in ipairs({ exact, starts, has }) do
        for _, e in ipairs(list) do
            if #out >= (max or 12) then return out; end
            if not seen[e.low] then seen[e.low] = true; out[#out + 1] = e; end
        end
    end
    return out;
end

-- What the profile says for an item: 'lot', 'pass' or nil (leave).
local function rule_for(p, id)
    if p == nil then return nil; end
    local low = item_name(id):lower();
    for _, it in ipairs(p.items) do
        if it.on ~= false and ((it.id ~= 0 and it.id == id) or it.name:lower() == low) then
            if it.id == 0 then it.id = id; end   -- learn the id
            return it.action;
        end
    end
    if p.default == 'lot' or p.default == 'pass' then return p.default; end
    return nil;
end

local function on_list(p, id, name)
    for i, it in ipairs(p.items) do
        if (it.id ~= 0 and it.id == id) or it.name:lower() == name:lower() then return i, it; end
    end
    return nil;
end

local function add_item(p, id, name, action)
    if p == nil then return; end
    local i, it = on_list(p, id, name);
    if it then it.action = action; it.id = id; it.on = true; else p.items[#p.items + 1] = { id = id, name = name, action = action, on = true }; end
    table.sort(p.items, function (a, b) return a.name:lower() < b.name:lower(); end);
    save();
end

-- ============================================================================ seen drops
-- Every item that goes into the treasure pool is remembered for the zone it dropped in, so a
-- zone (Dynamis - Jeuno...) builds its own drop list to add to Lot / Pass from.
-- config\addons\omni\loot_seen.txt:  seen<TAB>zone id<TAB>item id<TAB>times<TAB>last seen (os.time)
local seen = {};          -- seen[zone] = { [item id] = { n = times, last = os.time() } }
local function seen_path() return base() .. 'loot_seen.txt'; end
local function seen_save()
    pcall(function ()
        local f = io.open(seen_path(), 'w');
        if f == nil then return; end
        for z, items in pairs(seen) do
            for id, s in pairs(items) do
                f:write('seen\t', tostring(z), '\t', tostring(id), '\t', tostring(s.n), '\t', tostring(s.last), '\n');
            end
        end
        f:close();
    end);
end
pcall(function ()
    local f = io.open(seen_path(), 'r');
    if f == nil then return; end
    for raw in f:lines() do
        local z, id, n, last = raw:match('^seen\t(%d+)\t(%d+)\t(%d+)\t(%d+)');
        if z then
            z, id = tonumber(z), tonumber(id);
            seen[z] = seen[z] or {};
            seen[z][id] = { n = tonumber(n), last = tonumber(last) };
        end
    end
    f:close();
end);

local function zone_now()
    local z = 0;
    pcall(function () z = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    return z;
end
local function zone_name(z)
    local ok, n = pcall(function () return AshitaCore:GetResourceManager():GetString('zones.names', z); end);
    return (ok and n ~= nil and n ~= '') and n or ('Zone ' .. tostring(z));
end
local function remember(id)
    local z = zone_now();
    if z == 0 then return; end
    seen[z] = seen[z] or {};
    local s = seen[z][id] or { n = 0, last = 0 };
    s.n = s.n + 1;
    s.last = os.time();
    seen[z][id] = s;
    seen_save();
end

-- ============================================================================ the pool
-- pool[slot] = { id, count, at = when it dropped, done = 'lot'|'pass'|nil, tries, next_try }
local pool = {};
local queue_at = 0;          -- the next lot/pass goes no sooner than this
local my_id = 0;
local function my_server_id()
    pcall(function () my_id = AshitaCore:GetMemoryManager():GetParty():GetMemberServerId(0); end);
    return my_id;
end

local function send(action, slot)
    local id = (action == 'pass') and 0x042 or 0x041;
    pcall(function () AshitaCore:GetPacketManager():AddOutgoingPacket(id, { id, 0x04, 0x00, 0x00, slot, 0x00, 0x00, 0x00 }); end);
end

-- Lot / pass one pool slot (by hand or from the profile).
local function act(slot, action)
    local e = pool[slot];
    if e == nil then return; end
    e.want = action;
    e.tries = 0;
    e.next_try = 0;
    e.done = nil;
end

local function decide(slot)
    local e = pool[slot];
    if e == nil or e.want ~= nil then return; end
    local u = my_use();
    if not u.on then return; end
    local r = rule_for(active(), e.id);
    if r then
        e.want = r;
        e.tries = 0;
        e.next_try = os.clock() + 0.5 + math.random() * 1.5;   -- a moment after the drop, like a person
    end
end

-- Drops already in the pool when omni loads: read once from the game's memory (if it offers it).
local function seed()
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        for slot = 0, 9 do
            if pool[slot] == nil then
                local it = inv:GetTreasurePoolItem(slot);
                local id = it and it.ItemId or 0;
                if id ~= nil and id > 0 and id ~= 0xFFFF then
                    local e = { id = id, count = it.Count or 1, at = os.clock() };
                    local lv = it.Lot;
                    if lv == 0xFFFF then e.done = 'pass'; elseif lv ~= nil and lv > 0 then e.done = 'lot'; end
                    pool[slot] = e;
                end
            end
        end
    end);
end
seed();

local zoning = false;
ashita.events.register('packet_in', 'omni_loot_in', function (e)
    if e.id == 0x00B then zoning = true; pool = {}; return; end
    if e.id == 0x00A then zoning = false; pool = {}; return; end
    if e.id == 0x0D2 then          -- an item found: it goes into the pool
        pcall(function ()
            local id = struct.unpack('H', e.data, 0x10 + 1);
            local count = struct.unpack('I', e.data, 0x0C + 1);
            local slot = struct.unpack('B', e.data, 0x14 + 1);
            if id == 0 or id == 0xFFFF then return; end
            pool[slot] = { id = id, count = count, at = os.clock() };
            remember(id);
            decide(slot);
        end);
    elseif e.id == 0x0D3 then      -- a lot, a pass, or the item leaving the pool
        pcall(function ()
            local slot = struct.unpack('B', e.data, 0x14 + 1);
            local drop = struct.unpack('B', e.data, 0x15 + 1);
            if drop ~= 0 then pool[slot] = nil; return; end
            local who = struct.unpack('I', e.data, 0x08 + 1);
            local lotv = struct.unpack('H', e.data, 0x12 + 1);
            local p = pool[slot];
            if p ~= nil and who == my_server_id() then
                p.done = (lotv == 0xFFFF) and 'pass' or 'lot';
                p.want = nil;
            end
        end);
    end
end);

-- One lot/pass at a time, tried again after 3.5 s if the server didn't answer (3 tries).
ashita.events.register('d3d_present', 'omni_loot_tick', function ()
    if zoning then return; end
    local now = os.clock();
    if now < queue_at then return; end
    for slot = 0, 9 do
        local e = pool[slot];
        if e ~= nil and e.want ~= nil and e.done ~= e.want and now >= (e.next_try or 0) then
            if (e.tries or 0) >= 3 then
                e.want = nil;
            else
                send(e.want, slot);
                e.tries = (e.tries or 0) + 1;
                e.next_try = now + 3.5;
                queue_at = now + 0.8;
                return;
            end
        end
    end
end);

local function all(action)
    local n = 0;
    for slot = 0, 9 do
        local e = pool[slot];
        if e ~= nil and e.done == nil then act(slot, action); n = n + 1; end
    end
    return n;
end

-- ============================================================================ commands
local function set_profile(name)
    for _, n in ipairs(data.order) do
        if n:lower() == name:lower() then
            local u = my_use();
            u.profile = n;
            save();
            for slot = 0, 9 do if pool[slot] and not pool[slot].done then pool[slot].want = nil; decide(slot); end end
            msg('Profile: ' .. n .. (u.on and '' or '  (Happy Loot is off - /loot on)'));
            return true;
        end
    end
    msg('No profile called "' .. name .. '".');
    return false;
end

loot.open = nil;   -- set by omni so /loot can open the page
ashita.events.register('command', 'omni_loot_cmd', function (e)
    local args = e.command:args();
    if #args == 0 or args[1]:lower() ~= '/loot' then return; end
    e.blocked = true;
    local sub = (args[2] or ''):lower();
    local u = my_use();
    if sub == 'on' or sub == 'off' then
        u.on = (sub == 'on'); save();
        if u.on then for slot = 0, 9 do decide(slot); end end
        msg('Happy Loot is ' .. (u.on and 'on' or 'off') .. (u.profile and (' - profile: ' .. u.profile) or ' - no profile loaded'));
    elseif sub == 'profile' and #args >= 3 then
        set_profile(table.concat(args, ' ', 3));
    elseif sub == 'lot' or sub == 'pass' then
        msg(string.format('%s %d item(s) in the pool.', sub == 'lot' and 'Lotting' or 'Passing', all(sub)));
    else
        msg('Items > Loot in omni.  /loot on | off  -  /loot profile <name>  -  /loot lot | pass');
        if loot.open ~= nil then pcall(loot.open); end
    end
end);

-- ============================================================================ Lootwhore
-- Lootwhore (the plugin) on or off: /load lootwhore and /unload lootwhore. Its own lots would
-- fight Happy Loot's; with it off you also lose its auto-stacking into your bags.
local lw_guess = true;   -- it loads at startup on this PC
local function lw_loaded()
    local ok, v = pcall(function ()
        local pm = AshitaCore:GetPluginManager();
        if pm.IsLoaded then return pm:IsLoaded('Lootwhore'); end
        if pm.Get then return pm:Get('Lootwhore') ~= nil; end
        return nil;
    end);
    if ok and v ~= nil then return v; end
    return lw_guess;
end
local function lw_set(on)
    lw_guess = on;
    pcall(function () AshitaCore:GetChatManager():QueueCommand(1, on and '/load lootwhore' or '/unload lootwhore'); end);
end

-- ============================================================================ page
local GOLD, DIM, GREEN, RED = { 0.90, 0.78, 0.40, 1.0 }, { 0.62, 0.66, 0.80, 1.0 }, { 0.45, 0.95, 0.45, 1.0 }, { 1.00, 0.50, 0.50, 1.0 };
local ui = { name = { '' }, find = { '' }, results = {}, confirm_delete = nil };

local function profile_buttons()
    local u = my_use();
    local avail = imgui.GetContentRegionAvail();
    local x = 0;
    for _, n in ipairs(data.order) do
        local w = imgui.CalcTextSize(n) + 18;
        if x > 0 and x + w < avail then imgui.SameLine(); else x = 0; end
        local is = (u.profile == n);
        if is then imgui.PushStyleColor(ImGuiCol_Button, { 0.20, 0.50, 0.25, 1.0 }); end
        if imgui.Button(n .. '##lootp') then set_profile(n); end
        if is then imgui.PopStyleColor(); end
        x = x + w + 8;
    end
end

local function list_column(p, action, title, col)
    imgui.TextColored(col, string.format('%s (%d)', title, (function ()
        local c = 0; for _, it in ipairs(p.items) do if it.action == action and it.on ~= false then c = c + 1; end end; return c; end)()));
    imgui.BeginChild('##loot_' .. action, { 0, 180 }, true);
    local remove = nil;
    for i, it in ipairs(p.items) do
        if it.action == action then
            if imgui.SmallButton('x##lootrm' .. action .. i) then remove = i; end
            if imgui.IsItemHovered() then imgui.SetTooltip('Take it off the list'); end
            imgui.SameLine();
            if imgui.SmallButton((action == 'lot' and '>' or '<') .. '##lootmv' .. action .. i) then
                it.action = (action == 'lot') and 'pass' or 'lot'; save();
            end
            if imgui.IsItemHovered() then imgui.SetTooltip(action == 'lot' and 'Move to Pass' or 'Move to Lot'); end
            imgui.SameLine();
            local tick = { it.on ~= false };
            if imgui.Checkbox('##lootchk' .. action .. i, tick) then it.on = tick[1]; save(); end
            if imgui.IsItemHovered() then imgui.SetTooltip(tick[1] and 'On - untick to ignore it for now (it stays on the list)' or 'Off - tick to use it again'); end
            imgui.SameLine();
            imgui.TextColored(it.on == false and DIM or { 1, 1, 1, 1 }, it.name);
        end
    end
    imgui.EndChild();
    if remove then table.remove(p.items, remove); save(); end
end

loot.render = function ()
    local u = my_use();
    local p = active();

    local on = { u.on };
    if imgui.Checkbox('Happy Loot on##loot_on', on) then
        u.on = on[1]; save();
        if u.on then for slot = 0, 9 do decide(slot); end end
    end
    if imgui.IsItemHovered() then imgui.SetTooltip('Lots and passes for you by the loaded profile (this character). /loot on | off'); end
    imgui.SameLine(0, 20);
    local lw = { lw_loaded() };
    if imgui.Checkbox('Lootwhore on##loot_lw', lw) then lw_set(lw[1]); end
    if imgui.IsItemHovered() then
        imgui.SetTooltip('The Lootwhore plugin (/load / unload lootwhore).\nIts own item list lots too, so turn it off if it fights Happy Loot.\nOff also stops its auto-stacking into your bags.');
    end
    imgui.SameLine(0, 20);
    imgui.TextColored(DIM, 'Profile:');
    imgui.SameLine();
    imgui.TextColored(p and GOLD or RED, p and p.name or 'none - click one below');
    imgui.SameLine(0, 20);
    if imgui.SmallButton('Lot all in pool') then msg(string.format('Lotting %d item(s).', all('lot'))); end
    imgui.SameLine();
    if imgui.SmallButton('Pass all in pool') then msg(string.format('Passing %d item(s).', all('pass'))); end

    imgui.Separator();
    imgui.TextColored(DIM, 'Profiles (click to load):');
    profile_buttons();

    -- New / rename / copy / delete
    imgui.PushItemWidth(220);
    imgui.InputTextWithHint('##loot_pname', 'profile name', ui.name, 64);
    imgui.PopItemWidth();
    local nm = ui.name[1]:gsub('^%s+', ''):gsub('%s+$', ''):gsub('\t', ' ');
    imgui.SameLine();
    if imgui.SmallButton('New') and nm ~= '' then
        new_profile(nm, 'leave'); save(); set_profile(nm); ui.name[1] = '';
    end
    if p then
        imgui.SameLine();
        if imgui.SmallButton('Rename') and nm ~= '' and data.profiles[nm] == nil then
            local old = p.name;
            data.profiles[old] = nil; p.name = nm; data.profiles[nm] = p;
            for i, n in ipairs(data.order) do if n == old then data.order[i] = nm; end end
            for _, uu in pairs(data.use) do if uu.profile == old then uu.profile = nm; end end
            save(); ui.name[1] = '';
        end
        imgui.SameLine();
        if imgui.SmallButton('Copy') and nm ~= '' and data.profiles[nm] == nil then
            local c = new_profile(nm, p.default);
            for _, it in ipairs(p.items) do c.items[#c.items + 1] = { id = it.id, name = it.name, action = it.action, on = it.on }; end
            save(); set_profile(nm); ui.name[1] = '';
        end
        if imgui.IsItemHovered() then imgui.SetTooltip('Copy this profile under the name in the box'); end
        imgui.SameLine();
        if ui.confirm_delete == p.name then
            if imgui.SmallButton('Really delete?') then
                data.profiles[p.name] = nil;
                for i, n in ipairs(data.order) do if n == p.name then table.remove(data.order, i); break; end end
                for _, uu in pairs(data.use) do if uu.profile == p.name then uu.profile = nil; end end
                ui.confirm_delete = nil; save(); return;
            end
            imgui.SameLine();
            if imgui.SmallButton('No') then ui.confirm_delete = nil; end
        elseif imgui.SmallButton('Delete') then
            ui.confirm_delete = p.name;
        end
    end

    if p == nil then return; end
    imgui.Separator();

    -- Items not on a list
    imgui.TextColored(DIM, 'Items not on a list:');
    for _, o in ipairs({ { 'leave', 'Leave them' }, { 'lot', 'Lot them' }, { 'pass', 'Pass them' } }) do
        imgui.SameLine();
        if imgui.RadioButton(o[2] .. '##lootdef', p.default == o[1]) then p.default = o[1]; save(); end
    end

    -- Add by name
    imgui.PushItemWidth(260);
    local enter = imgui.InputTextWithHint('##loot_find', 'item name or part of it, or an item id', ui.find, 64, ImGuiInputTextFlags_EnterReturnsTrue);
    imgui.PopItemWidth();
    imgui.SameLine();
    if imgui.SmallButton('Find') or enter then
        ui.results = find(ui.find[1], 12);
        if #ui.results == 0 then msg('No item matches "' .. ui.find[1] .. '".'); end
    end
    for i, r in ipairs(ui.results) do
        if imgui.SmallButton('+ Lot##lootfl' .. i) then add_item(p, r.id, r.name, 'lot'); end
        imgui.SameLine();
        if imgui.SmallButton('+ Pass##lootfp' .. i) then add_item(p, r.id, r.name, 'pass'); end
        imgui.SameLine();
        imgui.Text(r.name);
    end

    -- The two lists, side by side
    local w = (imgui.GetContentRegionAvail() - 10) / 2;
    imgui.BeginGroup(); imgui.PushItemWidth(w);
    imgui.BeginChild('##loot_lotcol', { w, 210 }, false);
    list_column(p, 'lot', 'Lot', GREEN);
    imgui.EndChild();
    imgui.PopItemWidth(); imgui.EndGroup();
    imgui.SameLine(0, 10);
    imgui.BeginChild('##loot_passcol', { w, 210 }, false);
    list_column(p, 'pass', 'Pass', RED);
    imgui.EndChild();

    -- The treasure pool right now
    imgui.Separator();
    imgui.TextColored(DIM, 'Treasure pool:');
    local any = false;
    for slot = 0, 9 do
        local e = pool[slot];
        if e ~= nil then
            any = true;
            local name = item_name(e.id);
            if imgui.SmallButton('Lot##lootpl' .. slot) then act(slot, 'lot'); end
            imgui.SameLine();
            if imgui.SmallButton('Pass##lootpp' .. slot) then act(slot, 'pass'); end
            imgui.SameLine();
            if imgui.SmallButton('+Lot list##lootal' .. slot) then add_item(p, e.id, name, 'lot'); end
            imgui.SameLine();
            if imgui.SmallButton('+Pass list##lootap' .. slot) then add_item(p, e.id, name, 'pass'); end
            imgui.SameLine();
            local state = e.done and (e.done == 'lot' and '  (lotted)' or '  (passed)')
                or (e.want and ('  (' .. e.want .. 'ting...)'):gsub('passting', 'passing') or '');
            imgui.TextColored(e.done == 'lot' and GREEN or (e.done == 'pass' and RED or GOLD),
                (e.count and e.count > 1 and (e.count .. ' x ') or '') .. name .. state);
        end
    end
    if not any then imgui.TextColored(DIM, '  empty (drops show here as they fall, from when omni was loaded)'); end

    -- What has dropped in a zone before (learnt from the pool), to add to the lists.
    imgui.Separator();
    local zones = {};
    for z, items in pairs(seen) do if next(items) ~= nil then zones[#zones + 1] = z; end end
    table.sort(zones, function (a, b) return zone_name(a) < zone_name(b); end);
    local here = zone_now();
    if ui.seen_zone == nil or seen[ui.seen_zone] == nil then
        ui.seen_zone = (seen[here] ~= nil) and here or zones[1];
    end
    imgui.TextColored(DIM, 'Seen drops in');
    imgui.SameLine();
    imgui.PushItemWidth(240);
    if imgui.BeginCombo('##loot_seenzone', ui.seen_zone and (zone_name(ui.seen_zone) .. (ui.seen_zone == here and '  (here)' or '')) or 'nothing yet') then
        for _, z in ipairs(zones) do
            if imgui.Selectable(zone_name(z) .. (z == here and '  (here)' or '') .. '##lootz' .. z, z == ui.seen_zone) then ui.seen_zone = z; end
        end
        imgui.EndCombo();
    end
    imgui.PopItemWidth();
    if ui.seen_zone and seen[ui.seen_zone] then
        imgui.SameLine();
        if ui.confirm_clear == ui.seen_zone then
            if imgui.SmallButton('Really clear?') then seen[ui.seen_zone] = nil; ui.confirm_clear = nil; seen_save(); return; end
            imgui.SameLine();
            if imgui.SmallButton('No##lootclr') then ui.confirm_clear = nil; end
        elseif imgui.SmallButton('Clear this zone') then
            ui.confirm_clear = ui.seen_zone;
        end
        local rows = {};
        for id, s in pairs(seen[ui.seen_zone]) do rows[#rows + 1] = { id = id, n = s.n, name = item_name(id) }; end
        table.sort(rows, function (a, b) return a.name:lower() < b.name:lower(); end);
        imgui.BeginChild('##loot_seenlist', { 0, math.min(260, 24 + #rows * 24) }, true);
        for i, r in ipairs(rows) do
            local _, it = on_list(p, r.id, r.name);
            if imgui.SmallButton('+ Lot##lootsl' .. i) then add_item(p, r.id, r.name, 'lot'); end
            imgui.SameLine();
            if imgui.SmallButton('+ Pass##lootsp' .. i) then add_item(p, r.id, r.name, 'pass'); end
            imgui.SameLine();
            local tag, col = '  (not on a list)', DIM;
            if it then
                tag = (it.action == 'lot' and '  on Lot' or '  on Pass') .. (it.on == false and ' (off)' or '');
                col = it.action == 'lot' and GREEN or RED;
            end
            imgui.Text(string.format('%s  x%d', r.name, r.n));
            imgui.SameLine();
            imgui.TextColored(col, tag);
        end
        imgui.EndChild();
    else
        imgui.TextColored(DIM, '  Drops are remembered per zone from now on - each Dynamis builds its own list.');
    end
end

return loot;
