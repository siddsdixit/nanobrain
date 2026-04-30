#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_brain_restore =="
D=$(make_tmp_brain)

# Add a second commit so we have history.
echo "x" > "$D/brain/decisions.md"
( cd "$D" && git add -A && git commit -q -m "second" )
sha=$(cd "$D" && git rev-parse HEAD)

# Refuse destructive flag.
out=$(bash "$V2_DIR/code/skills/brain-restore/restore.sh" --brain-dir "$D" --hard 2>&1 || true)
assert_contains "$out" "refused" "refuses --hard"

out=$(bash "$V2_DIR/code/skills/brain-restore/restore.sh" --brain-dir "$D" --force 2>&1 || true)
assert_contains "$out" "refused" "refuses --force"

# Non-destructive checkout to a branch.
bash "$V2_DIR/code/skills/brain-restore/restore.sh" --brain-dir "$D" --target "$sha" >/dev/null
branches=$(cd "$D" && git branch | tr -d ' *')
case "$branches" in
  *restore/*) _pass "restore branch created" ;;
  *) _fail "no restore branch (have: $branches)" ;;
esac

rm -rf "$D"; report
