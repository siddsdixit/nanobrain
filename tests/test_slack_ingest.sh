#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_slack_ingest =="
D=$(make_tmp_brain)

recent=$(iso_now_minus_days 1)
old=$(iso_now_minus_days 60)
stub=$(mktemp)
cat > "$stub" <<EOF
[
  {"id":"m1","workspace_id":"TWORK01","channel":"general","user":"@boss",
   "ts":"$recent","text":"ship it"},
  {"id":"m2","workspace_id":"TPERS99","channel":"diy","user":"@friend",
   "ts":"$recent","text":"saw your post"},
  {"id":"m3","workspace_id":"TWORK01","channel":"old","user":"@x",
   "ts":"$old","text":"stale"}
]
EOF

NANOBRAIN_SLACK_STUB="$stub" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/sources/slack/ingest.sh" >/dev/null

INBOX="$D/data/slack/INBOX.md"
assert_file_contains "$INBOX" "source_id: m1" "work msg"
assert_file_contains "$INBOX" "{context: work}" "work tag"
assert_file_contains "$INBOX" "source_id: m2" "personal msg"
if grep -Fq "source_id: m3" "$INBOX"; then _fail "stale leaked"; else _pass "outside-window dropped"; fi

rm -f "$stub"; rm -rf "$D"; report
