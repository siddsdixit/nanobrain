#!/usr/bin/env bash
# evolve.sh -- propose ONE brain improvement based on last 30 days of signal.

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
NANOBRAIN_DIR="${NANOBRAIN_DIR:-$HOME/Documents/nanobrain-v2}"
STUB="${NANOBRAIN_DISTILL_STUB:-}"

PROPOSED_DIR="$NANOBRAIN_DIR/code/agents/_proposed"
mkdir -p "$PROPOSED_DIR"

TS=$(date '+%Y%m%d-%H%M%S')
OUT="$PROPOSED_DIR/evolve-$TS.md"

# Cutoff: 30 days ago.
if date -v-30d +%Y-%m-%d >/dev/null 2>&1; then
  CUTOFF=$(date -v-30d +%Y-%m-%d)
else
  CUTOFF=$(date -d '30 days ago' +%Y-%m-%d)
fi

# Collect last-30-day entries.
SIGNAL=$(mktemp)
trap 'rm -f "$SIGNAL"' EXIT

for f in "$BRAIN_DIR/brain/learnings.md" "$BRAIN_DIR/brain/decisions.md"; do
  [ -f "$f" ] || continue
  awk -v cutoff="$CUTOFF" '
    /^### / {
      keep = 0
      if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
        d = substr($0, RSTART, RLENGTH)
        if (d >= cutoff) keep = 1
      }
    }
    keep { print }
  ' "$f" >> "$SIGNAL"
done

# If no signal, still write a stub proposal acknowledging that.
if [ ! -s "$SIGNAL" ]; then
  printf '# evolve proposal %s\n\nNo signal in last 30 days. No change proposed.\n' "$TS" > "$OUT"
  echo "[brain-evolve] proposal written: $OUT"
  LOG_SH="$NANOBRAIN_DIR/code/skills/brain-log/log.sh"
  [ -x "$LOG_SH" ] && BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" evolve "no signal, no change proposed" || true
  exit 0
fi

# Drive: stub > claude -p > graceful fallback.
if [ -n "$STUB" ] && [ -x "$STUB" ]; then
  bash "$STUB" < "$SIGNAL" > "$OUT" \
    || { echo "[brain-evolve] stub failed" >&2; exit 1; }
elif command -v claude >/dev/null 2>&1; then
  PROMPT="You are a brain self-improvement agent. Read the recent learnings and decisions below. Propose exactly ONE targeted edit to one brain file (path + before/after snippet). One sentence per decision. No em dashes. Output as markdown."
  {
    printf '# evolve proposal %s\n\n' "$TS"
    claude -p "$PROMPT" < "$SIGNAL" 2>/dev/null
  } > "$OUT" || { echo "[brain-evolve] claude invocation failed" >&2; exit 1; }
else
  printf '# evolve proposal %s\n\nNo claude CLI on PATH and no NANOBRAIN_DISTILL_STUB set. Skipping.\n' "$TS" > "$OUT"
  echo "[brain-evolve] no driver available, wrote skip note: $OUT"
  LOG_SH="$NANOBRAIN_DIR/code/skills/brain-log/log.sh"
  [ -x "$LOG_SH" ] && BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" evolve "skipped (no driver)" || true
  exit 0
fi

echo "[brain-evolve] proposal written: $OUT"

LOG_SH="$NANOBRAIN_DIR/code/skills/brain-log/log.sh"
if [ -x "$LOG_SH" ]; then
  BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" evolve "proposal $TS" || true
fi
