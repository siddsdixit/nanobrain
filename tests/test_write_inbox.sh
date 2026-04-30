#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_write_inbox =="
D=$(make_tmp_brain)
INBOX="$D/data/gmail/INBOX.md"

INBOX="$INBOX" SOURCE="gmail" SUBJECT="hello" CONTEXT="work" \
  SOURCE_ID="t-1" SENDER="vc@itn.com" BODY="meeting at 3" \
  bash "$V2_DIR/code/lib/write_inbox.sh"

assert_file_contains "$INBOX" "| gmail: hello" "header line includes source and subject"
assert_file_contains "$INBOX" "sender: vc@itn.com" "sender line written"
assert_file_contains "$INBOX" "### " "entry header uses ### marker"
assert_file_contains "$INBOX" "source_id: t-1" "source_id written"
assert_file_contains "$INBOX" "{context: work}" "context block written"
assert_file_contains "$INBOX" "meeting at 3" "body written"

# Redaction on write.
INBOX="$INBOX" SOURCE="gmail" SUBJECT="leak" CONTEXT="work" \
  SOURCE_ID="t-2" SENDER="vc@itn.com" BODY="apikey=sk-abcdefghij1234567890ABCDEFG end" \
  bash "$V2_DIR/code/lib/write_inbox.sh"

if grep -q "sk-abcdefghij1234567890ABCDEFG" "$INBOX"; then
  FAIL=$((FAIL + 1)); echo "  FAIL: secret leaked into INBOX"
else
  PASS=$((PASS + 1)); [ "${VERBOSE:-0}" = "1" ] && echo "  PASS: secret redacted on write"
fi
assert_file_contains "$INBOX" "[REDACTED]" "redacted token in INBOX"

rm -rf "$D"
report
