<#
.SYNOPSIS
  Pull latest chat, SNS feed, and stats for one WeChat contact into a local directory.

.DESCRIPTION
  Wraps `wx export`, `wx sns-feed`, and `wx stats` from @jackwener/wx-cli.
  Output files are gitignored (under people/<slug>/).

  **Incremental by default**: if `.last-sync` exists in the target directory,
  uses `wx export --since <date>` to pull only new messages since the last
  refresh. First run (no `.last-sync`) falls back to `-n $N` initial seed.
  Use `-Full` to force a full re-pull regardless.

.PARAMETER Name
  The contact's display name / remark name in WeChat. Required.

.PARAMETER Dir
  The output directory (relative to repo root). Required.
  Examples: people/zhangsan, people/alice

.PARAMETER N
  Max number of chat messages on initial seed (no `.last-sync` yet, or `-Full`).
  Default 500. Ignored when running incrementally.

.PARAMETER SnsN
  Max number of SNS (Moments) entries. Default 50.

.PARAMETER SkipSns
  Skip SNS feed pull (some contacts have privacy settings that block it).

.PARAMETER Full
  Force a full re-pull (ignore `.last-sync`, use `-n $N`).

.PARAMETER Since
  Manually specify the cutoff date (YYYY-MM-DD). Overrides `.last-sync` and `-Full`.

.EXAMPLE
  .\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan"
  # First run: pulls -n 500. Subsequent runs: incremental from last-sync.

.EXAMPLE
  .\tools\refresh.ps1 -Name "Alice" -Dir "people/alice" -Full
  # Force a full re-pull of the last 500 messages.

.EXAMPLE
  .\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan" -Since "2026-05-01"
  # Pull everything since 2026-05-01, ignoring last-sync.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][string]$Dir,
  [int]$N = 500,
  [int]$SnsN = 50,
  [switch]$SkipSns,
  [switch]$Full,
  [string]$Since
)

# Force UTF-8 for Chinese names / content
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Verify wx is on PATH
$wx = Get-Command wx -ErrorAction SilentlyContinue
if (-not $wx) {
  Write-Error "wx-cli not found on PATH. Install with: npm install -g @jackwener/wx-cli"
  exit 2
}

# Create output dir
if (-not (Test-Path $Dir)) {
  New-Item -ItemType Directory -Force -Path $Dir | Out-Null
  Write-Host "[refresh] created $Dir" -ForegroundColor Green
}

$chatPath = Join-Path $Dir 'chat.md'
$snsPath  = Join-Path $Dir 'sns.json'
$statsPath = Join-Path $Dir 'stats.txt'
$syncPath = Join-Path $Dir '.last-sync'

# Decide cutoff: -Since > .last-sync (unless -Full) > nothing (initial seed via -n)
$sinceDate = $null
if ($Since) {
  $sinceDate = $Since
  Write-Host "[refresh] mode: explicit -Since $sinceDate" -ForegroundColor DarkCyan
} elseif (-not $Full -and (Test-Path $syncPath)) {
  $lastSync = (Get-Content $syncPath -Raw -Encoding UTF8).Trim()
  # .last-sync stores "yyyy-MM-dd HH:mm:ss". wx-cli --since takes a date,
  # so split off the date portion.
  if ($lastSync -match '^(\d{4}-\d{2}-\d{2})') {
    $sinceDate = $matches[1]
    Write-Host "[refresh] mode: incremental since $sinceDate" -ForegroundColor DarkCyan
  } else {
    Write-Warning "[refresh] .last-sync file exists but unparseable: '$lastSync' — falling back to -n $N"
  }
} elseif ($Full) {
  Write-Host "[refresh] mode: -Full (re-pull last $N)" -ForegroundColor DarkCyan
} else {
  Write-Host "[refresh] mode: initial seed (last $N messages)" -ForegroundColor DarkCyan
}

# 1. Export chat
if ($sinceDate) {
  Write-Host "[refresh] exporting chat (since $sinceDate) -> $chatPath" -ForegroundColor Cyan
  wx export $Name --since $sinceDate --format markdown -o $chatPath
} else {
  Write-Host "[refresh] exporting chat ($N messages) -> $chatPath" -ForegroundColor Cyan
  wx export $Name -n $N --format markdown -o $chatPath
}
# Note: wx.exe stdout sometimes shows as RemoteException in PowerShell — that's a
# PowerShell quirk, not a real error. Check $LASTEXITCODE, not $?.
if ($LASTEXITCODE -ne 0) {
  Write-Error "wx export failed (exit $LASTEXITCODE)"
  exit $LASTEXITCODE
}

# 2. SNS feed (optional). Also use --since when available.
if (-not $SkipSns) {
  Write-Host "[refresh] pulling SNS feed -> $snsPath" -ForegroundColor Cyan
  if ($sinceDate) {
    $sns = wx sns-feed --user $Name --since $sinceDate --json 2>&1
  } else {
    $sns = wx sns-feed --user $Name -n $SnsN --json 2>&1
  }
  if ($LASTEXITCODE -eq 0) {
    $sns | Out-File $snsPath -Encoding utf8
  } else {
    Write-Warning "wx sns-feed failed (exit $LASTEXITCODE) — skipping. Use -SkipSns to suppress."
  }
}

# 3. Stats (always full — wx stats has its own time range; we just snapshot it)
Write-Host "[refresh] computing stats -> $statsPath" -ForegroundColor Cyan
wx stats $Name | Out-File $statsPath -Encoding utf8

# 4. Sync timestamp
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
"$timestamp" | Out-File $syncPath -Encoding utf8

Write-Host "[refresh] done. last-sync: $timestamp" -ForegroundColor Green
Write-Host ""
Write-Host "Next: read $chatPath and update $Dir\profile.md" -ForegroundColor Yellow
