<#
.SYNOPSIS
  Transcribe WeChat voice notes for one contact, append to voice-transcripts.md.

.DESCRIPTION
  5-stage pipeline (see docs/voice-transcription.md for the full methodology):

      wx attachments --kind voice  →  list voice ids
      wx extract <id>              →  .silk decrypted
      silk_v3_decoder              →  .pcm raw audio
      ffmpeg                       →  .wav 16-bit
      whisper / whisper.cpp        →  text

  Output: people/<slug>/voice-transcripts.md (gitignored).

  Privacy-first defaults:
    - Local Whisper backends only (whisper.cpp / faster-whisper / openai-whisper)
    - `-Backend cloud-openai` requires interactive confirmation
    - Intermediate .silk / .pcm / .wav files deleted after transcription
      (use -KeepTemp to retain for debugging)
    - Output is gitignored; existing transcripts NOT overwritten unless -Force

.PARAMETER Person
  Person slug under people/. Required.

.PARAMETER Name
  Contact display name in WeChat (used for `wx attachments`). Defaults to slug.
  Pass explicitly if the display name differs from the slug.

.PARAMETER Since
  YYYY-MM-DD cutoff. Defaults to 30 days ago.

.PARAMETER N
  Max voice notes to process. Default 200.

.PARAMETER Model
  tiny / base / small / medium / large. Default base.

.PARAMETER Backend
  whisper-cpp / faster-whisper / openai-whisper / cloud-openai / auto.
  Default auto = first available local backend. cloud-openai requires explicit
  consent and is documented in docs/voice-transcription.md.

.PARAMETER SilkDecoder
  Path to silk_v3_decoder binary if not on PATH.

.PARAMETER WhisperCli
  Path to whisper / whisper-cli / python -m whisper if non-standard.

.PARAMETER WorkDir
  Intermediate work directory. Default $env:TEMP/wx-voice-<slug>.

.PARAMETER KeepTemp
  Keep intermediate .silk / .pcm / .wav files (default: delete after transcribe).

.PARAMETER SilkDir
  Skip wx-cli + use a pre-existing directory of .silk files. Filter by mtime.

.PARAMETER Force
  Re-transcribe even if voice-transcripts.md already covers this id.

.EXAMPLE
  .\tools\voice-transcribe.ps1 -Person qiumu -Since "2026-04-01" -Model base

.EXAMPLE
  .\tools\voice-transcribe.ps1 -Person alice -Backend whisper-cpp -KeepTemp
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Person,
  [string]$Name,
  [string]$Since,
  [int]$N = 200,
  [ValidateSet('tiny','base','small','medium','large')]
  [string]$Model = 'base',
  [ValidateSet('whisper-cpp','faster-whisper','openai-whisper','cloud-openai','auto')]
  [string]$Backend = 'auto',
  [string]$SilkDecoder,
  [string]$WhisperCli,
  [string]$WorkDir,
  [switch]$KeepTemp,
  [string]$SilkDir,
  [switch]$Force
)

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

if (-not $Name) { $Name = $Person }
if (-not $Since) { $Since = (Get-Date).AddDays(-30).ToString('yyyy-MM-dd') }
if (-not $WorkDir) { $WorkDir = Join-Path $env:TEMP "wx-voice-$Person" }

$peopleDir = Join-Path 'people' $Person
if (-not (Test-Path $peopleDir)) {
  Write-Error "Directory $peopleDir does not exist. Run tools/refresh.ps1 -Name '$Name' -Dir '$peopleDir' first."
  exit 1
}
$transcriptsPath = Join-Path $peopleDir 'voice-transcripts.md'

# --- Helper: locate binary ---
function Find-Bin {
  param([string]$Name, [string]$Override)
  if ($Override -and (Test-Path $Override)) { return $Override }
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  return $null
}

# --- Dependency check ---
$wx = Find-Bin -Name 'wx'
$silk = Find-Bin -Name 'silk_v3_decoder' -Override $SilkDecoder
$ffmpeg = Find-Bin -Name 'ffmpeg'

if (-not $silk) {
  Write-Error "silk_v3_decoder not found. Install: https://github.com/kn007/silk-v3-decoder (build + add to PATH, or pass -SilkDecoder <path>)"
  exit 2
}
if (-not $ffmpeg) {
  Write-Error "ffmpeg not found. Install: winget install Gyan.FFmpeg  (or scoop install ffmpeg)"
  exit 2
}

# --- Pick whisper backend ---
$resolvedBackend = $Backend
if ($Backend -eq 'auto') {
  if (Find-Bin -Name 'whisper-cli' -Override $WhisperCli) {
    $resolvedBackend = 'whisper-cpp'
    $WhisperCli = if ($WhisperCli) { $WhisperCli } else { (Get-Command 'whisper-cli').Source }
  } elseif (Find-Bin -Name 'whisper') {
    $resolvedBackend = 'openai-whisper'
    $WhisperCli = (Get-Command 'whisper').Source
  } else {
    Write-Error "No local Whisper backend found. Install one:"
    Write-Error "  whisper.cpp:     brew install whisper-cpp  (or build from https://github.com/ggerganov/whisper.cpp)"
    Write-Error "  faster-whisper:  pip install faster-whisper"
    Write-Error "  openai-whisper:  pip install openai-whisper"
    exit 2
  }
}

if ($resolvedBackend -eq 'cloud-openai') {
  Write-Warning "Backend 'cloud-openai' will send audio to OpenAI's servers."
  Write-Warning "Per docs/voice-transcription.md § Privacy, voice content is more sensitive than text."
  $confirm = Read-Host "Type 'I CONSENT' (case-sensitive) to proceed, anything else to abort"
  if ($confirm -cne 'I CONSENT') {
    Write-Host "Aborted. Re-run with a local backend (whisper-cpp / faster-whisper / openai-whisper)." -ForegroundColor Yellow
    exit 1
  }
  if (-not $env:OPENAI_API_KEY) {
    Write-Error "Backend cloud-openai needs `$env:OPENAI_API_KEY set."
    exit 2
  }
}

# --- Stage 1: list voice ids (or scan SilkDir) ---
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

$voiceItems = @()

if ($SilkDir) {
  if (-not (Test-Path $SilkDir)) {
    Write-Error "SilkDir not found: $SilkDir"
    exit 1
  }
  $sinceDate = [DateTime]::ParseExact($Since, 'yyyy-MM-dd', $null)
  $voiceItems = Get-ChildItem -Path $SilkDir -Filter '*.silk' |
                Where-Object { $_.LastWriteTime -ge $sinceDate } |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First $N |
                ForEach-Object {
                  [PSCustomObject]@{
                    id = $_.BaseName
                    timestamp = $_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
                    silk_path = $_.FullName
                    sender = '?'
                    duration = $null
                  }
                }
} else {
  if (-not $wx) {
    Write-Error "wx-cli not found. Install: npm install -g @jackwener/wx-cli  (or pass -SilkDir <path> to skip wx-cli)"
    exit 2
  }

  Write-Host "[voice] listing voice attachments for '$Name' since $Since (n=$N)..." -ForegroundColor Cyan
  $rawList = wx attachments $Name --kind voice -n $N --since $Since --json 2>&1
  if ($LASTEXITCODE -ne 0) {
    Write-Error "wx attachments --kind voice failed (exit $LASTEXITCODE). Your wx-cli may not support voice — see docs/voice-transcription.md § Fallback."
    exit $LASTEXITCODE
  }
  try {
    $list = $rawList | Out-String | ConvertFrom-Json
  } catch {
    Write-Error "Could not parse wx attachments output as JSON."
    exit 3
  }
  if (-not $list -or $list.Count -eq 0) {
    Write-Host "No voice attachments in window."
    exit 0
  }

  $voiceItems = foreach ($v in $list) {
    [PSCustomObject]@{
      id = if ($v.id) { $v.id } elseif ($v.attachment_id) { $v.attachment_id } else { '' }
      timestamp = if ($v.timestamp) { $v.timestamp } elseif ($v.time) { $v.time } else { '' }
      silk_path = $null
      sender = if ($v.sender) { $v.sender } elseif ($v.from) { $v.from } else { '?' }
      duration = if ($v.duration) { $v.duration } else { $null }
    }
  }
}

# --- Idempotency: skip ids already transcribed ---
$alreadyDone = @{}
if ((Test-Path $transcriptsPath) -and -not $Force) {
  $existing = Get-Content $transcriptsPath -Raw -Encoding UTF8
  foreach ($m in [Regex]::Matches($existing, '<!-- voice-id: (\S+) -->')) {
    $alreadyDone[$m.Groups[1].Value] = $true
  }
  Write-Host "[voice] $($alreadyDone.Count) ids already transcribed (use -Force to re-transcribe)." -ForegroundColor DarkGray
}

# --- Stage 2-5 loop ---
$newTranscripts = @()
$ok = 0
$fail = 0

foreach ($v in $voiceItems) {
  if ($alreadyDone.ContainsKey($v.id)) { continue }

  $silkPath = if ($v.silk_path) { $v.silk_path } else { Join-Path $WorkDir "$($v.id).silk" }
  $pcmPath = Join-Path $WorkDir "$($v.id).pcm"
  $wavPath = Join-Path $WorkDir "$($v.id).wav"

  # 2. Extract silk
  if (-not (Test-Path $silkPath)) {
    Write-Host "  [extract] $($v.id) -> $silkPath" -ForegroundColor DarkCyan
    wx extract $v.id -o $silkPath 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $silkPath)) {
      Write-Warning "  extract failed for $($v.id)"
      $fail += 1
      continue
    }
  }

  # 3. silk → pcm
  Write-Host "  [silk]    $($v.id) -> $pcmPath" -ForegroundColor DarkCyan
  & $silk $silkPath $pcmPath 24000 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $pcmPath)) {
    Write-Warning "  silk_v3_decoder failed for $($v.id)"
    $fail += 1
    continue
  }

  # 4. pcm → wav
  Write-Host "  [wav]     $($v.id) -> $wavPath" -ForegroundColor DarkCyan
  & $ffmpeg -y -loglevel error -f s16le -ar 24000 -ac 1 -i $pcmPath $wavPath 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $wavPath)) {
    Write-Warning "  ffmpeg failed for $($v.id)"
    $fail += 1
    continue
  }

  # 5. wav → text
  Write-Host "  [whisper] $($v.id) (model=$Model, backend=$resolvedBackend)" -ForegroundColor DarkCyan
  $text = ''
  switch ($resolvedBackend) {
    'whisper-cpp' {
      $out = & $WhisperCli -m "models/ggml-$Model.bin" -f $wavPath -nt -l auto 2>&1 | Out-String
      $text = ($out -split "`n" | Where-Object { $_ -match '\d+\:\d+' } | ForEach-Object { ($_ -split '\]')[1] } | Where-Object { $_ } | ForEach-Object { $_.Trim() }) -join ' '
      if (-not $text) { $text = $out.Trim() }
    }
    'openai-whisper' {
      $out = & $WhisperCli $wavPath --model $Model --output_format txt --output_dir $WorkDir 2>&1 | Out-String
      $txtFile = Join-Path $WorkDir "$($v.id).txt"
      if (Test-Path $txtFile) {
        $text = (Get-Content $txtFile -Raw -Encoding UTF8).Trim()
      } else {
        $text = '<transcription empty>'
      }
    }
    'faster-whisper' {
      $text = & python -c "from faster_whisper import WhisperModel; m=WhisperModel('$Model'); segs,_=m.transcribe(r'$wavPath'); print(' '.join(s.text.strip() for s in segs))" 2>&1 | Out-String
      $text = $text.Trim()
    }
    'cloud-openai' {
      $text = & python -c "import openai,os; openai.api_key=os.environ['OPENAI_API_KEY']; print(openai.Audio.transcribe('whisper-1', open(r'$wavPath','rb'))['text'])" 2>&1 | Out-String
      $text = $text.Trim()
    }
  }

  if (-not $text) { $text = '<transcription empty>' }

  $direction = if ($v.sender -eq 'me' -or $v.sender -eq '我') { "me → $Name" } else { "$Name → me" }
  $durStr = if ($v.duration) { "$($v.duration)s" } else { '?s' }

  $block = @()
  $block += "<!-- voice-id: $($v.id) -->"
  $block += "## $($v.timestamp) · $durStr · $direction"
  $block += "> $text"
  $block += ""
  $newTranscripts += ($block -join "`n")
  $ok += 1

  # Cleanup intermediates
  if (-not $KeepTemp) {
    Remove-Item -Force -ErrorAction SilentlyContinue $pcmPath, $wavPath
    if (-not $SilkDir) { Remove-Item -Force -ErrorAction SilentlyContinue $silkPath }
  }
}

# --- Write / append output ---
if ($newTranscripts.Count -gt 0) {
  if (-not (Test-Path $transcriptsPath)) {
    $header = @()
    $header += "# Voice transcripts — $Name"
    $header += ""
    $header += "source: people/$Person/voice/"
    $header += "model: $Model ($resolvedBackend)"
    $header += "generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm'))"
    $header += "backend: $(if ($resolvedBackend -eq 'cloud-openai') { 'CLOUD — OpenAI API' } else { 'local' })"
    $header += ""
    $header += "---"
    $header += ""
    ($header -join "`n") + ($newTranscripts -join "`n") | Out-File -FilePath $transcriptsPath -Encoding utf8
  } else {
    $existing = Get-Content $transcriptsPath -Raw -Encoding UTF8
    ($existing.TrimEnd() + "`n`n" + ($newTranscripts -join "`n") + "`n") | Out-File -FilePath $transcriptsPath -Encoding utf8
  }
}

if (-not $KeepTemp -and -not $SilkDir) {
  Remove-Item -Force -Recurse -ErrorAction SilentlyContinue $WorkDir
}

Write-Host ""
Write-Host "[voice] done. transcribed=$ok failed=$fail output=$transcriptsPath" -ForegroundColor Green
if ($fail -gt 0) { exit 1 }
