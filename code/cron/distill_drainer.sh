#!/usr/bin/env bash
# distill_drainer.sh -- async distill drainer.
# Fired by launchd every ~30 min. Idle-gated. Bounded backlog drain.
# Reads queue entries from data/claude/queue/, ingests + distills, marks .done or .failed.
# Also scans for orphaned transcripts (sessions with new bytes but no queue entry) as a safety net.

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

queue="$BRAIN_DIR/data/claude/queue"
state_dir="$BRAIN_DIR/data/_state"
wm_dir="$state_dir/watermarks"
logs_dir="$BRAIN_DIR/data/_logs"
mkdir -p "$queue" "$wm_dir" "$logs_dir"

# Tunables (env-overridable for tests).
IDLE_BUSY_SEC="${NANOBRAIN_IDLE_BUSY:-300}"      # below this = user busy, skip
IDLE_AWAY_SEC="${NANOBRAIN_IDLE_AWAY:-1800}"     # above this = user away, full drain
DRAIN_CAP_BUSY="${NANOBRAIN_DRAIN_CAP_BUSY:-1}"  # max entries per tick when 5-30 min idle
DRAIN_CAP_AWAY="${NANOBRAIN_DRAIN_CAP_AWAY:-10}" # max entries per tick when 30+ min idle
DISTILL_TIMEOUT="${NANOBRAIN_DISTILL_TIMEOUT:-180}"
SKIP_IDLE_CHECK="${NANOBRAIN_SKIP_IDLE_CHECK:-0}" # tests set 1

# Get HID idle time in seconds. Returns 0 on non-darwin or on error.
hid_idle_sec() {
  if [ "$SKIP_IDLE_CHECK" = "1" ]; then
    printf '%s\n' "${NANOBRAIN_FAKE_IDLE:-0}"
    return
  fi
  if command -v ioreg >/dev/null 2>&1; then
    # HIDIdleTime is in nanoseconds. Pick the first match.
    ns=$(ioreg -c IOHIDSystem 2>/dev/null \
      | awk '/HIDIdleTime/ { gsub(/[^0-9]/,"",$NF); print $NF; exit }')
    if [ -n "$ns" ] && [ "$ns" -gt 0 ] 2>/dev/null; then
      printf '%s\n' $((ns / 1000000000))
      return
    fi
  fi
  printf '0\n'
}

# Returns 0 if lid is closed, 1 otherwise. Best-effort; absent → assume open.
lid_closed() {
  if [ "$SKIP_IDLE_CHECK" = "1" ]; then
    [ "${NANOBRAIN_FAKE_LID_CLOSED:-0}" = "1" ]
    return
  fi
  if command -v pmset >/dev/null 2>&1; then
    pmset -g 2>/dev/null | grep -qi "lidchange.*closed" && return 0
  fi
  return 1
}

# Process one queue entry. Args: <pending_file>
process_one() {
  local pending="$1"
  local trans session bytes ts wm last_bytes delta

  # Parse (key=value lines).
  trans=$(awk -F= '/^transcript=/ { sub(/^transcript=/,""); print; exit }' "$pending")
  session=$(awk -F= '/^session_id=/ { sub(/^session_id=/,""); print; exit }' "$pending")
  bytes=$(awk -F= '/^bytes=/ { sub(/^bytes=/,""); print; exit }' "$pending")
  ts=$(awk -F= '/^ts=/ { sub(/^ts=/,""); print; exit }' "$pending")

  if [ -z "$trans" ] || [ -z "$session" ]; then
    mv "$pending" "${pending%.pending}.failed" 2>/dev/null || true
    echo "[drainer] malformed pending file: $pending" >&2
    return 1
  fi

  if [ ! -f "$trans" ]; then
    # Transcript deleted/moved. Drop the pointer silently.
    mv "$pending" "${pending%.pending}.done" 2>/dev/null || true
    return 0
  fi

  # Watermark dedupe: skip if delta is trivial.
  wm="$wm_dir/${session}.bytes"
  last_bytes=0
  [ -f "$wm" ] && last_bytes=$(cat "$wm" 2>/dev/null || echo 0)
  delta=$(( bytes - last_bytes ))
  if [ "$delta" -lt 1024 ]; then
    # <1KB delta = noise. Mark done without distilling.
    printf '%s\n' "$bytes" > "$wm"
    mv "$pending" "${pending%.pending}.done" 2>/dev/null || true
    return 0
  fi

  # 1. Append claude session entry to data/claude/INBOX.md.
  local ingest_sh="$FRAMEWORK_DIR/code/sources/claude/ingest.sh"
  if [ -f "$ingest_sh" ]; then
    BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
      bash "$ingest_sh" --project "${CLAUDE_PROJECT_DIR:-$PWD}" \
                        --transcript "$trans" \
                        --session "$session" 2>>"$logs_dir/drainer.log" || true
  fi

  # 2. Distill (with hard timeout).
  local distill_sh="$FRAMEWORK_DIR/code/skills/brain-distill/dispatch.sh"
  local rc=0
  if [ -f "$distill_sh" ]; then
    if command -v gtimeout >/dev/null 2>&1; then
      gtimeout "$DISTILL_TIMEOUT" bash -c "BRAIN_DIR='$BRAIN_DIR' NANOBRAIN_DIR='$FRAMEWORK_DIR' bash '$distill_sh' claude" \
        >>"$logs_dir/drainer.log" 2>&1 || rc=$?
    elif command -v timeout >/dev/null 2>&1; then
      timeout "$DISTILL_TIMEOUT" bash -c "BRAIN_DIR='$BRAIN_DIR' NANOBRAIN_DIR='$FRAMEWORK_DIR' bash '$distill_sh' claude" \
        >>"$logs_dir/drainer.log" 2>&1 || rc=$?
    else
      # Bash-only timeout fallback. Run distill in background, watchdog kills it.
      ( BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
          bash "$distill_sh" claude >>"$logs_dir/drainer.log" 2>&1 ) &
      local pid=$!
      local waited=0
      while kill -0 "$pid" 2>/dev/null; do
        if [ "$waited" -ge "$DISTILL_TIMEOUT" ]; then
          # Kill the process group (claude -p may have spawned children).
          kill -TERM "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
          sleep 1
          kill -KILL "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
          rc=124
          break
        fi
        sleep 1
        waited=$((waited + 1))
      done
      if [ "$rc" -eq 0 ]; then
        wait "$pid" 2>/dev/null || rc=$?
      fi
    fi
  fi

  # rc 124 = timeout (GNU), 143 = SIGTERM. Both are timeouts.
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 143 ]; then
    {
      echo "$(date '+%Y-%m-%d %H:%M:%S')"
      echo "session=$session transcript=$trans"
      echo "reason=distill_timeout cap=${DISTILL_TIMEOUT}s"
    } > "${pending%.pending}.failed"
    rm -f "$pending"
    echo "[drainer] FAILED (timeout) session=$session" >&2
    return 1
  fi

  if [ "$rc" -ne 0 ]; then
    {
      echo "$(date '+%Y-%m-%d %H:%M:%S')"
      echo "session=$session transcript=$trans"
      echo "reason=distill_rc=$rc"
    } > "${pending%.pending}.failed"
    rm -f "$pending"
    echo "[drainer] FAILED rc=$rc session=$session" >&2
    return 1
  fi

  # Update watermark + mark done.
  printf '%s\n' "$bytes" > "$wm"
  mv "$pending" "${pending%.pending}.done" 2>/dev/null || true
  return 0
}

# Synthesize queue entries for orphaned transcripts (in ~/.claude/projects/*/sessions/*.jsonl)
# whose mtime exceeds the watermark and have no .pending entry.
scan_orphans() {
  local projects_dir="${CLAUDE_PROJECTS_DIR:-$HOME/.claude/projects}"
  [ -d "$projects_dir" ] || return 0
  find "$projects_dir" -maxdepth 4 -name "*.jsonl" -type f 2>/dev/null \
    | while read -r trans; do
      local session
      session=$(basename "$trans" .jsonl)
      # Skip if we already have a pending entry for this session.
      if ls "$queue/${session}-"*.pending >/dev/null 2>&1; then
        continue
      fi
      local bytes wm last_bytes
      bytes=$(wc -c <"$trans" | tr -d ' ' 2>/dev/null || echo 0)
      wm="$wm_dir/${session}.bytes"
      last_bytes=0
      [ -f "$wm" ] && last_bytes=$(cat "$wm" 2>/dev/null || echo 0)
      if [ "$bytes" -gt "$last_bytes" ] && [ $((bytes - last_bytes)) -ge 1024 ]; then
        local ts
        ts=$(date +%s)
        printf 'transcript=%s\nsession_id=%s\nbytes=%s\nts=%s\nsource=orphan\n' \
          "$trans" "$session" "$bytes" "$ts" \
          > "$queue/${session}-${ts}.pending"
      fi
    done
}

# List pending files oldest-first. Avoids glob/ls/nullglob hazards.
list_pending_lines() {
  local f
  for f in "$queue"/*.pending; do
    [ -f "$f" ] || continue
    local mt
    mt=$(stat -f '%m' "$f" 2>/dev/null || stat -c '%Y' "$f" 2>/dev/null || echo 0)
    printf '%s\t%s\n' "$mt" "$f"
  done | sort -n -k1 | cut -f2-
}

# Gate: any work to do?
pending_files=$(list_pending_lines)
pending_count=0
if [ -n "$pending_files" ]; then
  pending_count=$(printf '%s\n' "$pending_files" | wc -l | tr -d ' ')
fi

# Always scan orphans first (cheap, no LLM).
scan_orphans
pending_files=$(list_pending_lines)
pending_count=0
if [ -n "$pending_files" ]; then
  pending_count=$(printf '%s\n' "$pending_files" | wc -l | tr -d ' ')
fi

if [ "$pending_count" -eq 0 ]; then
  exit 0
fi

# Idle gating.
idle=$(hid_idle_sec)
cap=0
if [ "$SKIP_IDLE_CHECK" = "1" ] || lid_closed; then
  cap="$DRAIN_CAP_AWAY"
elif [ "$idle" -ge "$IDLE_AWAY_SEC" ]; then
  cap="$DRAIN_CAP_AWAY"
elif [ "$idle" -ge "$IDLE_BUSY_SEC" ]; then
  cap="$DRAIN_CAP_BUSY"
else
  # User actively working. Skip silently.
  exit 0
fi

# Drain up to $cap entries, oldest first.
drained=0
while IFS= read -r pending; do
  [ -z "$pending" ] && continue
  [ "$drained" -ge "$cap" ] && break
  [ -f "$pending" ] || continue
  process_one "$pending" || true
  drained=$((drained + 1))
done <<< "$pending_files"

if [ "$drained" -gt 0 ]; then
  log_sh="$FRAMEWORK_DIR/code/skills/brain-log/log.sh"
  [ -x "$log_sh" ] && BRAIN_DIR="$BRAIN_DIR" bash "$log_sh" drainer "drained $drained queue entries (idle=${idle}s)" || true
  echo "[drainer] drained $drained entries (idle=${idle}s, cap=$cap)" >&2
fi

exit 0
