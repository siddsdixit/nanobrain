#!/usr/bin/env bash
# fetch.sh -- slack. Searches public+private messages via Slack MCP.
# Stdout: JSON array. Stderr: progress only.

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
DATA_DIR="$BRAIN_DIR/data/slack"
WM="$DATA_DIR/.fetch_watermark"
mkdir -p "$DATA_DIR"

SINCE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    *) echo "[slack/fetch] unknown arg: $1" >&2; exit 64 ;;
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

command -v claude >/dev/null 2>&1 || { echo "[slack/fetch] claude CLI not in PATH" >&2; exit 3; }

prompt="Use the Slack MCP (mcp__claude_ai_Slack__slack_search_public_and_private) to fetch messages from the last $SINCE days. For each message, output a JSON array with fields: id, workspace_id, channel, user, ts (ISO8601), text. Output ONLY the JSON array, no other text, no markdown fence, no prose. If there are no results, output []."

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
  echo "[slack/fetch] non-array output from claude; returning []" >&2
  json="[]"
fi

printf '%s\n' "$json"
date +%s > "$WM"
exit 0
