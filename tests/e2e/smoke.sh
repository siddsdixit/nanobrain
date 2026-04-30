#!/usr/bin/env bash
# smoke.sh -- end-to-end pipeline using stubs.

set -eu
. "$(dirname "$0")/../_lib.sh"

echo "== smoke =="
D=$(make_tmp_brain)

# 1. Ingest gmail with a stub.
recent=$(iso_now_minus_days 1)
gstub=$(mktemp)
cat > "$gstub" <<EOF
[
  {"id":"smk-1","from":"vc@itn.com","to":"me@itn.com","date":"$recent",
   "subject":"Series B intro","body":"meet thursday 2pm"},
  {"id":"smk-noise","from":"noreply@bank.com","to":"me@gmail.com","date":"$recent",
   "subject":"statement","body":"bla"}
]
EOF
NANOBRAIN_GMAIL_STUB="$gstub" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/sources/gmail/ingest.sh" >/dev/null

assert_file_contains "$D/data/gmail/INBOX.md" "source_id: smk-1" "stage1: INBOX has signal"
if grep -Fq "smk-noise" "$D/data/gmail/INBOX.md"; then _fail "smoke: noreply leaked"; else _pass "stage1: noise filtered"; fi

# 2. Distill with a stub.
dstub=$(mktemp)
cat > "$dstub" <<'EOF'
target_path: brain/decisions.md
{source_id: smk-1, context: work}
- agreed: meet vc@itn.com Thursday 2pm
>>>
target_path: brain/people.md
{source_id: smk-1, context: work}
- vc@itn.com -- introduced for Series B
EOF
NANOBRAIN_DISTILL_STUB="$dstub" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/skills/brain-distill/dispatch.sh" gmail >/dev/null 2>&1

assert_file_contains "$D/brain/decisions.md" "Thursday 2pm" "stage2: brain has decision"
assert_file_contains "$D/brain/raw.md" "Thursday 2pm" "stage3: raw mirror"
assert_file_contains "$D/brain/decisions.md" "{source_id: smk-1, context: work}" "stage2: provenance"

# 3. Doctor still passes.
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/skills/brain-doctor/check.sh" 2>&1)
assert_contains "$out" "OK" "stage4: doctor OK"

# 4. MCP read with context filter.
agent=$(mktemp)
cat > "$agent" <<'EOF'
---
slug: smoke-agent
reads:
  files: [brain/decisions.md]
  filter:
    context_in: [work]
---
EOF
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/mcp-server/read_brain_file.sh" \
  --agent "$agent" --file brain/decisions.md)
assert_contains "$out" "Thursday 2pm" "stage5: mcp read returns work entry"

# 5. MCP server stdio test.
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' \
  | BRAIN_DIR="$D" bash "$V2_DIR/code/mcp-server/server.sh" \
  > /tmp/mcp-out.$$ 2>&1
assert_file_contains "/tmp/mcp-out.$$" "read_brain_file" "stage6: mcp tools/list"
rm -f /tmp/mcp-out.$$

rm -f "$gstub" "$dstub" "$agent"; rm -rf "$D"; report
