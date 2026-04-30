#!/usr/bin/env bash
# test_brain_log.sh -- brain-log skill: append-only chronological log.

. "$(cd "$(dirname "$0")" && pwd)/_lib.sh"

LOG_SH="$V2_DIR/code/skills/brain-log/log.sh"

# 1. Skill file exists and is executable.
[ -x "$LOG_SH" ] && _pass "log.sh exists and is executable" || _fail "log.sh missing or not executable"

# 2. Missing args -> exit 2.
rc=0
out=$(bash "$LOG_SH" 2>&1) || rc=$?
assert_eq "$rc" "2" "log.sh with no args exits 2"

# 3. First call creates header + first entry.
B=$(make_tmp_brain)
BRAIN_DIR="$B" bash "$LOG_SH" save "first entry" >/dev/null
[ -f "$B/brain/log.md" ] && _pass "log.md is created on first call" || _fail "log.md not created"
assert_file_contains "$B/brain/log.md" "# Operation Log" "header line present"
assert_file_contains "$B/brain/log.md" "Append-only" "header description present"
n=$(grep -c "^## \[" "$B/brain/log.md" || true)
assert_eq "$n" "1" "exactly one entry after first call"

# 4. Format check: regex ^## \[YYYY-MM-DD HH:MM\] op | title
line=$(grep "^## \[" "$B/brain/log.md" | head -1)
case "$line" in
  "## ["[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" "[0-9][0-9]":"[0-9][0-9]"] save | first entry") _pass "entry format matches contract" ;;
  *) _fail "entry format wrong: $line" ;;
esac

# 5. Ten consecutive ops -> ten lines, all match.
B2=$(make_tmp_brain)
i=0
while [ "$i" -lt 10 ]; do
  BRAIN_DIR="$B2" bash "$LOG_SH" capture "op $i" >/dev/null
  i=$((i + 1))
done
n2=$(grep -c "^## \[" "$B2/brain/log.md" || true)
assert_eq "$n2" "10" "ten consecutive ops produce ten lines"
bad=$(grep -c -v -e "^## \[" -e "^# " -e "^_" -e "^$" "$B2/brain/log.md" || true)
assert_eq "$bad" "0" "no malformed lines in log"

# 6. Header is written only once.
hdr=$(grep -c "^# Operation Log" "$B2/brain/log.md" || true)
assert_eq "$hdr" "1" "header appears exactly once after many calls"

# 7. No brain dir -> exit 0 silently.
TMPNO=$(mktemp -d)
rc=0
BRAIN_DIR="$TMPNO" bash "$LOG_SH" save "no brain" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "0" "no brain dir -> exit 0"
[ ! -f "$TMPNO/brain/log.md" ] && _pass "no log.md created when no brain dir" || _fail "log.md created spuriously"
rm -rf "$TMPNO"

# 8. Multiline title is squashed onto one line.
B3=$(make_tmp_brain)
BRAIN_DIR="$B3" bash "$LOG_SH" save "$(printf 'line one\nline two')" >/dev/null
nlines=$(grep -c "^## \[" "$B3/brain/log.md" || true)
assert_eq "$nlines" "1" "multiline title produces one entry line"

report
