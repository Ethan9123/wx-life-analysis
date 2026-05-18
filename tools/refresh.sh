#!/usr/bin/env bash
#
# refresh.sh — Pull latest chat, SNS feed, and stats for one WeChat contact.
#
# POSIX-compatible equivalent of refresh.ps1. Works on macOS Big Sur+ and Linux.
#
# Incremental by default: if `.last-sync` exists in the target directory, uses
# `wx export --since <date>` to pull only new messages since the last refresh.
# First run (no `.last-sync`) falls back to `--n` initial seed. Use `--full` to
# force a full re-pull regardless.
#
# Usage:
#   ./tools/refresh.sh --name "张三" --dir "people/zhangsan"
#   ./tools/refresh.sh --name "Alice" --dir "people/alice" --n 1000 --skip-sns
#   ./tools/refresh.sh --name "张三" --dir "people/zhangsan" --full
#   ./tools/refresh.sh --name "张三" --dir "people/zhangsan" --since 2026-05-01
#
# Options:
#   --name NAME       Contact display name in WeChat (required)
#   --dir  DIR        Output directory relative to repo root (required)
#   --n    NUM        Max chat messages on initial seed (default: 500)
#   --sns-n NUM       Max SNS entries to pull on initial seed (default: 50)
#   --skip-sns        Skip SNS feed pull
#   --full            Force a full re-pull (ignore .last-sync)
#   --since YYYY-MM-DD  Manually specify cutoff date (overrides --full and .last-sync)
#
# Output files (all in --dir):
#   chat.md           Exported chat messages
#   sns.json          SNS/Moments feed
#   stats.txt         Contact statistics
#   .last-sync        Timestamp of last refresh

set -euo pipefail

# --- Defaults ---
N=500
SNS_N=50
SKIP_SNS=false
FULL=false
SINCE=""
NAME=""
DIR=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)     NAME="$2";    shift 2 ;;
    --dir)      DIR="$2";     shift 2 ;;
    --n)        N="$2";       shift 2 ;;
    --sns-n)    SNS_N="$2";   shift 2 ;;
    --skip-sns) SKIP_SNS=true; shift ;;
    --full)     FULL=true;    shift ;;
    --since)    SINCE="$2";   shift 2 ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      echo "Usage: $0 --name NAME --dir DIR [--n NUM] [--sns-n NUM] [--skip-sns] [--full] [--since YYYY-MM-DD]" >&2
      exit 1
      ;;
  esac
done

# --- Validate required args ---
if [[ -z "$NAME" ]]; then
  echo "ERROR: --name is required" >&2
  exit 1
fi
if [[ -z "$DIR" ]]; then
  echo "ERROR: --dir is required" >&2
  exit 1
fi

# --- Verify wx is on PATH ---
if ! command -v wx &>/dev/null; then
  echo "ERROR: wx-cli not found on PATH. Install with: npm install -g @jackwener/wx-cli" >&2
  exit 2
fi

# --- Create output dir ---
if [[ ! -d "$DIR" ]]; then
  mkdir -p "$DIR"
  echo "[refresh] created $DIR"
fi

CHAT_PATH="$DIR/chat.md"
SNS_PATH="$DIR/sns.json"
STATS_PATH="$DIR/stats.txt"
SYNC_PATH="$DIR/.last-sync"

# --- Decide cutoff: --since > .last-sync (unless --full) > nothing (initial seed via --n) ---
SINCE_DATE=""
if [[ -n "$SINCE" ]]; then
  SINCE_DATE="$SINCE"
  echo "[refresh] mode: explicit --since $SINCE_DATE"
elif [[ "$FULL" != "true" ]] && [[ -f "$SYNC_PATH" ]]; then
  LAST_SYNC=$(cat "$SYNC_PATH" | tr -d '[:space:]')
  # .last-sync stores "yyyy-MM-dd HH:mm:ss"; wx-cli --since takes a date,
  # so split off the date portion.
  if [[ "$LAST_SYNC" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
    SINCE_DATE="${BASH_REMATCH[1]}"
    echo "[refresh] mode: incremental since $SINCE_DATE"
  else
    echo "WARNING: .last-sync file exists but unparseable: '$LAST_SYNC' — falling back to --n $N" >&2
  fi
elif [[ "$FULL" == "true" ]]; then
  echo "[refresh] mode: --full (re-pull last $N)"
else
  echo "[refresh] mode: initial seed (last $N messages)"
fi

# --- 1. Export chat ---
if [[ -n "$SINCE_DATE" ]]; then
  echo "[refresh] exporting chat (since $SINCE_DATE) -> $CHAT_PATH"
  wx export "$NAME" --since "$SINCE_DATE" --format markdown -o "$CHAT_PATH"
else
  echo "[refresh] exporting chat ($N messages) -> $CHAT_PATH"
  wx export "$NAME" -n "$N" --format markdown -o "$CHAT_PATH"
fi
# Note: wx may print warnings to stderr; only the exit code matters.
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: wx export failed (exit $EXIT_CODE)" >&2
  exit "$EXIT_CODE"
fi

# --- 2. SNS feed (optional, also uses --since when available) ---
if [[ "$SKIP_SNS" != "true" ]]; then
  echo "[refresh] pulling SNS feed -> $SNS_PATH"
  if [[ -n "$SINCE_DATE" ]]; then
    if wx sns-feed --user "$NAME" --since "$SINCE_DATE" --json > "$SNS_PATH" 2>/dev/null; then
      :
    else
      echo "WARNING: wx sns-feed failed (exit $?) — skipping. Use --skip-sns to suppress." >&2
      rm -f "$SNS_PATH"
    fi
  else
    if wx sns-feed --user "$NAME" -n "$SNS_N" --json > "$SNS_PATH" 2>/dev/null; then
      :
    else
      echo "WARNING: wx sns-feed failed (exit $?) — skipping. Use --skip-sns to suppress." >&2
      rm -f "$SNS_PATH"
    fi
  fi
fi

# --- 3. Stats (always full — wx stats has its own time range; we just snapshot it) ---
echo "[refresh] computing stats -> $STATS_PATH"
wx stats "$NAME" > "$STATS_PATH"

# --- 4. Sync timestamp ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP" > "$SYNC_PATH"

echo "[refresh] done. last-sync: $TIMESTAMP"
echo ""
echo "Next: read $CHAT_PATH and update $DIR/profile.md"
