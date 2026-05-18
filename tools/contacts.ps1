<#
.SYNOPSIS
  Fuzzy-lookup a WeChat contact and confirm the exact display name before refresh.

.DESCRIPTION
  Wraps `wx contacts --query`. Returns matching contacts with their canonical
  display name, remark, alias, chat type, and most-recent activity. Use this
  before `tools/refresh.ps1` to confirm you're targeting the right person — WeChat
  names can have look-alikes (multiple "张三"s, the contact's actual remark
  differing from their nickname, etc).

  This is a *lookup* tool, not a data-pull tool. It hits `wx contacts` only —
  no chat history, no SNS, no statistics. Output is intended for the agent
  (or the user) to read once, pick the right `display_name`, then pass it to
  `refresh.ps1 -Name`.

.PARAMETER Query
  Substring to fuzzy-match against display name, remark, alias, or wxid.
  If omitted, dumps all contacts (capped by -N).

.PARAMETER N
  Max rows to return. Default 50.

.PARAMETER Format
  markdown | json. Default markdown.

.EXAMPLE
  .\tools\contacts.ps1 -Query "张"
  # Find all contacts matching '张' (multiple 张三 / 张丽 / etc)

.EXAMPLE
  .\tools\contacts.ps1 -Query "alice" -Format json
  # JSON output for programmatic filtering

.EXAMPLE
  .\tools\contacts.ps1
  # First 50 contacts (no filter)
#>

[CmdletBinding()]
param(
  [string]$Query,
  [int]$N = 50,
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

# Build wx args
$wxArgs = @('contacts', '--json')
if ($Query) { $wxArgs += '--query', $Query }

$raw = wx @wxArgs 2>&1
if ($LASTEXITCODE -ne 0) {
  Write-Error "wx contacts failed (exit $LASTEXITCODE). Is the daemon running? Try: wx daemon stop; wx new-messages"
  exit $LASTEXITCODE
}

try {
  $data = $raw | Out-String | ConvertFrom-Json
} catch {
  Write-Error "Could not parse wx contacts output as JSON."
  exit 3
}

if (-not $data -or $data.Count -eq 0) {
  if ($Query) {
    Write-Host "No contacts match '$Query'."
  } else {
    Write-Host "No contacts returned."
  }
  exit 0
}

# Cap to -N (wx contacts may return huge lists)
$rows = $data | Select-Object -First $N

if ($Format -eq 'json') {
  $rows | ConvertTo-Json -Depth 4
  exit 0
}

# Markdown table
$out = @()
$out += "# wx contacts lookup" + ($(if ($Query) { " — query: \`$Query\`" } else { "" }))
$out += ""
$out += "| Display name | Remark | Alias | Chat type | wxid | Last msg |"
$out += "|---|---|---|---|---|---|"

foreach ($r in $rows) {
  $display = if ($r.display_name) { $r.display_name } elseif ($r.nickname) { $r.nickname } else { '' }
  $remark  = if ($r.remark) { $r.remark } else { '' }
  $alias   = if ($r.alias) { $r.alias } else { '' }
  $type    = if ($r.chat_type) { $r.chat_type } elseif ($r.type) { $r.type } else { '' }
  $wxid    = if ($r.wxid) { $r.wxid } else { '' }
  $last    = if ($r.last_message_time) { $r.last_message_time } elseif ($r.last_msg) { $r.last_msg } else { '' }
  $out += "| $display | $remark | $alias | $type | $wxid | $last |"
}

$out += ""
$out += "_Pass the exact \`Display name\` to \`refresh.ps1 -Name\` for the right contact._"

$out -join "`n"
