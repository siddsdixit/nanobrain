#!/usr/bin/env bash
# capture.sh -- Claude Code Stop hook. Throttled (30 min OR 5KB new transcript).
# Reads CLAUDE_PROJECT_DIR, transcript path; calls claude -p with STOP.md;
# routes signal blocks; commits.

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
HOOKS_DIR="$FRAMEWORK_DIR/code/hooks"

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${PWD:-unknown}}"
TRANSCRIPT="${CLAUDE_TRANSCRIPT:-}"
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%s)}"

state_dir="$BRAIN_DIR/data/_state"
mkdir -p "$state_dir"
mark="$state_dir/capture.mark"     # last run epoch
wm="$state_dir/capture.bytes"      # last transcript size when we ran

now=$(date +%s)
last=0
[ -f "$mark" ] && last=$(cat "$mark" 2>/dev/null || echo 0)
elapsed=$(( now - last ))

bytes=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  bytes=$(wc -c <"$TRANSCRIPT" | tr -d ' ')
fi
last_bytes=0
[ -f "$wm" ] && last_bytes=$(cat "$wm" 2>/dev/null || echo 0)
delta=$(( bytes - last_bytes ))

# brain-checkpoint sets FORCE_CAPTURE=1 to bypass throttle.
if [ "${FORCE_CAPTURE:-0}" != "1" ]; then
  if [ "$elapsed" -lt 1800 ] && [ "$delta" -lt 5120 ]; then
    echo "[capture] throttled (elapsed=${elapsed}s delta=${delta}B)" >&2
    exit 0
  fi
fi

# 1. Append claude session entry to data/claude/INBOX.md.
bash "$FRAMEWORK_DIR/code/sources/claude/ingest.sh" \
  --project "$PROJECT_DIR" \
  --transcript "${TRANSCRIPT:-/dev/null}" \
  --session "$SESSION_ID" || true

# 2. Distill (best-effort).
NANOBRAIN_DIR="$FRAMEWORK_DIR" BRAIN_DIR="$BRAIN_DIR" \
  bash "$FRAMEWORK_DIR/code/skills/brain-distill/dispatch.sh" claude || true

# 3. Update marks.
printf '%s\n' "$now"   > "$mark"
printf '%s\n' "$bytes" > "$wm"

LOG_SH="$FRAMEWORK_DIR/code/skills/brain-log/log.sh"
if [ -x "$LOG_SH" ]; then
  BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" capture "Stop hook: session=$SESSION_ID delta=${delta}B" || true
fi

echo "[capture] done"
