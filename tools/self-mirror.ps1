<#
.SYNOPSIS
  Generate a self-mirror report that quantifies the user's own chat habits.

.DESCRIPTION
  Scans people/*/chat.md (or one person via -Person), detects the user's sender label,
  and writes a Markdown report with 7 sections to SELF-MIRROR.md by default.

.EXAMPLE
  .\tools\self-mirror.ps1

.EXAMPLE
  .\tools\self-mirror.ps1 -Person alice -Out reports/SELF-MIRROR.md
#>

[CmdletBinding()]
param(
  [string]$Out = 'SELF-MIRROR.md',
  [string]$Person
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

function Get-FrontmatterMap {
  param([string]$Path)
  if (-not (Test-Path $Path)) { return @{} }
  $content = Get-Content -Path $Path -Raw -Encoding UTF8
  $match = [Regex]::Match($content, '(?ms)^---\s*\r?\n(.*?)\r?\n---\s*(\r?\n|$)')
  if (-not $match.Success) { return @{} }
  $map = @{}
  foreach ($line in ($match.Groups[1].Value -split "`r?`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $kv = [Regex]::Match($line, '^([A-Za-z0-9_.-]+)\s*:\s*(.*)$')
    if (-not $kv.Success) { continue }
    $map[$kv.Groups[1].Value] = $kv.Groups[2].Value.Trim(" \t\"'")
  }
  return $map
}

function Get-DoNotDisturbHour {
  param([string]$ProfilePath)
  $meta = Get-FrontmatterMap -Path $ProfilePath
  if (-not $meta.ContainsKey('comms.frequency')) { return $null }
  $f = $meta['comms.frequency']
  $m = [Regex]::Match($f, '(2[0-3]|[01]?\d)\s*点后')
  if ($m.Success) { return [int]$m.Groups[1].Value }
  return $null
}

function Normalize-Text {
  param([string]$Text)
  if (-not $Text) { return '' }
  $lower = $Text.ToLowerInvariant()
  return ([Regex]::Replace($lower, '[\p{P}\p{S}\s]+', '')).Trim()
}

function Get-Tokens {
  param([string]$Text)
  $n = Normalize-Text -Text $Text
  if (-not $n) { return @() }
  $arr = @()
  foreach ($c in $n.ToCharArray()) { $arr += [string]$c }
  return $arr
}

function Parse-Chat {
  param([string]$Path, [string]$Recipient)
  $lines = Get-Content -Path $Path -Encoding UTF8
  $msgs = New-Object System.Collections.ArrayList
  $current = $null

  foreach ($line in $lines) {
    $m = [Regex]::Match($line, '^\[(?<ts>[^\]]+)\]\s+(?<sender>[^:]+):\s*(?<text>.*)$')
    if ($m.Success) {
      if ($current) { [void]$msgs.Add($current) }
      $dt = $null
      try { $dt = [datetime]::Parse($m.Groups['ts'].Value) } catch { }
      $current = [ordered]@{ Ts=$dt; Sender=$m.Groups['sender'].Value.Trim(); Text=$m.Groups['text'].Value.Trim(); Recipient=$Recipient }
      continue
    }
    if ($current) {
      $current.Text = ($current.Text + "`n" + $line).Trim()
    }
  }
  if ($current) { [void]$msgs.Add($current) }
  return ,$msgs
}

$basePeople = 'people'
if (-not (Test-Path $basePeople)) { throw 'people/ directory not found.' }

$dirs = Get-ChildItem -Path $basePeople -Directory | Where-Object { $_.Name -ne '_template' }
if ($Person) {
  $dirs = $dirs | Where-Object { $_.Name -eq $Person }
  if (-not $dirs) { throw "Person slug not found: $Person" }
}

$allByRecipient = @{}
$labelChats = @{}
foreach ($d in $dirs) {
  $chat = Join-Path $d.FullName 'chat.md'
  if (-not (Test-Path $chat)) { Write-Warning "Skip $($d.Name): missing chat.md"; continue }
  $msgs = Parse-Chat -Path $chat -Recipient $d.Name
  if (-not $msgs -or $msgs.Count -eq 0) { Write-Warning "Skip $($d.Name): unparseable chat.md"; continue }
  $allByRecipient[$d.Name] = $msgs
  $labels = $msgs | ForEach-Object { $_.Sender } | Select-Object -Unique
  foreach ($lb in $labels) {
    if (-not $labelChats.ContainsKey($lb)) { $labelChats[$lb] = @{} }
    $labelChats[$lb][$d.Name] = $true
  }
}

if ($allByRecipient.Count -eq 0) { throw 'No valid chat.md files found.' }

$totalChats = $allByRecipient.Count
$userLabel = $null
foreach ($kv in $labelChats.GetEnumerator()) {
  if ($kv.Value.Count -eq $totalChats) { $userLabel = $kv.Key; break }
}
if (-not $userLabel) {
  $best = $labelChats.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | Select-Object -First 1
  if ($best -and $best.Value.Count -ge [Math]::Ceiling($totalChats * 0.8)) { $userLabel = $best.Key }
}
if (-not $userLabel) { throw 'Unable to detect user sender label across chats.' }

$userMsgs = New-Object System.Collections.ArrayList
$echoAll = New-Object System.Collections.ArrayList
$echoByR = @{}
$openings = @{}
$lenBins = @{'1-10'=0;'11-30'=0;'31-100'=0;'101-300'=0;'300+'=0}
$lenByR = @{}
$qByR = @{}
$hour = @(0)*24
$dndViolations = New-Object System.Collections.ArrayList
$softWords = @('嘛','吧','啊','呢','哦','嗯','哈','喔')
$softTotal = 0
$softByR = @{}
$wordByR = @{}
$emojiByR = @{}

foreach ($r in $allByRecipient.Keys) {
  $msgs = $allByRecipient[$r]
  $lenByR[$r] = @{'1-10'=0;'11-30'=0;'31-100'=0;'101-300'=0;'300+'=0}
  $qByR[$r] = @{Q=0;Total=0}
  $softByR[$r] = 0
  $wordByR[$r] = 0
  $emojiByR[$r] = 0
  $dnd = Get-DoNotDisturbHour -ProfilePath (Join-Path (Join-Path $basePeople $r) 'profile.md')

  for ($i=0; $i -lt $msgs.Count; $i++) {
    $m = $msgs[$i]
    if ($m.Sender -ne $userLabel) { continue }
    [void]$userMsgs.Add($m)

    $tlen = $m.Text.Length
    $bin = if ($tlen -le 10) {'1-10'} elseif ($tlen -le 30) {'11-30'} elseif ($tlen -le 100) {'31-100'} elseif ($tlen -le 300) {'101-300'} else {'300+'}
    $lenBins[$bin]++; $lenByR[$r][$bin]++

    $qByR[$r].Total++
    if ($m.Text.TrimEnd() -match '[？?]$') { $qByR[$r].Q++ }

    if ($m.Ts) {
      $hour[$m.Ts.Hour]++
      if ($dnd -ne $null -and $m.Ts.Hour -ge $dnd) { [void]$dndViolations.Add("$($m.Ts.ToString('yyyy-MM-dd HH:mm')) · $r · $($m.Text.Replace("`n",' '))") }
    }

    $chars = Get-Tokens -Text $m.Text
    $wordByR[$r] += [Math]::Max($chars.Count,1)
    foreach ($sw in $softWords) {
      $cnt = ([Regex]::Matches($m.Text, [Regex]::Escape($sw))).Count
      $softTotal += $cnt
      $softByR[$r] += $cnt
    }
    $emojiByR[$r] += ([Regex]::Matches($m.Text, '(\[[^\]]+\]|[\uD83C-\uDBFF\uDC00-\uDFFF])')).Count

    if ($i -gt 0) {
      $prev = $msgs[$i-1]
      if ($prev.Sender -ne $userLabel) {
        $uTok = Get-Tokens -Text $m.Text
        $pTok = Get-Tokens -Text $prev.Text
        if ($uTok.Count -gt 0) {
          $shared=0
          foreach ($t in $uTok) { if ($pTok -contains $t) { $shared++ } }
          $overlap = $shared / [double]$uTok.Count
          $remaining = ($m.Text.Length - $shared)
          $soft = $m.Text -match '^(好\S*|挺\S*|也\S*|.*[啊呢吧哦嗯哈喔]\s*!?)$'
          if ($overlap -ge 0.5 -and ($remaining -lt 8 -or $soft)) {
            $e = [ordered]@{Ts=$m.Ts;Recipient=$r;Prev=$prev.Text.Replace("`n",' ');Echo=$m.Text.Replace("`n",' ')}
            [void]$echoAll.Add($e)
            if (-not $echoByR.ContainsKey($r)) { $echoByR[$r]=0 }
            $echoByR[$r]++
          }
        }
      }
    }

    if ($i -eq 0 -or (-not $msgs[$i-1].Ts) -or (-not $m.Ts) -or (($m.Ts - $msgs[$i-1].Ts).TotalHours -gt 2)) {
      $norm = Normalize-Text -Text $m.Text
      if ($norm) {
        if (-not $openings.ContainsKey($norm)) { $openings[$norm] = New-Object System.Collections.ArrayList }
        [void]$openings[$norm].Add("$($m.Ts.ToString('yyyy-MM-dd HH:mm')) · $r · $($m.Text.Replace("`n",' '))")
      }
    }
  }
}

$md = New-Object System.Collections.Generic.List[string]
$md.Add('# SELF-MIRROR')
$md.Add('')
$md.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$md.Add("Detected user sender label: **$userLabel**")
$md.Add('')
$md.Add('## 1. Echo-reply Offenses')
$md.Add("- Total count: **$($echoAll.Count)**")
$md.Add('- Per-recipient count:')
foreach ($k in ($echoByR.Keys | Sort-Object)) { $md.Add("  - $k: $($echoByR[$k])") }
$md.Add('- Top 10 examples:')
$topEcho = $echoAll | Sort-Object Ts -Descending | Select-Object -First 10
foreach ($e in $topEcho) { $md.Add("  - $($e.Ts.ToString('yyyy-MM-dd')) · $($e.Recipient) · 对方：$($e.Prev) · 我：$($e.Echo)") }
$md.Add('')
$md.Add('## 2. Top 10 Opening Lines')
foreach ($o in ($openings.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | Select-Object -First 10)) {
  $md.Add("- `$( $o.Key )`: $($o.Value.Count)")
  foreach ($s in ($o.Value | Select-Object -First 3)) { $md.Add("  - $s") }
}
$md.Add('')
$md.Add('## 3. Length Distribution')
$md.Add('| Bin | Total |')
$md.Add('|---|---:|')
foreach ($b in @('1-10','11-30','31-100','101-300','300+')) { $md.Add("| $b | $($lenBins[$b]) |") }
$md.Add('')
$md.Add('Per-recipient:')
foreach ($r in ($lenByR.Keys | Sort-Object)) { $md.Add("- $r: 1-10=$($lenByR[$r]['1-10']), 11-30=$($lenByR[$r]['11-30']), 31-100=$($lenByR[$r]['31-100']), 101-300=$($lenByR[$r]['101-300']), 300+=$($lenByR[$r]['300+'])") }
$md.Add('')
$md.Add('## 4. Question vs Statement Ratio')
foreach ($r in ($qByR.Keys | Sort-Object)) {
  $total = [Math]::Max($qByR[$r].Total,1)
  $ratio = [Math]::Round(($qByR[$r].Q / [double]$total) * 100, 1)
  $md.Add("- $r: question=$($qByR[$r].Q), total=$($qByR[$r].Total), ratio=$ratio%")
}
$md.Add('')
$md.Add('## 5. Time-of-day Pattern')
$md.Add('| Hour | Count |')
$md.Add('|---:|---:|')
for ($h=0; $h -lt 24; $h++) { $md.Add("| $h | $($hour[$h]) |") }
$md.Add('')
$md.Add('DND violations (best effort):')
if ($dndViolations.Count -eq 0) { $md.Add('- none') } else { foreach ($v in $dndViolations | Select-Object -First 30) { $md.Add("- $v") } }
$md.Add('')
$md.Add('## 6. Connector/Softener Word Frequency')
$md.Add("- Target words: $($softWords -join ' ')" )
$md.Add("- Total softener hits: $softTotal")
foreach ($r in ($softByR.Keys | Sort-Object)) {
  $base = [Math]::Max($wordByR[$r],1)
  $pct = [Math]::Round(($softByR[$r] / [double]$base)*100,2)
  $flag = if ($pct -gt 5) { ' ⚠️ overuse' } else { '' }
  $md.Add("- $r: $($softByR[$r]) / $base = $pct%$flag")
}
$md.Add('')
$md.Add('## 7. Emoji / Sticker Proxy Count')
foreach ($r in ($emojiByR.Keys | Sort-Object)) { $md.Add("- $r: $($emojiByR[$r])") }

$md -join "`n" | Out-File -FilePath $Out -Encoding UTF8
Write-Host "[self-mirror] wrote $Out" -ForegroundColor Green
