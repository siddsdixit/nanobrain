#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_resolve =="
D=$(make_tmp_brain)

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/resolve.sh" gmail "vc@itn.com")
assert_eq "$out" "work" "gmail itn -> work"

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/resolve.sh" gmail "friend@gmail.com")
assert_eq "$out" "personal" "gmail gmail -> personal"

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/resolve.sh" gmail "stranger@unknown.com")
assert_eq "$out" "personal" "no match -> default personal"

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/resolve.sh" gdrive "/Drive/work/itn/notes.md")
assert_eq "$out" "work" "gdrive work path -> work"

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/resolve.sh" gdrive "/Drive/personal/journal.md")
assert_eq "$out" "personal" "gdrive personal -> personal"

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/resolve.sh" slack "TWORK01")
assert_eq "$out" "work" "slack work workspace"

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/resolve.sh" claude "/Users/x/work/itn/repo")
assert_eq "$out" "work" "claude work path glob"

# Missing _contexts.yaml -> default personal, no crash.
rm "$D/brain/_contexts.yaml"
out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/lib/resolve.sh" gmail "anyone@anywhere.com" 2>/dev/null)
assert_eq "$out" "personal" "missing yaml -> personal default"

rm -rf "$D"
report
