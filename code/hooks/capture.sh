#!/usr/bin/env bash
# Stop-hook backend. Throttled per-session capture so weeks-long sessions
# don't blow tokens on every turn. Tracks a watermark per session_id.
#
# Decision logic:
#   - Stop hook fires every assistant turn (NOT when session truly ends).
#   - Capture only if: (a) >= MIN_NEW_BYTES of new transcript since last capture,
#                  OR (b) >= MIN_HOURS since last capture,
#                  OR (c) FORCE_CAPTURE=1 in env (manual /brain checkpoint).
#   - Each capture passes only the DELTA (new bytes) to claude -p, not the full transcript.
#
# Wired in ~/.claude/settings.json:
#   {"hooks": {"Stop": [{"matcher": "", "hooks": [
#     {"type": "command", "command": "$HOME/brain/code/hooks/capture.sh"}
#   ]}]}}

set -euo pipefail

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
LOG_DIR="$BRAIN_DIR/data/_logs"
SESSIONS_DIR="$LOG_DIR/sessions"
LOG="$LOG_DIR/capture.log"
LOCK="$BRAIN_DIR/.capture.lock"
STOP_MD="$BRAIN_DIR/code/hooks/STOP.md"
TIMEOUT_SEC=90

# Throttle thresholds (override via env if needed)
MIN_NEW_BYTES="${NANOBRAIN_MIN_BYTES:-5000}"   # 5 KB of new transcript
MIN_MINUTES="${NANOBRAIN_MIN_MINUTES:-30}"     # OR 30 minutes since last capture
FORCE="${FORCE_CAPTURE:-0}"                    # /brain checkpoint sets this

mkdir -p "$LOG_DIR" "$SESSIONS_DIR"

ts() { date +%Y-%m-%dT%H:%M:%S; }
epoch() { date +%s; }
log() { printf '%s [%s] %s\n' "$(ts)" "${SESSION_ID:-?}" "$*" >> "$LOG"; }

# Recursion guard #1 — env var
[ "${NANOBRAIN_CAPTURING:-0}" = "1" ] && exit 0

# Read hook payload
PAYLOAD="$(cat 2>/dev/null || true)"
SESSION_ID="$(echo "$PAYLOAD" | (jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown"))"
TRANSCRIPT="$(echo "$PAYLOAD" | (jq -r '.transcript_path // empty' 2>/dev/null || true))"
STOP_HOOK_ACTIVE="$(echo "$PAYLOAD" | (jq -r '.stop_hook_active // false' 2>/dev/null || echo false))"
EVENT="$(echo "$PAYLOAD" | (jq -r '.hook_event_name // "Stop"' 2>/dev/null || echo "Stop"))"

# Terminal events always force-capture (session ending or context about to compact).
# These are safety nets for long-running sessions: even if the throttle hasn't
# fired, force a capture before signal is lost.
case "$EVENT" in
  SessionEnd|PreCompact|Notification) FORCE=1 ;;
esac

# Recursion guard #2
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  log "skip: stop_hook_active=true"
  exit 0
fi

# Pre-flight: required tools
command -v claude >/dev/null 2>&1 || { log "skip: claude CLI missing"; exit 0; }
command -v jq >/dev/null 2>&1 || { log "skip: jq missing"; exit 0; }
[ -f "$STOP_MD" ] || { log "skip: STOP.md missing"; exit 0; }

# Pre-flight: transcript exists
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  log "skip: no transcript"
  exit 0
fi
TRANSCRIPT_BYTES="$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)"
[ "${TRANSCRIPT_BYTES:-0}" -ge 500 ] || { log "skip: transcript too small ($TRANSCRIPT_BYTES bytes)"; exit 0; }

# Watermark per session_id
WATERMARK="$SESSIONS_DIR/${SESSION_ID}.json"
NOW_EPOCH="$(epoch)"
NOW_TS="$(ts)"

if [ -f "$WATERMARK" ]; then
  LAST_OFFSET="$(jq -r '.last_byte_offset // 0' "$WATERMARK" 2>/dev/null || echo 0)"
  LAST_EPOCH="$(jq -r '.last_capture_epoch // 0' "$WATERMARK" 2>/dev/null || echo 0)"
  CAPTURE_COUNT="$(jq -r '.capture_count // 0' "$WATERMARK" 2>/dev/null || echo 0)"
else
  LAST_OFFSET=0
  LAST_EPOCH=0
  CAPTURE_COUNT=0
fi

NEW_BYTES=$((TRANSCRIPT_BYTES - LAST_OFFSET))
SECONDS_SINCE=$((NOW_EPOCH - LAST_EPOCH))
MINUTES_SINCE=$((SECONDS_SINCE / 60))

# Throttle decision
SHOULD_CAPTURE=0
REASON=""
if [ "$FORCE" = "1" ]; then
  SHOULD_CAPTURE=1; REASON="force/$EVENT"
elif [ "$NEW_BYTES" -ge "$MIN_NEW_BYTES" ]; then
  SHOULD_CAPTURE=1; REASON="bytes=$NEW_BYTES"
elif [ "$MINUTES_SINCE" -ge "$MIN_MINUTES" ] && [ "$LAST_EPOCH" -gt 0 ] && [ "$NEW_BYTES" -gt 500 ]; then
  SHOULD_CAPTURE=1; REASON="minutes=$MINUTES_SINCE"
elif [ "$LAST_EPOCH" -eq 0 ] && [ "$TRANSCRIPT_BYTES" -ge "$MIN_NEW_BYTES" ]; then
  SHOULD_CAPTURE=1; REASON="first capture"
fi

if [ "$SHOULD_CAPTURE" -eq 0 ]; then
  log "throttle: event=$EVENT new=$NEW_BYTES bytes, since=${MINUTES_SINCE}m, count=$CAPTURE_COUNT"
  exit 0
fi

# Acquire lock
if [ -f "$LOCK" ]; then
  HOLDER="$(cat "$LOCK" 2>/dev/null || echo)"
  if [ -n "$HOLDER" ] && kill -0 "$HOLDER" 2>/dev/null; then
    log "skip: lock held by pid $HOLDER"
    exit 0
  fi
  rm -f "$LOCK"
fi
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

# Stash any manual edits
cd "$BRAIN_DIR"
DIRTY="$(git status --porcelain 2>/dev/null | head -c 1)"
STASHED=0
if [ -n "$DIRTY" ]; then
  if git stash push --quiet -m "auto-stash before capture $NOW_TS" 2>/dev/null; then
    STASHED=1
    log "stash: pre-existing edits saved"
  else
    log "skip: dirty tree, stash failed"
    exit 0
  fi
fi

HEAD_BEFORE="$(git rev-parse HEAD 2>/dev/null || echo unknown)"

# Build delta payload: only new portion of transcript
# Pass session metadata so claude knows this is a continuation
DELTA_FILE="$(mktemp)"
trap 'rm -f "$LOCK" "$DELTA_FILE"' EXIT

{
  echo "# Session capture context"
  echo ""
  echo "- session_id: $SESSION_ID"
  echo "- capture_count_before: $CAPTURE_COUNT (this is capture #$((CAPTURE_COUNT + 1)))"
  echo "- new_bytes_since_last: $NEW_BYTES"
  echo "- hours_since_last: $HOURS_SINCE"
  echo "- reason: $REASON"
  echo ""
  if [ "$LAST_OFFSET" -gt 0 ]; then
    echo "## Prior captures already extracted earlier signal."
    echo "Only extract from the NEW transcript content below."
    echo "Avoid re-capturing decisions/learnings already saved."
    echo ""
  fi
  echo "## Protocol"
  echo ""
  cat "$STOP_MD"
  echo ""
  echo "## New transcript (delta only)"
  echo ""
  if [ "$LAST_OFFSET" -gt 0 ]; then
    tail -c +"$((LAST_OFFSET + 1))" "$TRANSCRIPT"
  else
    cat "$TRANSCRIPT"
  fi
} > "$DELTA_FILE"

DELTA_BYTES="$(wc -c < "$DELTA_FILE")"
log "run: reason=$REASON, delta=$DELTA_BYTES bytes (new transcript=$NEW_BYTES)"

export NANOBRAIN_CAPTURING=1
if command -v timeout >/dev/null 2>&1; then
  timeout "$TIMEOUT_SEC" claude -p --add-dir "$BRAIN_DIR" < "$DELTA_FILE" >/dev/null 2>&1 || \
    log "warn: claude -p exited non-zero or timed out"
else
  claude -p --add-dir "$BRAIN_DIR" < "$DELTA_FILE" >/dev/null 2>&1 || \
    log "warn: claude -p exited non-zero"
fi

# Verify outcome
HEAD_AFTER="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
if [ "$HEAD_AFTER" != "$HEAD_BEFORE" ]; then
  COMMIT_SUBJECT="$(git log -1 --pretty=%s 2>/dev/null)"
  log "ok: committed → $HEAD_AFTER ($COMMIT_SUBJECT)"
else
  ORPHAN="$(git status --porcelain 2>/dev/null | head -c 1)"
  if [ -n "$ORPHAN" ]; then
    log "warn: uncommitted changes after capture; reverting"
    git checkout -- . 2>/dev/null || true
    git clean -fd brain/ data/ 2>/dev/null || true
  else
    log "ok: nothing worth keeping in delta"
  fi
fi

# Update watermark (regardless of whether commit happened — we processed up to here)
NEW_COUNT=$((CAPTURE_COUNT + 1))
jq -n \
  --arg sid "$SESSION_ID" \
  --arg first_seen "$(jq -r '.first_seen // empty' "$WATERMARK" 2>/dev/null || echo "$NOW_TS")" \
  --arg last_capture "$NOW_TS" \
  --argjson last_capture_epoch "$NOW_EPOCH" \
  --argjson last_byte_offset "$TRANSCRIPT_BYTES" \
  --argjson capture_count "$NEW_COUNT" \
  --arg last_reason "$REASON" \
  '{session_id: $sid, first_seen: $first_seen, last_capture: $last_capture, last_capture_epoch: $last_capture_epoch, last_byte_offset: $last_byte_offset, capture_count: $capture_count, last_reason: $last_reason}' \
  > "$WATERMARK"

# Restore stash
if [ "$STASHED" = "1" ]; then
  git stash pop --quiet 2>/dev/null || log "warn: stash pop failed"
fi

exit 0
