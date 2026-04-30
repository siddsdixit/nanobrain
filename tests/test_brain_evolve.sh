#!/usr/bin/env bash
# Tests for brain-evolve.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EVOLVE="$ROOT/code/skills/brain-evolve/evolve.sh"

echo "test_brain_evolve.sh"
TPASS=0; TFAIL=0
pass() { echo "  PASS: $1"; TPASS=$((TPASS+1)); }
fail() { echo "  FAIL: $1"; TFAIL=$((TFAIL+1)); exit 1; }

# Sandbox.
D=$(mktemp -d)
SAND_NB=$(mktemp -d)
mkdir -p "$SAND_NB/code/agents" "$D/brain"
TODAY=$(date '+%Y-%m-%d')
cat > "$D/brain/learnings.md" <<EOF
### $TODAY Recent learning
A pattern that should evolve into a rule.
EOF
cat > "$D/brain/decisions.md" <<EOF
### $TODAY Recent decision
Decided to do X.
EOF

# 1. With stub set, writes proposal file under _proposed/.
STUB=$(mktemp)
cat > "$STUB" <<'EOS'
#!/usr/bin/env bash
echo "# Proposed edit"
echo "Edit brain/self.md to add: 'Pattern Z: ...'"
EOS
chmod +x "$STUB"

BRAIN_DIR="$D" NANOBRAIN_DIR="$SAND_NB" NANOBRAIN_DISTILL_STUB="$STUB" bash "$EVOLVE" >/dev/null 2>&1 \
  || fail "1: evolve with stub failed"
ls "$SAND_NB/code/agents/_proposed/evolve-"*.md >/dev/null 2>&1 || fail "1: no proposal file"
prop=$(ls -t "$SAND_NB/code/agents/_proposed/evolve-"*.md | head -1)
grep -q "Proposed edit" "$prop" || fail "1: stub output not captured"
pass "1: stub-driven proposal lands in _proposed/"

# 2. Proposal lands in _proposed/, not in code/agents/ direct.
[ ! -f "$SAND_NB/code/agents/evolve-"*.md ] 2>/dev/null \
  || fail "2: proposal leaked to code/agents/ direct"
case "$prop" in
  */code/agents/_proposed/*) : ;;
  *) fail "2: proposal not in _proposed/" ;;
esac
pass "2: proposal isolated to _proposed/"

# 3. No claude CLI and no stub: graceful skip note (still exits 0, writes a stub note).
SAND_NB2=$(mktemp -d)
mkdir -p "$SAND_NB2/code/agents"
# Neutralize PATH so 'claude' is not found.
out=$(BRAIN_DIR="$D" NANOBRAIN_DIR="$SAND_NB2" PATH="/usr/bin:/bin" bash "$EVOLVE" 2>&1)
rc=$?
[ "$rc" = "0" ] || fail "3: expected exit 0, got $rc"
ls "$SAND_NB2/code/agents/_proposed/evolve-"*.md >/dev/null 2>&1 || fail "3: no skip note written"
prop2=$(ls -t "$SAND_NB2/code/agents/_proposed/evolve-"*.md | head -1)
grep -q -i "no claude\|skip\|no driver" "$prop2" || fail "3: skip note missing"
pass "3: graceful skip when no claude and no stub"

rm -rf "$D" "$SAND_NB" "$SAND_NB2" "$STUB"
printf 'pass=%d fail=%d\n' "$TPASS" "$TFAIL"
