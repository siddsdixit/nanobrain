#!/usr/bin/env bash
# Tests for brain-spawn.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SPAWN="$ROOT/code/skills/brain-spawn/spawn.sh"

echo "test_brain_spawn.sh"
TPASS=0; TFAIL=0
pass() { echo "  PASS: $1"; TPASS=$((TPASS+1)); }
fail() { echo "  FAIL: $1"; TFAIL=$((TFAIL+1)); exit 1; }

# Use a sandbox NANOBRAIN_DIR with the same agents/_TEMPLATE.md.
SANDBOX=$(mktemp -d)
mkdir -p "$SANDBOX/code/agents"
cp "$ROOT/code/agents/_TEMPLATE.md" "$SANDBOX/code/agents/_TEMPLATE.md"

# 1. Spawn personal-scoped agent.
NANOBRAIN_DIR="$SANDBOX" bash "$SPAWN" --slug "branding" --role "Brand voice" --reads "brain/self.md,brain/projects.md" --context personal >/dev/null 2>&1 \
  || fail "1: spawn failed"
[ -f "$SANDBOX/code/agents/branding.md" ] || fail "1: agent file not written"
grep -q "slug: branding" "$SANDBOX/code/agents/branding.md" || fail "1: slug missing in frontmatter"
grep -q "context_in:" "$SANDBOX/code/agents/branding.md" || fail "1: context_in missing"
grep -q "      - personal" "$SANDBOX/code/agents/branding.md" || fail "1: personal context missing"
pass "1: spawns personal-scoped agent"

# 2. Duplicate slug fails.
NANOBRAIN_DIR="$SANDBOX" bash "$SPAWN" --slug "branding" --role "x" --reads "brain/self.md" --context personal >/dev/null 2>&1 \
  && fail "2: duplicate should fail"
pass "2: duplicate slug refused"

# 3. Slug with space rejected.
NANOBRAIN_DIR="$SANDBOX" bash "$SPAWN" --slug "bad slug" --role "x" --reads "brain/self.md" --context personal >/dev/null 2>&1 \
  && fail "3: spaced slug should fail"
pass "3: slug with spaces rejected"

# 4. Frontmatter matches schema (slug, reads.files, reads.filter.context_in).
agent="$SANDBOX/code/agents/branding.md"
grep -q "^reads:" "$agent" || fail "4: reads: key missing"
grep -q "^  files:" "$agent" || fail "4: files key missing"
grep -q "^  filter:" "$agent" || fail "4: filter key missing"
grep -q "^    context_in:" "$agent" || fail "4: context_in key missing"
grep -q "    - brain/self.md" "$agent" || fail "4: reads file missing"
# v2 simplification: must NOT have sensitivity_max or ownership_in.
grep -q "sensitivity_max" "$agent" && fail "4: leftover sensitivity_max"
grep -q "ownership_in" "$agent" && fail "4: leftover ownership_in"
pass "4: frontmatter matches v2 template schema"

# 5. Refuse firehose reads.
NANOBRAIN_DIR="$SANDBOX" bash "$SPAWN" --slug "leaky" --role "x" --reads "brain/raw.md" --context personal >/dev/null 2>&1 \
  && fail "5: raw.md reads should be refused"
pass "5: refuses firehose in reads"

# 6. context=both -> two context lines.
NANOBRAIN_DIR="$SANDBOX" bash "$SPAWN" --slug "dualctx" --role "Both" --reads "brain/self.md" --context both >/dev/null 2>&1 \
  || fail "6: both-context spawn failed"
grep -q "      - work" "$SANDBOX/code/agents/dualctx.md" || fail "6: work line missing"
grep -q "      - personal" "$SANDBOX/code/agents/dualctx.md" || fail "6: personal line missing"
pass "6: context=both writes both context lines"

rm -rf "$SANDBOX"
printf 'pass=%d fail=%d\n' "$TPASS" "$TFAIL"
