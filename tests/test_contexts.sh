#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_contexts =="

D=$(make_tmp_brain)

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/contexts.sh" validate 2>&1)
assert_contains "$out" "OK" "validate emits OK"

# Bad version.
cat > "$D/brain/_contexts.yaml" <<'EOF'
version: 2
contexts:
  work: {}
EOF
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/contexts.sh" validate 2>&1 || true)
assert_contains "$out" "version" "rejects bad version"

# Disallowed context name.
cat > "$D/brain/_contexts.yaml" <<'EOF'
version: 1
contexts:
  legal: {}
EOF
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/contexts.sh" validate 2>&1 || true)
assert_contains "$out" "work|personal" "rejects extra context"

# Resolver target must reference a declared context.
cat > "$D/brain/_contexts.yaml" <<'EOF'
version: 1
contexts:
  personal: {}
resolvers:
  gmail:
    - { match: { from: '@company\.com$' }, context: work }
EOF
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/contexts.sh" validate 2>&1 || true)
assert_contains "$out" "unknown context" "rejects resolver unknown context"

# Resolver source/key shape is validated, including configured Granola.
cat > "$D/brain/_contexts.yaml" <<'EOF'
version: 1
defaults:
  context: personal
contexts:
  work: {}
  personal: {}
resolvers:
  gmail:
    - { match: { from: '@company\.com$' }, context: work }
  granola:
    - { match: { attendee_domain: 'gmail\.com$' }, context: personal }
EOF
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/contexts.sh" validate 2>&1)
assert_contains "$out" "OK" "accepts gmail and granola resolvers"

cat > "$D/brain/_contexts.yaml" <<'EOF'
version: 1
contexts:
  personal: {}
resolvers:
  gmail:
    - { match: { path_glob: '**/work/**' }, context: personal }
EOF
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/contexts.sh" validate 2>&1 || true)
assert_contains "$out" "invalid resolver rule" "rejects invalid resolver key"

cat > "$D/brain/_contexts.yaml" <<'EOF'
version: 1
contexts:
  personal: {}
resolvers:
  gmail: {}
EOF
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/contexts.sh" validate 2>&1 || true)
assert_contains "$out" "array" "rejects non-array resolver"

rm -rf "$D"
report
