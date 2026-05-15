<#
.SYNOPSIS
  First-pass TODO candidate extractor from chat + optional project/topic files.

.DESCRIPTION
  Companion tool for docs/task-extract.md.
  This script only does first-pass candidate filtering by pattern matching.
  It does NOT call any LLM, does NOT do final bucket classification, and does NOT write notes.md.

  Methodology reference:
  docs/task-extract.md

.EXAMPLE
  .\tools\task-extract.ps1 -Person zhangsan -Project acme-launch

.EXAMPLE
  .\tools\task-extract.ps1 -Person zhangsan -Since "2026-05-01"

.EXAMPLE
  .\tools\task-extract.ps1 -Person zhangsan -Project acme-launch -Out projects/acme-launch/task-candidates.md
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Person,
  [string]$Project,
  [string]$Since,
  [string]$Out
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

function Parse-SinceDate {
  param([string]$SinceText)
  if ([string]::IsNullOrWhiteSpace($SinceText)) {
    return (Get-Date).Date.AddDays(-30)
  }
  try {
    return [DateTime]::ParseExact($SinceText, 'yyyy-MM-dd', $null)
  } catch {
    throw "Since 参数格式错误。请使用 yyyy-MM-dd，例如 2026-05-01（示例名：Alice）。"
  }
}

$sinceDate = Parse-SinceDate -SinceText $Since
$chatPath = Join-Path (Join-Path 'people' $Person) 'chat.md'
if (-not (Test-Path $chatPath)) {
  throw "找不到聊天文件：$chatPath。请先运行 refresh 脚本（示例联系人：张三）。"
}

if ([string]::IsNullOrWhiteSpace($Out)) {
  if ($Project) {
    $Out = Join-Path (Join-Path 'projects' $Project) 'task-candidates.md'
  } else {
    $Out = 'task-candidates.md'
  }
}

$outDir = Split-Path -Parent $Out
if ($outDir -and -not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

$lines = Get-Content -Path $chatPath -Encoding UTF8
$messages = New-Object System.Collections.Generic.List[object]

# Best-effort parser for wx markdown export.
# Expected common line shapes:
# - 2026-05-14 14:44 Alice: message
# - [2026-05-14 14:44] Alice: message
# - 2026/05/14 14:44 张三: message
$parseMiss = 0
foreach ($line in $lines) {
  if ([string]::IsNullOrWhiteSpace($line)) { continue }

  $m = [Regex]::Match($line, '^\[?(?<dt>\d{4}[-/]\d{1,2}[-/]\d{1,2}\s+\d{1,2}:\d{2}(?::\d{2})?)\]?\s+(?<sender>[^:：]{1,60})[:：]\s*(?<text>.*)$')
  if (-not $m.Success) { $parseMiss++; continue }

  try {
    $dt = [DateTime]::Parse($m.Groups['dt'].Value)
  } catch {
    $parseMiss++; continue
  }

  if ($dt.Date -lt $sinceDate.Date) { continue }

  $sender = $m.Groups['sender'].Value.Trim()
  $text = $m.Groups['text'].Value.Trim()
  $isUser = $sender -match '^(我|me|self|本人|我自己)$'
  $messages.Add([PSCustomObject]@{ Date = $dt; Sender = $sender; Text = $text; IsUser = $isUser })
}

if ($messages.Count -eq 0) {
  throw "没有可解析的消息。请检查 $chatPath 的格式（示例名：Acme Corp）。"
}
if ($parseMiss -gt 0) {
  Write-Warning "有 $parseMiss 行无法解析，已跳过。"
}

$directPatterns = @(
  '请','麻烦','帮我','帮忙','需要你','你看','你做','你写','你查','你提供','你来','你那边','Please','Can you','Could you','Need you to'
)
$decisionPatterns = @('你来定','你拍板','看你','你决定','Your call')
$deadlinePatterns = @('\d+月\d+(日|号)','月底','月初','周五','周末','下周','这周','今天','明天','before','\bby\b','\bEOW\b','\bASAP\b','urgent')
$promisePatterns = @('我来','我做','我帮你','我会','我给你','等我','我下周','我明天')

$section1 = @(); $section2 = @(); $section3 = @(); $section4 = @(); $section5 = @(); $section6 = @()

for ($i = 0; $i -lt $messages.Count; $i++) {
  $msg = $messages[$i]

  $matchedDirect = $null
  foreach ($p in $directPatterns) { if ($msg.Text -match [Regex]::Escape($p)) { $matchedDirect = $p; break } }
  if ($matchedDirect -and -not $msg.IsUser) {
    $section1 += [PSCustomObject]@{ Date=$msg.Date; Sender=$msg.Sender; Text=$msg.Text; Why=$matchedDirect }
  }

  foreach ($p in $decisionPatterns) {
    if ($msg.Text -match [Regex]::Escape($p)) { $section2 += [PSCustomObject]@{ Date=$msg.Date; Sender=$msg.Sender; Text=$msg.Text; Why=$p }; break }
  }

  if (-not $msg.IsUser) {
    $isResource = ($msg.Text -match '^(https?://\S+)$') -or ($msg.Text -match '\.(pdf|docx?|xlsx?|pptx?|png|jpg|jpeg|gif|zip)\b')
    $hasOnlyResource = $isResource -and ($msg.Text -notmatch '[\u4e00-\u9fa5A-Za-z]{4,}')
    if ($hasOnlyResource) {
      $prev = if ($i -gt 0) { $messages[$i-1] } else { $null }
      $next = if ($i -lt $messages.Count - 1) { $messages[$i+1] } else { $null }
      $section3 += [PSCustomObject]@{ Date=$msg.Date; Sender=$msg.Sender; Text=$msg.Text; Prev=$prev; Next=$next }
    }
  }

  foreach ($p in $deadlinePatterns) {
    if ($msg.Text -match $p) { $section4 += [PSCustomObject]@{ Date=$msg.Date; Sender=$msg.Sender; Text=$msg.Text; Hit=$matches[0] }; break }
  }

  if ($msg.IsUser) {
    foreach ($p in $promisePatterns) {
      if ($msg.Text -match [Regex]::Escape($p)) { $section5 += [PSCustomObject]@{ Date=$msg.Date; Sender=$msg.Sender; Text=$msg.Text; Why=$p }; break }
    }
  }

  if (-not $msg.IsUser -and $msg.Text -match '(\?|？)\s*$') {
    $nextUser = $null
    for ($j = $i + 1; $j -lt $messages.Count; $j++) {
      if ($messages[$j].IsUser) { $nextUser = $messages[$j]; break }
    }
    if (-not $nextUser) {
      $section6 += [PSCustomObject]@{ Date=$msg.Date; Sender=$msg.Sender; Text=$msg.Text; Why='no user reply' }
    } else {
      $delay = ($nextUser.Date - $msg.Date).TotalHours
      if ($delay -gt 2 -or $nextUser.Text -notmatch '.{2,}') {
        $section6 += [PSCustomObject]@{ Date=$msg.Date; Sender=$msg.Sender; Text=$msg.Text; Why=("reply delay {0:N1}h" -f $delay) }
      }
    }
  }
}

$projectTxtCount = 0
if ($Project) {
  $projectDir = Join-Path 'projects' $Project
  if (Test-Path $projectDir) {
    $projectTxtCount = (Get-ChildItem -Path $projectDir -Filter '*.txt' -File -ErrorAction SilentlyContinue).Count
  } else {
    Write-Warning "项目目录不存在：$projectDir（示例：Acme 项目）。"
  }
}

$topicPath = Join-Path (Join-Path 'topics' $Person) 'search.json'
$topicNote = if (Test-Path $topicPath) { "Found topics/$Person/search.json" } else { 'No topic search.json' }

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# Task candidates for $Person")
[void]$sb.AppendLine("")
[void]$sb.AppendLine("- Since: $($sinceDate.ToString('yyyy-MM-dd'))")
[void]$sb.AppendLine("- Source chat: $chatPath")
[void]$sb.AppendLine("- Optional topic: $topicNote")
[void]$sb.AppendLine("- Optional project txt count: $projectTxtCount")
[void]$sb.AppendLine("- Boundary: first-pass filtering only (no LLM, no final classification, no notes.md write)")
[void]$sb.AppendLine("")

function Add-List {
  param($title, $rows, $formatter)
  [void]$sb.AppendLine("## $title")
  if (-not $rows -or $rows.Count -eq 0) {
    [void]$sb.AppendLine("- (none)")
    [void]$sb.AppendLine("")
    return
  }
  foreach ($r in $rows) { [void]$sb.AppendLine((& $formatter $r)) }
  [void]$sb.AppendLine("")
}

Add-List '1. Direct asks (high signal)' $section1 { param($r) "- [$($r.Date.ToString('yyyy-MM-dd HH:mm'))] $($r.Sender): $($r.Text)`n  - why-flagged: $($r.Why)" }
Add-List '2. Deferred decisions' $section2 { param($r) "- [$($r.Date.ToString('yyyy-MM-dd HH:mm'))] $($r.Sender): $($r.Text)`n  - why-flagged: $($r.Why)" }
Add-List '3. Resource sends (implicit tasks)' $section3 { param($r) $p = if($r.Prev){"[$($r.Prev.Date.ToString('HH:mm'))] $($r.Prev.Sender): $($r.Prev.Text)"}else{'(none)'}; $n = if($r.Next){"[$($r.Next.Date.ToString('HH:mm'))] $($r.Next.Sender): $($r.Next.Text)"}else{'(none)'}; "- [$($r.Date.ToString('yyyy-MM-dd HH:mm'))] $($r.Sender): $($r.Text)`n  - context-before: $p`n  - context-after: $n" }
Add-List '4. Deadlines mentioned' $section4 { param($r) "- [$($r.Date.ToString('yyyy-MM-dd HH:mm'))] $($r.Sender): $($r.Text)`n  - deadline-hit: **$($r.Hit)**" }
Add-List "5. User's own promises (Already-promised)" $section5 { param($r) "- [$($r.Date.ToString('yyyy-MM-dd HH:mm'))] $($r.Sender): $($r.Text)`n  - why-flagged: $($r.Why)" }
Add-List "6. Questions to the user that didn't get answered" $section6 { param($r) "- [$($r.Date.ToString('yyyy-MM-dd HH:mm'))] $($r.Sender): $($r.Text)`n  - why-flagged: $($r.Why)" }

$sb.ToString() | Out-File -FilePath $Out -Encoding UTF8
Write-Host "[task-extract] wrote $Out" -ForegroundColor Green
