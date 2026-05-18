#!/usr/bin/env bash
#
# warmth.sh — Summarize SNS engagement on your own posts.
#
# POSIX-compatible equivalent of warmth.ps1. Wraps `wx sns-notifications` and
# groups by sender, ranking by recent engagement. Useful as the "warmth gauge"
# referenced in docs/mbti-analysis.md — answers "who's still actively engaging
# with my SNS, who's gone silent, and over what window".
#
# Usage:
#   ./tools/warmth.sh
#   ./tools/warmth.sh --include-read --n 300 --out reports/warmth.md
#   ./tools/warmth.sh --format json | jq '.[] | select(.total > 5)'
#
# Options:
#   --n NUM            Max notifications to pull (default: 100)
#   --include-read     Include already-read notifications (default: only unread)
#   --out PATH         Optional output file (default: stdout)
#   --format FMT       markdown | json (default: markdown)
#
# Requires:
#   - wx-cli (@jackwener/wx-cli) on PATH
#   - jq for JSON parsing

set -euo pipefail

# --- Defaults ---
N=100
INCLUDE_READ=false
OUT=""
FORMAT="markdown"

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --n)            N="$2"; shift 2 ;;
    --include-read) INCLUDE_READ=true; shift ;;
    --out)          OUT="$2"; shift 2 ;;
    --format)       FORMAT="$2"; shift 2 ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      echo "Usage: $0 [--n NUM] [--include-read] [--out PATH] [--format markdown|json]" >&2
      exit 1
      ;;
  esac
done

# --- Validate ---
if ! command -v wx &>/dev/null; then
  echo "ERROR: wx-cli not found on PATH. Install with: npm install -g @jackwener/wx-cli" >&2
  exit 2
fi
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq not found on PATH. Install jq: https://stedolan.github.io/jq/" >&2
  exit 2
fi
case "$FORMAT" in
  markdown|json) ;;
  *)
    echo "ERROR: --format must be 'markdown' or 'json' (got '$FORMAT')" >&2
    exit 1
    ;;
esac

# --- Build wx call ---
WX_ARGS=(sns-notifications --json -n "$N")
if [[ "$INCLUDE_READ" == "true" ]]; then
  WX_ARGS+=(--include-read)
fi

# Run wx
RAW=$(wx "${WX_ARGS[@]}" 2>&1) || {
  echo "ERROR: wx sns-notifications failed. Is the daemon running? Try: wx daemon stop; wx new-messages" >&2
  exit "${PIPESTATUS[0]:-1}"
}

# Empty?
if [[ -z "$RAW" ]] || [[ "$RAW" == "[]" ]] || [[ "$RAW" == "null" ]]; then
  echo "No SNS notifications in window (n=$N, include-read=$INCLUDE_READ)."
  exit 0
fi

# --- Aggregate via jq ---
# Output rows: sender,total,likes,comments,latest
AGG=$(echo "$RAW" | jq -r '
  group_by(.sender // .user // .from // "<unknown>") |
  map({
    sender:   (.[0].sender // .[0].user // .[0].from // "<unknown>"),
    total:    length,
    likes:    map(select((.type // .kind) == "like"))    | length,
    comments: map(select((.type // .kind) == "comment")) | length,
    latest:   (map(.timestamp // .time // .created_at) | map(select(.)) | sort | reverse | .[0] // "-")
  }) |
  sort_by(-.total)
')

# --- Emit ---
emit_markdown() {
  echo "# Warmth gauge — SNS engagement on your posts"
  echo
  if [[ "$INCLUDE_READ" == "true" ]]; then
    echo "Window: latest $N notifications (incl. read)"
  else
    echo "Window: latest $N notifications (unread only)"
  fi
  echo "Source: \`wx sns-notifications\`"
  echo
  echo "| Sender | Total | Likes | Comments | Latest |"
  echo "|---|---:|---:|---:|---|"
  echo "$AGG" | jq -r '.[] | "| \(.sender) | \(.total) | \(.likes) | \(.comments) | \(.latest) |"'
  echo
  echo "_Read this alongside \`chat.md\` + \`sns.json\` per \`docs/mbti-analysis.md\` § Interaction signals._"
}

emit_json() {
  echo "$AGG"
}

OUTPUT=""
case "$FORMAT" in
  markdown) OUTPUT=$(emit_markdown) ;;
  json)     OUTPUT=$(emit_json) ;;
esac

if [[ -n "$OUT" ]]; then
  echo "$OUTPUT" > "$OUT"
  echo "[warmth] wrote $OUT"
else
  echo "$OUTPUT"
fi
