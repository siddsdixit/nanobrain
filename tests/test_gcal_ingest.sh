#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_gcal_ingest =="
D=$(make_tmp_brain)

soon=$(iso_now_minus_days -2 2>/dev/null || iso_now_minus_days 0)
recent=$(iso_now_minus_days 1)

stub=$(mktemp)
cat > "$stub" <<EOF
[
  {"id":"e1","calendar_id":"user@itn.com","organizer":"boss@itn.com",
   "start":"$recent","title":"standup","description":"daily"},
  {"id":"e2","calendar_id":"user@gmail.com","organizer":"mom",
   "start":"$soon","title":"family dinner","description":""}
]
EOF

NANOBRAIN_GCAL_STUB="$stub" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/sources/gcal/ingest.sh" >/dev/null

INBOX="$D/data/gcal/INBOX.md"
assert_file_contains "$INBOX" "source_id: e1" "work cal event"
assert_file_contains "$INBOX" "{context: work}" "work tag"
assert_file_contains "$INBOX" "source_id: e2" "personal cal event"
assert_file_contains "$INBOX" "{context: personal}" "personal tag"

rm -f "$stub"; rm -rf "$D"; report
