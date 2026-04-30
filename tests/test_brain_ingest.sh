#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_brain_ingest =="
D=$(make_tmp_brain)

stub=$(mktemp)
recent=$(iso_now_minus_days 1)
cat > "$stub" <<EOF
[{"id":"d-1","from":"vc@itn.com","to":"me@itn.com","date":"$recent","subject":"hello","body":"world"}]
EOF

NANOBRAIN_GMAIL_STUB="$stub" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/skills/brain-ingest/dispatch.sh" gmail >/dev/null

assert_file_contains "$D/data/gmail/INBOX.md" "source_id: d-1" "dispatch routed gmail"

out=$(bash "$V2_DIR/code/skills/brain-ingest/dispatch.sh" zorp 2>&1 || true)
assert_contains "$out" "unknown source" "rejects unknown source"

rm -f "$stub"; rm -rf "$D"; report
