--[[
    omni_update.lua - /omniupdate: gets the latest omni from GitHub (github.com/Happyfists/Omni) and
    copies it over this omni folder, then reloads omni.

        /omniupdate          update now (does nothing if you already have the latest)
        /omniupdate check    just say whether there is a newer version

    The download is done by a hidden PowerShell helper (omni_update.ps1), the same way Happy
    Translate talks to the internet. Your settings live in config\addons\omni\ and are not touched.
]]

local ffi = require('ffi');

local up = {};

pcall(ffi.cdef, [[
    typedef struct {
        unsigned long cb; char* lpReserved; char* lpDesktop; char* lpTitle;
        unsigned long dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        unsigned short wShowWindow, cbReserved2; unsigned char* lpReserved2;
        void* hStdInput; void* hStdOutput; void* hStdError;
    } omni_tr_STARTUPINFOA;
    typedef struct { void* hProcess; void* hThread; unsigned long dwProcessId; unsigned long dwThreadId; } omni_tr_PROCESS_INFORMATION;
]]);
pcall(ffi.cdef, [[
    int CreateProcessA(const char* app, char* cmd, void* pa, void* ta, int inherit, unsigned long flags, void* env, const char* dir, void* si, void* pi);
]]);
pcall(ffi.cdef, [[ int CloseHandle(void* h); ]]);
pcall(ffi.cdef, [[ unsigned long GetLastError(void); ]]);

local function say(t) print('\30\68[omni update]\30\01 ' .. t); end

local function addon_dir()
    local p = (addon ~= nil and type(addon.path) == 'string' and addon.path ~= '') and addon.path
        or ('%s\\addons\\omni\\'):format(AshitaCore:GetInstallPath());
    if p:sub(-1) ~= '\\' and p:sub(-1) ~= '/' then p = p .. '\\'; end
    return p;
end

local function run_hidden(cmdline)
    local ok, res = pcall(function ()
        local si = ffi.new('omni_tr_STARTUPINFOA[1]');
        si[0].cb = ffi.sizeof('omni_tr_STARTUPINFOA');
        local pi = ffi.new('omni_tr_PROCESS_INFORMATION[1]');
        local cmd = ffi.new('char[?]', #cmdline + 1);
        ffi.copy(cmd, cmdline);
        local r = ffi.C.CreateProcessA(nil, cmd, nil, nil, 0, 0x08000000, nil, nil, si, pi);
        if r ~= 0 then
            ffi.C.CloseHandle(pi[0].hThread);
            ffi.C.CloseHandle(pi[0].hProcess);
            return true;
        end
        return 'Windows error ' .. tostring(ffi.C.GetLastError());
    end);
    if not ok then return false, tostring(res); end
    if res ~= true then return false, res; end
    return true;
end

local job = nil;    -- { log, started, check }

up.start = function (check)
    if job then say('Already updating - wait a moment.'); return; end
    local dir = addon_dir();
    local ps1 = dir .. 'omni_update.ps1';
    local f = io.open(ps1, 'r');
    if not f then say('omni_update.ps1 is missing from ' .. dir); return; end
    f:close();
    local logf = dir .. 'omni_update.log';
    os.remove(logf);
    local dest = dir:gsub('\\$', '');
    local cmd = ('powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%s" -Dest "%s" -Old "%s"%s')
        :format(ps1, dest, tostring(addon.version), check and ' -Check' or '');
    local ok, err = run_hidden(cmd);
    if not ok then say('Could not start PowerShell: ' .. tostring(err)); return; end
    job = { log = logf, started = os.clock(), check = check };
    say(check and 'Checking GitHub for a newer omni...' or 'Downloading the latest omni from GitHub...');
end

-- Waits for the helper's answer (checked twice a second).
local next_look = 0;
ashita.events.register('d3d_present', 'omni_update_poll', function ()
    if not job then return; end
    local now = os.clock();
    if now < next_look then return; end
    next_look = now + 0.5;
    if now - job.started > 120 then job = nil; say('No answer after 2 minutes - check your internet and try again.'); return; end
    local f = io.open(job.log, 'r');
    if not f then return; end
    local line = f:read('*l') or '';
    f:close();
    if line == '' then return; end
    local was_check = job.check;
    job = nil;
    local kind, rest = line:match('^(%u+)%s*(.*)$');
    if kind == 'OK' then
        local old, new = rest:match('^(%S+)%s+(%S+)');
        say(('Updated %s -> %s. Reloading omni...'):format(old or '?', new or '?'));
        AshitaCore:GetChatManager():QueueCommand(1, '/addon reload omni');
    elseif kind == 'SAME' then
        say('You already have the latest omni (' .. rest .. ').');
    elseif kind == 'NEWER' then
        local old, new = rest:match('^(%S+)%s+(%S+)');
        say(('A newer omni is on GitHub: %s (you have %s). Type /omniupdate to get it.'):format(new or '?', old or '?'));
    else
        say('Update failed: ' .. (rest ~= '' and rest or line));
    end
end);

return up;
