#!/usr/bin/env bash
# Tests for brain-hash.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HASH="$ROOT/code/skills/brain-hash/hash.sh"

echo "test_brain_hash.sh"
TPASS=0; TFAIL=0
pass() { echo "  PASS: $1"; TPASS=$((TPASS+1)); }
fail() { echo "  FAIL: $1"; TFAIL=$((TFAIL+1)); exit 1; }

D=$(mktemp -d)
mkdir -p "$D/brain"
echo "self" > "$D/brain/self.md"
echo "decisions" > "$D/brain/decisions.md"
echo "noise" > "$D/brain/raw.md"  # excluded

# 1. Build then verify clean.
BRAIN_DIR="$D" bash "$HASH" build >/dev/null 2>&1 || fail "1: build failed"
[ -f "$D/BRAIN_HASH.txt" ] || fail "1: hash file missing"
BRAIN_DIR="$D" bash "$HASH" verify >/dev/null 2>&1 || fail "1: verify clean failed"
pass "1: build then verify clean"

# 2. Modify a file then verify reports drift.
echo "modified" >> "$D/brain/self.md"
BRAIN_DIR="$D" bash "$HASH" verify >/dev/null 2>&1 \
  && fail "2: verify should fail after drift"
pass "2: verify reports drift after edit"

# 3. Touching raw.md should NOT cause drift (excluded).
BRAIN_DIR="$D" bash "$HASH" build >/dev/null 2>&1 || fail "3: rebuild failed"
echo "more noise" >> "$D/brain/raw.md"
BRAIN_DIR="$D" bash "$HASH" verify >/dev/null 2>&1 || fail "3: raw.md edit caused drift"
pass "3: raw.md is excluded from hash"

# 4. Verify with no baseline fails clean.
D2=$(mktemp -d)
mkdir -p "$D2/brain"
echo "x" > "$D2/brain/self.md"
out=$(BRAIN_DIR="$D2" bash "$HASH" verify 2>&1)
rc=$?
[ "$rc" = "1" ] || fail "4: expected exit 1, got $rc"
echo "$out" | grep -q "no baseline" || fail "4: missing 'no baseline' message"
pass "4: verify with no baseline fails cleanly"

rm -rf "$D" "$D2"
printf 'pass=%d fail=%d\n' "$TPASS" "$TFAIL"
