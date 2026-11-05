--[[
    omni_abyatma.lua - "Atma" page of omni's Abyssea tab: every atma and abyssite.

      Atma       by zone (opens on the zone you are in), with the NM that drops it, what it does,
                 and a tick for the ones you have. "Other" holds the atma that no zone NM drops.
      Abyssites  each kind, how many of its colours you have, and what it does.
    Hover any row for the game's own key item text. The search box looks through names, NMs and
    effects of everything at once.

    Data: abydata/atma_data.lua (LandSandBoat server scripts + bg-wiki, see that file).
    Key items you have come from the NM Pops page's key item tracking (omni_abypops.lua).
]]

local imgui = require('imgui');

local atma = {};

local data = require('abydata.atma_data');

local ZONES = { 'Konschtat', 'La Theine', 'Tahrongi', 'Attohwa', 'Misareaux', 'Vunkerl',
                'Altepa', 'Uleguerand', 'Grauberg', 'Other' };
local ZONE_IDS = { [15] = 'Konschtat', [132] = 'La Theine', [45] = 'Tahrongi', [215] = 'Attohwa',
    [216] = 'Misareaux', [217] = 'Vunkerl', [218] = 'Altepa', [253] = 'Uleguerand', [254] = 'Grauberg' };
local EXPANSION = { Konschtat = 'Vision', ['La Theine'] = 'Vision', Tahrongi = 'Vision',
    Attohwa = 'Scars', Misareaux = 'Scars', Vunkerl = 'Scars',
    Altepa = 'Heroes', Uleguerand = 'Heroes', Grauberg = 'Heroes', Other = '' };

local C = {
    gold = { 0.90, 0.78, 0.40, 1.0 }, text = { 0.92, 0.92, 0.95, 1.0 }, dim = { 0.62, 0.66, 0.80, 1.0 },
    faint = { 0.42, 0.44, 0.52, 1.0 }, green = { 0.45, 0.88, 0.45, 1.0 }, fx = { 0.70, 0.82, 1.00, 1.0 },
};

local st = { view = 'atma', zone = nil, last_game_zone = -1, search = { '' } };

-- Set by omni.lua: the NM Pops module, for its key item tracking.
atma.pops = nil;

local function has(id)
    local p = atma.pops;
    if p ~= nil and p.has_ki_id ~= nil then
        local ok, r = pcall(p.has_ki_id, id);
        if ok then return r == true; end
    end
    local r = false;
    pcall(function () r = AshitaCore:GetMemoryManager():GetPlayer():HasKeyItem(id) == true; end);
    return r;
end

-- The game's own name / text for a key item (cached).
local names, texts = {}, {};
local function ki_name(id, fallback)
    if names[id] == nil then
        local n = nil;
        pcall(function () n = AshitaCore:GetResourceManager():GetString('keyitems.names', id); end);
        names[id] = (type(n) == 'string' and #n > 1) and n or (fallback or ('Key item ' .. id));
    end
    return names[id];
end
local function ki_text(id)
    if texts[id] == nil then
        local t = nil;
        pcall(function () t = AshitaCore:GetResourceManager():GetString('keyitems.descriptions', id); end);
        texts[id] = (type(t) == 'string' and #t > 1) and t:gsub('[%c]+', ' ') or false;
    end
    return texts[id] or nil;
end

local function zone_of(a) return (a.zone ~= nil and a.zone ~= '') and a.zone or 'Other'; end

local function head_button(label, on)
    imgui.PushStyleColor(ImGuiCol_Button, on and { 0.55, 0.45, 0.18, 1.0 } or { 0.16, 0.17, 0.26, 1.0 });
    imgui.PushStyleColor(ImGuiCol_Text, on and { 1, 0.96, 0.85, 1 } or C.dim);
    local text = label:gsub('##.*$', '');
    local clicked = imgui.Button(label, { imgui.CalcTextSize(text) + 18, 0 });
    imgui.PopStyleColor(2);
    return clicked;
end

-- Every search word must appear somewhere in the text.
local function matches(text, words)
    for _, w in ipairs(words) do
        if not text:find(w, 1, true) then return false; end
    end
    return true;
end

local function atma_row(a, i, wrap_at, show_zone)
    local owned = has(a.id);
    local name = ki_name(a.id, a.name);
    imgui.TextColored(owned and C.green or C.faint, owned and '+' or '-');
    imgui.SameLine(0, 8);
    imgui.TextColored(owned and C.gold or C.text, name);
    local hovered = imgui.IsItemHovered();
    imgui.SameLine(0, 10);
    local where = a.nm ~= '' and a.nm or 'not from a zone NM';
    if show_zone and a.zone ~= '' then where = where .. ' (' .. a.zone .. ')'; end
    imgui.TextColored(C.dim, where);
    hovered = hovered or imgui.IsItemHovered();
    imgui.PushTextWrapPos(wrap_at);
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 18);
    imgui.TextColored(C.fx, a.fx ~= '' and a.fx or '(no effect in the server data - see the game text)');
    imgui.PopTextWrapPos();
    hovered = hovered or imgui.IsItemHovered();
    if hovered then
        local t = ki_text(a.id);
        local lines = { name .. (owned and '  - you have it' or '  - you don\'t have it') };
        if a.nm ~= '' then lines[#lines + 1] = 'Drops from ' .. a.nm .. (a.zone ~= '' and (' in Abyssea - ' .. a.zone) or ''); end
        if t then lines[#lines + 1] = ''; lines[#lines + 1] = t; end
        imgui.SetTooltip(table.concat(lines, '\n'));
    end
    imgui.Spacing();
end

local function render_atma(W, words)
    -- Which zone: follows you into an Abyssea zone, otherwise stays on the last one picked.
    local gz = 0;
    pcall(function () gz = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0) or 0; end);
    if gz ~= st.last_game_zone then
        st.last_game_zone = gz;
        if ZONE_IDS[gz] then st.zone = ZONE_IDS[gz]; end
    end
    st.zone = st.zone or 'Konschtat';

    local total, have = 0, 0;
    for _, a in ipairs(data.atma) do
        total = total + 1;
        if has(a.id) then have = have + 1; end
    end

    if #words == 0 then
        for i, z in ipairs(ZONES) do
            if i > 1 then imgui.SameLine(0, 4); end
            local n, h = 0, 0;
            for _, a in ipairs(data.atma) do
                if zone_of(a) == z then n = n + 1; if has(a.id) then h = h + 1; end end
            end
            local here = (ZONE_IDS[gz] == z) and ' *' or '';
            if head_button(('%s %d/%d%s##atz%d'):format(z, h, n, here, i), st.zone == z) then st.zone = z; end
            if imgui.IsItemHovered() then
                imgui.SetTooltip((z == 'Other') and 'Atma that no zone NM drops.'
                    or ('Abyssea - ' .. z .. ' (' .. EXPANSION[z] .. ')' .. (here ~= '' and ' - you are here' or '')));
            end
        end
    end
    imgui.TextColored(C.dim, ('You have %d of %d atma.'):format(have, total));
    imgui.Separator();

    imgui.BeginChild('##aby_atma_list', { 0, 420 }, false);
    local wrap = imgui.GetCursorPosX() + W - 30;
    local shown = 0;
    for i, a in ipairs(data.atma) do
        local show;
        if #words > 0 then
            show = matches((ki_name(a.id, a.name) .. ' ' .. a.nm .. ' ' .. a.zone .. ' ' .. a.fx):lower(), words);
        else
            show = zone_of(a) == st.zone;
        end
        if show then
            shown = shown + 1;
            atma_row(a, i, wrap, #words > 0);
        end
    end
    if shown == 0 then imgui.TextColored(C.faint, 'Nothing matches.'); end
    imgui.EndChild();
end

local function render_abyssites(W, words)
    local kinds, have_any = 0, 0;
    for _, ab in ipairs(data.abyssites) do
        for _, id in ipairs(ab.ids) do if has(id) then have_any = have_any + 1; break; end end
        kinds = kinds + 1;
    end
    imgui.TextColored(C.dim, ('You have some of %d of the %d kinds of abyssite.'):format(have_any, kinds));
    imgui.Separator();
    imgui.BeginChild('##aby_abyssite_list', { 0, 420 }, false);
    local wrap = imgui.GetCursorPosX() + W - 30;
    local shown = 0;
    for i, ab in ipairs(data.abyssites) do
        local owned = {};
        for _, id in ipairs(ab.ids) do if has(id) then owned[#owned + 1] = id; end end
        local show = (#words == 0) or matches((ab.name .. ' ' .. ab.desc):lower(), words);
        if show then
            shown = shown + 1;
            imgui.TextColored(#owned > 0 and C.gold or C.text, ab.name);
            local hovered = imgui.IsItemHovered();
            imgui.SameLine(0, 10);
            imgui.TextColored(#owned == #ab.ids and C.green or (#owned > 0 and C.text or C.faint), ('%d / %d'):format(#owned, #ab.ids));
            hovered = hovered or imgui.IsItemHovered();
            imgui.PushTextWrapPos(wrap);
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 18);
            imgui.TextColored(C.fx, ab.desc);
            imgui.PopTextWrapPos();
            hovered = hovered or imgui.IsItemHovered();
            if hovered then
                local lines = { ab.name };
                for _, id in ipairs(ab.ids) do
                    lines[#lines + 1] = (has(id) and '  + ' or '  - ') .. ki_name(id);
                end
                local t = ki_text(ab.ids[1]);
                if t then lines[#lines + 1] = ''; lines[#lines + 1] = t; end
                imgui.SetTooltip(table.concat(lines, '\n'));
            end
            imgui.Spacing();
        end
    end
    if shown == 0 then imgui.TextColored(C.faint, 'Nothing matches.'); end
    imgui.EndChild();
end

atma.render = function (opts)
    local W = math.floor(imgui.GetContentRegionAvail());
    if head_button('Atma##aby_atv', st.view == 'atma') then st.view = 'atma'; end
    imgui.SameLine(0, 4);
    if head_button('Abyssites##aby_abv', st.view == 'abyssites') then st.view = 'abyssites'; end
    imgui.SameLine(0, 16);
    imgui.PushItemWidth(math.min(260, W - 200));
    imgui.InputTextWithHint('##aby_atma_search', 'Search names, NMs, effects', st.search, 64);
    imgui.PopItemWidth();
    if st.search[1] ~= '' then
        imgui.SameLine(0, 4);
        if imgui.SmallButton('x##aby_atma_clear') then st.search[1] = ''; end
    end
    local words = {};
    for w in st.search[1]:lower():gmatch('%S+') do if #w >= 2 then words[#words + 1] = w; end end
    if st.view == 'atma' then render_atma(W, words); else render_abyssites(W, words); end
end

-- For a global search: atma whose name / NM / effect matches (used by other pages later).
atma.find = function (text)
    local out = {};
    local words = {};
    for w in (text or ''):lower():gmatch('%S+') do words[#words + 1] = w; end
    if #words == 0 then return out; end
    for _, a in ipairs(data.atma) do
        if matches((ki_name(a.id, a.name) .. ' ' .. a.nm .. ' ' .. a.zone .. ' ' .. a.fx):lower(), words) then out[#out + 1] = a; end
    end
    return out;
end

return atma;
