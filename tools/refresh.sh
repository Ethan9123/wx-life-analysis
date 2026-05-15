#!/usr/bin/env bash
#
# refresh.sh — Pull latest chat, SNS feed, and stats for one WeChat contact.
#
# POSIX-compatible equivalent of refresh.ps1. Works on macOS Big Sur+ and Linux.
#
# Usage:
#   ./tools/refresh.sh --name "张三" --dir "people/zhangsan"
#   ./tools/refresh.sh --name "Alice" --dir "people/alice" --n 1000 --skip-sns
#
# Options:
#   --name NAME     Contact display name in WeChat (required)
#   --dir  DIR      Output directory relative to repo root (required)
#   --n    NUM      Max chat messages to export (default: 500)
#   --sns-n NUM     Max SNS entries to pull (default: 50)
#   --skip-sns      Skip SNS feed pull
#
# Output files (all in --dir):
#   chat.md         Exported chat messages
#   sns.json        SNS/Moments feed
#   stats.txt       Contact statistics
#   .last-sync      Timestamp of last refresh

set -euo pipefail

# --- Defaults ---
N=500
SNS_N=50
SKIP_SNS=false
NAME=""
DIR=""

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)    NAME="$2";    shift 2 ;;
    --dir)     DIR="$2";     shift 2 ;;
    --n)       N="$2";       shift 2 ;;
    --sns-n)   SNS_N="$2";   shift 2 ;;
    --skip-sns) SKIP_SNS=true; shift ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      echo "Usage: $0 --name NAME --dir DIR [--n NUM] [--sns-n NUM] [--skip-sns]" >&2
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

# --- 1. Export chat ---
echo "[refresh] exporting chat ($N messages) -> $CHAT_PATH"
wx export "$NAME" -n "$N" --format markdown -o "$CHAT_PATH"
# Note: wx may print warnings to stderr; only the exit code matters.
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: wx export failed (exit $EXIT_CODE)" >&2
  exit "$EXIT_CODE"
fi

# --- 2. SNS feed (optional) ---
if [[ "$SKIP_SNS" != "true" ]]; then
  echo "[refresh] pulling SNS feed -> $SNS_PATH"
  if wx sns-feed --user "$NAME" -n "$SNS_N" --json > "$SNS_PATH" 2>/dev/null; then
    :  # success
  else
    echo "WARNING: wx sns-feed failed (exit $?) — skipping. Use --skip-sns to suppress." >&2
    rm -f "$SNS_PATH"
  fi
fi

# --- 3. Stats ---
echo "[refresh] computing stats -> $STATS_PATH"
wx stats "$NAME" > "$STATS_PATH"

# --- 4. Sync timestamp ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP" > "$SYNC_PATH"

echo "[refresh] done. last-sync: $TIMESTAMP"
echo ""
echo "Next: read $CHAT_PATH and update $DIR/profile.md"
