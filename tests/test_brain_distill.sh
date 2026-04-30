#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_brain_distill =="
D=$(make_tmp_brain)

# Seed an INBOX (so dispatch finds something).
mkdir -p "$D/data/gmail"
cat > "$D/data/gmail/INBOX.md" <<'EOF'
-- 2026-04-28 10:00 --
source: gmail
sender: vc@itn.com
subject: investor intro
source_id: t-99
{context: work}

let's chat next tuesday
EOF

# Stub distill output: two valid blocks, one disallowed.
stub=$(mktemp)
cat > "$stub" <<'EOF'
target_path: brain/decisions.md
{source_id: t-99, context: work}
- agreed to a tuesday call with vc@itn.com
>>>
target_path: brain/people.md
{source_id: t-99, context: work}
- vc@itn.com (firm tbd)
>>>
target_path: brain/secrets.md
{source_id: t-99, context: work}
- this should be rejected
EOF

NANOBRAIN_DISTILL_STUB="$stub" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/skills/brain-distill/dispatch.sh" gmail >/dev/null 2>&1

assert_file_contains "$D/brain/decisions.md" "tuesday call" "decision routed"
assert_file_contains "$D/brain/people.md" "vc@itn.com" "person routed"
assert_file_contains "$D/brain/decisions.md" "{source_id: t-99, context: work}" "provenance kept"
assert_file_contains "$D/brain/raw.md" "tuesday call" "raw mirror written"
assert_file_contains "$D/brain/raw.md" "vc@itn.com" "raw mirror has people"

if [ -f "$D/brain/secrets.md" ]; then _fail "disallowed target written"; else _pass "disallowed target rejected"; fi

# Per-entity routing: stub that targets brain/people.md AND brain/people/jen.md.
stub2=$(mktemp)
cat > "$stub2" <<'EOF'
target_path: brain/people.md
{source_id: t-99, context: personal}
- jen wang -- friend, gmail
>>>
target_path: brain/people/jen.md
{source_id: t-99, context: personal}
- 2026-04-28 -- coffee tuesday confirmed
>>>
target_path: brain/projects/ghx-cto.md
{source_id: t-99, context: work}
- 2026-04-28 -- Steve Jackson call confirmed
>>>
target_path: brain/people/../../etc/passwd
{source_id: t-99, context: work}
- traversal attempt
EOF

NANOBRAIN_DISTILL_STUB="$stub2" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/skills/brain-distill/dispatch.sh" gmail >/dev/null 2>&1

assert_file_contains "$D/brain/people.md" "jen wang" "category-level people.md updated"
[ -f "$D/brain/people/jen.md" ] && _pass "per-entity people page created" || _fail "per-entity people page missing"
assert_file_contains "$D/brain/people/jen.md" "coffee tuesday" "per-entity people page populated"
[ -f "$D/brain/projects/ghx-cto.md" ] && _pass "per-entity projects page created" || _fail "per-entity projects page missing"
assert_file_contains "$D/brain/projects/ghx-cto.md" "Steve Jackson" "projects page populated"
[ ! -e "$D/brain/people/../../etc/passwd" ] && _pass "traversal target rejected" || _fail "traversal target accepted"

rm -f "$stub" "$stub2"; rm -rf "$D"; report
