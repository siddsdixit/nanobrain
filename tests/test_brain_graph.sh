#!/usr/bin/env bash
# Tests for brain-graph.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GRAPH="$ROOT/code/skills/brain-graph/graph.sh"

echo "test_brain_graph.sh"
TPASS=0; TFAIL=0
pass() { echo "  PASS: $1"; TPASS=$((TPASS+1)); }
fail() { echo "  FAIL: $1"; TFAIL=$((TFAIL+1)); exit 1; }

# 1. Three entities cross-referenced.
D=$(mktemp -d)
mkdir -p "$D/brain"
cat > "$D/brain/decisions.md" <<'EOF'
### 2026-04-01 Picked [[ProjectA]] over [[ProjectB]]
Notes about [[Sid]].
EOF
cat > "$D/brain/projects.md" <<'EOF'
### ProjectA notes
[[ProjectA]] is the focus. [[Sid]] owns it.
EOF
echo "noise [[ProjectA]] in raw" > "$D/brain/raw.md"  # should NOT be scanned

BRAIN_DIR="$D" bash "$GRAPH" >/dev/null 2>&1 || fail "1: graph build failed"
[ -f "$D/brain/_graph.md" ] || fail "1: _graph.md missing"
grep -q "\[\[ProjectA\]\]" "$D/brain/_graph.md" || fail "1: ProjectA section missing"
grep -q "\[\[ProjectB\]\]" "$D/brain/_graph.md" || fail "1: ProjectB section missing"
grep -q "\[\[Sid\]\]" "$D/brain/_graph.md" || fail "1: Sid section missing"
# Backlinks list at least one file:line each.
grep -q "decisions.md:" "$D/brain/_graph.md" || fail "1: decisions backlink missing"
grep -q "projects.md:" "$D/brain/_graph.md" || fail "1: projects backlink missing"
# raw.md must not appear as backlink source.
grep "raw.md:" "$D/brain/_graph.md" >/dev/null && fail "1: raw.md leaked into graph"
pass "1: 3 entities + backlinks; raw.md excluded"

# 2. Empty brain -> graph stub.
D2=$(mktemp -d)
mkdir -p "$D2/brain"
echo "no entities here" > "$D2/brain/self.md"
BRAIN_DIR="$D2" bash "$GRAPH" >/dev/null 2>&1 || fail "2: empty graph build failed"
grep -q "no \[\[ \]\] references" "$D2/brain/_graph.md" || fail "2: stub message missing"
pass "2: empty brain produces stub"

# 3. Idempotent: regenerate yields same content (modulo timestamp).
BRAIN_DIR="$D" bash "$GRAPH" >/dev/null 2>&1
A=$(grep -v "^_Last regenerated" "$D/brain/_graph.md")
sleep 1
BRAIN_DIR="$D" bash "$GRAPH" >/dev/null 2>&1
B=$(grep -v "^_Last regenerated" "$D/brain/_graph.md")
[ "$A" = "$B" ] || fail "3: regeneration not idempotent"
pass "3: regeneration is idempotent (content unchanged)"

rm -rf "$D" "$D2"
printf 'pass=%d fail=%d\n' "$TPASS" "$TFAIL"
