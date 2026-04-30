#!/usr/bin/env bash
set -eu
. "$(dirname "$0")/_lib.sh"

echo "== test_gmail_ingest =="
D=$(make_tmp_brain)

recent_work=$(iso_now_minus_days 2)
recent_pers=$(iso_now_minus_days 30)
old_work=$(iso_now_minus_days 60)         # outside work 9d window
old_pers=$(iso_now_minus_days 1500)       # outside personal 1095d
inside_pers=$(iso_now_minus_days 800)     # inside personal 1095d

stub=$(mktemp)
cat > "$stub" <<EOF
[
  {"id":"t-work-1","from":"vc@itn.com","to":"me@itn.com",
   "date":"$recent_work","subject":"meeting","body":"hi"},
  {"id":"t-noreply","from":"noreply@bank.com","to":"me@gmail.com",
   "date":"$recent_pers","subject":"statement","body":"x"},
  {"id":"t-pers-1","from":"friend@gmail.com","to":"me@gmail.com",
   "date":"$inside_pers","subject":"birthday","body":"happy bday"},
  {"id":"t-work-old","from":"vc@itn.com","to":"me@itn.com",
   "date":"$old_work","subject":"old","body":"old"},
  {"id":"t-pers-old","from":"friend@gmail.com","to":"me@gmail.com",
   "date":"$old_pers","subject":"ancient","body":"old"}
]
EOF

NANOBRAIN_GMAIL_STUB="$stub" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/sources/gmail/ingest.sh" >/dev/null

INBOX="$D/data/gmail/INBOX.md"
assert_file_contains "$INBOX" "source_id: t-work-1" "work thread written"
assert_file_contains "$INBOX" "source_id: t-pers-1" "personal thread written"
assert_file_contains "$INBOX" "{context: work}" "work tag present"
assert_file_contains "$INBOX" "{context: personal}" "personal tag present"

if grep -Fq "source_id: t-noreply" "$INBOX"; then _fail "noreply leaked"; else _pass "noreply filtered"; fi
if grep -Fq "source_id: t-work-old" "$INBOX"; then _fail "work-old leaked"; else _pass "work outside-window dropped"; fi
if grep -Fq "source_id: t-pers-old" "$INBOX"; then _fail "pers-old leaked"; else _pass "personal outside-window dropped"; fi

# Idempotency: re-run, count of t-work-1 should stay at 1.
NANOBRAIN_GMAIL_STUB="$stub" BRAIN_DIR="$D" \
  bash "$V2_DIR/code/sources/gmail/ingest.sh" >/dev/null
n=$(grep -c "source_id: t-work-1" "$INBOX" || true)
assert_eq "$n" "1" "idempotent on re-run"

rm -f "$stub"
rm -rf "$D"
report
