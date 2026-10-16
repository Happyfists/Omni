--[[
    omni_chatcolors.lua - brighter chat colours.

    Re-colours party, linkshell, linkshell 2 and tell lines in the game's chat log with brighter
    shades (say stays white). Only the colour changes, never the text. Turned on and off in the
    Options tab (chat_bright).
]]

local cc = {};
cc.settings = nil;

-- Ashita chat colour codes (colour table 1).
local C = {
    party = 82,    -- aqua
    ls1   = 88,    -- light green (medium spring green)
    ls2   = 79,    -- lime
    tell  = 73,    -- violet
    shout = 8,     -- coral
};

-- The game's chat modes (low byte): your own line and other people's.
local MODES = {
    [5] = 'party', [13] = 'party',
    [6] = 'ls1',   [14] = 'ls1',
    [4] = 'tell',  [12] = 'tell',
    [2] = 'shout', [10] = 'shout', [11] = 'shout',
};

local function strip(s) return (s:gsub('[\30\31].', '')); end

local function on_text(e)
    local S = cc.settings;
    if S == nil or S.chat_bright == false then return; end
    if e.injected then return; end
    local mode = bit.band(e.mode_modified or e.mode or 0, 0xFF);
    local msg = e.message_modified or e.message;
    if type(msg) ~= 'string' or msg == '' then return; end

    -- Linkshells by their [1] / [2] mark (works whatever number the game gives the line).
    local plain = strip(msg):sub(1, 40);
    local kind = nil;
    if plain:find('%[2%]<') then kind = 'ls2';
    elseif plain:find('%[1%]<') then kind = 'ls1';
    else kind = MODES[mode]; end
    if kind == nil then return; end

    local code = '\30' .. string.char(C[kind]);
    -- Every "back to the line's colour" mark (a timestamp's end, say) goes back to ours instead.
    local body = msg:gsub('\30\1', '\30\1' .. code);
    -- Keep the line's ending (newline) outside the colour.
    local core, tail = body:match('^(.-)([\r\n]*)$');
    e.message_modified = code .. core .. '\30\1' .. tail;
end

ashita.events.register('text_in', 'omni_chatcolors', function (e)
    pcall(on_text, e);
end);

return cc;
