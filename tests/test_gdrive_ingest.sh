#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_gdrive_ingest =="
D=$(make_tmp_brain)

recent=$(iso_now_minus_days 1)
stub=$(mktemp)
cat > "$stub" <<EOF
[
  {"id":"d1","folder_path":"/Drive/work/itn/notes","owner":"me@itn.com",
   "modified":"$recent","title":"Q2 plan","snippet":"plan body"},
  {"id":"d2","folder_path":"/Drive/personal/journal","owner":"me@gmail.com",
   "modified":"$recent","title":"Apr","snippet":"journal entry"},
  {"id":"d3","folder_path":"/Drive/work/itn/Trash/old","owner":"me@itn.com",
   "modified":"$recent","title":"trashed","snippet":""}
]
EOF

NANOBRAIN_GDRIVE_STUB="$stub" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/sources/gdrive/ingest.sh" >/dev/null

INBOX="$D/data/gdrive/INBOX.md"
assert_file_contains "$INBOX" "source_id: d1" "work doc"
assert_file_contains "$INBOX" "{context: work}" "work tag"
assert_file_contains "$INBOX" "source_id: d2" "personal doc"
if grep -Fq "source_id: d3" "$INBOX"; then _fail "trash leaked"; else _pass "trash filtered"; fi

rm -f "$stub"; rm -rf "$D"; report
