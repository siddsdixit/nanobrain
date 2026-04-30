#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_redact =="

run() { printf '%s' "$1" | bash "$V2_DIR/code/lib/redact.sh" 2>/dev/null; }

out=$(run "key=sk-abcdefghij1234567890ABCDEFG hello")
assert_contains "$out" "[REDACTED]" "openai sk- redacted"

out=$(run "AKIAIOSFODNN7EXAMPLE here")
assert_contains "$out" "[REDACTED]" "AWS key redacted"

out=$(run "tok=ghp_abcdefghijklmnopqrstuvwxyz0123456789ab end")
assert_contains "$out" "[REDACTED]" "github ghp_ redacted"

out=$(run "Authorization: Bearer abc.def.ghi")
assert_contains "$out" "Bearer [REDACTED]" "bearer redacted"

out=$(run "password=hunter2")
assert_contains "$out" "[REDACTED]" "password assignment redacted"

out=$(run "nothing to see here")
assert_eq "$out" "nothing to see here" "no false positive on plain text"

report
