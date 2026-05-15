<#
.SYNOPSIS
  Pull latest chat, SNS feed, and stats for one WeChat contact into a local directory.

.DESCRIPTION
  Wraps `wx export`, `wx sns-feed`, and `wx stats` from @jackwener/wx-cli.
  Output files are gitignored (under people/<name>/ or projects/<name>/).

.PARAMETER Name
  The contact's display name / remark name in WeChat. Required.

.PARAMETER Dir
  The output directory (relative to repo root). Required.
  Examples: people/zhangsan, people/alice

.PARAMETER N
  Max number of chat messages to export. Default 500.

.PARAMETER SnsN
  Max number of SNS (Moments) entries. Default 50.

.PARAMETER SkipSns
  Skip SNS feed pull (some contacts have privacy settings that block it).

.EXAMPLE
  .\tools\refresh.ps1 -Name "张三" -Dir "people/zhangsan"

.EXAMPLE
  .\tools\refresh.ps1 -Name "Alice" -Dir "people/alice" -N 1000 -SkipSns
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][string]$Dir,
  [int]$N = 500,
  [int]$SnsN = 50,
  [switch]$SkipSns
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

# 1. Export chat
Write-Host "[refresh] exporting chat ($N messages) -> $chatPath" -ForegroundColor Cyan
wx export $Name -n $N --format markdown -o $chatPath
# Note: wx.exe stdout sometimes shows as RemoteException in PowerShell — that's a
# PowerShell quirk, not a real error. Check $LASTEXITCODE, not $?.
if ($LASTEXITCODE -ne 0) {
  Write-Error "wx export failed (exit $LASTEXITCODE)"
  exit $LASTEXITCODE
}

# 2. SNS feed (optional)
if (-not $SkipSns) {
  Write-Host "[refresh] pulling SNS feed -> $snsPath" -ForegroundColor Cyan
  $sns = wx sns-feed --user $Name -n $SnsN --json 2>&1
  if ($LASTEXITCODE -eq 0) {
    $sns | Out-File $snsPath -Encoding utf8
  } else {
    Write-Warning "wx sns-feed failed (exit $LASTEXITCODE) — skipping. Use -SkipSns to suppress."
  }
}

# 3. Stats
Write-Host "[refresh] computing stats -> $statsPath" -ForegroundColor Cyan
wx stats $Name | Out-File $statsPath -Encoding utf8

# 4. Sync timestamp
$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
"$timestamp" | Out-File $syncPath -Encoding utf8

Write-Host "[refresh] done. last-sync: $timestamp" -ForegroundColor Green
Write-Host ""
Write-Host "Next: read $chatPath and update $Dir\profile.md" -ForegroundColor Yellow
