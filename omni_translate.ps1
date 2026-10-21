# omni_translate.ps1 - helper for omni's Happy Translate (omni_translate.lua).
# Reads Japanese text (UTF-8) from -In, asks MyMemory for English, writes it (UTF-8) to -Out.
# On failure writes "!<reason>" to -Out. Started hidden by omni; nothing else is sent anywhere.
param([string]$In, [string]$Out)

$utf8 = New-Object System.Text.UTF8Encoding $false
function Write-Result([string]$text) {
    $tmp = "$Out.tmp"
    [System.IO.File]::WriteAllText($tmp, $text, $utf8)
    Move-Item -LiteralPath $tmp -Destination $Out -Force
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $text = [System.IO.File]::ReadAllText($In, $utf8).Trim()
    if ($text.Length -eq 0) { Write-Result '!empty line'; exit }
    # MyMemory takes at most 500 bytes; Japanese is 3 bytes a character in UTF-8.
    while ($utf8.GetByteCount($text) -gt 490) { $text = $text.Substring(0, $text.Length - 1) }
    $q = [Uri]::EscapeDataString($text)
    $url = "https://api.mymemory.translated.net/get?q=$q&langpair=ja%7Cen"
    $r = Invoke-RestMethod -Uri $url -TimeoutSec 12 -UseBasicParsing
    if ($r.responseStatus -and [int]$r.responseStatus -ne 200) { Write-Result ('!' + [string]$r.responseDetails); exit }
    $en = [string]$r.responseData.translatedText
    if ([string]::IsNullOrWhiteSpace($en)) { Write-Result ('!' + [string]$r.responseDetails); exit }
    if ($en -match 'MYMEMORY WARNING|QUERY LENGTH LIMIT') { Write-Result ('!' + $en); exit }
    $en = [System.Net.WebUtility]::HtmlDecode($en)
    Write-Result $en
}
catch {
    Write-Result ('!' + $_.Exception.Message)
}
