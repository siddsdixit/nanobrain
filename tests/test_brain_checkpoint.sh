#!/usr/bin/env bash
# Tests for brain-checkpoint.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$ROOT/code/skills/brain-checkpoint/checkpoint.sh"

echo "test_brain_checkpoint.sh"
TPASS=0; TFAIL=0
pass() { echo "  PASS: $1"; TPASS=$((TPASS+1)); }
fail() { echo "  FAIL: $1"; TFAIL=$((TFAIL+1)); exit 1; }

# 1. Stub captures FORCE_CAPTURE=1 and stdin payload.
STUB=$(mktemp)
LOG=$(mktemp)
cat > "$STUB" <<EOS
#!/usr/bin/env bash
{
  echo "FORCE_CAPTURE=\${FORCE_CAPTURE:-unset}"
  echo "BRAIN_DIR=\${BRAIN_DIR:-unset}"
  cat
} > "$LOG"
exit 0
EOS
chmod +x "$STUB"

D=$(mktemp -d)
out=$(BRAIN_DIR="$D" NANOBRAIN_CAPTURE_STUB="$STUB" bash "$CHECK" 2>&1)
rc=$?
[ "$rc" = "0" ] || fail "1: checkpoint exit $rc"
grep -q "FORCE_CAPTURE=1" "$LOG" || fail "1: FORCE_CAPTURE=1 not passed"
grep -q "BRAIN_DIR=$D" "$LOG" || fail "1: BRAIN_DIR not propagated"
grep -q "manual_checkpoint" "$LOG" || fail "1: synthetic payload missing"
pass "1: invokes capture with FORCE_CAPTURE=1 and synthetic payload"

# 2. Prints status line.
echo "$out" | grep -q "capture invoked" || fail "2: status line missing"
pass "2: prints status line"

# 3. No-session run still succeeds.
HOME_BACKUP=$HOME
TMPHOME=$(mktemp -d)
HOME="$TMPHOME" BRAIN_DIR="$D" NANOBRAIN_CAPTURE_STUB="$STUB" bash "$CHECK" >/dev/null 2>&1 \
  || fail "3: failed when no session present"
HOME="$HOME_BACKUP"
pass "3: no-session run succeeds"

rm -rf "$D" "$TMPHOME" "$STUB" "$LOG"
printf 'pass=%d fail=%d\n' "$TPASS" "$TFAIL"
