#!/usr/bin/env bash
# checkpoint.sh -- force capture bypassing the throttle.

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
NANOBRAIN_DIR="${NANOBRAIN_DIR:-$HOME/Documents/nanobrain-v2}"
STUB="${NANOBRAIN_CAPTURE_STUB:-}"

CAPTURE="$NANOBRAIN_DIR/code/hooks/capture.sh"
[ -n "$STUB" ] && CAPTURE="$STUB"

if [ ! -f "$CAPTURE" ]; then
  echo "[brain-checkpoint] capture script not found: $CAPTURE" >&2
  exit 2
fi

# Find current session transcript if any (best effort).
TRANSCRIPT=""
if ls "$HOME"/.claude/projects/*/*.jsonl >/dev/null 2>&1; then
  TRANSCRIPT=$(ls -t "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null | head -1)
fi
SESSION_ID="manual-$(date +%s)"
[ -n "$TRANSCRIPT" ] && SESSION_ID=$(basename "$TRANSCRIPT" .jsonl)

PAYLOAD=$(printf '{"session_id":"%s","transcript_path":"%s","hook_event_name":"manual_checkpoint","stop_hook_active":false}' "$SESSION_ID" "$TRANSCRIPT")

FORCE_CAPTURE=1 \
BRAIN_DIR="$BRAIN_DIR" \
NANOBRAIN_DIR="$NANOBRAIN_DIR" \
CLAUDE_TRANSCRIPT="$TRANSCRIPT" \
CLAUDE_SESSION_ID="$SESSION_ID" \
bash "$CAPTURE" <<EOF
$PAYLOAD
EOF
RC=$?

if [ "$RC" -eq 0 ]; then
  echo "[brain-checkpoint] capture invoked (FORCE_CAPTURE=1, session=$SESSION_ID)"
else
  echo "[brain-checkpoint] capture exited with $RC (session=$SESSION_ID)"
fi

LOG_SH="$NANOBRAIN_DIR/code/skills/brain-log/log.sh"
if [ -x "$LOG_SH" ]; then
  BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" checkpoint "manual capture session=$SESSION_ID rc=$RC" || true
fi
exit "$RC"
