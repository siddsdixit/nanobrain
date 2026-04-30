#!/usr/bin/env bash
# Tests for brain-redact (skill, distinct from lib redact).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REDACT="$ROOT/code/skills/brain-redact/redact.sh"

echo "test_brain_redact.sh"
TPASS=0; TFAIL=0
pass() { echo "  PASS: $1"; TPASS=$((TPASS+1)); }
fail() { echo "  FAIL: $1"; TFAIL=$((TFAIL+1)); exit 1; }

# 1. Scan finds known patterns.
D=$(mktemp -d)
mkdir -p "$D/brain"
printf 'leak: sk-abcdefghijklmnopqrstuvwxyz1234567890\n' > "$D/brain/learnings.md"
echo "clean" > "$D/brain/self.md"
out=$(BRAIN_DIR="$D" bash "$REDACT" --scan 2>&1)
rc=$?
[ "$rc" = "1" ] || fail "1: scan should exit 1 on hit, got $rc"
echo "$out" | grep -q "sk-abcdefghij" || fail "1: hit not surfaced"
pass "1: scan finds known pattern"

# 1b. Scan on clean tree exits 0.
rm "$D/brain/learnings.md"
BRAIN_DIR="$D" bash "$REDACT" --scan >/dev/null 2>&1 || fail "1b: clean scan should exit 0"
pass "1b: scan on clean tree exits 0"

# 2. Scrub on temp git repo removes the offending blob (with --force-push to actually run).
G=$(mktemp -d)
( cd "$G" && git init -q && git config user.email "t@l" && git config user.name "t" )
echo 'sk-abcdefghijklmnopqrstuvwxyz1234567890' > "$G/secrets.md"
( cd "$G" && git add secrets.md && git commit -q -m "leak" )
# Replace the offending file with safe content before scrub (clean tree required).
echo 'clean' > "$G/secrets.md"
( cd "$G" && git add secrets.md && git commit -q -m "patch" )
# Now scrub history.
BRAIN_DIR="$G" bash "$REDACT" --scrub 'sk-[A-Za-z0-9]{20,}' --force-push >/dev/null 2>&1 \
  || fail "2: scrub failed"
# Verify history no longer contains the secret.
if ( cd "$G" && git log --all -p 2>/dev/null | grep -q 'sk-abcdefghijklmnopqr' ); then
  fail "2: secret still present in history"
fi
pass "2: scrub --force-push removes blob from history"

# 3. Scrub WITHOUT --force-push is dry-run.
G2=$(mktemp -d)
( cd "$G2" && git init -q && git config user.email "t@l" && git config user.name "t" )
echo 'sk-abcdefghijklmnopqrstuvwxyz1234567890' > "$G2/secrets.md"
( cd "$G2" && git add secrets.md && git commit -q -m "leak" )
out=$(BRAIN_DIR="$G2" bash "$REDACT" --scrub 'sk-[A-Za-z0-9]{20,}' 2>&1)
echo "$out" | grep -q "DRY RUN" || fail "3: should print DRY RUN without --force-push"
# History should be untouched.
( cd "$G2" && git log --all -p 2>/dev/null | grep -q 'sk-abcdefghijklmnopqr' ) \
  || fail "3: dry-run accidentally rewrote history"
pass "3: scrub without --force-push is dry-run"

rm -rf "$D" "$G" "$G2"
printf 'pass=%d fail=%d\n' "$TPASS" "$TFAIL"
