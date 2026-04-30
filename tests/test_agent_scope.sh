#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_agent_scope =="
D=$(make_tmp_brain)

# Two decision entries, one work, one personal.
cat > "$D/brain/decisions.md" <<'EOF'
## entry one
{source_id: t-1, context: work}

- ship the build

## entry two
{source_id: t-2, context: personal}

- call mom on sunday
EOF

# Empty firehose to test refusal.
: > "$D/brain/raw.md"

agent=$(mktemp)
cat > "$agent" <<'EOF'
---
slug: work-only
reads:
  files:
    - brain/decisions.md
  filter:
    context_in:
      - work
---
work-only agent.
EOF

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/mcp-server/read_brain_file.sh" \
  --agent "$agent" --file "brain/decisions.md")
assert_contains "$out" "ship the build" "work entry visible"
case "$out" in
  *"call mom"*) _fail "personal entry leaked through filter" ;;
  *) _pass "personal entry filtered out" ;;
esac

# Firehose refused.
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/mcp-server/read_brain_file.sh" \
  --agent "$agent" --file "brain/raw.md" 2>&1 || true)
assert_contains "$out" "refused" "raw.md refused"

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/mcp-server/read_brain_file.sh" \
  --agent "$agent" --file "data/gmail/INBOX.md" 2>&1 || true)
assert_contains "$out" "refused" "INBOX.md refused"

# Also refuse files not in agent's reads.files whitelist.
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/mcp-server/read_brain_file.sh" \
  --agent "$agent" --file "brain/projects.md" 2>&1 || true)
assert_contains "$out" "not in agent" "non-whitelisted file refused"

# Production-style entries keep a blank line between metadata and body.
cat > "$D/brain/decisions.md" <<'EOF'
### 2026-04-29 10:00 -- save: work decision
{context: work, source_id: t-1}

- preserve this body

### 2026-04-29 11:00 -- save: personal note
{context: personal, source_id: t-2}

- hide this body
EOF

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/mcp-server/read_brain_file.sh" \
  --agent "$agent" --file "brain/decisions.md")
assert_contains "$out" "preserve this body" "production entry body preserved"
case "$out" in
  *"hide this body"*) _fail "production personal entry leaked" ;;
  *) _pass "production personal entry filtered out" ;;
esac

# Path traversal and missing read scope fail closed.
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/mcp-server/read_brain_file.sh" \
  --agent "$agent" --file "brain/../.git/config" 2>&1 || true)
assert_contains "$out" "invalid" "path traversal refused"

noscope=$(mktemp)
cat > "$noscope" <<'EOF'
---
slug: no-scope
reads: {}
---
EOF
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/mcp-server/read_brain_file.sh" \
  --agent "$noscope" --file "brain/decisions.md" 2>&1 || true)
assert_contains "$out" "reads.files required" "missing reads.files refused"

rm -f "$agent" "$noscope"; rm -rf "$D"; report
