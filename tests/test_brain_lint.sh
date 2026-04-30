#!/usr/bin/env bash
# test_brain_lint.sh -- quality report covering each issue category.

. "$(cd "$(dirname "$0")" && pwd)/_lib.sh"

LINT="$V2_DIR/code/skills/brain-lint/lint.sh"

[ -x "$LINT" ] && _pass "lint.sh exists and is executable" || _fail "lint.sh missing or not executable"

# 1. No brain dir -> exit 0 silently.
TMPNO=$(mktemp -d)
rc=0
BRAIN_DIR="$TMPNO" bash "$LINT" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "0" "no brain dir -> exit 0"
rm -rf "$TMPNO"

# 2. Clean brain -> 0 issues, exit 0 even with --strict.
B=$(make_tmp_brain)
mkdir -p "$B/brain/people"
cat > "$B/brain/self.md" <<'EOF'
# Self
{context: personal}

Identity stuff. See [[jen]].
EOF
cat > "$B/brain/people/jen.md" <<'EOF'
# Jen Wang

friend.

## Mentions
- 2026-04-28 -- coffee

## See also
[[self]]
EOF
out=$(BRAIN_DIR="$B" bash "$LINT" 2>&1)
assert_contains "$out" "total issues: 0" "clean brain reports 0 issues"

rc=0
BRAIN_DIR="$B" bash "$LINT" --strict >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "0" "clean brain --strict exits 0"

# 3. Seeded brain with each issue type.
BAD=$(make_tmp_brain)
mkdir -p "$BAD/brain/people" "$BAD/brain/projects"

# Orphan: no other file links to "alice".
cat > "$BAD/brain/people/alice.md" <<'EOF'
# Alice Anders

note.

## Mentions

## See also
EOF

# Linked person (used as ref target).
cat > "$BAD/brain/people/bob.md" <<'EOF'
# Bob

note.

## Mentions

## See also
EOF

# decisions.md with broken ref, TODO, duplicate header, and an entry missing context.
cat > "$BAD/brain/decisions.md" <<'EOF'
# Decisions

### 2026-04-28 10:00 -- save: thing
{context: work}
TODO finalize wording. See [[bob]] and [[ghost-entity]].

### 2026-04-28 10:00 -- save: thing
{context: work}
duplicate header above.

### 2026-04-28 11:00 -- save: orphan-entry
no context tag here.
EOF

out=$(BRAIN_DIR="$BAD" bash "$LINT" 2>&1)

assert_contains "$out" "people/alice.md" "alice flagged as orphan"
case "$out" in
  *bob.md*) _fail "bob (linked) should not be orphan" ;;
  *)        _pass "bob (linked) not flagged" ;;
esac
assert_contains "$out" "ghost-entity" "broken ref reported"
case "$out" in
  *"[[bob]]"*"Broken refs"*) _fail "valid ref [[bob]] should not be in broken section" ;;
  *)                          _pass "valid ref [[bob]] not in broken" ;;
esac
assert_contains "$out" "TODO finalize" "TODO line reported"
assert_contains "$out" "### 2026-04-28 10:00 -- save: thing" "duplicate header reported"
assert_contains "$out" "save: orphan-entry" "missing-context entry reported"

# Lint exit 0 normally, exit 1 with --strict when issues exist.
rc=0
BRAIN_DIR="$BAD" bash "$LINT" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "0" "issues -> exit 0 without --strict"

rc=0
BRAIN_DIR="$BAD" bash "$LINT" --strict >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "1" "issues -> --strict exits 1"

# 4. Lint logged.
[ -f "$BAD/brain/log.md" ] && _pass "brain-log invoked by lint" || _fail "brain-log not invoked"
grep -q "lint |" "$BAD/brain/log.md" && _pass "log entry has lint op" || _fail "log entry missing lint op"

rm -rf "$B" "$BAD"
report
