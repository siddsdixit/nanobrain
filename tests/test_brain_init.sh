#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_brain_init =="
D=$(mktemp -d)

# Non-interactive: both emails.
bash "$V2_DIR/code/skills/brain-init/wizard.sh" \
  --brain-dir "$D" --work "sd@itn.com" --personal "sd@gmail.com" >/dev/null

assert_file_contains "$D/brain/_contexts.yaml" "version: 1" "version present"
assert_file_contains "$D/brain/_contexts.yaml" "work: {}" "work context"
assert_file_contains "$D/brain/_contexts.yaml" "personal: {}" "personal context"
assert_file_contains "$D/brain/_contexts.yaml" "@itn\\.com" "work resolver escaped"
assert_file_contains "$D/brain/_contexts.yaml" "granola:" "granola resolver section"

out=$(bash "$V2_DIR/code/lib/contexts.sh" validate "$D/brain/_contexts.yaml" 2>&1)
assert_contains "$out" "OK" "generated contexts validates"

# Refuse to overwrite.
out=$(bash "$V2_DIR/code/skills/brain-init/wizard.sh" \
  --brain-dir "$D" --work "sd@itn.com" --personal "sd@gmail.com" 2>&1 || true)
assert_contains "$out" "exists" "refuses overwrite"

# Solo personal: no --work flag.
D2=$(mktemp -d)
bash "$V2_DIR/code/skills/brain-init/wizard.sh" \
  --brain-dir "$D2" --personal "sd@gmail.com" >/dev/null
if grep -q "work:" "$D2/brain/_contexts.yaml"; then _fail "solo brain has work"; else _pass "solo brain has no work context"; fi

# Invalid emails are rejected before writing.
D3=$(mktemp -d)
out=$(bash "$V2_DIR/code/skills/brain-init/wizard.sh" \
  --brain-dir "$D3" --work "bad email" --personal "sd@gmail.com" 2>&1 || true)
assert_contains "$out" "invalid work email" "rejects invalid work email"
[ ! -f "$D3/brain/_contexts.yaml" ] && _pass "invalid init writes nothing" || _fail "invalid init wrote contexts"

rm -rf "$D" "$D2" "$D3"; report
