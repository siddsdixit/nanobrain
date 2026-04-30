#!/usr/bin/env bash
# Tests for brain-compact.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMPACT="$ROOT/code/skills/brain-compact/compact.sh"

echo "test_brain_compact.sh"
TPASS=0; TFAIL=0
pass() { echo "  PASS: $1"; TPASS=$((TPASS+1)); }
fail() { echo "  FAIL: $1"; TFAIL=$((TFAIL+1)); exit 1; }

# 1. Dedupes file with 2 identical headers (and bodies).
D=$(mktemp -d)
mkdir -p "$D/brain"
cat > "$D/brain/decisions.md" <<'EOF'
# Decisions

### 2026-04-01 Pick A over B
Reason 1.

### 2026-04-01 Pick A over B
Reason 1.

### 2026-04-15 New choice
Reason 2.
EOF
echo "raw firehose" > "$D/brain/raw.md"
echo "people" > "$D/brain/people.md"

NANOBRAIN_DIR="$ROOT" BRAIN_DIR="$D" NANOBRAIN_COMPACT_NO_COMMIT=1 bash "$COMPACT" >/dev/null 2>&1 \
  || fail "1: compact failed"
n=$(grep -c "^### 2026-04-01 Pick A over B" "$D/brain/decisions.md")
[ "$n" = "1" ] || fail "1: expected 1 occurrence, got $n"
grep -q "^### 2026-04-15 New choice" "$D/brain/decisions.md" || fail "1: unique entry lost"
pass "1: dedupes duplicate dated headers"

# 2. Archives entries older than 365 days.
if date -v-400d +%Y-%m-%d >/dev/null 2>&1; then
  OLD=$(date -v-400d +%Y-%m-%d)
else
  OLD=$(date -d '400 days ago' +%Y-%m-%d)
fi
cat > "$D/brain/learnings.md" <<EOF
### $OLD Old learning
Stale.

### 2026-04-15 Recent learning
Fresh.
EOF
NANOBRAIN_DIR="$ROOT" BRAIN_DIR="$D" NANOBRAIN_COMPACT_NO_COMMIT=1 bash "$COMPACT" >/dev/null 2>&1 \
  || fail "2: compact failed"
grep -q "Old learning" "$D/brain/learnings.md" && fail "2: old learning should have been archived"
grep -q "Recent learning" "$D/brain/learnings.md" || fail "2: recent learning lost"
ls "$D/brain/archive/learnings-"*.md >/dev/null 2>&1 || fail "2: no archive file written"
grep -q "Old learning" "$D/brain/archive/learnings-"*.md || fail "2: old not in archive"
pass "2: archives entries older than 365 days"

# 3. Leaves raw.md and people.md untouched.
RAW_BEFORE=$(cat "$D/brain/raw.md")
PEOPLE_BEFORE=$(cat "$D/brain/people.md")
NANOBRAIN_DIR="$ROOT" BRAIN_DIR="$D" NANOBRAIN_COMPACT_NO_COMMIT=1 bash "$COMPACT" >/dev/null 2>&1
[ "$RAW_BEFORE" = "$(cat "$D/brain/raw.md")" ] || fail "3: raw.md modified"
[ "$PEOPLE_BEFORE" = "$(cat "$D/brain/people.md")" ] || fail "3: people.md modified"
pass "3: raw.md and people.md untouched"

# 4. Idempotent.
A=$(cat "$D/brain/decisions.md" "$D/brain/learnings.md")
NANOBRAIN_DIR="$ROOT" BRAIN_DIR="$D" NANOBRAIN_COMPACT_NO_COMMIT=1 bash "$COMPACT" >/dev/null 2>&1
B=$(cat "$D/brain/decisions.md" "$D/brain/learnings.md")
[ "$A" = "$B" ] || fail "4: second run changed content"
pass "4: idempotent"

rm -rf "$D"
printf 'pass=%d fail=%d\n' "$TPASS" "$TFAIL"
