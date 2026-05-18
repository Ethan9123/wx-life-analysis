<#
.SYNOPSIS
  List or extract WeChat chat attachments (images / files / videos / voice) for one contact.

.DESCRIPTION
  Wraps `wx attachments` (list) and `wx extract` (decrypt + save). Two modes:

  * **List mode** (default): emit a markdown / JSON table of attachments
    matching the filters. No files written.
  * **Extract mode**: when `-Extract` or `-ExtractAll` is given, decrypt the
    selected attachments to `-Out`. `-Out` is required for extract mode.

  Useful when a contact (especially a work-stakeholder like a boss) sends
  PDFs / images / files that you need locally as project material —
  `task-extract.ps1` then reads the extracted text via `extract-pdf.js`.

  Output directories under `people/<slug>/attachments/` or `projects/<slug>/raw/`
  are already gitignored.

.PARAMETER Name
  Contact display name. Required. Use `tools/contacts.ps1 -Query` first if unsure.

.PARAMETER Kind
  image | file | video | voice | all. Default `all`.

.PARAMETER N
  Max attachments to list. Default 50.

.PARAMETER Since
  YYYY-MM-DD cutoff. Optional.

.PARAMETER Until
  YYYY-MM-DD upper bound. Optional.

.PARAMETER Extract
  Comma-separated list of attachment ids to extract. Triggers extract mode.

.PARAMETER ExtractAll
  Extract every attachment matching the list filters. Triggers extract mode.

.PARAMETER Out
  Output directory for extracted files. Required for extract mode.

.PARAMETER Format
  markdown | json. Default markdown. Ignored in extract mode.

.EXAMPLE
  .\tools\attachments.ps1 -Name "Alice" -Kind file -Since "2026-05-01"
  # List all files Alice sent since May 1.

.EXAMPLE
  .\tools\attachments.ps1 -Name "Alice" -Kind file -Since "2026-05-01" -ExtractAll -Out "projects/acme-launch/raw"
  # Extract every file Alice sent since May 1 into projects/acme-launch/raw/

.EXAMPLE
  .\tools\attachments.ps1 -Name "Alice" -Extract "att_abc123","att_def456" -Out "projects/acme-launch/raw"
  # Extract two specific attachments by id.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [ValidateSet('image', 'file', 'video', 'voice', 'all')]
  [string]$Kind = 'all',
  [int]$N = 50,
  [string]$Since,
  [string]$Until,
  [string[]]$Extract,
  [switch]$ExtractAll,
  [string]$Out,
  [ValidateSet('markdown', 'json')]
  [string]$Format = 'markdown'
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

$wx = Get-Command wx -ErrorAction SilentlyContinue
if (-not $wx) {
  Write-Error "wx-cli not found on PATH. Install with: npm install -g @jackwener/wx-cli"
  exit 2
}

$wantsExtract = ($Extract -and $Extract.Count -gt 0) -or $ExtractAll

if ($wantsExtract -and -not $Out) {
  Write-Error "-Out is required when -Extract or -ExtractAll is used"
  exit 1
}

# Build list-mode wx args
$wxArgs = @('attachments', $Name, '--json', '-n', "$N")
if ($Kind -ne 'all') { $wxArgs += '--kind', $Kind }
if ($Since)          { $wxArgs += '--since', $Since }
if ($Until)          { $wxArgs += '--until', $Until }

$raw = wx @wxArgs 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Error "wx attachments failed (exit $LASTEXITCODE). Is the daemon running? Try: wx daemon stop; wx new-messages"
  exit $LASTEXITCODE
}

try {
  $data = $raw | Out-String | ConvertFrom-Json
} catch {
  Write-Error "Could not parse wx attachments output as JSON. Sample: $($raw | Out-String | Select-Object -First 200)"
  exit 3
}

if (-not $data -or $data.Count -eq 0) {
  Write-Host "No attachments match (name='$Name', kind=$Kind, since=$Since, until=$Until, n=$N)."
  exit 0
}

# === List mode ===
if (-not $wantsExtract) {
  if ($Format -eq 'json') {
    $data | ConvertTo-Json -Depth 4
    exit 0
  }

  $out = @()
  $out += "# wx attachments — $Name"
  $out += ""
  $filters = @()
  if ($Kind -ne 'all') { $filters += "kind=$Kind" }
  if ($Since)          { $filters += "since=$Since" }
  if ($Until)          { $filters += "until=$Until" }
  $filters += "n=$N"
  $out += "Filters: $($filters -join ', ')"
  $out += ""
  $out += "| Id | Kind | Filename / preview | Sender | Timestamp | Size |"
  $out += "|---|---|---|---|---|---:|"

  foreach ($a in $data) {
    $id       = if ($a.id) { $a.id } elseif ($a.attachment_id) { $a.attachment_id } else { '' }
    $kind     = if ($a.kind) { $a.kind } elseif ($a.type) { $a.type } else { '' }
    $filename = if ($a.filename) { $a.filename } elseif ($a.name) { $a.name } elseif ($a.preview) { $a.preview } else { '' }
    $sender   = if ($a.sender) { $a.sender } elseif ($a.from) { $a.from } else { '' }
    $ts       = if ($a.timestamp) { $a.timestamp } elseif ($a.time) { $a.time } else { '' }
    $size     = if ($a.size) { $a.size } elseif ($a.bytes) { $a.bytes } else { '' }
    $out += "| $id | $kind | $filename | $sender | $ts | $size |"
  }
  $out += ""
  $out += "_Pass an `Id` to `attachments.ps1 -Extract <id> -Out <dir>` or use `-ExtractAll` to pull every row above._"
  $out -join "`n"
  exit 0
}

# === Extract mode ===
if (-not (Test-Path $Out)) {
  New-Item -ItemType Directory -Force -Path $Out | Out-Null
  Write-Host "[attachments] created $Out" -ForegroundColor Green
}

$idsToExtract = if ($ExtractAll) {
  $data | ForEach-Object {
    if ($_.id) { $_.id } elseif ($_.attachment_id) { $_.attachment_id }
  } | Where-Object { $_ }
} else {
  $Extract
}

$failures = 0
$successes = 0
foreach ($id in $idsToExtract) {
  $info = $data | Where-Object {
    ($_.id -eq $id) -or ($_.attachment_id -eq $id)
  } | Select-Object -First 1

  $filename = if ($info -and $info.filename) { $info.filename }
              elseif ($info -and $info.name) { $info.name }
              else { "$id.bin" }

  # Sanitize filename — no path separators, no shell-meta
  $safeFilename = $filename -replace '[\\/:*?"<>|]', '_'
  $outPath = Join-Path $Out $safeFilename

  Write-Host "[attachments] extracting $id -> $outPath" -ForegroundColor Cyan
  wx extract $id -o $outPath
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Failed to extract $id (exit $LASTEXITCODE)"
    $failures += 1
  } else {
    $successes += 1
  }
}

Write-Host ""
Write-Host "[attachments] done. extracted=$successes failed=$failures out=$Out" -ForegroundColor Green
if ($failures -gt 0) { exit 1 }
