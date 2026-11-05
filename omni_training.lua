--[[
    omni_training.lua - Training regime (Fields of Valor / Grounds of Tome) kill counts in a strip
    under omni's buff box (bottom left of the bar row), in omni's look.

        Crawlers' Nest   Worker Crawler 1/3   Death Jacket 3/3

    The tracking is trainmon by onimitch (MIT, trainmon\LICENSE_trainmon): it reads the Field
    Manual / Grounds Tome messages and "defeats the ..." lines in chat. Shown only while you're in
    the training's zone (unless "always"). Turn it on or off in Options > Bars.

        /tmon or /trainmon   status | reset | show | show always | hide
]]

local imgui = require('imgui');
local monitor_mod = require('trainmon.monitor');
local encoding = require('trainmon.encoding');
local chat_modes = require('trainmon.chat_modes');

local tr = {};
tr.settings = nil;            -- omni.settings (set by omni.lua)
tr.save = nil;                -- saves omni.settings

local mon = nil;
local job_main, job_sub = 0, 0;
local busy = false;
local open = { true };

local function say(t) print('\30\68[Training]\30\01 ' .. t); end
local function print_sjis(m) print(encoding:UTF8_To_ShiftJIS(m)); end

local function init()
    if mon ~= nil then return mon; end
    local lang = 2;
    pcall(function () lang = AshitaCore:GetConfigurationManager():GetInt32('boot', 'ashita.language', 'playonline', 2); end);
    mon = monitor_mod:new((lang == 1) and 'ja' or 'en', print_sjis);
    return mon;
end
pcall(init);

local function zone_now()
    local z = 0;
    pcall(function () z = tonumber(AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)) or 0; end);
    return z;
end

local function opt(k, d)
    local s = tr.settings;
    if s == nil or s[k] == nil then return d; end
    return s[k];
end

-- Chat: training set up / kills / done (the same lines trainmon reads).
ashita.events.register('text_in', 'omni_training_text', function (e)
    if e.injected or mon == nil then return; end
    local mode = bit.band(e.mode, 0xFF);
    -- every chat line (CatsEyeXI/VanaCore can use other modes for kill lines); the patterns are exact
    if busy then return; end
    busy = true;
    local ok, err = pcall(function () mon:process_input(mode, encoding:ShiftJIS_To_UTF8(e.message)); end);
    busy = false;
    if not ok then LogManager:Log(5, 'omni', 'training: ' .. tostring(err)); end
end);

-- A job change ends the training regime in game, so clear it here too (as trainmon does).
local last_check = 0;
local function check_job()
    if os.clock() - last_check < 1 then return; end
    last_check = os.clock();
    local p = AshitaCore:GetMemoryManager():GetPlayer();
    if p == nil then return; end
    local m, s = p:GetMainJob(), p:GetSubJob();
    if m == 0 then return; end
    if job_main == 0 then job_main, job_sub = m, s; return; end
    if m ~= job_main or s ~= job_sub then
        job_main, job_sub = m, s;
        if mon then mon:reset_training_data(); mon:save_training_data(); end
    end
end

-- Should the strip show right now?
tr.visible = function ()
    if mon == nil or #mon._target_monsters == 0 then return false; end
    if opt('train_bar', true) == false then return false; end
    return opt('train_always', false) or mon._target_zone_id == zone_now();
end

-- Draw the strip at x, y (screen), w wide, in the same style as the monster strip beside it.
-- top: extra room above the text (the buff times sit there). Returns its height (0 if not shown).
tr.HEIGHT = 20;
tr.draw = function (x, y, w, c, top)
    pcall(check_job);
    if not tr.visible() then return 0; end
    top = top or 0;
    local zname = '';
    pcall(function ()
        zname = encoding:ShiftJIS_To_UTF8(AshitaCore:GetResourceManager():GetString('zones.names', mon._target_zone_id), true) or '';
    end);
    imgui.SetNextWindowPos({ x, y }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ w, tr.HEIGHT + top }, ImGuiCond_Always);
    -- Same frame as the bars above (the crystal / themed looks draw their own border).
    local orn = tr.look ~= nil and tr.look.crystal();
    imgui.PushStyleColor(ImGuiCol_WindowBg, orn and { 0, 0, 0, 0 } or c.bg);
    imgui.PushStyleColor(ImGuiCol_Border, orn and { 0, 0, 0, 0 } or c.border);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 10, 2 });
    if orn then imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 0); end
    imgui.PushStyleVar(ImGuiStyleVar_ItemSpacing, { 0, 0 });
    local flags = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoSavedSettings,
        ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoScrollbar);
    open[1] = true;
    if imgui.Begin('OmniTraining', open, flags) then
        if orn then
            local wx, wy = imgui.GetWindowPos();
            pcall(tr.look.frame, imgui.GetWindowDrawList(), wx + 1, wy + 1, wx + w - 1, wy + tr.HEIGHT + top - 1);
        end
        imgui.SetWindowFontScale(0.85);
        if top > 0 then imgui.SetCursorPosY(imgui.GetCursorPosY() + top); end
        local dim, text = c.dim or { 0.6, 0.6, 0.65, 1 }, c.text or { 1, 1, 1, 1 };
        local GREEN, AMBER = { 0.50, 0.92, 0.50, 1.0 }, { 1.0, 0.75, 0.35, 1.0 };
        -- What goes on the line: "Zone:  Name n/N   Name n/N"
        local items = {};
        for _, v in ipairs(mon._target_monsters) do
            local done = (v.count or 0) >= (v.total or 0);
            items[#items + 1] = { name = v.name or '?', count = ('%d/%d'):format(v.count or 0, v.total or 0), done = done };
        end
        local room = w - 20;
        local function width(show_zone, cut)
            local tw = show_zone and (imgui.CalcTextSize(zname .. ':') + 10) or 0;
            for i, it in ipairs(items) do
                local n = cut and it.name:sub(1, cut) or it.name;
                tw = tw + imgui.CalcTextSize(n) + 5 + imgui.CalcTextSize(it.count) + ((i > 1) and 14 or 0);
            end
            return tw;
        end
        -- Fit on one line: drop the zone name first, then shorten the monster names.
        local show_zone, cut = zname ~= '', nil;
        if width(show_zone, nil) > room then show_zone = false; end
        if width(false, nil) > room then
            cut = 14;
            while cut > 4 and width(false, cut) > room do cut = cut - 1; end
        end
        local first = true;
        local function put(t, col, gap)
            if not first then imgui.SameLine(0, gap); end
            first = false;
            imgui.TextColored(col, t);
        end
        if show_zone then put(zname .. ':', dim); end
        for i, it in ipairs(items) do
            local n = it.name;
            if cut and #n > cut then n = n:sub(1, cut - 1) .. '.'; end
            put(n, it.done and GREEN or text, (i == 1 and show_zone) and 10 or 14);
            put(it.count, it.done and GREEN or AMBER, 5);
        end
        if imgui.IsWindowHovered() then
            local lines = { 'Training regime' .. (zname ~= '' and (' - ' .. zname) or '') };
            local all_done = true;
            for _, v in ipairs(mon._target_monsters) do
                local d = (v.count or 0) >= (v.total or 0);
                if not d then all_done = false; end
                lines[#lines + 1] = ('  %s  %d / %d%s'):format(v.name or '?', v.count or 0, v.total or 0, d and '  done' or '');
            end
            if all_done then lines[#lines + 1] = 'All done - the regime finishes with the next kill message.'; end
            lines[#lines + 1] = '(/tmon status | reset | show always | hide)';
            imgui.SetTooltip(table.concat(lines, '\n'));
        end
    end
    imgui.End();
    imgui.PopStyleVar(orn and 3 or 2);
    imgui.PopStyleColor(2);
    return tr.HEIGHT + top;
end

ashita.events.register('command', 'omni_training_cmd', function (e)
    local a = e.command:args();
    if #a == 0 then return; end
    local c0 = a[1]:lower();
    if c0 ~= '/tmon' and c0 ~= '/trainmon' then return; end
    e.blocked = true;
    init();
    local c = (a[2] or 'status'):lower();
    if c == 'st' or c == 'status' then
        if #mon._target_monsters == 0 then say('no training regime.'); return; end
        local zn = '';
        pcall(function () zn = encoding:ShiftJIS_To_UTF8(AshitaCore:GetResourceManager():GetString('zones.names', mon._target_zone_id), true); end);
        say('training in ' .. zn .. ':');
        for i, v in ipairs(mon._target_monsters) do say(('  %d: %s (%d/%d)'):format(i, v.name, v.count, v.total)); end
    elseif c == 'reset' then
        mon:reset_training_data(); mon:save_training_data();
        say('training data cleared (your regime in game is not cancelled).');
    elseif c == 'show' then
        if tr.settings then tr.settings.train_bar = true; tr.settings.train_always = (a[3] or ''):lower() == 'always'; end
        if tr.save then pcall(tr.save); end
        say('shown' .. ((tr.settings and tr.settings.train_always) and ' in every zone.' or ' in the training zone.'));
    elseif c == 'hide' then
        if tr.settings then tr.settings.train_bar = false; tr.settings.train_always = false; end
        if tr.save then pcall(tr.save); end
        say('hidden - /tmon show to bring it back.');
    else
        say('/tmon status | reset | show | show always | hide');
    end
end);

return tr;
