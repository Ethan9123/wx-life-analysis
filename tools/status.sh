#!/usr/bin/env bash
#
# status.sh — Print a one-line status row for every active contact and project.
#
# POSIX-compatible equivalent of status.ps1. Works on macOS Big Sur+ and Linux.
#
# Usage:
#   ./tools/status.sh
#   ./tools/status.sh --stale-days 7
#
# Options:
#   --stale-days NUM  Highlight rows not updated in the last N days (default: 7)

set -euo pipefail

STALE_DAYS=7

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --stale-days) STALE_DAYS="$2"; shift 2 ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      echo "Usage: $0 [--stale-days NUM]" >&2
      exit 1
      ;;
  esac
done

# --- Helpers ---

# Get frontmatter field from a markdown file.
# Matches: `field: value`, `**field**: value`, `- field: value`, `field：value` (Chinese colon)
get_frontmatter() {
  local file="$1"
  local field="$2"
  if [[ ! -f "$file" ]]; then
    echo ""
    return
  fi
  # Grep for the field with various formats, extract the value
  # Patterns: field: value, **field**: value, - field: value, field：value
  local val
  val=$(grep -im1 "^[[:space:]]*[-*]*[[:space:]]*\*\{0,2\}$field\*\{0,2\}[[:space:]]*[:：][[:space:]]*" "$file" 2>/dev/null \
    | sed -E 's/^[[:space:]]*[-*]*[[:space:]]*\*{0,2}[^:：]*[:：][[:space:]]*//' \
    | sed 's/[[:space:]]*$//')
  echo "$val"
}

# Check if a date string is older than STALE_DAYS
is_stale() {
  local date_str="$1"
  if [[ -z "$date_str" ]]; then
    return 1
  fi
  # Try to parse date (macOS `date` and Linux `date` have different flags)
  local date_epoch
  if date --version 2>/dev/null | grep -q GNU; then
    # GNU date (Linux)
    date_epoch=$(date -d "$date_str" +%s 2>/dev/null) || return 1
  else
    # BSD date (macOS)
    date_epoch=$(date -j -f "%Y-%m-%d" "${date_str:0:10}" +%s 2>/dev/null) || return 1
  fi
  local now_epoch
  now_epoch=$(date +%s)
  local diff_days=$(( (now_epoch - date_epoch) / 86400 ))
  if [[ $diff_days -gt "$STALE_DAYS" ]]; then
    return 0  # is stale
  fi
  return 1  # not stale
}

# Print a row with optional yellow highlighting for stale items
show_row() {
  local kind="$1"
  local name="$2"
  local updated="$3"
  local ball="$4"
  local next="$5"

  local updated_show="${updated:-(no date)}"
  local ball_show="${ball:--}"
  local next_show="${next:--}"

  if [[ -n "$updated" ]] && is_stale "$updated"; then
    # ANSI yellow
    printf "\033[33m%-8s %-16s %-12s %-10s %s\033[0m\n" \
      "$kind" "${name:0:16}" "${updated_show:0:12}" "${ball_show:0:10}" "$next_show"
  else
    printf "%-8s %-16s %-12s %-10s %s\n" \
      "$kind" "${name:0:16}" "${updated_show:0:12}" "${ball_show:0:10}" "$next_show"
  fi
}

# --- Header ---
printf "\033[36m%-8s %-16s %-12s %-10s %s\033[0m\n" "KIND" "NAME" "UPDATED" "BALL" "NEXT"
printf "\033[90m%s\033[0m\n" "-------------------------------------------------------------------------------"

# --- People ---
if [[ -d "people" ]]; then
  for d in people/*/; do
    d_name=$(basename "$d")
    [[ "$d_name" = "_template" ]] && continue
    profile="$d/profile.md"
    [[ ! -f "$profile" ]] && continue

    updated=$(get_frontmatter "$profile" "last-updated")
    ball=$(get_frontmatter "$profile" "球在谁那")
    [[ -z "$ball" ]] && ball=$(get_frontmatter "$profile" "ball-in-court")
    next=$(get_frontmatter "$profile" "下次动作")
    [[ -z "$next" ]] && next=$(get_frontmatter "$profile" "next-action")

    show_row "person" "$d_name" "$updated" "$ball" "$next"
  done
fi

# --- Projects ---
if [[ -d "projects" ]]; then
  for d in projects/*/; do
    d_name=$(basename "$d")
    [[ "$d_name" = "_template" ]] && continue
    notes="$d/notes.md"
    [[ ! -f "$notes" ]] && continue

    updated=$(get_frontmatter "$notes" "last-updated")
    ball=$(get_frontmatter "$notes" "球在谁那")
    [[ -z "$ball" ]] && ball=$(get_frontmatter "$notes" "ball-in-court")
    next=$(get_frontmatter "$notes" "下次动作")
    [[ -z "$next" ]] && next=$(get_frontmatter "$notes" "next-action")

    show_row "project" "$d_name" "$updated" "$ball" "$next"
  done
fi

echo ""
printf "\033[90mrows in color are older than %s days\033[0m\n" "$STALE_DAYS"
