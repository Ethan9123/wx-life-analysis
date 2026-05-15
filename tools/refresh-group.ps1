<##
.SYNOPSIS
  Pull one WeChat group chat into topics/<slug>/.

.PARAMETER Name
  Group display name in WeChat. Required.

.PARAMETER Slug
  ASCII slug for topics/<slug>/, must match ^[a-z0-9][a-z0-9-]*$. Required.

.PARAMETER SinceDays
  Pull only last N days (default: 14).

.PARAMETER SinceDate
  Pull from this date (YYYY-MM-DD). Overrides SinceDays.

.PARAMETER Format
  Export format: markdown or json (default: json).

.PARAMETER Out
  Optional output path. Default: topics/<slug>/chat.json or chat.md.

.EXAMPLE
  .\tools\refresh-group.ps1 -Name "研发群" -Slug "rd-group"

.EXAMPLE
  .\tools\refresh-group.ps1 -Name "Acme Team Chat" -Slug "acme-team" -SinceDays 30

.EXAMPLE
  .\tools\refresh-group.ps1 -Name "AI讨论" -Slug "ai-discuss" -SinceDate "2026-04-01"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][string]$Slug,
  [int]$SinceDays = 14,
  [string]$SinceDate,
  [ValidateSet('markdown', 'json')][string]$Format = 'json',
  [string]$Out
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

if ($Slug -notmatch '^[a-z0-9][a-z0-9-]*$') {
  throw 'Slug 必须是 ASCII 小写连字符，例如 `ungc-work-group`，不能用「UNGC 工作群」'
}
if ($SinceDays -lt 0) {
  throw '-SinceDays must be a non-negative integer'
}
if ($SinceDate -and $SinceDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
  throw '-SinceDate must be in YYYY-MM-DD format'
}

$wx = Get-Command wx -ErrorAction SilentlyContinue
if (-not $wx) {
  Write-Error 'wx-cli not found on PATH. Install with: npm install -g @jackwener/wx-cli'
  exit 2
}

$topicDir = Join-Path 'topics' $Slug
if (-not (Test-Path $topicDir)) {
  New-Item -ItemType Directory -Force -Path $topicDir | Out-Null
  Write-Host "[refresh-group] created $topicDir" -ForegroundColor Green
}

$ext = if ($Format -eq 'markdown') { 'md' } else { 'json' }
if (-not $Out) {
  $Out = Join-Path $topicDir ("chat.$ext")
}

$membersPath = Join-Path $topicDir 'members.json'
$syncPath = Join-Path $topicDir '.last-sync'

$since = if ($SinceDate) { $SinceDate } else { (Get-Date).AddDays(-$SinceDays).ToString('yyyy-MM-dd') }

Write-Host "[refresh-group] pulling members -> $membersPath" -ForegroundColor Cyan
wx members $Name --json | Out-File $membersPath -Encoding utf8
if ($LASTEXITCODE -ne 0) {
  Write-Error "wx members failed (exit $LASTEXITCODE)"
  exit $LASTEXITCODE
}

Write-Host "[refresh-group] exporting group chat since $since ($Format) -> $Out" -ForegroundColor Cyan
wx export $Name --since $since --format $Format -o $Out
if ($LASTEXITCODE -ne 0) {
  Write-Error "wx export failed (exit $LASTEXITCODE)"
  exit $LASTEXITCODE
}

$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$timestamp | Out-File $syncPath -Encoding utf8

Write-Host "[refresh-group] done. last-sync: $timestamp" -ForegroundColor Green
