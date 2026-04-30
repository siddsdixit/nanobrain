#!/usr/bin/env bash
# test_brain_index.sh -- catalog page covering category files, per-entity pages, sources.

. "$(cd "$(dirname "$0")" && pwd)/_lib.sh"

BUILD="$V2_DIR/code/skills/brain-index/build.sh"

[ -x "$BUILD" ] && _pass "build.sh exists and is executable" || _fail "build.sh missing or not executable"

# 1. No brain dir -> exit 0 silently, no index.md created.
TMPNO=$(mktemp -d)
rc=0
BRAIN_DIR="$TMPNO" bash "$BUILD" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "0" "no brain dir -> exit 0"
[ ! -f "$TMPNO/brain/index.md" ] && _pass "no index.md created when no brain dir" || _fail "spurious index.md"
rm -rf "$TMPNO"

# 2. Bare brain -> only category files that exist appear.
B=$(make_tmp_brain)
printf '# Self\n\nIdentity stuff.\n' > "$B/brain/self.md"
printf '# Decisions\n\n### 2026-04-28 -- save: foo\nbody\n' > "$B/brain/decisions.md"
BRAIN_DIR="$B" bash "$BUILD" >/dev/null
[ -f "$B/brain/index.md" ] && _pass "index.md created" || _fail "index.md not created"

assert_file_contains "$B/brain/index.md" "# Index" "title present"
assert_file_contains "$B/brain/index.md" "## Categorized files" "categorized section"
assert_file_contains "$B/brain/index.md" "self.md" "self.md row present"
assert_file_contains "$B/brain/index.md" "decisions.md" "decisions.md row present"
assert_file_contains "$B/brain/index.md" "Identity, voice, principles" "self summary correct"
assert_file_contains "$B/brain/index.md" "Material decisions with rationale" "decisions summary correct"

# Files that don't exist should NOT show up.
case "$(cat "$B/brain/index.md")" in
  *learnings.md*) _fail "learnings.md row should not appear (file absent)" ;;
  *)              _pass "absent files omitted" ;;
esac

# 3. With per-entity pages.
B2=$(make_tmp_brain)
printf '# Self\n' > "$B2/brain/self.md"
mkdir -p "$B2/brain/people" "$B2/brain/projects"
printf '# Jen Wang\n\nfriend, gmail. Tuesday coffee touchpoint.\n' > "$B2/brain/people/jen.md"
printf '# GHX CTO\n\nPIP-001, GHX CTO interview pipeline.\n' > "$B2/brain/projects/ghx-cto.md"
BRAIN_DIR="$B2" bash "$BUILD" >/dev/null
assert_file_contains "$B2/brain/index.md" "## Per-entity pages" "per-entity section present"
assert_file_contains "$B2/brain/index.md" "### People" "people subsection"
assert_file_contains "$B2/brain/index.md" "### Projects" "projects subsection"
assert_file_contains "$B2/brain/index.md" "people/jen.md" "jen page linked"
assert_file_contains "$B2/brain/index.md" "projects/ghx-cto.md" "ghx page linked"
assert_file_contains "$B2/brain/index.md" "friend, gmail" "jen summary picked up"
assert_file_contains "$B2/brain/index.md" "PIP-001" "ghx summary picked up"

# 4. Sources table.
B3=$(make_tmp_brain)
printf '# Self\n' > "$B3/brain/self.md"
mkdir -p "$B3/data/gmail" "$B3/data/gcal"
printf '# gmail INBOX\n\n### t-friend-001\nbody\n\n### t-friend-002\nbody\n' > "$B3/data/gmail/INBOX.md"
printf '# gcal INBOX\n\n### evt-001\nbody\n' > "$B3/data/gcal/INBOX.md"
BRAIN_DIR="$B3" bash "$BUILD" >/dev/null
assert_file_contains "$B3/brain/index.md" "## Sources" "sources section"
assert_file_contains "$B3/brain/index.md" "| gmail |" "gmail source row"
assert_file_contains "$B3/brain/index.md" "| gcal |" "gcal source row"
gm=$(grep "| gmail |" "$B3/brain/index.md" | head -1)
case "$gm" in
  *"| 2 |"*) _pass "gmail entry count is 2" ;;
  *)         _fail "gmail entry count wrong: $gm" ;;
esac

# 5. Idempotent: two runs produce identical files.
BRAIN_DIR="$B3" bash "$BUILD" >/dev/null
h1=$(shasum "$B3/brain/index.md" | awk '{print $1}')
sleep 1
BRAIN_DIR="$B3" bash "$BUILD" >/dev/null
h2=$(shasum "$B3/brain/index.md" | awk '{print $1}')
# Timestamp differs, so just compare structural lines.
sl1=$(grep -v "Last updated" "$B3/brain/index.md" | shasum | awk '{print $1}')
BRAIN_DIR="$B3" bash "$BUILD" >/dev/null
sl2=$(grep -v "Last updated" "$B3/brain/index.md" | shasum | awk '{print $1}')
assert_eq "$sl1" "$sl2" "idempotent (modulo timestamp)"

# 6. Index is logged.
[ -f "$B3/brain/log.md" ] && _pass "brain-log invoked" || _fail "brain-log not invoked"
grep -q "index | rebuilt" "$B3/brain/log.md" && _pass "log entry has index op" || _fail "log entry missing index op"

report
