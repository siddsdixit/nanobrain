#!/usr/bin/env bash
# log.sh -- append one operation line to brain/log.md.
#
# Usage: log.sh <op> "<title>"

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"

OP="${1:-}"
TITLE="${2:-}"

if [ -z "$OP" ] || [ -z "$TITLE" ]; then
  echo "usage: log.sh <op> \"<title>\"" >&2
  exit 2
fi

# Skip silently if no brain dir (we never want to fail a caller).
if [ ! -d "$BRAIN_DIR/brain" ]; then
  exit 0
fi

LOG="$BRAIN_DIR/brain/log.md"

if [ ! -f "$LOG" ]; then
  {
    printf '# Operation Log\n\n'
    printf '_Append-only. Format: `## [YYYY-MM-DD HH:MM] <op> | <title>`._\n'
    printf '_Greppable: `grep "^## \\[" brain/log.md | tail -10`._\n\n'
  } > "$LOG"
fi

TS=$(date '+%Y-%m-%d %H:%M')
# Strip newlines from title to keep one line per entry.
TITLE_ONELINE=$(printf '%s' "$TITLE" | tr '\n' ' ')

printf '## [%s] %s | %s\n' "$TS" "$OP" "$TITLE_ONELINE" >> "$LOG"
