# omni_update.ps1 - downloads the latest omni from GitHub and copies it over this omni folder.
# Started hidden by /omniupdate (omni_update.lua). Writes how it went to omni_update.log in this folder:
#   first line  OK <old version> <new version>  |  SAME <version>  |  FAIL <reason>
param([string]$Dest, [string]$Old = '?', [switch]$Check)
$ErrorActionPreference = 'Stop'
$log = Join-Path $Dest 'omni_update.log'
function Done($line) { Set-Content -Path $log -Value $line -Encoding ASCII; exit 0 }
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $tmp = Join-Path $env:TEMP ('omni_update_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp 'omni.zip'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/Happyfists/Omni/archive/refs/heads/main.zip' -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $src = Get-ChildItem -Path $tmp -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'omni.lua') } | Select-Object -First 1
    if (-not $src) { Done 'FAIL the download had no omni.lua in it' }
    $new = '?'
    $m = Select-String -Path (Join-Path $src.FullName 'omni.lua') -Pattern "addon\.version\s*=\s*'([^']+)'" | Select-Object -First 1
    if ($m) { $new = $m.Matches[0].Groups[1].Value }
    if ($new -eq $Old -and -not $Check) {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        Done "SAME $new"
    }
    if ($Check) {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        if ($new -eq $Old) { Done "SAME $new" } else { Done "NEWER $Old $new" }
    }
    # robocopy merges folders properly (lib, plugins...) and overwrites changed files
    & robocopy $src.FullName $Dest /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { Done "FAIL copying the files (robocopy $LASTEXITCODE) - is the game holding a file open?" }
    Get-ChildItem -Path $Dest -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    Done "OK $Old $new"
} catch {
    Done ('FAIL ' + ($_.Exception.Message -replace "[\r\n]+", ' '))
}
