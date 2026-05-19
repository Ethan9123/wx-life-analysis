#!/usr/bin/env bash
#
# digest.sh — Show what changed since last session.
#
# POSIX-compatible equivalent of digest.ps1. Wraps `wx new-messages --json`,
# groups by contact, and prints a compact 5-column digest:
#   名字 / 消息数 / 最后消息时间 / 前 80 字预览 / 球在你?
#
# Ball-in-court status is read from people/<slug>/profile.md YAML frontmatter.
# Rows where ball-in-court=me are flagged with ⚠️.
#
# Usage:
#   ./tools/digest.sh                       # print digest to stdout
#   ./tools/digest.sh --write               # also write DIGEST.md (gitignored)
#   ./tools/digest.sh --since 2026-05-10    # filter by date
#
# Options:
#   --write           Also write DIGEST.md at repo root
#   --since DATE      Pass --since DATE to wx new-messages (YYYY-MM-DD)
#
# Requires:
#   - wx-cli on PATH (and a healthy daemon)
#   - jq for JSON parsing

set -euo pipefail

WRITE=false
SINCE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --write) WRITE=true; shift ;;
    --since) SINCE="$2"; shift 2 ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      echo "Usage: $0 [--write] [--since YYYY-MM-DD]" >&2
      exit 1
      ;;
  esac
done

# --- Dep checks ---
if ! command -v wx &>/dev/null; then
  echo "ERROR: wx-cli not found on PATH. Install with: npm install -g @jackwener/wx-cli" >&2
  exit 2
fi
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq not found on PATH. Install jq: https://stedolan.github.io/jq/" >&2
  exit 2
fi

# --- Validate --since format ---
if [[ -n "$SINCE" ]]; then
  if ! [[ "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "ERROR: --since must be YYYY-MM-DD (got '$SINCE')" >&2
    exit 1
  fi
fi

# --- Helper: read a single frontmatter field from a markdown file ---
get_frontmatter_field() {
  local file="$1" field="$2"
  [[ ! -f "$file" ]] && { echo ""; return; }
  # Extract YAML frontmatter block, then grep the field at column 0
  awk '
    BEGIN { in_fm = 0 }
    /^---[[:space:]]*$/ {
      if (in_fm == 0) { in_fm = 1; next }
      else { exit }
    }
    in_fm == 1 { print }
  ' "$file" | \
    grep -E "^[[:space:]]*${field}[[:space:]]*:" | \
    head -n 1 | \
    sed -E "s/^[[:space:]]*${field}[[:space:]]*:[[:space:]]*//; s/[[:space:]]+$//; s/^\"(.*)\"\$/\\1/; s/^'(.*)'\$/\\1/"
}

# --- Build ball-in-court lookup map (slug -> ball value, lowercase) ---
declare -A BALL_MAP
if [[ -d people ]]; then
  for dir in people/*/; do
    slug=$(basename "$dir")
    [[ "$slug" == "_template" ]] && continue
    profile="$dir/profile.md"
    [[ ! -f "$profile" ]] && continue
    ball=$(get_frontmatter_field "$profile" "ball-in-court")
    if [[ -n "$ball" ]]; then
      # Lowercase
      ball_lc=$(echo "$ball" | tr '[:upper:]' '[:lower:]')
      slug_lc=$(echo "$slug" | tr '[:upper:]' '[:lower:]')
      BALL_MAP[$slug_lc]="$ball_lc"
    fi
  done
fi

# --- Call wx new-messages ---
WX_ARGS=(new-messages --json)
if [[ -n "$SINCE" ]]; then
  WX_ARGS+=(--since "$SINCE")
fi

RAW=$(wx "${WX_ARGS[@]}" 2>&1) || {
  echo "ERROR: wx new-messages failed. If daemon is not running, try: wx daemon stop && wx new-messages" >&2
  echo "$RAW" >&2
  exit 1
}

if [[ -z "$RAW" ]] || [[ "$RAW" == "[]" ]] || [[ "$RAW" == "null" ]]; then
  echo "No new messages."
  exit 0
fi

# --- Aggregate via jq ---
# Each row: name | count | last_time | preview (80-char) | ball-flag
ROWS_JSON=$(echo "$RAW" | jq -r '
  group_by(.contactName // .talker // "Unknown") |
  map({
    name: (.[0].contactName // .[0].talker // "Unknown"),
    count: length,
    last_time: (
      map(.timestamp // .time // "") |
      map(select(. != "")) |
      sort | reverse | .[0] // "-"
    ),
    preview: (
      (sort_by(.timestamp // .time // "") | reverse | .[0]) |
      (.content // .text // .message // "") |
      gsub("[\r\n]+"; " ") |
      gsub("[[:space:]]+"; " ") |
      ltrimstr(" ") | rtrimstr(" ")
    )
  }) |
  sort_by(.last_time) | reverse
')

if [[ -z "$ROWS_JSON" ]] || [[ "$ROWS_JSON" == "[]" ]]; then
  echo "No new messages."
  exit 0
fi

# --- Truncate preview to 80 chars + assemble final rows with ball flag ---
ROW_COUNT=$(echo "$ROWS_JSON" | jq 'length')
if [[ "$ROW_COUNT" == "0" ]]; then
  echo "No new messages."
  exit 0
fi

# Build final array with ball flags applied per row
ROWS_FINAL=$(echo "$ROWS_JSON" | jq -c '.[]' | while IFS= read -r row; do
  name=$(echo "$row" | jq -r '.name')
  count=$(echo "$row" | jq -r '.count')
  last=$(echo "$row" | jq -r '.last_time')
  preview=$(echo "$row" | jq -r '.preview')

  # Truncate preview
  if [[ ${#preview} -gt 80 ]]; then
    preview="${preview:0:80}..."
  fi
  if [[ -z "$preview" ]] || [[ "$preview" == "null" ]]; then
    preview="<example preview text>"
  fi

  # Ball flag
  slug_lc=$(echo "$name" | tr '[:upper:]' '[:lower:]')
  ball="${BALL_MAP[$slug_lc]:-}"
  if [[ "$ball" == "me" ]]; then
    flag="⚠️"
  else
    flag=""
  fi

  # Emit as TSV for downstream formatting
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$count" "$last" "$preview" "$flag"
done)

# --- Print table to stdout ---
printf '\033[36m%-20s %6s %-19s %-83s %s\033[0m\n' "名字" "消息数" "最后消息时间" "前 80 字预览" "球在你?"
printf '\033[90m%s\033[0m\n' "------------------------------------------------------------------------------------------------------------------------------------------------------"

while IFS=$'\t' read -r name count last preview flag; do
  [[ -z "$name" ]] && continue
  if [[ "$flag" == "⚠️" ]]; then
    printf '\033[33m%-20s %6s %-19s %-83s %s\033[0m\n' "$name" "$count" "$last" "$preview" "$flag"
  else
    printf '%-20s %6s %-19s %-83s %s\n' "$name" "$count" "$last" "$preview" "$flag"
  fi
done <<< "$ROWS_FINAL"

# --- Write DIGEST.md if requested ---
if [[ "$WRITE" == "true" ]]; then
  {
    echo "# DIGEST"
    echo
    echo "generated-at: $(date '+%Y-%m-%d %H:%M:%S')"
    [[ -n "$SINCE" ]] && echo "since: $SINCE"
    echo
    echo "| 名字 | 消息数 | 最后消息时间 | 前 80 字预览 | 球在你? |"
    echo "|---|---:|---|---|---|"
    while IFS=$'\t' read -r name count last preview flag; do
      [[ -z "$name" ]] && continue
      # Escape pipes in preview
      preview_safe=$(echo "$preview" | sed 's/|/\\|/g')
      echo "| $name | $count | $last | $preview_safe | $flag |"
    done <<< "$ROWS_FINAL"
  } > DIGEST.md
  echo ""
  echo "Wrote DIGEST.md"
fi
