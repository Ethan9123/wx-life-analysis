#!/usr/bin/env bash
#
# refresh-group.sh — Pull one WeChat group chat into topics/<slug>/.
#
# Usage:
#   ./tools/refresh-group.sh --name "研发群" --slug "rd-group"
#   ./tools/refresh-group.sh --name "Acme Team Chat" --slug "acme-team" --since-days 30
#   ./tools/refresh-group.sh --name "AI讨论" --slug "ai-discuss" --since-date "2026-04-01"

set -euo pipefail

NAME=""
SLUG=""
SINCE_DAYS="14"
SINCE_DATE=""
FORMAT="json"
OUT=""

usage() {
  echo "Usage: $0 --name NAME --slug SLUG [--since-days N] [--since-date YYYY-MM-DD] [--format markdown|json] [--out PATH]" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name) NAME="$2"; shift 2 ;;
    --slug) SLUG="$2"; shift 2 ;;
    --since-days) SINCE_DAYS="$2"; shift 2 ;;
    --since-date) SINCE_DATE="$2"; shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "ERROR: --name is required" >&2
  exit 1
fi
if [[ -z "$SLUG" ]]; then
  echo "ERROR: --slug is required" >&2
  exit 1
fi
if [[ ! "$SLUG" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "ERROR: Slug 必须是 ASCII 小写连字符，例如 \`ungc-work-group\`，不能用「UNGC 工作群」" >&2
  exit 1
fi
if [[ ! "$SINCE_DAYS" =~ ^[0-9]+$ ]]; then
  echo "ERROR: --since-days must be a non-negative integer" >&2
  exit 1
fi
if [[ -n "$SINCE_DATE" ]] && [[ ! "$SINCE_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "ERROR: --since-date must be in YYYY-MM-DD format" >&2
  exit 1
fi
if [[ "$FORMAT" != "json" && "$FORMAT" != "markdown" ]]; then
  echo "ERROR: --format must be one of: json, markdown" >&2
  exit 1
fi

if ! command -v wx >/dev/null 2>&1; then
  echo "ERROR: wx-cli not found on PATH. Install with: npm install -g @jackwener/wx-cli" >&2
  exit 2
fi

TOPIC_DIR="topics/$SLUG"
if [[ ! -d "$TOPIC_DIR" ]]; then
  mkdir -p "$TOPIC_DIR"
  echo "[refresh-group] created $TOPIC_DIR"
fi

EXT="json"
if [[ "$FORMAT" == "markdown" ]]; then
  EXT="md"
fi

if [[ -z "$OUT" ]]; then
  OUT="$TOPIC_DIR/chat.$EXT"
fi

MEMBERS_PATH="$TOPIC_DIR/members.json"
SYNC_PATH="$TOPIC_DIR/.last-sync"

SINCE_VALUE=""
if [[ -n "$SINCE_DATE" ]]; then
  SINCE_VALUE="$SINCE_DATE"
else
  if command -v gdate >/dev/null 2>&1; then
    SINCE_VALUE=$(gdate -d "$SINCE_DAYS days ago" '+%Y-%m-%d')
  else
    SINCE_VALUE=$(date -v-"$SINCE_DAYS"d '+%Y-%m-%d' 2>/dev/null || date -d "$SINCE_DAYS days ago" '+%Y-%m-%d')
  fi
fi

echo "[refresh-group] pulling members -> $MEMBERS_PATH"
wx members "$NAME" --json > "$MEMBERS_PATH"
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: wx members failed (exit $EXIT_CODE)" >&2
  exit "$EXIT_CODE"
fi

echo "[refresh-group] exporting group chat since $SINCE_VALUE ($FORMAT) -> $OUT"
wx export "$NAME" --since "$SINCE_VALUE" --format "$FORMAT" -o "$OUT"
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
  echo "ERROR: wx export failed (exit $EXIT_CODE)" >&2
  exit "$EXIT_CODE"
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "$TIMESTAMP" > "$SYNC_PATH"

echo "[refresh-group] done. last-sync: $TIMESTAMP"
