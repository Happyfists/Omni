--[[
    omni_sky.lua - Sky god pop item tracker for the "Sky" tab.

    Lists the pop items for Genbu, Seiryu, Byakko, Suzaku and Kirin, how many
    of each you are holding (every bag is counted), and where each one comes
    from. Pop requirements and drop sources are taken from the public
    CatsEyeXI server data; the live server can differ.
]]

local imgui = require('imgui');

local sky = {};

-- from  = who or what gives the item
-- needs = a further item needed to spawn that monster
local GODS = {
    {
        name = 'Genbu', spawn = "Trade both to the ??? in Ru'Aun Gardens.",
        items = {
            { id = 1424, name = 'Gem of the North', from = "Zipacna - Ve'Lugannon Palace" },
            { id = 1425, name = 'Winterstone', from = "Olla Grande - The Shrine of Ru'Avitau",
              needs = { id = 1195, name = "Ro'Maeve Spring Water", from = "Aura Pot (1%) - starts the Olla chain" } },
        },
    },
    {
        name = 'Seiryu', spawn = "Trade both to the ??? in Ru'Aun Gardens.",
        items = {
            { id = 1418, name = 'Gem of the East', from = "Steam Cleaner - Ve'Lugannon Palace" },
            { id = 1419, name = 'Springstone', from = "Mother Globe - The Shrine of Ru'Avitau" },
        },
    },
    {
        name = 'Byakko', spawn = "Trade both to the ??? in Ru'Aun Gardens.",
        items = {
            { id = 1422, name = 'Gem of the West', from = "Despot - Ru'Aun Gardens" },
            { id = 1423, name = 'Autumnstone', from = "Ullikummi - The Shrine of Ru'Avitau",
              needs = { id = 2388, name = 'Chunk of Diorite', from = "Aura Statue (1%) - pops Ullikummi" } },
        },
    },
    {
        name = 'Suzaku', spawn = "Trade both to the ??? in Ru'Aun Gardens.",
        items = {
            { id = 1420, name = 'Gem of the South', from = "Brigandish Blade - Ve'Lugannon Palace",
              needs = { id = 16575, name = 'Curtana', from = "??? in Ve'Lugannon Palace - pops Brigandish Blade" } },
            { id = 1421, name = 'Summerstone', from = "Faust - The Shrine of Ru'Avitau" },
        },
    },
    {
        name = 'Kirin', spawn = "Trade all four to the ??? in The Shrine of Ru'Avitau.",
        items = {
            { id = 1404, name = 'Seal of Genbu', from = 'Genbu' },
            { id = 1405, name = 'Seal of Seiryu', from = 'Seiryu' },
            { id = 1406, name = 'Seal of Byakko', from = 'Byakko' },
            { id = 1407, name = 'Seal of Suzaku', from = 'Suzaku' },
        },
    },
};

-- What each god drops (gear and abjurations), from the public CatsEyeXI server data and the
-- FFXI Wiki's CatsEyeXI Sky page. "sky2" is the Sky 2.0 (Escha - Ru'Aun) version of the god.
-- An entry without an id is a CatsEyeXI item that is matched by name instead.
local function abj(kind, slot, id) return { id = id, name = kind .. ' Abjuration: ' .. slot }; end
local DROPS = {
    Genbu = {
        sky = { { id = 12296, name = "Genbu's Shield" }, { id = 12434, name = "Genbu's Kabuto" },
            abj('Wyrmal', 'Feet', 1338), abj('Aquarian', 'Head', 1324), abj('Aquarian', 'Hands', 1326), abj('Martial', 'Hands', 1331),
            abj('Hadean', 'Head', 2434), abj('Phantasmal', 'Head', 2429) },
        sky2 = { { id = 15831, name = 'Fenian Ring' }, { id = 17758, name = 'Ruler' }, { id = 16158, name = "Gnadbhod's Helm" },
            { id = 15918, name = 'Witch Sash' }, { id = 14964, name = "Deimos's Gauntlets" }, { id = 14976, name = "Enlil's Kolluks" },
            { id = 14968, name = "Freya's Gloves" }, { id = 14972, name = 'Hikazu Gote' }, { id = 14980, name = "Macha's Cuffs" },
            { name = 'Cracked Kabuto' }, { id = 27539, name = 'Genmei Earring' } },
    },
    Seiryu = {
        sky = { { id = 17659, name = "Seiryu's Sword" }, { id = 12690, name = "Seiryu's Kote" },
            abj('Wyrmal', 'Hands', 1336), abj('Dryadic', 'Head', 1314), abj('Aquarian', 'Legs', 1327), abj('Martial', 'Head', 1329),
            abj('Hadean', 'Hands', 2436), abj('Phantasmal', 'Hands', 2431) },
        sky2 = { { id = 18598, name = 'Prester' }, { id = 11392, name = 'Koschei Crackows' }, { id = 16159, name = "Zha'Go's Barbut" },
            { id = 16001, name = 'Crapaud Earring' }, { id = 15729, name = "Bodb's Pigaches" }, { id = 15725, name = "Ea's Crackows" },
            { id = 15717, name = "Freyr's Ledelsens" }, { id = 15713, name = "Phobos's Sabatons" }, { id = 15721, name = 'Tsukikazu Sune-Ate' },
            { name = 'Ruined Kote' }, { id = 26320, name = 'Kobo Obi' } },
    },
    Byakko = {
        sky = { { id = 18198, name = "Byakko's Axe" }, { id = 12818, name = "Byakko's Haidate" },
            abj('Neptunal', 'Hands', 1341), abj('Dryadic', 'Legs', 1317), abj('Earthen', 'Feet', 1323), abj('Aquarian', 'Head', 1324),
            abj('Hadean', 'Feet', 2438), abj('Phantasmal', 'Feet', 2433) },
        sky2 = { { id = 13403, name = 'Assault Earring' }, { id = 18498, name = 'Balestarius' }, { id = 16241, name = "Cuchulain's Mantle" },
            { id = 16356, name = "Nimue's Tights" }, { id = 15714, name = "Deimos's Leggings" }, { id = 15726, name = "Enlil's Crackows" },
            { id = 15718, name = "Freya's Ledelsens" }, { id = 15722, name = 'Hikazu Sune-Ate' }, { id = 15730, name = "Macha's Pigaches" },
            { name = 'Ripped Haidate' }, { id = 27525, name = 'Jokushu Chain' } },
    },
    Suzaku = {
        sky = { { id = 12946, name = "Suzaku's Sune-Ate" }, { id = 18043, name = "Suzaku's Scythe" },
            abj('Neptunal', 'Feet', 1343), abj('Dryadic', 'Hands', 1316), abj('Earthen', 'Head', 1319), abj('Aquarian', 'Legs', 1327),
            abj('Hadean', 'Legs', 2437), abj('Phantasmal', 'Legs', 2432) },
        sky2 = { { id = 16002, name = 'Roundel Earring' }, { id = 13624, name = 'Enhancing Mantle' }, { id = 15917, name = "Cuchulain's Belt" },
            { id = 11365, name = 'Karasutengu' }, { id = 15724, name = "Anu's Gaiters" }, { id = 15712, name = "Enyo's Leggings" },
            { id = 15720, name = 'Hoshikazu Kyahan' }, { id = 15728, name = "Nemain's Sabots" }, { id = 15716, name = "Njord's Ledelsens" },
            { name = 'Scuffed Sune-Ate' }, { id = 26161, name = 'Shukuyu Ring' } },
    },
    Kirin = {
        sky = { { id = 17567, name = "Kirin's Pole" }, { id = 12562, name = "Kirin's Osode" },
            abj('Dryadic', 'Body', 1315), abj('Wyrmal', 'Legs', 1337), abj('Neptunal', 'Body', 1340),
            abj('Hadean', 'Body', 2435), abj('Phantasmal', 'Body', 2430) },
        sky2 = { { id = 16160, name = "Ree's Headgear" }, { id = 19030, name = 'Wise Strap' }, { id = 15833, name = "Diverter's Ring" },
            { id = 11281, name = 'Hachiryu Haramaki' }, { id = 18447, name = 'Nanatsusaya' }, { id = 18759, name = 'Shlang Baghnakhs' },
            { id = 18594, name = 'Dorje' }, { name = 'Tattered Osode' }, { id = 20842, name = 'Reikiono' } },
    },
};

local LAST_BAG = 16;        -- inventory, safes, storage, locker, satchel, sack, case, wardrobes
local RESCAN_SECONDS = 2;

local counts = {};
local owned_ids, owned_names = {}, {};
local name_ids = {};   -- item name -> id, learned from your bags
local scanned_at = -100;

-- Count every tracked item across all bags. Runs at most every couple of seconds.
local function scan()
    local now = os.clock();
    if (now - scanned_at < RESCAN_SECONDS) then
        return;
    end
    scanned_at = now;

    local wanted = {};
    for _, god in ipairs(GODS) do
        for _, item in ipairs(god.items) do
            wanted[item.id] = 0;
            if (item.needs ~= nil) then
                wanted[item.needs.id] = 0;
            end
        end
    end

    local inventory = AshitaCore:GetMemoryManager():GetInventory();
    local res = AshitaCore:GetResourceManager();
    local ids, names = {}, {};
    for bag = 0, LAST_BAG do
        local max = inventory:GetContainerCountMax(bag) or 0;
        for slot = 1, max do
            local ok, entry = pcall(function () return inventory:GetContainerItem(bag, slot); end);
            if (ok and entry ~= nil and entry.Id ~= nil and wanted[entry.Id] ~= nil) then
                wanted[entry.Id] = wanted[entry.Id] + (entry.Count or 1);
            end
            -- Every item you own, by number and by name, for the drop lists.
            if (ok and entry ~= nil and entry.Id ~= nil and entry.Id ~= 0 and entry.Id ~= 65535) then
                ids[entry.Id] = true;
                local r = res:GetItemById(entry.Id);
                if (r ~= nil and r.Name ~= nil and r.Name[1] ~= nil) then
                    names[r.Name[1]:lower()] = true;
                    name_ids[r.Name[1]:lower()] = entry.Id;   -- lets name-only drops show their icon
                end
                -- The full name too ("Deimos's Gauntlets +1", not the short "Deimos's Gnt. +1").
                local full = nil;
                pcall(function () full = r.LogNameSingular and r.LogNameSingular[1]; end);
                if (full ~= nil and full ~= '') then
                    names[full:lower()] = true;
                    if (name_ids[full:lower()] == nil) then name_ids[full:lower()] = entry.Id; end
                end
            end
        end
    end
    counts = wanted;
    owned_ids, owned_names = ids, names;
end

local GREEN = { 0.40, 0.90, 0.40, 1.0 };

local function draw_item(host, item, indent, is_sub)
    local ui = host.ui;
    local have = counts[item.id] or 0;

    imgui.SetCursorPosX(imgui.GetCursorPosX() + indent);
    if (not host.renderIcon(item.id, 18)) then
        imgui.Dummy({ 18, 18 });
    end
    imgui.SameLine(0, 6);
    imgui.TextColored((have > 0) and GREEN or ui.color('dimmed'), (is_sub and 'needs ' or '') .. item.name);
    imgui.SameLine(250);
    imgui.TextColored((have > 0) and GREEN or ui.color('dimmed'), string.format('x%d', have));
    imgui.SameLine(295);
    imgui.TextColored(ui.color('dimmed'), (item.from:gsub('%%', '%%%%')));
end

-- Drops you've marked as owned by hand (right-click a box), saved between sessions.
local settings = require('settings');
local marks = settings.load(T{ owned = T{} }, 'omni_sky_marks');
settings.register('omni_sky_marks', 'omni_sky_marks_update', function (s) if (s ~= nil) then marks = s; end end);

-- VNM armour (Ventures > VNM Armor): each Sky 2.0 armour drop is one tier of a set, and it is
-- upgraded T1 -> T2 -> T3 -> the finished piece. Owning a later tier or the finished piece means
-- you have had that drop. Rows: T1, T2, T3, finished; columns: head, body, hands, legs, feet.
local VNM_CHAINS = {
    { { 16085, 14547, 14962, 15626, 15712 }, { 16086, 14548, 14963, 15627, 15713 }, { 16087, 14549, 14964, 15628, 15714 }, { 16084, 14546, 14961, 15625, 15711 } },  -- Ares
    { { 16089, 14551, 14966, 15630, 15716 }, { 16090, 14552, 14967, 15631, 15717 }, { 16091, 14553, 14968, 15632, 15718 }, { 16088, 14550, 14965, 15629, 15715 } },  -- Skadi
    { { 16093, 14555, 14970, 15634, 15720 }, { 16094, 14556, 14971, 15635, 15721 }, { 16095, 14557, 14972, 15636, 15722 }, { 16092, 14554, 14969, 15633, 15719 } },  -- Usukane
    { { 16097, 14559, 14974, 15638, 15724 }, { 16098, 14560, 14975, 15639, 15725 }, { 16099, 14561, 14976, 15640, 15726 }, { 16096, 14558, 14973, 15637, 15723 } },  -- Marduk
    { { 16101, 14563, 14978, 15642, 15728 }, { 16102, 14564, 14979, 15643, 15729 }, { 16103, 14565, 14980, 15644, 15730 }, { 16100, 14562, 14977, 15641, 15727 } },  -- Morrigan
};
local LATER = {};   -- item id -> ids of the later tiers and the finished piece
for _, chain in ipairs(VNM_CHAINS) do
    for slot = 1, 5 do
        for t = 1, 3 do
            local later = {};
            for u = t + 1, 4 do later[#later + 1] = chain[u][slot]; end
            LATER[chain[t][slot]] = later;
        end
    end
end

-- Owned if you have the item itself, an upgraded version of it ("+1", "+2"...), or you marked it.
-- Returns true/false and how (nil, 'upgraded' or 'marked').
local function owns(d)
    local key = d.name:lower();
    if ((d.id and owned_ids[d.id]) or owned_names[key]) then return true, nil; end
    -- Upgraded into a later VNM tier or the finished piece.
    for _, later in ipairs(d.id and LATER[d.id] or {}) do
        if (owned_ids[later]) then return true, 'upgraded'; end
    end
    for n in pairs(owned_names) do
        if (n:sub(1, #key + 2) == key .. ' +') then return true, 'upgraded'; end
    end
    if (marks.owned[key] == true) then return true, 'marked'; end
    return false, nil;
end

-- A wrapped row of item boxes: green if you own it, red if not.
local function draw_drops(host, title, list)
    local have = 0;
    for _, d in ipairs(list) do
        if (owns(d)) then have = have + 1; end
    end
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 4);
    imgui.TextColored({ 0.79, 0.69, 0.42, 1.0 }, string.format('%s  (%d / %d)', title, have, #list));
    local ww = imgui.GetWindowWidth();
    local per_row = 3;
    local boxW = math.floor((ww - 30 - (per_row - 1) * 4) / per_row);
    for i, d in ipairs(list) do
        local own, how = owns(d);
        if ((i - 1) % per_row ~= 0) then imgui.SameLine(0, 4); else imgui.SetCursorPosX(imgui.GetCursorPosX() + 4); end
        imgui.PushStyleColor(ImGuiCol_ChildBg, own and { 0.16, 0.42, 0.16, 1.0 } or { 0.45, 0.13, 0.13, 1.0 });
        imgui.BeginChild('##skydrop_' .. title .. i, { boxW, 26 }, true, bit.bor(ImGuiWindowFlags_NoScrollbar, ImGuiWindowFlags_NoScrollWithMouse));
        imgui.SetCursorPos({ 3, 2 });
        local icon_id = d.id or name_ids[d.name:lower()];
        if (not (icon_id and host.renderIcon(icon_id, 20))) then imgui.Dummy({ 20, 20 }); end
        imgui.SameLine(0, 6);
        imgui.SetCursorPosY(5);
        imgui.TextColored({ 1.0, 1.0, 1.0, 1.0 }, d.name .. ((how == 'upgraded') and '  (upgraded)' or ((how == 'marked') and '  *' or '')));
        imgui.EndChild();
        imgui.PopStyleColor(1);
        if (imgui.IsItemHovered()) then
            imgui.BeginTooltip();
            if (how == 'upgraded') then
                imgui.Text(d.name .. ' - you have the upgraded version');
            elseif (how == 'marked') then
                imgui.Text(d.name .. ' - marked as owned by you (right-click to unmark)');
            else
                imgui.Text(d.name .. (own and ' - you have this' or ' - you do not have this'));
                if (not own) then imgui.TextColored({ 0.7, 0.7, 0.75, 1.0 }, 'Right-click if you have it (e.g. upgraded into something else).'); end
            end
            imgui.EndTooltip();
            -- Right-click: mark / unmark as owned.
            if (imgui.IsMouseClicked(1) and (how == 'marked' or not own)) then
                local key = d.name:lower();
                marks.owned[key] = (marks.owned[key] ~= true) and true or nil;
                pcall(function () settings.save('omni_sky_marks'); end);
            end
        end
    end
end

-- host is the trove host module (gives the item icons and the shared look).
sky.render = function (host)
    local ui = host.ui;
    scan();

    local pushed = ui.pushWindowStyle();
    for _, god in ipairs(GODS) do
        local ready = 0;
        for _, item in ipairs(god.items) do
            if ((counts[item.id] or 0) > 0) then
                ready = ready + 1;
            end
        end
        local label;
        if (ready == #god.items) then
            label = string.format('%s  -  READY to pop', god.name);
        else
            label = string.format('%s  -  %d / %d', god.name, ready, #god.items);
        end
        -- Click a god's heading to fold its list away.
        if (ui.sectionHeader(label, nil, 'sky:' .. god.name)) then
            for _, item in ipairs(god.items) do
                draw_item(host, item, 4, false);
                if (item.needs ~= nil) then
                    draw_item(host, item.needs, 28, true);
                end
            end
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 4);
            imgui.TextColored(ui.color('dimmed'), god.spawn);
            local drops = DROPS[god.name];
            if (drops ~= nil) then
                imgui.Spacing();
                draw_drops(host, god.name .. ' drops', drops.sky);
            end
        end
        imgui.Spacing();
    end
    imgui.TextColored(ui.color('dimmed'), '(Every bag is counted. Sources from public CatsEyeXI server data - live server can differ.)');
    ui.popWindowStyle(pushed);
end

----------------------------------------------------------------------------------------------------
-- The server's !pops answer: which NMs you can pop now, and Sky 2.0 key items.
-- Lines look like "=== Sky 2.0 ===", then "● Escha-Suzaku ★" (● = can pop, × = cannot,
-- ★ = you already have the key item). omni asks for it while the Sky 2.0 / Pops tabs are open
-- and keeps that answer out of chat; your own !pops still shows as normal.
----------------------------------------------------------------------------------------------------
local ask_method = 'packet';   -- how !pops is sent (see send_pops)
local waiting_since = nil;     -- os.clock() of an ask still waiting for its answer
local pops = nil;           -- { sections = { { title, notes = {}, entries = { { name, ready, ki } } } }, at }
local capture = nil;
local capture_until = 0;
local asked_at = -1000;
local ASK_EVERY = 60;

-- Colour codes removed; ● -> 'O', × -> 'X', ★ -> '*' (Shift-JIS 81 9C, 81 7E, 81 9A).
local function clean(text)
    local out, i = {}, 1;
    while (i <= #text) do
        local b = text:byte(i);
        local b2 = text:byte(i + 1);
        if (b == 0x1E or b == 0x1F or b == 0x7F) then
            i = i + 2;
        elseif (b == 0x81 and b2 == 0x9C) then out[#out + 1] = 'O'; i = i + 2;
        elseif (b == 0x81 and b2 == 0x7E) then out[#out + 1] = 'X'; i = i + 2;
        elseif (b == 0x81 and b2 == 0x9A) then out[#out + 1] = '*'; i = i + 2;
        elseif (b >= 0x80) then i = i + 2;
        elseif (b < 0x20) then i = i + 1;
        else out[#out + 1] = string.char(b); i = i + 1; end
    end
    return table.concat(out);
end

local function finish_capture()
    if (capture ~= nil and #capture.sections > 0) then
        capture.at = os.time();
        pops = capture;
        waiting_since = nil;
    end
    capture = nil;
end

-- Called from omni.lua for every chat line. Returns true to hide the line.
sky.on_text = function (e)
    local text = clean(e.message or '');
    local now = os.clock();
    if (capture ~= nil and now > capture_until) then
        finish_capture();
    end
    local title = text:match('^%s*===%s*(.-)%s*===%s*$');
    if (title ~= nil) then
        if (capture == nil) then capture = { sections = {} }; end
        capture.sections[#capture.sections + 1] = { title = title, notes = {}, entries = {} };
    elseif (capture ~= nil) then
        local sec = capture.sections[#capture.sections];
        local mark, name = text:match('^%s*([OX])%s+(.-)%s*$');
        if (mark ~= nil) then
            local ki = name:find('%*') ~= nil;
            name = name:gsub('%*', ''):gsub('%s+$', '');
            sec.entries[#sec.entries + 1] = { name = name, ready = (mark == 'O'), ki = ki };
        elseif (text:match('^%s*%(') ~= nil) then
            sec.notes[#sec.notes + 1] = text;
        elseif (text:match('^%s*$') == nil) then
            return false;   -- some other chat line; not part of the answer
        end
    else
        return false;
    end
    capture_until = now + 2;
    return (now - asked_at) < 10;
end

-- "!pops" sent the same way the game sends a typed chat line; if the server does not answer
-- within a few seconds, it is typed through the chat line instead.
local POPS_PACKET = { 0xB5, 0x08, 0x81, 0x01, 0x00, 0x00, 0x21, 0x70, 0x6F, 0x70, 0x73, 0x00, 0x00, 0x00, 0x00, 0x00 };  -- "!pops"

local function send_pops()
    asked_at = os.clock();
    waiting_since = os.clock();
    if (ask_method == 'packet') then
        pcall(function () AshitaCore:GetPacketManager():AddOutgoingPacket(0xB5, POPS_PACKET); end);
    else
        pcall(function () AshitaCore:GetChatManager():QueueCommand(1, '/say !pops'); end);
    end
end

local function ask_if_due()
    -- No answer to the last ask: try the other way once.
    if (waiting_since ~= nil and os.clock() - waiting_since > 6) then
        waiting_since = nil;
        if (ask_method == 'packet') then
            ask_method = 'command';
            send_pops();
            return;
        end
    end
    if (os.clock() - asked_at < ASK_EVERY) then return; end
    send_pops();
end

local function pops_section(match)
    if (pops == nil) then return nil; end
    for _, sec in ipairs(pops.sections) do
        if (sec.title:lower():find(match, 1, true)) then return sec; end
    end
    return nil;
end

-- Refresh button and how fresh the list is. It also refreshes by itself every minute.
local function pops_age(ui, id)
    if (imgui.Button('Refresh (!pops)##pops_refresh_' .. id)) then
        send_pops();
    end
    imgui.SameLine(0, 12);
    if (waiting_since ~= nil) then
        imgui.TextColored({ 1.0, 0.85, 0.35, 1.0 }, 'Asking the server...');
    elseif (pops == nil) then
        imgui.TextColored(ui.color('dimmed'), 'No answer yet - press Refresh.');
    else
        local ago = os.time() - pops.at;
        local next_in = math.max(0, math.floor(ASK_EVERY - (os.clock() - asked_at)));
        imgui.TextColored(ui.color('dimmed'), string.format('%s  -  updates again in %ds.',
            (ago < 60) and 'Updated just now' or string.format('Updated %dm ago', math.floor(ago / 60)), next_in));
    end
end

-- Sky 2.0 (Escha - Ru'Aun): can you pop each god, do you have its key item, and its drops.
local SKY2 = {
    { god = 'Byakko', portal = 7,  ki = "Byakko's Pride" },
    { god = 'Genbu',  portal = 10, ki = "Genbu's Honor" },
    { god = 'Seiryu', portal = 13, ki = "Seiryu's Nobility" },
    { god = 'Suzaku', portal = 4,  ki = "Suzaku's Benefaction" },
    { god = 'Kirin',  portal = 15 },
};
local GREEN2, RED2, GOLD2 = { 0.45, 0.90, 0.45, 1.0 }, { 1.0, 0.45, 0.45, 1.0 }, { 1.0, 0.82, 0.25, 1.0 };

sky.render_sky2 = function (host)
    local ui = host.ui;
    scan();
    ask_if_due();
    local pushed = ui.pushWindowStyle();
    pops_age(ui, 'sky2');
    imgui.PushTextWrapPos(0);
    imgui.TextColored(ui.color('dimmed'), "Trade 25 of the god's Scraps to Dremi (Escha - Ru'Aun H-11), then use its Beacon on the island. Beating a god gives its key item; all four open Kirin.");
    imgui.PopTextWrapPos();
    imgui.Spacing();
    local sec = pops_section('sky 2.0');
    local kis = 0;

    -- Which god key items you have (from !pops), for Kirin's checklist.
    local have_ki = {};
    if (sec ~= nil) then
        for _, g in ipairs(SKY2) do
            for _, en in ipairs(sec.entries) do
                if (g.ki and en.ki and en.name:lower():find(g.god:lower(), 1, true)) then have_ki[g.god] = true; end
            end
        end
    end

    -- One key item line: green tick-style "Have" or red "Need".
    local function ki_line(x, name, have)
        imgui.SetCursorPosX(x);
        if (sec == nil) then
            imgui.TextColored(ui.color('dimmed'), '?');
        else
            imgui.TextColored(have and GREEN2 or RED2, have and 'Have' or 'Need');
        end
        imgui.SameLine(x + 44);
        imgui.TextColored((sec ~= nil) and (have and GREEN2 or RED2) or ui.color('dimmed'), name);
    end

    for _, g in ipairs(SKY2) do
        local entry = nil;
        if (sec ~= nil) then
            for _, en in ipairs(sec.entries) do
                if (en.name:lower():find(g.god:lower(), 1, true)) then entry = en; end
            end
        end
        if (entry and entry.ki and g.ki) then kis = kis + 1; end
        local state = (entry == nil) and '' or (entry.ready and '  -  can pop' or '  -  cannot pop yet');
        local label = string.format('%s (Portal #%d)%s%s', g.god, g.portal, state, (entry and entry.ki) and '  *' or '');
        if (ui.sectionHeader(label, nil, 'sky2:' .. g.god)) then
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 4);
            if (entry == nil) then
                imgui.TextColored(ui.color('dimmed'), 'Pop status: waiting for !pops');
            else
                imgui.TextColored(entry.ready and GREEN2 or RED2, entry.ready and 'You can pop it now.' or 'You cannot pop it yet.');
            end
            local x0 = imgui.GetCursorPosX() + 4;
            if (g.ki ~= nil) then
                imgui.SetCursorPosX(x0);
                imgui.TextColored(ui.color('dimmed'), 'Beating it gives:');
                ki_line(x0 + 12, g.ki, have_ki[g.god]);
            else
                local got = 0;
                for _, k in ipairs(SKY2) do if (k.ki and have_ki[k.god]) then got = got + 1; end end
                imgui.SetCursorPosX(x0);
                imgui.TextColored(ui.color('dimmed'), string.format('Needs all four key items  (%d / 4)', got));
                -- Two columns, two rows.
                local col2 = x0 + 12 + 230;
                local n = 0;
                for _, k in ipairs(SKY2) do
                    if (k.ki) then
                        n = n + 1;
                        if (n % 2 == 0) then
                            imgui.SameLine(col2);
                            ki_line(col2, k.ki, have_ki[k.god]);
                        else
                            ki_line(x0 + 12, k.ki, have_ki[k.god]);
                        end
                    end
                end
            end
            imgui.Spacing();
            local drops = DROPS[g.god];
            if (drops ~= nil) then draw_drops(host, g.god .. ' (Sky 2.0) drops', drops.sky2); end
        end
        imgui.Spacing();
    end
    ui.popWindowStyle(pushed);
end

-- Every section of the !pops answer.
sky.render_pops = function (host)
    local ui = host.ui;
    ask_if_due();
    local pushed = ui.pushWindowStyle();
    pops_age(ui, 'pops');
    imgui.Spacing();
    if (pops ~= nil) then
        for _, sec in ipairs(pops.sections) do
            local ready = 0;
            for _, en in ipairs(sec.entries) do if en.ready then ready = ready + 1; end end
            if (ui.sectionHeader(string.format('%s  (%d / %d can pop)', sec.title, ready, #sec.entries), nil, 'pops:' .. sec.title)) then
                for _, note in ipairs(sec.notes) do
                    imgui.SetCursorPosX(12);
                    imgui.PushTextWrapPos(0);
                    imgui.TextColored(ui.color('dimmed'), (note:gsub('%%', '%%%%')));
                    imgui.PopTextWrapPos();
                end
                for _, en in ipairs(sec.entries) do
                    imgui.SetCursorPosX(12);
                    imgui.TextColored(en.ready and GREEN2 or RED2, (en.ready and 'O  ' or 'X  ') .. en.name:gsub('%%', '%%%%'));
                    if (en.ki) then
                        imgui.SameLine(0, 8);
                        imgui.TextColored(GOLD2, '* key item');
                    end
                end
            end
            imgui.Spacing();
        end
    end
    ui.popWindowStyle(pushed);
end

return sky;
