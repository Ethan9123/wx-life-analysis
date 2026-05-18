#!/usr/bin/env bash
#
# contacts.sh — Fuzzy-lookup a WeChat contact and confirm exact name before refresh.
#
# POSIX-compatible equivalent of contacts.ps1. Wraps `wx contacts --query`,
# emits a markdown table with display name, remark, alias, chat type, wxid,
# last message time.
#
# Usage:
#   ./tools/contacts.sh --query "张"
#   ./tools/contacts.sh --query "alice" --format json
#   ./tools/contacts.sh
#
# Options:
#   --query STR       Substring fuzzy-match (display / remark / alias / wxid)
#   --n NUM           Max rows (default: 50)
#   --format FMT      markdown | json (default: markdown)
#
# Requires:
#   - wx-cli on PATH
#   - jq for JSON parsing (only when --format markdown)

set -euo pipefail

QUERY=""
N=50
FORMAT="markdown"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --query)  QUERY="$2";  shift 2 ;;
    --n)      N="$2";      shift 2 ;;
    --format) FORMAT="$2"; shift 2 ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      echo "Usage: $0 [--query STR] [--n NUM] [--format markdown|json]" >&2
      exit 1
      ;;
  esac
done

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

# Build wx args
WX_ARGS=(contacts --json)
if [[ -n "$QUERY" ]]; then
  WX_ARGS+=(--query "$QUERY")
fi

RAW=$(wx "${WX_ARGS[@]}" 2>&1) || {
  echo "ERROR: wx contacts failed. Is the daemon running? Try: wx daemon stop; wx new-messages" >&2
  exit "${PIPESTATUS[0]:-1}"
}

if [[ -z "$RAW" ]] || [[ "$RAW" == "[]" ]] || [[ "$RAW" == "null" ]]; then
  if [[ -n "$QUERY" ]]; then
    echo "No contacts match '$QUERY'."
  else
    echo "No contacts returned."
  fi
  exit 0
fi

# Cap to N
CAPPED=$(echo "$RAW" | jq --argjson n "$N" '.[:$n]')

if [[ "$FORMAT" == "json" ]]; then
  echo "$CAPPED"
  exit 0
fi

# Markdown
if [[ -n "$QUERY" ]]; then
  echo "# wx contacts lookup — query: \`$QUERY\`"
else
  echo "# wx contacts lookup"
fi
echo
echo "| Display name | Remark | Alias | Chat type | wxid | Last msg |"
echo "|---|---|---|---|---|---|"

echo "$CAPPED" | jq -r '.[] | "| \(.display_name // .nickname // "") | \(.remark // "") | \(.alias // "") | \(.chat_type // .type // "") | \(.wxid // "") | \(.last_message_time // .last_msg // "") |"'

echo
echo "_Pass the exact \`Display name\` to \`refresh.sh --name\` for the right contact._"
