#!/usr/bin/env bash
#
# voice-transcribe.sh — Transcribe WeChat voice notes for one contact.
#
# POSIX-compatible equivalent of voice-transcribe.ps1.
# See docs/voice-transcription.md for the full pipeline and privacy notes.
#
# Pipeline:
#   wx attachments --kind voice → wx extract → silk_v3_decoder → ffmpeg → whisper
#
# Output: people/<slug>/voice-transcripts.md  (gitignored).
#
# Usage:
#   ./tools/voice-transcribe.sh --person alice --since 2026-04-01 --model base
#   ./tools/voice-transcribe.sh --person alice --backend whisper-cpp --keep-temp
#
# Options:
#   --person SLUG       people/<slug>/ directory (required)
#   --name NAME         WeChat display name (default: same as slug)
#   --since DATE        YYYY-MM-DD cutoff (default: 30 days ago)
#   --n NUM             Max voices to process (default: 200)
#   --model MODEL       tiny|base|small|medium|large (default: base)
#   --backend BACKEND   whisper-cpp|faster-whisper|openai-whisper|cloud-openai|auto
#                       (default: auto — first available local backend)
#   --silk-decoder PATH Path to silk_v3_decoder if not on PATH
#   --whisper-cli PATH  Path to whisper / whisper-cli if non-standard
#   --work-dir DIR      Intermediate work dir (default: /tmp/wx-voice-<slug>)
#   --keep-temp         Keep .silk/.pcm/.wav after transcribe
#   --silk-dir DIR      Skip wx-cli; use a pre-existing dir of .silk files
#   --force             Re-transcribe ids already in voice-transcripts.md
#
# Requires:
#   - wx-cli (unless --silk-dir)
#   - silk_v3_decoder    https://github.com/kn007/silk-v3-decoder
#   - ffmpeg
#   - one of: whisper-cli (whisper.cpp), whisper (openai-whisper), python+faster-whisper

set -euo pipefail

# --- Defaults ---
PERSON=""
NAME=""
SINCE=""
N=200
MODEL="base"
BACKEND="auto"
SILK_DECODER=""
WHISPER_CLI=""
WORK_DIR=""
KEEP_TEMP=false
SILK_DIR=""
FORCE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --person)        PERSON="$2"; shift 2 ;;
    --name)          NAME="$2"; shift 2 ;;
    --since)         SINCE="$2"; shift 2 ;;
    --n)             N="$2"; shift 2 ;;
    --model)         MODEL="$2"; shift 2 ;;
    --backend)       BACKEND="$2"; shift 2 ;;
    --silk-decoder)  SILK_DECODER="$2"; shift 2 ;;
    --whisper-cli)   WHISPER_CLI="$2"; shift 2 ;;
    --work-dir)      WORK_DIR="$2"; shift 2 ;;
    --keep-temp)     KEEP_TEMP=true; shift ;;
    --silk-dir)      SILK_DIR="$2"; shift 2 ;;
    --force)         FORCE=true; shift ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

[[ -z "$PERSON" ]] && { echo "ERROR: --person is required" >&2; exit 1; }
[[ -z "$NAME" ]]  && NAME="$PERSON"
[[ -z "$SINCE" ]] && SINCE=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d '30 days ago' +%Y-%m-%d)
[[ -z "$WORK_DIR" ]] && WORK_DIR="/tmp/wx-voice-$PERSON"

PEOPLE_DIR="people/$PERSON"
if [[ ! -d "$PEOPLE_DIR" ]]; then
  echo "ERROR: $PEOPLE_DIR does not exist. Run tools/refresh.sh --name '$NAME' --dir '$PEOPLE_DIR' first." >&2
  exit 1
fi
TRANSCRIPTS_PATH="$PEOPLE_DIR/voice-transcripts.md"

# --- Dep checks ---
have() { command -v "$1" &>/dev/null; }

resolve_bin() {
  local name="$1" override="$2"
  if [[ -n "$override" ]] && [[ -x "$override" ]]; then
    echo "$override"
  elif have "$name"; then
    command -v "$name"
  fi
}

SILK_BIN=$(resolve_bin silk_v3_decoder "$SILK_DECODER")
[[ -z "$SILK_BIN" ]] && { echo "ERROR: silk_v3_decoder not found. Install: https://github.com/kn007/silk-v3-decoder" >&2; exit 2; }

have ffmpeg || { echo "ERROR: ffmpeg not found. Install: brew install ffmpeg / apt install ffmpeg" >&2; exit 2; }
have jq     || { echo "ERROR: jq not found. Install: https://stedolan.github.io/jq/" >&2; exit 2; }

# --- Resolve whisper backend ---
RESOLVED_BACKEND="$BACKEND"
if [[ "$BACKEND" == "auto" ]]; then
  if have whisper-cli || [[ -n "$WHISPER_CLI" && -x "$WHISPER_CLI" ]]; then
    RESOLVED_BACKEND="whisper-cpp"
    [[ -z "$WHISPER_CLI" ]] && WHISPER_CLI=$(command -v whisper-cli)
  elif have whisper; then
    RESOLVED_BACKEND="openai-whisper"
    WHISPER_CLI=$(command -v whisper)
  else
    cat >&2 <<EOF
ERROR: No local Whisper backend found. Install one:
  whisper.cpp:     brew install whisper-cpp  (or build from https://github.com/ggerganov/whisper.cpp)
  faster-whisper:  pip install faster-whisper
  openai-whisper:  pip install openai-whisper
EOF
    exit 2
  fi
fi

if [[ "$RESOLVED_BACKEND" == "cloud-openai" ]]; then
  echo "WARNING: Backend 'cloud-openai' will send audio to OpenAI's servers." >&2
  echo "Per docs/voice-transcription.md § Privacy, voice content is more sensitive than text." >&2
  read -r -p "Type 'I CONSENT' (case-sensitive) to proceed, anything else to abort: " CONFIRM
  if [[ "$CONFIRM" != "I CONSENT" ]]; then
    echo "Aborted. Re-run with a local backend."
    exit 1
  fi
  [[ -z "${OPENAI_API_KEY:-}" ]] && { echo "ERROR: cloud-openai needs OPENAI_API_KEY set." >&2; exit 2; }
fi

# --- Stage 1: list voice items ---
mkdir -p "$WORK_DIR"
VOICE_JSON=""

if [[ -n "$SILK_DIR" ]]; then
  [[ ! -d "$SILK_DIR" ]] && { echo "ERROR: SilkDir not found: $SILK_DIR" >&2; exit 1; }
  SINCE_EPOCH=$(date -j -f "%Y-%m-%d" "$SINCE" "+%s" 2>/dev/null || date -d "$SINCE" "+%s")
  VOICE_JSON=$(find "$SILK_DIR" -name '*.silk' -type f -newermt "$SINCE" 2>/dev/null | \
    head -n "$N" | \
    while IFS= read -r f; do
      BASENAME=$(basename "$f" .silk)
      MTIME=$(date -r "$f" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || stat -c '%y' "$f" | cut -d. -f1)
      jq -n --arg id "$BASENAME" --arg ts "$MTIME" --arg sp "$f" \
        '{id: $id, timestamp: $ts, silk_path: $sp, sender: "?", duration: null}'
    done | jq -s '.')
else
  have wx || { echo "ERROR: wx-cli not found. Install: npm install -g @jackwener/wx-cli  (or use --silk-dir)" >&2; exit 2; }
  echo "[voice] listing voice attachments for '$NAME' since $SINCE (n=$N)..."
  RAW=$(wx attachments "$NAME" --kind voice -n "$N" --since "$SINCE" --json 2>&1) || {
    echo "ERROR: wx attachments --kind voice failed. Your wx-cli may not support voice — see docs/voice-transcription.md § Fallback." >&2
    exit 1
  }
  if [[ -z "$RAW" ]] || [[ "$RAW" == "[]" ]] || [[ "$RAW" == "null" ]]; then
    echo "No voice attachments in window."
    exit 0
  fi
  VOICE_JSON=$(echo "$RAW" | jq '[.[] | {
    id: (.id // .attachment_id),
    timestamp: (.timestamp // .time // ""),
    silk_path: null,
    sender: (.sender // .from // "?"),
    duration: (.duration // null)
  }]')
fi

VOICE_COUNT=$(echo "$VOICE_JSON" | jq 'length')
[[ "$VOICE_COUNT" == "0" ]] && { echo "No voice items to process."; exit 0; }

# --- Idempotency ---
declare -A ALREADY_DONE
if [[ -f "$TRANSCRIPTS_PATH" ]] && [[ "$FORCE" != "true" ]]; then
  while IFS= read -r ID; do
    ALREADY_DONE[$ID]=1
  done < <(grep -oE '<!-- voice-id: \S+ -->' "$TRANSCRIPTS_PATH" | sed -E 's/<!-- voice-id: (\S+) -->/\1/')
  echo "[voice] ${#ALREADY_DONE[@]} ids already transcribed (use --force to re-transcribe)."
fi

# --- Stage 2-5 loop ---
NEW_BLOCKS=""
OK=0
FAIL=0

while IFS= read -r ITEM; do
  ID=$(echo "$ITEM" | jq -r '.id')
  TS=$(echo "$ITEM" | jq -r '.timestamp')
  SP=$(echo "$ITEM" | jq -r '.silk_path // ""')
  SENDER=$(echo "$ITEM" | jq -r '.sender')
  DUR=$(echo "$ITEM" | jq -r '.duration // "?"')

  [[ -n "${ALREADY_DONE[$ID]:-}" ]] && continue

  SILK_PATH=${SP:-$WORK_DIR/$ID.silk}
  PCM_PATH="$WORK_DIR/$ID.pcm"
  WAV_PATH="$WORK_DIR/$ID.wav"

  # 2. Extract silk
  if [[ ! -f "$SILK_PATH" ]]; then
    echo "  [extract] $ID -> $SILK_PATH"
    wx extract "$ID" -o "$SILK_PATH" >/dev/null 2>&1 || { echo "    extract failed for $ID" >&2; FAIL=$((FAIL+1)); continue; }
  fi

  # 3. silk → pcm
  echo "  [silk]    $ID -> $PCM_PATH"
  "$SILK_BIN" "$SILK_PATH" "$PCM_PATH" 24000 >/dev/null 2>&1 || { echo "    silk_v3_decoder failed for $ID" >&2; FAIL=$((FAIL+1)); continue; }

  # 4. pcm → wav
  echo "  [wav]     $ID -> $WAV_PATH"
  ffmpeg -y -loglevel error -f s16le -ar 24000 -ac 1 -i "$PCM_PATH" "$WAV_PATH" || { echo "    ffmpeg failed for $ID" >&2; FAIL=$((FAIL+1)); continue; }

  # 5. wav → text
  echo "  [whisper] $ID (model=$MODEL, backend=$RESOLVED_BACKEND)"
  TEXT=""
  case "$RESOLVED_BACKEND" in
    whisper-cpp)
      TEXT=$("$WHISPER_CLI" -m "models/ggml-${MODEL}.bin" -f "$WAV_PATH" -nt -l auto 2>/dev/null | grep -oE '\][^[]+' | sed 's/^\]//;s/[[:space:]]\+/ /g' | paste -sd ' ' -) || true
      ;;
    openai-whisper)
      "$WHISPER_CLI" "$WAV_PATH" --model "$MODEL" --output_format txt --output_dir "$WORK_DIR" >/dev/null 2>&1 || true
      [[ -f "$WORK_DIR/$ID.txt" ]] && TEXT=$(cat "$WORK_DIR/$ID.txt")
      ;;
    faster-whisper)
      TEXT=$(python -c "from faster_whisper import WhisperModel; m=WhisperModel('$MODEL'); segs,_=m.transcribe(r'$WAV_PATH'); print(' '.join(s.text.strip() for s in segs))" 2>/dev/null) || true
      ;;
    cloud-openai)
      TEXT=$(python -c "import openai,os; openai.api_key=os.environ['OPENAI_API_KEY']; print(openai.Audio.transcribe('whisper-1', open(r'$WAV_PATH','rb'))['text'])" 2>/dev/null) || true
      ;;
  esac

  [[ -z "$TEXT" ]] && TEXT="<transcription empty>"

  if [[ "$SENDER" == "me" ]] || [[ "$SENDER" == "我" ]]; then
    DIRECTION="me → $NAME"
  else
    DIRECTION="$NAME → me"
  fi

  BLOCK="<!-- voice-id: $ID -->
## $TS · ${DUR}s · $DIRECTION
> $TEXT
"
  NEW_BLOCKS+="$BLOCK
"
  OK=$((OK+1))

  if [[ "$KEEP_TEMP" != "true" ]]; then
    rm -f "$PCM_PATH" "$WAV_PATH"
    [[ -z "$SILK_DIR" ]] && rm -f "$SILK_PATH"
  fi
done < <(echo "$VOICE_JSON" | jq -c '.[]')

# --- Write/append ---
if [[ -n "$NEW_BLOCKS" ]]; then
  if [[ ! -f "$TRANSCRIPTS_PATH" ]]; then
    cat > "$TRANSCRIPTS_PATH" <<EOF
# Voice transcripts — $NAME

source: people/$PERSON/voice/
model: $MODEL ($RESOLVED_BACKEND)
generated: $(date '+%Y-%m-%d %H:%M')
backend: $(if [[ "$RESOLVED_BACKEND" == "cloud-openai" ]]; then echo "CLOUD — OpenAI API"; else echo "local"; fi)

---

EOF
  fi
  echo "$NEW_BLOCKS" >> "$TRANSCRIPTS_PATH"
fi

if [[ "$KEEP_TEMP" != "true" ]] && [[ -z "$SILK_DIR" ]]; then
  rm -rf "$WORK_DIR"
fi

echo ""
echo "[voice] done. transcribed=$OK failed=$FAIL output=$TRANSCRIPTS_PATH"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
