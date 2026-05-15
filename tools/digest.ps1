<#!
.SYNOPSIS
  Show what changed since last session from wx new-messages.

.DESCRIPTION
  Calls `wx new-messages --json` once, groups messages by contact, and prints
  a compact 5-column digest:
  名字 / 消息数 / 最后消息时间 / 前 80 字预览 / 球在你?

  Ball-in-court status is read from `people/<slug>/profile.md` YAML frontmatter.
  If `ball-in-court: me`, the row is flagged with ⚠️.

  Use -Write to also save the table into DIGEST.md at repo root.

.EXAMPLE
  .\tools\digest.ps1

.EXAMPLE
  .\tools\digest.ps1 -Write

.EXAMPLE
  .\tools\digest.ps1 -Since "2026-05-10"
#>

[CmdletBinding()]
param(
  [switch]$Write,
  [string]$Since
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

function Get-FrontmatterMap {
  param(
    [string]$Path
  )

  if (-not (Test-Path $Path)) { return @{} }

  $content = Get-Content -Path $Path -Raw -Encoding UTF8
  if (-not $content) { return @{} }

  $match = [Regex]::Match($content, '(?ms)^---\s*\r?\n(.*?)\r?\n---\s*(\r?\n|$)')
  if (-not $match.Success) { return @{} }

  $yaml = $match.Groups[1].Value
  $lines = $yaml -split "`r?`n"
  $map = @{}

  foreach ($line in $lines) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.TrimStart().StartsWith('#')) { continue }

    $kv = [Regex]::Match($line, '^([A-Za-z0-9_-]+)\s*:\s*(.*)$')
    if (-not $kv.Success) { continue }

    $key = $kv.Groups[1].Value
    $value = $kv.Groups[2].Value.Trim()

    if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
      $value = $matches[1]
    }

    $map[$key] = $value
  }

  return $map
}

function Get-BallInCourtMap {
  $map = @{}
  $peopleDirs = Get-ChildItem -Path 'people' -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne '_template' }

  foreach ($dir in $peopleDirs) {
    $profile = Join-Path $dir.FullName 'profile.md'
    if (-not (Test-Path $profile)) { continue }

    $meta = Get-FrontmatterMap -Path $profile
    $ball = $meta['ball-in-court']
    if (-not $ball) { continue }

    $map[$dir.Name.ToLowerInvariant()] = $ball.ToString().Trim().ToLowerInvariant()
  }

  return $map
}

function Short-Preview {
  param(
    [string]$Text,
    [int]$MaxLen = 80
  )

  if (-not $Text) { return '<example preview text>' }

  $oneLine = ($Text -replace "`r?`n", ' ')
  $collapsed = [Regex]::Replace($oneLine, '\s+', ' ').Trim()
  if ($collapsed.Length -le $MaxLen) { return $collapsed }

  return $collapsed.Substring(0, $MaxLen) + '...'
}

$wxArgs = @('new-messages', '--json')
if ($Since) {
  try {
    [void][DateTime]::Parse($Since)
  } catch {
    throw "Invalid -Since value '$Since'. Use a date like 2026-05-10."
  }
  $wxArgs += @('--since', $Since)
}

$json = ''
$wxFailed = $false
try {
  $json = & wx @wxArgs 2>&1 | Out-String
  if ($LASTEXITCODE -ne 0) {
    $wxFailed = $true
  }
} catch {
  $json = $_.Exception.Message
  $wxFailed = $true
}

if ($wxFailed) {
  Write-Error "Failed to run wx new-messages. If daemon is not running, try: wx daemon stop && wx new-messages"
  if ($json) { Write-Error $json.Trim() }
  exit 1
}

if (-not $json.Trim()) {
  Write-Host 'No new messages.' -ForegroundColor DarkGray
  exit 0
}

$messages = $null
try {
  $messages = $json | ConvertFrom-Json
} catch {
  Write-Error 'wx new-messages returned non-JSON output. Ensure wx daemon is healthy: wx daemon stop && wx new-messages'
  exit 1
}

if ($messages -isnot [System.Array]) {
  $messages = @($messages)
}

if ($messages.Count -eq 0) {
  Write-Host 'No new messages.' -ForegroundColor DarkGray
  exit 0
}

$ballMap = Get-BallInCourtMap
$groups = $messages | Group-Object {
  if ($_.contactName) { $_.contactName }
  elseif ($_.talker) { $_.talker }
  else { 'Unknown' }
}

$rows = @()
foreach ($g in $groups) {
  $lastMsg = $g.Group | Sort-Object {
    if ($_.timestamp) { $_.timestamp }
    elseif ($_.time) { $_.time }
    else { '' }
  } | Select-Object -Last 1

  $lastTime = if ($lastMsg.timestamp) { $lastMsg.timestamp }
              elseif ($lastMsg.time) { $lastMsg.time }
              else { '-' }

  $body = if ($lastMsg.content) { $lastMsg.content }
          elseif ($lastMsg.text) { $lastMsg.text }
          elseif ($lastMsg.message) { $lastMsg.message }
          else { '' }

  $slug = $g.Name.ToString().ToLowerInvariant()
  $ball = ''
  if ($ballMap.ContainsKey($slug)) {
    $ball = $ballMap[$slug]
  }
  $flag = if ($ball -eq 'me') { '⚠️' } else { '' }

  $rows += [PSCustomObject]@{
    Name = $g.Name
    Count = $g.Count
    LastTime = $lastTime
    Preview = Short-Preview -Text $body -MaxLen 80
    Ball = $flag
  }
}

$rows = $rows | Sort-Object LastTime -Descending

$header = "{0,-20} {1,6} {2,-19} {3,-83} {4}" -f '名字', '消息数', '最后消息时间', '前 80 字预览', '球在你?'
Write-Host $header -ForegroundColor Cyan
Write-Host ('-' * 150) -ForegroundColor DarkGray

foreach ($r in $rows) {
  $line = "{0,-20} {1,6} {2,-19} {3,-83} {4}" -f $r.Name, $r.Count, $r.LastTime, $r.Preview, $r.Ball
  $color = if ($r.Ball -eq '⚠️') { 'Yellow' } else { 'White' }
  Write-Host $line -ForegroundColor $color
}

if ($Write) {
  $out = @()
  $out += '# DIGEST'
  $out += ''
  $out += "generated-at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  if ($Since) { $out += "since: $Since" }
  $out += ''
  $out += '| 名字 | 消息数 | 最后消息时间 | 前 80 字预览 | 球在你? |'
  $out += '|---|---:|---|---|---|'
  foreach ($r in $rows) {
    $preview = $r.Preview.Replace('|', '\|')
    $out += "| $($r.Name) | $($r.Count) | $($r.LastTime) | $preview | $($r.Ball) |"
  }
  Set-Content -Path 'DIGEST.md' -Value ($out -join "`n") -Encoding UTF8
  Write-Host "`nWrote DIGEST.md" -ForegroundColor Green
}
