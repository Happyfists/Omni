--[[
    omni_jailers.lua - Sea > Jailers: the Sea NM pop chain.

    For every Jailer, Ix'aern and Absolute Virtue: what to trade, where the ??? is (zone and map
    grid), where each pop item comes from, and what it drops. Pop items you are holding (any bag)
    show green with the count.

    Sources: retail-era Sea data (HorizonXI wiki, Allakhazam) plus the CatsEyeXI changes listed on
    bg-wiki "CatsEyeXI Content/Sea". The live server can differ - lines marked (check) were not
    confirmed by any source.
]]

local imgui = require('imgui');

local jailers = {};

local GOLD  = { 0.90, 0.78, 0.40, 1.0 };
local TEXT  = { 0.92, 0.92, 0.95, 1.0 };
local DIM   = { 0.62, 0.66, 0.80, 1.0 };
local GREEN = { 0.45, 0.88, 0.45, 1.0 };
local RED   = { 1.00, 0.50, 0.45, 1.0 };
local CATS  = { 0.55, 0.80, 1.00, 1.0 };

-- pop    = items traded ({ name, how many })
-- from   = where each pop item comes from (same order as pop)
-- where  = zone and ??? position
-- drops  = main drops; cats = CatsEyeXI extras (bg-wiki CatsEyeXI Content/Sea)
local NMS = {
    { group = 'Step 1 - the first three Virtues' },
    { name = 'Jailer of Temperance', zone = "Grand Palace of Hu'Xzoi",
      where = "Kill the Eo'zdei placeholders in the small alcove rooms, upper (entrance) level: H-4, C-8, L-8, J-13, F-13. It pops 3-5 sec after the right one dies. The placeholder changes about every 15 min.",
      pop = {}, from = {},
      drops = 'First Virtue (100%), Temperance Axe (100%), Temperance Torque (~10%)' },
    { name = 'Jailer of Fortitude', zone = "The Garden of Ru'Hmet",
      where = "??? in the small room on the outer edge of the ground floor of one of the five towers. Comes back 5 min after it dies, in a random tower.",
      pop = { { 'Ghrah M Chip', 12 } }, from = { "Aw'ghrah (Garden of Ru'Hmet)" },
      drops = 'Second Virtue (100%), Fortitude Axe (100%), Fortitude Torque (~16%)' },
    { name = 'Jailer of Faith', zone = "The Garden of Ru'Hmet",
      where = "??? on the 2nd floor of one of the five towers, in the small Aw'euvhi room on the side facing the middle of the map. Moves every 15-30 min; back 3 min after a kill.",
      pop = { { 'High-Quality Euvhi Organ', 1 } }, from = { "Aw'euvhi (Garden of Ru'Hmet)" },
      drops = 'Third Virtue (100%), Faith Baghnakhs (100%), Faith Torque (~20%)' },

    { group = "Step 2 - the Deeds (Ix'aern)" },
    { name = "Ix'aern (DRK)", zone = "The Garden of Ru'Hmet",
      where = "??? on the ground floor at F-8, J-8, F-10 or J-10 (moves every 30 min). Kill the aerns in the room next to it until someone gets \"enveloped in sheer animosity\", then that player checks the ??? within 10 min. Two Qn'aern come with it.",
      pop = {}, from = {},
      drops = 'Deed of Moderation  or  Vice of Avarice (Altruistic Cape)', cats = 'CatsEyeXI: 60% chance to reraise.' },
    { name = "Ix'aern (DRG)", zone = "The Garden of Ru'Hmet",
      where = "Trade 1-3 organs to the ??? (check: basement, G-7 or I-7). More organs = more Qn'aern helpers but a better drop chance (1 = 33%, 2 = 66%, 3 = 100%).",
      pop = { { 'Aern Organ', 3 } }, from = { "Aw'aern (Garden of Ru'Hmet)" },
      drops = 'Deed of Sensibility  or  Vice of Aspersion' },
    { name = "Ix'aern (MNK)", zone = "Grand Palace of Hu'Xzoi",
      where = "Trade 1-3 organs to the ??? at G-6 or I-6, first floor. More organs = more helpers but a better drop chance.",
      pop = { { 'High-Quality Aern Organ', 3 } }, from = { "Aerns in Hu'Xzoi (check)" },
      drops = 'Deed of Placidity  or  Vice of Antipathy' },

    { group = "Step 3 - Al'Taieu Jailers" },
    { name = 'Jailer of Hope', zone = "Al'Taieu",
      where = '??? at D-9.',
      pop = { { 'First Virtue', 1 }, { 'Deed of Placidity', 1 }, { 'High-Quality Phuabo Organ', 1 } },
      from = { 'Jailer of Temperance', "Ix'aern (MNK)", "Phuabo NMs in Al'Taieu (check)" },
      drops = 'Fifth Virtue (100%), Hope Staff (100%), Hope Torque (~15-23%)',
      cats = 'CatsEyeXI: also Galateia, H.Q. Phuabo Organ. Lv92 WAR, Mighty Strikes every 90s from 95%.' },
    { name = 'Jailer of Justice', zone = "Al'Taieu",
      where = '??? at F-11.',
      pop = { { 'Second Virtue', 1 }, { 'Deed of Moderation', 1 }, { 'High-Quality Xzomit Organ', 1 } },
      from = { 'Jailer of Fortitude', "Ix'aern (DRK)", "Xzomit NMs in Al'Taieu (check)" },
      drops = 'Fourth Virtue (100%), Justice Sword (100%), Justice Torque (~15-18%)',
      cats = "CatsEyeXI: also Kunwu Iron, H.Q. Xzomit Organ. 30 min rage, charm every 4 min, a Qn'xzomit every 30s (max 6)." },
    { name = 'Jailer of Prudence', zone = "Al'Taieu",
      where = '??? at L-8. Two of them pop.',
      pop = { { 'Third Virtue', 1 }, { 'Deed of Sensibility', 1 }, { 'High-Quality Hpemde Organ', 1 } },
      from = { 'Jailer of Faith', "Ix'aern (DRG)", "Hpemde NMs in Al'Taieu (check)" },
      drops = 'Sixth Virtue (100%), Prudence Rod (100%), Prudence Torque (~15-22%)',
      cats = "CatsEyeXI: also Mercurial Kris, Toreador's Ring, Beech Log, H.Q. Hpemde Organ. Kill one, let it DESPAWN, then kill the other - both dying together = no loot." },

    { group = 'Step 4 - Love and Absolute Virtue' },
    { name = 'Jailer of Love', zone = "Al'Taieu",
      where = '??? at K-12. Despawns 2 hours after it pops.',
      pop = { { 'Fourth Virtue', 1 }, { 'Fifth Virtue', 1 }, { 'Sixth Virtue', 1 } },
      from = { 'Jailer of Justice', 'Jailer of Hope', 'Jailer of Prudence' },
      drops = 'Love Torque, Love Halberd, Aura of Adulation / Aura of Voracity',
      cats = "CatsEyeXI: Suspended Virtue (pops AV), Kejusu Satin, Yovra Organ, one of 10 weapons (10% each). Unkillable until 9 Qn'xzomit + 9 Qn'hpemde die. 80 min rage." },
    { name = 'Absolute Virtue', zone = "Al'Taieu",
      where = 'CatsEyeXI: trade Suspended Virtue to the ??? at K-12 (the Love spot).',
      pop = { { 'Suspended Virtue', 1 } }, from = { 'Jailer of Love (CatsEyeXI)' },
      drops = 'Virtue Ring, Virtue Sash, Virtue Torque (Synergy), Shining Memory',
      cats = 'CatsEyeXI: Shining Memory trades at the ??? for any Jailer of Love weapon. The AV tab has the 2-hour helper.' },
};

-- How many of each pop item you hold (all bags), looked up every few seconds.
local held, held_at = {}, -100;
local BAGS = { [0] = 'Inventory', 'Mog Safe', 'Storage', 'Temporary', 'Mog Locker', 'Mog Satchel', 'Mog Sack', 'Mog Case',
    'Wardrobe', 'Mog Safe 2', 'Wardrobe 2', 'Wardrobe 3', 'Wardrobe 4', 'Wardrobe 5', 'Wardrobe 6', 'Wardrobe 7', 'Wardrobe 8' };
local where_held = {};   -- lowercase name -> { bag name = count }
local ids = nil;         -- item id -> lowercase pop item name (looked up once)

local function scan(force)
    if not force and os.clock() - held_at < 3 then return; end
    held_at = os.clock();
    local found, at = {}, {};
    pcall(function ()
        local inv = AshitaCore:GetMemoryManager():GetInventory();
        local res = AshitaCore:GetResourceManager();
        -- Match by item number as well as by name, so a name spelt differently still counts.
        if ids == nil then
            ids = {};
            for _, nm in ipairs(NMS) do
                for _, p in ipairs(nm.pop or {}) do
                    for _, lang in ipairs({ 0, 2, 1 }) do
                        local ok, r = pcall(function () return res:GetItemByName(p[1], lang); end);
                        if ok and r ~= nil and r.Id ~= nil and r.Id ~= 0 then ids[r.Id] = p[1]:lower(); break; end
                    end
                end
            end
        end
        local wanted = {};
        for _, nm in ipairs(NMS) do for _, p in ipairs(nm.pop or {}) do wanted[p[1]:lower()] = true; end end
        for bag = 0, 16 do
            -- Every slot, not just up to the bag's size (a bag that is not loaded can report 0).
            for slot = 0, 80 do
                local ok, it = pcall(function () return inv:GetContainerItem(bag, slot); end);
                if ok and it ~= nil and it.Id ~= nil and it.Id ~= 0 and it.Id ~= 65535 then
                    local n = ids[it.Id];
                    if n == nil then
                        local r = res:GetItemById(it.Id);
                        local nn = r and r.Name and r.Name[1];
                        if nn ~= nil and wanted[nn:lower()] then n = nn:lower(); end
                    end
                    if n ~= nil then
                        local c = (it.Count ~= nil and it.Count > 0) and it.Count or 1;
                        found[n] = (found[n] or 0) + c;
                        at[n] = at[n] or {};
                        local bn = BAGS[bag] or ('bag ' .. bag);
                        at[n][bn] = (at[n][bn] or 0) + c;
                    end
                end
            end
        end
    end);
    held, where_held = found, at;
end

local function wrap(col, text)
    imgui.PushTextWrapPos(0);
    imgui.TextColored(col, (text:gsub('%%', '%%%%')));
    imgui.PopTextWrapPos();
end

local function ready(nm)
    if #nm.pop == 0 then return nil; end
    for _, p in ipairs(nm.pop) do
        if (held[p[1]:lower()] or 0) < (p[2] == 3 and 1 or p[2]) then return false; end
    end
    return true;
end

jailers.render = function (host)
    local ui = host.ui;
    scan();
    -- First time: every NM starts folded (just its heading), so the page stays short.
    if not ui.isFolded('jailer:started') then
        ui.toggleFold('jailer:started');
        for _, nm in ipairs(NMS) do
            if nm.name and not ui.isFolded('jailer:' .. nm.name) then ui.toggleFold('jailer:' .. nm.name); end
        end
    end
    local pushed = ui.pushWindowStyle();
    imgui.Spacing();
    if imgui.Button('Rescan bags##jl_rescan') then
        scan(true);
        local t = {};
        for n, c in pairs(held) do t[#t + 1] = ('%s x%d'):format(n, c); end
        table.sort(t);
        print('\30\68[omni Jailers]\30\01 ' .. (#t > 0 and ('found: ' .. table.concat(t, ', ')) or 'no Sea pop items found in any bag.'));
    end
    if imgui.IsItemHovered() then imgui.SetTooltip('Look through every bag again (inventory, safes, storage, locker,\nsatchel, sack, case, wardrobes). It also checks by itself every 3 sec.'); end
    imgui.Spacing();
    wrap(DIM, 'Temperance, Fortitude, Faith -> 1st/2nd/3rd Virtue.  Ix\'aern -> Deeds.  Hope, Justice, Prudence -> 5th/4th/6th Virtue.  Love -> Suspended Virtue -> AV.');
    imgui.Spacing();
    for _, nm in ipairs(NMS) do
        if nm.group then
            imgui.Spacing();
            imgui.TextColored(GOLD, nm.group);
            imgui.Separator();
        else
            local r = ready(nm);
            local tag = (r == true) and '   - ready to pop' or '';
            if ui.sectionHeader(nm.name .. '  -  ' .. nm.zone .. tag, nil, 'jailer:' .. nm.name) then
                imgui.Indent(12);
                imgui.TextColored(GOLD, 'Where');
                imgui.SameLine(70);
                wrap(TEXT, nm.where);
                if #nm.pop > 0 then
                    imgui.TextColored(GOLD, 'Trade');
                    for i, p in ipairs(nm.pop) do
                        local have = held[p[1]:lower()] or 0;
                        local need = p[2];
                        local want = (need == 3) and 1 or need;
                        local ok = have >= want;
                        if i == 1 then imgui.SameLine(70); else imgui.SetCursorPosX(70); end
                        imgui.TextColored(ok and GREEN or RED, p[1]);
                        imgui.SameLine(0, 8);
                        imgui.TextColored(ok and GREEN or RED, ('%d/%d'):format(have, want) .. ((need == 3) and ' (up to 3)' or ''));
                        if imgui.IsItemHovered() and where_held[p[1]:lower()] then
                            local t = {};
                            for bn, c in pairs(where_held[p[1]:lower()]) do t[#t + 1] = ('%s: %d'):format(bn, c); end
                            imgui.SetTooltip(table.concat(t, '\n'));
                        end
                        imgui.SetCursorPosX(88);
                        imgui.TextColored(DIM, 'from ' .. (nm.from[i] or '?'));
                    end
                end
                imgui.TextColored(GOLD, 'Drops');
                imgui.SameLine(70);
                wrap(TEXT, nm.drops);
                if nm.cats then
                    imgui.SetCursorPosX(70);
                    wrap(CATS, nm.cats);
                end
                imgui.Unindent(12);
                imgui.Spacing();
            end
        end
    end
    imgui.Spacing();
    wrap(DIM, 'Green = you have it (any bag). Grids are the in-game map grid. Lines marked (check) are not confirmed for CatsEyeXI.');
    ui.popWindowStyle(pushed);
end

return jailers;
