# omni_translate.ps1 - helper for omni's Happy Translate (omni_translate.lua).
# Reads text (UTF-8) from -In, writes the result (UTF-8) to -Out. On failure writes "!<reason>".
# Started hidden by omni; only the one chat line is sent.
#   -Mode ja   Japanese -> English                     (MyMemory)
#   -Mode py   pinyin -> Chinese characters -> English  (Google Input Tools, then MyMemory)
#   -Mode zh   English -> Chinese characters            (MyMemory; omni turns them into pinyin)
#   -Mode es / pt / fr / de   that language -> English  (MyMemory)
#   -Mode to_ja / to_fr / to_de / to_es / to_pt   English -> that language (your replies)
param([string]$In, [string]$Out, [string]$Mode = 'ja')

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
    $r = Invoke-RestMethod -Uri $url -TimeoutSec 12 -UseBasicParsing
    if ($r.responseStatus -and [int]$r.responseStatus -ne 200) { throw [string]$r.responseDetails }
    $t = [string]$r.responseData.translatedText
    if ([string]::IsNullOrWhiteSpace($t)) { throw ('no translation: ' + [string]$r.responseDetails) }
    if ($t -match 'MYMEMORY WARNING|QUERY LENGTH LIMIT') { throw $t }
    return [System.Net.WebUtility]::HtmlDecode($t)
}

function PinyinToHanzi([string]$text) {
    # Each comma/full-stop separated piece is sent without spaces ("dou tong guan le" -> "doutongguanle").
    $out = @()
    foreach ($piece in ($text -split '[,.!?;:]+')) {
        $p = ($piece -replace '[^A-Za-z]', '').ToLower()
        if ($p.Length -eq 0) { continue }
        $url = "https://inputtools.google.com/request?text=$p&itc=zh-t-i0-pinyin&num=1&cp=0&cs=1&ie=utf-8&oe=utf-8"
        $r = Invoke-RestMethod -Uri $url -TimeoutSec 12 -UseBasicParsing
        if ($r[0] -ne 'SUCCESS') { throw 'pinyin lookup failed' }
        $h = [string]$r[1][0][1][0]
        # A question ending in "ma" is the question word 吗, not 妈 (mum) - e.g. "da ma" -> 打吗 not 大妈.
        if ($p.EndsWith('ma') -and ($h.EndsWith([string][char]0x5988))) {
            $h = $h.Substring(0, $h.Length - 1) + [string][char]0x5417
            if ($p.EndsWith('dama') -and $h.Length -ge 2 -and $h[$h.Length - 2] -eq [char]0x5927) {
                $h = $h.Substring(0, $h.Length - 2) + [string][char]0x6253 + [string][char]0x5417
            }
        }
        $out += $h
    }
    return ($out -join ', ')
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $text = [System.IO.File]::ReadAllText($In, $utf8).Trim()
    if ($text.Length -eq 0) { Write-Result '!empty line'; exit }
    switch ($Mode) {
        'py' {
            $hanzi = PinyinToHanzi $text
            if ($hanzi.Length -eq 0) { Write-Result '!no pinyin found'; exit }
            Write-Result (MyMemory $hanzi 'zh-CN|en')
        }
        'zh' { Write-Result (MyMemory $text 'en|zh-CN') }
        { $_ -match '^to_[a-z]{2}$' } {
            # English -> the reply language you picked (to_ja, to_fr, to_de, to_es, to_pt)
            Write-Result (MyMemory $text ('en|' + $Mode.Substring(3)))
        }
        default {
            # ja, es, pt, fr, de ... -> English
            if ($Mode -notmatch '^[a-z]{2}$') { $Mode = 'ja' }
            Write-Result (MyMemory $text ($Mode + '|en'))
        }
    }
}
catch {
    Write-Result ('!' + $_.Exception.Message)
}
