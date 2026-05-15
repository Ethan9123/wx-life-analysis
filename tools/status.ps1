<#
.SYNOPSIS
  Print a one-line status row for every active contact and project.

.DESCRIPTION
  Walks people/*/profile.md and projects/*/notes.md, extracts the
  `last-updated:`, `球在谁那:` (ball-in-court), and `下次动作:` (next action)
  frontmatter fields, and prints a compact table.

  Useful at the start of a session to see what's stale and where to focus.

.EXAMPLE
  .\tools\status.ps1

.EXAMPLE
  .\tools\status.ps1 -StaleDays 7
  # highlight rows not updated in the last 7 days
#>

[CmdletBinding()]
param(
  [int]$StaleDays = 7
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

function Get-FrontmatterField {
  param(
    [string]$Path,
    [string]$Field
  )
  if (-not (Test-Path $Path)) { return $null }
  $content = Get-Content $Path -Raw -Encoding UTF8
  # Match either `field: value` or `**field**: value` or `- field: value`
  $pattern = "(?im)^\s*[-*]?\s*\*{0,2}$([Regex]::Escape($Field))\*{0,2}\s*[:：]\s*(.+?)\s*$"
  $m = [Regex]::Match($content, $pattern)
  if ($m.Success) { return $m.Groups[1].Value.Trim() }
  return $null
}

function Show-Row {
  param($Kind, $Name, $Updated, $Ball, $Next)

  $now = Get-Date
  $isStale = $false
  if ($Updated) {
    try {
      $u = [DateTime]::Parse($Updated)
      $isStale = ($now - $u).TotalDays -gt $StaleDays
    } catch { }
  }

  $color = if ($isStale) { 'Yellow' } else { 'White' }
  $updatedShow = if ($Updated) { $Updated } else { '(no date)' }
  $ballShow    = if ($Ball)    { $Ball }    else { '-' }
  $nextShow    = if ($Next)    { $Next }    else { '-' }

  $line = "{0,-8} {1,-16} {2,-12} {3,-10} {4}" -f $Kind, $Name, $updatedShow, $ballShow, $nextShow
  Write-Host $line -ForegroundColor $color
}

Write-Host ("{0,-8} {1,-16} {2,-12} {3,-10} {4}" -f 'KIND', 'NAME', 'UPDATED', 'BALL', 'NEXT') -ForegroundColor Cyan
Write-Host ('-' * 80) -ForegroundColor DarkGray

# People
$peopleDirs = Get-ChildItem -Path 'people' -Directory -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -ne '_template' }
foreach ($d in $peopleDirs) {
  $profile = Join-Path $d.FullName 'profile.md'
  if (-not (Test-Path $profile)) { continue }
  $updated = Get-FrontmatterField -Path $profile -Field 'last-updated'
  $ball    = Get-FrontmatterField -Path $profile -Field '球在谁那'
  if (-not $ball) { $ball = Get-FrontmatterField -Path $profile -Field 'ball-in-court' }
  $next    = Get-FrontmatterField -Path $profile -Field '下次动作'
  if (-not $next) { $next = Get-FrontmatterField -Path $profile -Field 'next-action' }
  Show-Row 'person' $d.Name $updated $ball $next
}

# Projects
$projectDirs = Get-ChildItem -Path 'projects' -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne '_template' }
foreach ($d in $projectDirs) {
  $notes = Join-Path $d.FullName 'notes.md'
  if (-not (Test-Path $notes)) { continue }
  $updated = Get-FrontmatterField -Path $notes -Field 'last-updated'
  $ball    = Get-FrontmatterField -Path $notes -Field '球在谁那'
  if (-not $ball) { $ball = Get-FrontmatterField -Path $notes -Field 'ball-in-court' }
  $next    = Get-FrontmatterField -Path $notes -Field '下次动作'
  if (-not $next) { $next = Get-FrontmatterField -Path $notes -Field 'next-action' }
  Show-Row 'project' $d.Name $updated $ball $next
}

Write-Host ''
Write-Host "rows in Yellow are older than $StaleDays days" -ForegroundColor DarkGray
