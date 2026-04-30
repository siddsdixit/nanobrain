#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_brain_doctor =="
D=$(make_tmp_brain)

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/skills/brain-doctor/check.sh" 2>&1)
assert_contains "$out" "gmail" "doctor lists gmail"
assert_contains "$out" "slack" "doctor lists slack"
assert_contains "$out" "github sync" "doctor shows github sync section"
assert_contains "$out" "no remote configured" "doctor warns when no remote set"

rm -rf "$D"; report
