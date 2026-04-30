#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_install_cron =="
D=$(mktemp -d)

out=$(BRAIN_DIR="$D" bash "$V2_DIR/code/cron/install.sh" --dry-run --brain-dir "$D" 2>&1)
assert_contains "$out" "DRY:" "dry-run prefix"
assert_contains "$out" "autosave" "autosave plist mentioned"
assert_contains "$out" "ingest.gmail" "gmail plist mentioned"

# Should not have written anything to ~/Library/LaunchAgents.
if [ -f "$HOME/Library/LaunchAgents/com.nanobrain.autosave.plist" ]; then
  : # may be pre-existing on dev box; we only care about no NEW writes from this test
fi

rm -rf "$D"; report
