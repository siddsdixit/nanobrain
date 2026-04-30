#!/usr/bin/env bash
# fetch.sh -- gcal. Bidirectional window: last N days + next 14 days.
# Stdout: JSON array. Stderr: progress only.

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
DATA_DIR="$BRAIN_DIR/data/gcal"
WM="$DATA_DIR/.fetch_watermark"
mkdir -p "$DATA_DIR"

SINCE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    *) echo "[gcal/fetch] unknown arg: $1" >&2; exit 64 ;;
  esac
done

if [ -z "$SINCE" ]; then
  if [ -f "$WM" ]; then
    last=$(cat "$WM" 2>/dev/null || echo 0)
    now=$(date +%s)
    diff_days=$(( (now - last) / 86400 + 1 ))
    [ "$diff_days" -lt 1 ] && diff_days=1
    [ "$diff_days" -gt 90 ] && diff_days=90
    SINCE="$diff_days"
  else
    SINCE=7
  fi
fi

command -v claude >/dev/null 2>&1 || { echo "[gcal/fetch] claude CLI not in PATH" >&2; exit 3; }

prompt="Use the Google Calendar MCP (mcp__claude_ai_Google_Calendar__list_events) to fetch calendar events from the last $SINCE days AND the next 14 days. For each event, output a JSON array with fields: id, calendar_id, organizer, start (ISO8601), title, description. Output ONLY the JSON array, no other text, no markdown fence, no prose. If there are no results, output []."

raw=$(printf '%s' "$prompt" | claude -p --output-format json 2>/dev/null || \
      printf '%s' "$prompt" | claude -p 2>/dev/null || true)

json=$(printf '%s' "$raw" | awk '
  /^```/ { in_fence = !in_fence; next }
  in_fence { print; next }
  /^\[/ { found=1 }
  found { print }
')
[ -n "$json" ] || json="$raw"

if ! printf '%s' "$json" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "[gcal/fetch] non-array output from claude; returning []" >&2
  json="[]"
fi

printf '%s\n' "$json"
date +%s > "$WM"
exit 0
