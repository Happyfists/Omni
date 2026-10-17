--[[
    omni_talks.lua - Happy Talks: spoken alerts (Options > Happy Talks).

    Says something when you get a tell, a GM tell, a party or alliance invite, a trade, an emote at
    you, someone checks you, your bags are full, you skill up, or someone says your name in chat.
    Pick a voice pack (assets/alerts/<pack>/<alert>.wav), test each one, and switch each alert on
    or off.

    Based on chatmon by atom0s (Ashita Development Team, GNU GPL v3) - the same events, read the
    same way. Voices made with Kokoro TTS; "Classic" is chatmon's own clips; "Chimes" has no voice.
    Unload chatmon when using this, or you'll hear both.
]]

local imgui = require('imgui');

local talks = {};
talks.settings = nil;

-- The voice packs, in the order shown.
talks.PACKS = {
    { id = 'random',  label = 'Random!',   tip = 'a different voice pack every time' },
    { id = 'heart',   label = 'Heart',     tip = 'US woman' },
    { id = 'emma',    label = 'Emma',      tip = 'British woman' },
    { id = 'lily',    label = 'Lily',      tip = 'British woman' },
    { id = 'sky',     label = 'Sky',       tip = 'soft US woman' },
    { id = 'michael', label = 'Michael',   tip = 'US man' },
    { id = 'george',  label = 'George',    tip = 'British man' },
    { id = 'moogle',  label = 'Moogle',    tip = 'kupo!' },
    { id = 'butler',  label = 'Butler',    tip = 'very proper' },
    { id = 'pirate',  label = 'Pirate',    tip = 'arr!' },
    { id = 'hype',    label = 'HYPE!!!',   tip = 'way over the top, with an air horn' },
    { id = 'comedy',  label = 'Comedy',    tip = 'cheeky jokes' },
    { id = 'drunk',   label = 'Drunk',     tip = 'one too many at the Kazham bar' },
    { id = 'rude',    label = 'Rude',      tip = 'oi, numpty!' },
    { id = 'sweary',  label = 'Sweary',    tip = 'mild swearing - bloody hell!' },
    { id = 'violent', label = 'Violent',   tip = 'cartoon berserker - SMASH!' },
    { id = 'grumpy',  label = 'Grumpy',    tip = 'not impressed' },
    { id = 'whisper', label = 'Whisper',   tip = 'psst...' },
    { id = 'frat',    label = 'Frat Bro',  tip = 'brooo, gains' },
    { id = 'fratgirl',label = 'Frat Girl', tip = 'oh my gosh, literally' },
    { id = 'indian',  label = 'Indian',    tip = 'kindly do the needful' },
    { id = 'german',  label = 'German',    tip = 'Achtung! very efficient' },
    { id = 'italian', label = 'Italian',   tip = 'mamma mia!' },
    { id = 'aussie',  label = 'Aussie',    tip = 'crikey, mate!' },
    { id = 'southern',label = 'Southern',  tip = 'well, bless your heart' },
    { id = 'chinese', label = 'Chinese',   tip = 'very lucky, very good!' },
    { id = 'singalong',label = 'Sing-along', tip = 'old nursery tunes, new words' },
    { id = 'quotes',  label = 'Quotes',    tip = 'Shakespeare and history, Vana\'diel style' },
    { id = 'trailer', label = 'Trailer',   tip = 'in a world... (movie trailer voice)' },
    { id = 'nature',  label = 'Nature Show', tip = 'hushed wildlife documentary' },
    { id = 'action',  label = 'Action Hero', tip = 'gruff, explosions' },
    { id = 'royal',   label = 'Royal',     tip = 'one is most amused' },
    { id = 'football',label = 'Football',  tip = 'GET IN! back of the net!' },
    { id = 'wrestling',label = 'Wrestling', tip = 'ring the bell!' },
    { id = 'wizard',  label = 'Wizard',    tip = 'wise old mage' },
    { id = 'classic', label = 'Classic',   tip = "chatmon's own voice" },
    { id = 'chimes',  label = 'Chimes',    tip = 'no voice, just tones' },
};

-- The alerts: key (also the .wav name), label, seconds before it can sound again.
talks.ALERTS = {
    { key = 'tell',     label = 'Tell',                 delay = 15 },
    { key = 'gm',       label = 'Tell from a GM',       delay = 5 },
    { key = 'invite',   label = 'Party / alliance invite', delay = 5 },
    { key = 'trade',    label = 'Trade',                delay = 5 },
    { key = 'emote',    label = 'Emote at you',         delay = 5 },
    { key = 'examined', label = 'Someone checks you',   delay = 5 },
    { key = 'bags',     label = 'Bags full',            delay = 30 },
    { key = 'skillup',  label = 'Skill up',             delay = 10 },
    { key = 'name',     label = 'Your name said in chat', delay = 5 },
};
local DELAY = {};
for _, a in ipairs(talks.ALERTS) do DELAY[a.key] = a.delay; end

local function S() return talks.settings or {}; end
local function on(key, default) local v = S()[key]; if v == nil then return default; end return v == true; end
local function pack() return S().talk_pack or 'heart'; end

local function base()
    return (addon.path:gsub('[\\/]+$', '')) .. '\\assets\\alerts\\';
end

-- Play one alert's clip from a pack (the current one unless given).
-- "Random!" picks any voiced pack (not Chimes) each time, never the same one twice running.
local last_rand = nil;
local function random_pack()
    local pool = {};
    for _, p in ipairs(talks.PACKS) do
        if p.id ~= 'random' and p.id ~= 'chimes' and p.id ~= last_rand then pool[#pool + 1] = p.id; end
    end
    last_rand = pool[math.random(#pool)];
    return last_rand;
end
math.randomseed(os.time());

talks.play = function (key, pk)
    pk = pk or pack();
    if pk == 'random' then pk = random_pack(); end
    local path = base() .. pk .. '\\' .. key .. '.wav';
    pcall(function () ashita.misc.play_sound(path); end);
end

local last = {};
local function alert(key)
    if not on('talk_on', true) or not on('talk_' .. key, true) then return; end
    local now = os.time();
    if last[key] and (now - last[key]) < (DELAY[key] or 5) then return; end
    last[key] = now;
    talks.play(key);
end

----------------------------------------------------------------------------------------------------
-- Events (as chatmon reads them)
----------------------------------------------------------------------------------------------------
local bag_check = 0;
local function bags_full()
    local inv = AshitaCore:GetMemoryManager():GetInventory();
    if inv == nil then return false; end
    local cnt = inv:GetContainerCount(0);
    return cnt > 0 and cnt >= inv:GetContainerCountMax(0);
end

local function on_packet(e)
    local d = e.data_modified or e.data;
    if e.id == 0x017 then                                         -- chat: tells
        if struct.unpack('b', d, 0x04 + 1) == 0x03 then
            if struct.unpack('b', d, 0x05 + 1) == 0 then alert('tell'); else alert('gm'); end
        end
    elseif e.id == 0x0DC then                                     -- party / alliance invite
        local kind = struct.unpack('b', d, 0x0B + 1);
        if kind == 0 or kind == 5 then alert('invite'); end
    elseif e.id == 0x021 then                                     -- trade request
        alert('trade');
    elseif e.id == 0x05A or e.id == 0x11E then                    -- emote (and jump emote) at you
        local t = (e.id == 0x05A) and struct.unpack('H', d, 0x0E + 1) or struct.unpack('H', d, 0x04 + 1);
        local me = GetPlayerEntity();
        if me ~= nil and t == me.TargetIndex then alert('emote'); end
    elseif e.id == 0x009 then                                     -- someone checks you
        if struct.unpack('H', d, 0x0A + 1) == 0x0059 then alert('examined'); end
    elseif e.id == 0x029 then                                     -- skill up
        local m = struct.unpack('H', d, 0x18 + 1);
        if m == 38 or m == 53 then alert('skillup'); end
    end
    -- Bags: looked at every 10 seconds or so.
    local now = os.time();
    if now - bag_check >= 10 then
        bag_check = now;
        if bags_full() then alert('bags'); end
    end
end

-- Your name in say, shout, yell, linkshells, party, unity or assist - but not your own lines.
local NAME_MODES = { [9] = true, [10] = true, [11] = true, [13] = true, [14] = true, [214] = true, [212] = true, [220] = true, [222] = true };
local function on_text(e)
    local mode = bit.band(e.mode_modified or e.mode or 0, 0xFF);
    if not NAME_MODES[mode] then return; end
    local name = AshitaCore:GetMemoryManager():GetParty():GetMemberName(0);
    if name == nil or name == '' then return; end
    local msg = (e.message_modified or e.message or ''):gsub('[\30\31].', '');
    local low, lname = msg:lower(), name:lower();
    if not low:find(lname, 1, true) then return; end
    -- Skip what you said yourself ("Name : ...", "<Name>", "(Name)", "[1]<Name>").
    if low:find(lname .. ' :', 1, true) or low:find('<' .. lname .. '>', 1, true) or low:find('(' .. lname .. ')', 1, true) then return; end
    alert('name');
end

ashita.events.register('packet_in', 'omni_talks_in', function (e) pcall(on_packet, e); end);
ashita.events.register('text_in', 'omni_talks_text', function (e) if not e.injected then pcall(on_text, e); end end);

----------------------------------------------------------------------------------------------------
-- Options > Happy Talks
----------------------------------------------------------------------------------------------------
local GOLD, DIM, TEXT = { 0.90, 0.78, 0.40, 1.0 }, { 0.62, 0.66, 0.80, 1.0 }, { 0.92, 0.92, 0.95, 1.0 };

talks.render = function (opts)
    talks.settings = opts.settings or talks.settings;
    local s = S();
    local function save() if opts.save then pcall(opts.save); end end

    local master = { on('talk_on', true) };
    if imgui.Checkbox('Happy Talks on##talk_on', master) then s.talk_on = master[1]; save(); end
    imgui.SameLine(0, 8);
    imgui.TextColored(DIM, 'spoken alerts for tells, invites, trades and more');
    imgui.Dummy({ 1, 4 });

    -- Voice packs: click to use, Play to hear it first.
    imgui.TextColored(GOLD, 'Voice');
    local cur = pack();
    local W = imgui.GetContentRegionAvail();
    local per = (W > 520) and 3 or 2;
    local cw = math.floor((W - (per - 1) * 8) / per);
    for i, p in ipairs(talks.PACKS) do
        if (i - 1) % per ~= 0 then imgui.SameLine(0, 8); end
        local sel = (cur == p.id);
        local pw = imgui.CalcTextSize('Play') + 14;
        imgui.PushStyleColor(ImGuiCol_Button, sel and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
        if imgui.Button((sel and '> ' or '') .. p.label .. '##talk_pk' .. i, { cw - pw - 4, 0 }) then
            s.talk_pack = p.id; save(); talks.play('tell', p.id);
        end
        imgui.PopStyleColor(1);
        if imgui.IsItemHovered() then imgui.SetTooltip(p.tip); end
        imgui.SameLine(0, 4);
        if imgui.Button('Play##talk_pp' .. i, { pw, 0 }) then talks.play('tell', p.id); end
    end
    imgui.Dummy({ 1, 6 });

    -- Each alert: on/off and a test button.
    imgui.TextColored(GOLD, 'Alerts');
    local x0 = imgui.GetCursorPosX();
    for i, a in ipairs(talks.ALERTS) do
        local v = { on('talk_' .. a.key, true) };
        if imgui.Checkbox(a.label .. '##talk_a' .. i, v) then s['talk_' .. a.key] = v[1]; save(); end
        imgui.SameLine(x0 + 250);
        if imgui.SmallButton('Test##talk_t' .. i) then talks.play(a.key); end
    end
    imgui.Dummy({ 1, 6 });

    imgui.TextColored(DIM, 'Using chatmon too? Unload it so you only hear one.');
    imgui.SameLine(0, 8);
    if imgui.SmallButton('Unload chatmon##talk_unl') then
        pcall(function () AshitaCore:GetChatManager():QueueCommand(-1, '/addon unload chatmon'); end);
    end
end

return talks;
