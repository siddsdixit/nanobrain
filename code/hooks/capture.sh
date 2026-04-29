#!/usr/bin/env bash
# capture.sh -- Claude Code Stop / SessionEnd / PreCompact hook.
# Cheap, always-on, no LLM. Just enqueues a pointer; the drainer does real work later.

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
TRANSCRIPT="${CLAUDE_TRANSCRIPT:-}"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)}"

[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

queue="$BRAIN_DIR/data/claude/queue"
mkdir -p "$queue"

bytes=$(wc -c <"$TRANSCRIPT" | tr -d ' ' 2>/dev/null || echo 0)
ts=$(date +%s)

# One pointer per (session, fire). Drainer dedupes by session_id.
printf 'transcript=%s\nsession_id=%s\nbytes=%s\nts=%s\n' \
  "$TRANSCRIPT" "$SESSION_ID" "$bytes" "$ts" \
  > "$queue/${SESSION_ID}-${ts}.pending"

exit 0
