#!/usr/bin/env bash
#
# attachments.sh — List or extract WeChat chat attachments for one contact.
#
# POSIX-compatible equivalent of attachments.ps1. Wraps `wx attachments` (list)
# and `wx extract` (decrypt + save) with two modes:
#
#   * List mode (default): emit a markdown / JSON table of attachments
#     matching the filters. No files written.
#   * Extract mode: when --extract or --extract-all is given, decrypt the
#     selected attachments to --out. --out is required for extract mode.
#
# Usage:
#   ./tools/attachments.sh --name "Alice" --kind file --since 2026-05-01
#   ./tools/attachments.sh --name "Alice" --kind file --since 2026-05-01 \
#     --extract-all --out projects/acme-launch/raw
#   ./tools/attachments.sh --name "Alice" --extract "att_abc123,att_def456" \
#     --out projects/acme-launch/raw
#
# Options:
#   --name NAME        Contact display name (required)
#   --kind KIND        image | file | video | voice | all (default: all)
#   --n NUM            Max attachments to list (default: 50)
#   --since DATE       YYYY-MM-DD cutoff (optional)
#   --until DATE       YYYY-MM-DD upper bound (optional)
#   --extract IDS      Comma-separated ids; triggers extract mode
#   --extract-all      Extract every matching attachment; triggers extract mode
#   --out DIR          Output dir for extracted files (required for extract mode)
#   --format FMT       markdown | json (default: markdown; list mode only)
#
# Requires: wx-cli, jq

set -euo pipefail

# --- Defaults ---
NAME=""
KIND="all"
N=50
SINCE=""
UNTIL=""
EXTRACT_IDS=""
EXTRACT_ALL=false
OUT=""
FORMAT="markdown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)         NAME="$2"; shift 2 ;;
    --kind)         KIND="$2"; shift 2 ;;
    --n)            N="$2"; shift 2 ;;
    --since)        SINCE="$2"; shift 2 ;;
    --until)        UNTIL="$2"; shift 2 ;;
    --extract)      EXTRACT_IDS="$2"; shift 2 ;;
    --extract-all)  EXTRACT_ALL=true; shift ;;
    --out)          OUT="$2"; shift 2 ;;
    --format)       FORMAT="$2"; shift 2 ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      echo "Usage: $0 --name NAME [--kind KIND] [--n NUM] [--since DATE] [--until DATE] [--extract IDS | --extract-all] [--out DIR] [--format markdown|json]" >&2
      exit 1
      ;;
  esac
done

# --- Validate ---
if [[ -z "$NAME" ]]; then
  echo "ERROR: --name is required" >&2
  exit 1
fi
case "$KIND" in
  image|file|video|voice|all) ;;
  *)
    echo "ERROR: --kind must be image|file|video|voice|all (got '$KIND')" >&2
    exit 1
    ;;
esac
case "$FORMAT" in
  markdown|json) ;;
  *)
    echo "ERROR: --format must be markdown|json (got '$FORMAT')" >&2
    exit 1
    ;;
esac

WANTS_EXTRACT=false
if [[ -n "$EXTRACT_IDS" ]] || [[ "$EXTRACT_ALL" == "true" ]]; then
  WANTS_EXTRACT=true
fi
if [[ "$WANTS_EXTRACT" == "true" ]] && [[ -z "$OUT" ]]; then
  echo "ERROR: --out is required when --extract or --extract-all is used" >&2
  exit 1
fi

if ! command -v wx &>/dev/null; then
  echo "ERROR: wx-cli not found on PATH. Install with: npm install -g @jackwener/wx-cli" >&2
  exit 2
fi
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq not found on PATH. Install jq: https://stedolan.github.io/jq/" >&2
  exit 2
fi

# --- List call ---
WX_ARGS=(attachments "$NAME" --json -n "$N")
if [[ "$KIND" != "all" ]]; then WX_ARGS+=(--kind "$KIND"); fi
if [[ -n "$SINCE" ]]; then WX_ARGS+=(--since "$SINCE"); fi
if [[ -n "$UNTIL" ]]; then WX_ARGS+=(--until "$UNTIL"); fi

RAW=$(wx "${WX_ARGS[@]}" 2>&1) || {
  echo "ERROR: wx attachments failed. Is the daemon running? Try: wx daemon stop; wx new-messages" >&2
  exit "${PIPESTATUS[0]:-1}"
}

if [[ -z "$RAW" ]] || [[ "$RAW" == "[]" ]] || [[ "$RAW" == "null" ]]; then
  echo "No attachments match (name='$NAME', kind=$KIND, since=$SINCE, until=$UNTIL, n=$N)."
  exit 0
fi

# === List mode ===
if [[ "$WANTS_EXTRACT" != "true" ]]; then
  if [[ "$FORMAT" == "json" ]]; then
    echo "$RAW"
    exit 0
  fi

  echo "# wx attachments — $NAME"
  echo
  FILTERS=()
  [[ "$KIND" != "all" ]] && FILTERS+=("kind=$KIND")
  [[ -n "$SINCE" ]] && FILTERS+=("since=$SINCE")
  [[ -n "$UNTIL" ]] && FILTERS+=("until=$UNTIL")
  FILTERS+=("n=$N")
  echo "Filters: $(IFS=', '; echo "${FILTERS[*]}")"
  echo
  echo "| Id | Kind | Filename / preview | Sender | Timestamp | Size |"
  echo "|---|---|---|---|---|---:|"
  echo "$RAW" | jq -r '.[] | "| \(.id // .attachment_id // "") | \(.kind // .type // "") | \(.filename // .name // .preview // "") | \(.sender // .from // "") | \(.timestamp // .time // "") | \(.size // .bytes // "") |"'
  echo
  echo "_Pass an \`Id\` to \`attachments.sh --extract <id> --out <dir>\` or use \`--extract-all\` to pull every row above._"
  exit 0
fi

# === Extract mode ===
if [[ ! -d "$OUT" ]]; then
  mkdir -p "$OUT"
  echo "[attachments] created $OUT"
fi

# Build id list
if [[ "$EXTRACT_ALL" == "true" ]]; then
  IDS=$(echo "$RAW" | jq -r '.[] | (.id // .attachment_id) | select(. != null)')
else
  IDS=$(echo "$EXTRACT_IDS" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | grep -v '^$')
fi

SUCCESSES=0
FAILURES=0
while IFS= read -r ID; do
  [[ -z "$ID" ]] && continue
  # Look up filename from list
  FILENAME=$(echo "$RAW" | jq -r --arg id "$ID" '.[] | select((.id // .attachment_id) == $id) | (.filename // .name // ($id + ".bin"))' | head -n 1)
  [[ -z "$FILENAME" ]] && FILENAME="${ID}.bin"

  # Sanitize
  SAFE_FILENAME=$(echo "$FILENAME" | tr '\\/:*?"<>|' '_')
  OUT_PATH="$OUT/$SAFE_FILENAME"

  echo "[attachments] extracting $ID -> $OUT_PATH"
  if wx extract "$ID" -o "$OUT_PATH"; then
    SUCCESSES=$((SUCCESSES + 1))
  else
    echo "WARNING: failed to extract $ID" >&2
    FAILURES=$((FAILURES + 1))
  fi
done <<< "$IDS"

echo
echo "[attachments] done. extracted=$SUCCESSES failed=$FAILURES out=$OUT"
[[ $FAILURES -gt 0 ]] && exit 1
exit 0
