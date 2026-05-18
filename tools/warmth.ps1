<#
.SYNOPSIS
  Summarize SNS engagement on your own posts — who's been liking and commenting.

.DESCRIPTION
  Wraps `wx sns-notifications`. Groups by sender, ranks by recent engagement,
  and emits a Markdown table or JSON. Useful as the "warmth gauge" referenced in
  docs/mbti-analysis.md — answers "who's still actively engaging with my SNS,
  who's gone silent, and over what window".

  Per-contact engagement is one of the higher-signal inputs to the per-person
  MBTI + comms-strategy analysis. Don't conflate it with chat warmth — some
  people compartmentalize (active in 1:1, silent on SNS) and the reverse.

.PARAMETER N
  Max number of notifications to pull. Default 100.

.PARAMETER IncludeRead
  Include already-read notifications. Default: only unread.

.PARAMETER Out
  Optional output file (default: stdout).

.PARAMETER Format
  markdown | json. Default markdown.

.EXAMPLE
  .\tools\warmth.ps1
  # markdown table grouped by sender

.EXAMPLE
  .\tools\warmth.ps1 -IncludeRead -N 300 -Out reports/warmth.md
  # wider window with all read+unread notifications, written to file

.EXAMPLE
  .\tools\warmth.ps1 -Format json | jq '.[] | select(.count > 5)'
  # JSON pipe to jq for further filtering
#>

[CmdletBinding()]
param(
  [int]$N = 100,
  [switch]$IncludeRead,
  [string]$Out,
  [ValidateSet('markdown', 'json')]
  [string]$Format = 'markdown'
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Verify wx is on PATH
$wx = Get-Command wx -ErrorAction SilentlyContinue
if (-not $wx) {
  Write-Error "wx-cli not found on PATH. Install with: npm install -g @jackwener/wx-cli"
  exit 2
}

# Build wx args
$wxArgs = @('sns-notifications', '--json', '-n', "$N")
if ($IncludeRead) { $wxArgs += '--include-read' }

# Capture output. Note: wx.exe stdout sometimes shows as RemoteException in PS — that's a
# PS quirk, not a real error. Check $LASTEXITCODE.
$raw = wx @wxArgs 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Error "wx sns-notifications failed (exit $LASTEXITCODE). Is the daemon running? Try: wx daemon stop; wx new-messages"
  exit $LASTEXITCODE
}

# Parse JSON
try {
  $data = $raw | Out-String | ConvertFrom-Json
} catch {
  Write-Error "Could not parse wx sns-notifications output as JSON. Sample: $($raw | Out-String | Select-Object -First 200)"
  exit 3
}

if (-not $data -or $data.Count -eq 0) {
  Write-Host "No SNS notifications in window (n=$N, include-read=$IncludeRead)."
  exit 0
}

# Group by sender. Each notification has: sender (or user), type (like|comment), post_id, timestamp, content
$groups = $data | Group-Object -Property {
  if ($_.sender) { $_.sender }
  elseif ($_.user) { $_.user }
  elseif ($_.from) { $_.from }
  else { '<unknown>' }
}

$rows = foreach ($g in $groups) {
  $sender = $g.Name
  $count = $g.Count
  $likes = ($g.Group | Where-Object { $_.type -eq 'like' -or $_.kind -eq 'like' }).Count
  $comments = ($g.Group | Where-Object { $_.type -eq 'comment' -or $_.kind -eq 'comment' }).Count

  # Latest engagement timestamp
  $tsRaw = $g.Group | ForEach-Object {
    if ($_.timestamp) { $_.timestamp }
    elseif ($_.time) { $_.time }
    elseif ($_.created_at) { $_.created_at }
  } | Sort-Object -Descending | Select-Object -First 1

  [PSCustomObject]@{
    sender   = $sender
    total    = $count
    likes    = $likes
    comments = $comments
    latest   = $tsRaw
  }
}

$rows = $rows | Sort-Object -Property total -Descending

# Emit
if ($Format -eq 'json') {
  $emitted = $rows | ConvertTo-Json -Depth 4
} else {
  $emitted = @()
  $emitted += "# Warmth gauge — SNS engagement on your posts"
  $emitted += ""
  $emitted += "Window: latest $N notifications" + ($(if ($IncludeRead) { " (incl. read)" } else { " (unread only)" }))
  $emitted += "Source: ``wx sns-notifications``"
  $emitted += ""
  $emitted += "| Sender | Total | Likes | Comments | Latest |"
  $emitted += "|---|---:|---:|---:|---|"
  foreach ($r in $rows) {
    $sender = if ($r.sender) { $r.sender } else { '<unknown>' }
    $latest = if ($r.latest) { $r.latest } else { '-' }
    $emitted += "| $sender | $($r.total) | $($r.likes) | $($r.comments) | $latest |"
  }
  $emitted += ""
  $emitted += "_Read this alongside `chat.md` + `sns.json` per `docs/mbti-analysis.md` § Interaction signals._"
  $emitted = $emitted -join "`n"
}

if ($Out) {
  $emitted | Out-File -FilePath $Out -Encoding utf8
  Write-Host "[warmth] wrote $Out"
} else {
  Write-Output $emitted
}
