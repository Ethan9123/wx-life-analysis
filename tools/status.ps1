<#
.SYNOPSIS
  Print a one-line status row for every active contact and project.

.DESCRIPTION
  Walks people/*/profile.md and projects/*/notes.md, parses YAML
  frontmatter, extracts `last-updated`, `ball-in-court`, and
  `next-action`, and prints a compact table.

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

  for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]

    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line.TrimStart().StartsWith('#')) { continue }

    $kv = [Regex]::Match($line, '^([A-Za-z0-9_-]+)\s*:\s*(.*)$')
    if (-not $kv.Success) { continue }

    $key = $kv.Groups[1].Value
    $value = $kv.Groups[2].Value.Trim()

    if ($key -eq 'tags') {
      $tags = @()
      if ($value -match '^\[(.*)\]$') {
        $inline = $matches[1].Trim()
        if ($inline) {
          $tags = $inline -split '\s*,\s*' | Where-Object { $_ -ne '' }
        }
      } else {
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
          $nextLine = $lines[$j]
          if ([string]::IsNullOrWhiteSpace($nextLine)) { continue }

          if ($nextLine -match '^\s*-' ) {
            $tagValue = [Regex]::Replace($nextLine, '^\s*-\s*', '').Trim()
            if ($tagValue) { $tags += $tagValue }
            $i = $j
            continue
          }

          if ($nextLine -match '^\s') {
            $i = $j
            continue
          }

          break
        }
      }
      $map[$key] = $tags
      continue
    }

    if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
      $value = $matches[1]
    }

    $map[$key] = $value
  }

  return $map
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
  $meta = Get-FrontmatterMap -Path $profile
  $updated = $meta['last-updated']
  $ball = $meta['ball-in-court']
  $next = $meta['next-action']
  Show-Row 'person' $d.Name $updated $ball $next
}

# Projects
$projectDirs = Get-ChildItem -Path 'projects' -Directory -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne '_template' }
foreach ($d in $projectDirs) {
  $notes = Join-Path $d.FullName 'notes.md'
  if (-not (Test-Path $notes)) { continue }
  $meta = Get-FrontmatterMap -Path $notes
  $updated = $meta['last-updated']
  $ball = $meta['ball-in-court']
  $next = $meta['next-action']
  Show-Row 'project' $d.Name $updated $ball $next
}

Write-Host ''
Write-Host "rows in Yellow are older than $StaleDays days" -ForegroundColor DarkGray
