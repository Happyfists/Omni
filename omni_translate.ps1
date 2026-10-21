# omni_translate.ps1 - helper for omni's Happy Translate (omni_translate.lua).
# Reads text (UTF-8) from -In, writes the result (UTF-8) to -Out. On failure writes "!<reason>".
# Started hidden by omni; only the one chat line is sent.
#   -Mode ja   Japanese -> English                     (MyMemory)
#   -Mode py   pinyin -> Chinese characters -> English  (Google Input Tools, then MyMemory)
#   -Mode zh   English -> Chinese characters            (MyMemory; omni turns them into pinyin)
#   -Mode es / pt / fr / de   that language -> English  (MyMemory)
#   -Mode to_ja / to_fr / to_de / to_es / to_pt   English -> that language (your replies)
param([string]$In, [string]$Out, [string]$Mode = 'ja', [string]$Email = '', [string]$Serve = '')

$utf8 = New-Object System.Text.UTF8Encoding $false
function Write-Result([string]$text) {
    $tmp = "$Out.tmp"
    [System.IO.File]::WriteAllText($tmp, $text, $utf8)
    Move-Item -LiteralPath $tmp -Destination $Out -Force
}

function MyMemory([string]$text, [string]$pair) {
    # MyMemory takes at most 500 bytes.
    while ($utf8.GetByteCount($text) -gt 490) { $text = $text.Substring(0, $text.Length - 1) }
    $q = [Uri]::EscapeDataString($text)
    $url = "https://api.mymemory.translated.net/get?q=$q&langpair=$([Uri]::EscapeDataString($pair))"
    # With an email address MyMemory allows 50000 characters a day instead of 5000.
    if ($Email -ne '') { $url += '&de=' + [Uri]::EscapeDataString($Email) }
    $r = Invoke-RestMethod -Uri $url -TimeoutSec 12 -UseBasicParsing
    if ($r.responseStatus -and [int]$r.responseStatus -ne 200) { throw [string]$r.responseDetails }
    $t = [string]$r.responseData.translatedText
    # Sometimes the best match is just the same words back (idioms, slang). Then take another match
    # that really is translated - the machine translation if there is one.
    if ($t.Trim().ToLower() -eq $text.Trim().ToLower() -and $r.matches) {
        $pick = $null
        foreach ($m in $r.matches) {
            $mt = [string]$m.translation
            if ($mt -and $mt.Trim().ToLower() -ne $text.Trim().ToLower()) {
                if ($null -eq $pick -or ([string]$m.'created-by') -eq 'MT!') { $pick = $mt }
            }
        }
        if ($pick) { $t = $pick }
    }
    if ([string]::IsNullOrWhiteSpace($t)) { throw ('no translation: ' + [string]$r.responseDetails) }
    if ($t -match 'MYMEMORY WARNING|QUERY LENGTH LIMIT') { throw $t }
    return [System.Net.WebUtility]::HtmlDecode($t)
}

function PinyinToHanzi([string]$text) {
    # Parts marked |like this| (English words, numbers) are kept as they are. Every other run is
    # pinyin: each comma/full-stop piece is sent without spaces ("dou tong guan le" -> "doutongguanle").
    $out = @()
    $segs = $text -split '\|'
    for ($i = 0; $i -lt $segs.Count; $i++) {
        if ($i % 2 -eq 1) { $out += $segs[$i].Trim(); continue }
        foreach ($piece in ($segs[$i] -split '[,.!?;:]+')) {
            $p = ($piece -replace '[^A-Za-z]', '').ToLower()
            if ($p.Length -eq 0) { continue }
            $url = "https://inputtools.google.com/request?text=$p&itc=zh-t-i0-pinyin&num=1&cp=0&cs=1&ie=utf-8&oe=utf-8"
            $r = Invoke-RestMethod -Uri $url -TimeoutSec 12 -UseBasicParsing
            if ($r[0] -ne 'SUCCESS') { throw 'pinyin lookup failed' }
            $h = [string]$r[1][0][1][0]
            # A question ending in "ma" is the question word (ma, U+5417), not "mum" (U+5988).
            if ($p.EndsWith('ma') -and ($h.EndsWith([string][char]0x5988))) {
                $h = $h.Substring(0, $h.Length - 1) + [string][char]0x5417
                if ($p.EndsWith('dama') -and $h.Length -ge 2 -and $h[$h.Length - 2] -eq [char]0x5927) {
                    $h = $h.Substring(0, $h.Length - 2) + [string][char]0x6253 + [string][char]0x5417
                }
            }
            $out += $h
        }
    }
    return ($out -join ' ').Trim()
}

function Translate([string]$text, [string]$mode) {
    switch ($mode) {
        'py' {
            $hanzi = PinyinToHanzi $text
            if ($hanzi.Length -eq 0) { throw 'no pinyin found' }
            return (MyMemory $hanzi 'zh-CN|en')
        }
        'zh' { return (MyMemory $text 'en|zh-CN') }
        { $_ -match '^to_[a-z]{2}$' } {
            # English -> the reply language you picked (to_ja, to_fr, to_de, to_es, to_pt)
            return (MyMemory $text ('en|' + $mode.Substring(3)))
        }
        default {
            # ja, es, pt, fr, de ... -> English
            if ($mode -notmatch '^[a-z]{2}$') { $mode = 'ja' }
            return (MyMemory $text ($mode + '|en'))
        }
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($Serve -ne '') {
    # Stay running and answer every <id>.<mode>.in file that appears in the folder (much lighter than
    # starting PowerShell for every line). Stops when omni writes a "stop" file, or after 30 idle minutes.
    $idle = 0
    while ($true) {
        $stop = Join-Path $Serve 'stop'
        if (Test-Path -LiteralPath $stop) { Remove-Item -LiteralPath $stop -ErrorAction SilentlyContinue; break }
        $files = @(Get-ChildItem -LiteralPath $Serve -Filter '*.in' -ErrorAction SilentlyContinue)
        if ($files.Count -gt 0) {
            $idle = 0
            foreach ($f in $files) {
                $work = $f.FullName + '.work'
                try { Move-Item -LiteralPath $f.FullName -Destination $work -ErrorAction Stop } catch { continue }
                $parts = $f.BaseName.Split('.')
                $m = $parts[$parts.Count - 1]
                $id = ($parts[0..($parts.Count - 2)] -join '.')
                $script:Out = Join-Path $Serve ($id + '.out')
                try {
                    $text = [System.IO.File]::ReadAllText($work, $utf8).Trim()
                    if ($text.Length -eq 0) { Write-Result '!empty line' } else { Write-Result (Translate $text $m) }
                } catch { Write-Result ('!' + $_.Exception.Message) }
                Remove-Item -LiteralPath $work -ErrorAction SilentlyContinue
            }
        } else {
            Start-Sleep -Milliseconds 250
            $idle += 250
            if ($idle -ge 1800000) { break }
        }
    }
    exit
}

# One line (older way): -In file -Out file -Mode mode
try {
    $text = [System.IO.File]::ReadAllText($In, $utf8).Trim()
    if ($text.Length -eq 0) { Write-Result '!empty line'; exit }
    Write-Result (Translate $text $Mode)
}
catch {
    Write-Result ('!' + $_.Exception.Message)
}
