#!/usr/bin/env bash
# Tests for code/skills/brain/query.sh (status, paths, links sub-commands).
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUERY="$ROOT/code/skills/brain/query.sh"

_pp() { :; }   # no-op; redefined inline below

echo "test_brain_query.sh"
TPASS=0; TFAIL=0
pass() { echo "  PASS: $1"; TPASS=$((TPASS+1)); }
fail() { echo "  FAIL: $1"; TFAIL=$((TFAIL+1)); exit 1; }

# 1. paths sub-command does not require an existing brain
out=$(BRAIN_DIR=/nonexistent bash "$QUERY" paths 2>&1)
echo "$out" | grep -q "brain dir:" || fail "1: paths missing brain dir line"
echo "$out" | grep -q "corpus:"    || fail "1: paths missing corpus line"
echo "$out" | grep -q "firehose:"  || fail "1: paths missing firehose line"
pass "1: paths sub-command prints canonical paths"

# 2. status on missing brain exits non-zero with clear message
out=$(BRAIN_DIR=/nonexistent-x bash "$QUERY" status 2>&1) && fail "2: status should fail on missing brain"
echo "$out" | grep -q "no brain" || fail "2: status should report missing brain"
pass "2: status fails cleanly on missing brain"

# 3. status on a real brain prints corpus sizes
D=$(mktemp -d)
mkdir -p "$D/brain"
( cd "$D" && git init -q && git config user.email "t@l" && git config user.name "t" && \
  printf 'self test\n' > brain/self.md && \
  git add . && git commit -q -m "init" )
out=$(BRAIN_DIR="$D" bash "$QUERY" status 2>&1)
echo "$out" | grep -q "last commit"  || fail "3: status missing last-commit line"
echo "$out" | grep -q "corpus sizes" || fail "3: status missing corpus-sizes header"
echo "$out" | grep -q "self.md"      || fail "3: status missing self.md in size list"
pass "3: status prints last commit + corpus sizes"
rm -rf "$D"

# 4. links: requires entity name
bash "$QUERY" links >/dev/null 2>&1 && fail "4: links should require entity name"
pass "4: links rejects missing entity"

# 5. links: greps backlinks correctly
D=$(mktemp -d)
mkdir -p "$D/brain"
printf '## people\n[[Jen Wang]] Tuesday coffee\n' > "$D/brain/people.md"
printf '## projects\nMet [[Jen Wang]] re funding\n' > "$D/brain/projects.md"
out=$(BRAIN_DIR="$D" bash "$QUERY" links "Jen Wang" 2>&1)
echo "$out" | grep -q "people.md"   || fail "5: links missed people.md"
echo "$out" | grep -q "projects.md" || fail "5: links missed projects.md"
pass "5: links surfaces all [[backlinks]]"
rm -rf "$D"

# 6. unknown sub-command falls through to help
out=$(bash "$QUERY" boguscmd 2>&1)
echo "$out" | grep -q "usage:" || fail "6: unknown subcmd should print usage"
pass "6: unknown subcmd prints help"

printf 'pass=%d fail=%d\n' "$TPASS" "$TFAIL"
