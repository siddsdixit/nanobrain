#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_claude_ingest =="
D=$(make_tmp_brain)

trans=$(mktemp)
echo "user> what changed in the build" > "$trans"
echo "assistant> ran the test suite, all green" >> "$trans"

BRAIN_DIR="$D" bash "$V2_DIR/code/sources/claude/ingest.sh" \
  --project "/Users/x/work/itn/repo" --transcript "$trans" --session "sess-1" >/dev/null

INBOX="$D/data/claude/INBOX.md"
assert_file_contains "$INBOX" "source_id: sess-1" "session id written"
assert_file_contains "$INBOX" "{context: work}" "context resolved from path"
assert_file_contains "$INBOX" "ran the test suite" "transcript captured"

# Personal path
BRAIN_DIR="$D" bash "$V2_DIR/code/sources/claude/ingest.sh" \
  --project "/Users/x/Documents/journal" --transcript "$trans" --session "sess-2" >/dev/null
assert_file_contains "$INBOX" "source_id: sess-2" "second session"
assert_file_contains "$INBOX" "{context: personal}" "personal default"

rm -f "$trans"; rm -rf "$D"; report
