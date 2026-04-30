#!/usr/bin/env bash
# fetch.sh -- gmail. Calls `claude -p` with the Gmail MCP, returns JSON array.
# Stdout: JSON array of threads (or [] if none). Stderr: progress only.
# Flags: --since DAYS (default: derived from .fetch_watermark, else 7).

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
DATA_DIR="$BRAIN_DIR/data/gmail"
WM="$DATA_DIR/.fetch_watermark"
mkdir -p "$DATA_DIR"

SINCE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --since) SINCE="$2"; shift 2 ;;
    *) echo "[gmail/fetch] unknown arg: $1" >&2; exit 64 ;;
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

command -v claude >/dev/null 2>&1 || { echo "[gmail/fetch] claude CLI not in PATH" >&2; exit 3; }

# Cheap MCP availability check (don't block on probe failure -- claude -p will
# emit [] if the tool is missing, and we'll surface that instead).
if [ -f "$HOME/.claude/settings.json" ]; then
  if ! grep -Fq "claude_ai_Gmail" "$HOME/.claude/settings.json" 2>/dev/null; then
    : # remote MCP may auto-attach; let claude -p decide.
  fi
fi

prompt="Use the Gmail MCP (mcp__claude_ai_Gmail__search_threads) to search recent email threads from the last $SINCE days. For each thread, output a JSON array with fields: id, from, to, date (ISO8601), subject, body (first 500 chars). Output ONLY the JSON array, no other text, no markdown fence, no prose. If there are no results, output []."

raw=$(printf '%s' "$prompt" | claude -p --output-format json 2>/dev/null || \
      printf '%s' "$prompt" | claude -p 2>/dev/null || true)

# Strip markdown fences and any leading/trailing prose.
json=$(printf '%s' "$raw" | awk '
  /^```/ { in_fence = !in_fence; next }
  in_fence { print; next }
  /^\[/ { found=1 }
  found { print }
')
[ -n "$json" ] || json="$raw"

# Validate; on failure emit [].
if ! printf '%s' "$json" | jq -e 'type == "array"' >/dev/null 2>&1; then
  echo "[gmail/fetch] non-array output from claude; returning []" >&2
  json="[]"
fi

printf '%s\n' "$json"
date +%s > "$WM"
exit 0
