#!/usr/bin/env bash
# Tests for code/skills/brain-save/save.sh: append + mirror + commit + redact.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SAVE="$ROOT/code/skills/brain-save/save.sh"

echo "test_brain_save.sh"
TPASS=0; TFAIL=0
pass() { echo "  PASS: $1"; TPASS=$((TPASS+1)); }
fail() { echo "  FAIL: $1"; TFAIL=$((TFAIL+1)); exit 1; }

# 1. Missing args
bash "$SAVE" >/dev/null 2>&1 && fail "1: missing args should fail"
bash "$SAVE" --text "x" >/dev/null 2>&1 && fail "1: missing --category should fail"
bash "$SAVE" --category decisions >/dev/null 2>&1 && fail "1: missing --text should fail"
pass "1: rejects missing required args"

# 2. Invalid category
D=$(mktemp -d)
( cd "$D" && git init -q && git config user.email "t@l" && git config user.name "t" )
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" bash "$SAVE" --category bogus --text "x" --no-commit >/dev/null 2>&1 \
  && fail "2: bogus category should fail"
pass "2: rejects invalid category"

# 3. Invalid context
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" bash "$SAVE" --category decisions --context bogus --text "x" --no-commit >/dev/null 2>&1 \
  && fail "3: bogus context should fail"
pass "3: rejects invalid context"

# 4. Happy path: writes to category file AND raw.md
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --category decisions --text "Pause Idaho-craig for Q3" --context personal --no-commit >/dev/null 2>&1 \
  || fail "4: save failed"
[ -f "$D/brain/decisions.md" ] || fail "4: decisions.md not created"
[ -f "$D/brain/raw.md" ]       || fail "4: raw.md not created"
grep -q "Pause Idaho-craig" "$D/brain/decisions.md" || fail "4: text missing from decisions.md"
grep -q "Pause Idaho-craig" "$D/brain/raw.md"       || fail "4: mirror failed (raw.md missing entry)"
grep -q "{context: personal" "$D/brain/decisions.md" || fail "4: context tag missing"
pass "4: writes to category + mirrors to raw.md"

# 5. Append (not overwrite)
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --category decisions --text "Second decision" --no-commit >/dev/null 2>&1
n=$(grep -c "^### " "$D/brain/decisions.md")
[ "$n" = "2" ] || fail "5: expected 2 entries, got $n"
pass "5: subsequent saves append (do not overwrite)"

# 6. Redaction: secret patterns get scrubbed
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --category learnings --text "API key: sk-abc123def456ghi789jkl012mno345pqr678 leaked" --no-commit >/dev/null 2>&1
grep -q "sk-abc123def456" "$D/brain/learnings.md" && fail "6: secret leaked into learnings.md"
grep -q "REDACTED" "$D/brain/learnings.md" || fail "6: redact marker missing"
pass "6: secrets redacted before write"

# 7. Default context = personal
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --category goals --text "Ship v2 by Friday" --no-commit >/dev/null 2>&1
grep -q "{context: personal" "$D/brain/goals.md" || fail "7: default context not personal"
pass "7: default context is personal"

# 8. Commit path: produces a single commit when --no-commit absent
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --category projects --text "Start v2.1 spawn skill" >/dev/null 2>&1
( cd "$D" && git log -1 --pretty=format:'%s' | grep -q "save: Start v2.1" ) \
  || fail "8: commit message wrong"
pass "8: produces a single commit with right message"

# 9. --page creates per-entity page if absent, with Mention bullet
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --page jen --type people --text "coffee tuesday 4pm" --no-commit >/dev/null 2>&1 \
  || fail "9: --page save failed"
[ -f "$D/brain/people/jen.md" ] || fail "9: brain/people/jen.md not created"
grep -q "^# jen$" "$D/brain/people/jen.md" || fail "9: scaffolded title missing"
grep -q "^## Mentions$" "$D/brain/people/jen.md" || fail "9: Mentions heading missing"
grep -q "coffee tuesday 4pm" "$D/brain/people/jen.md" || fail "9: mention bullet not appended"
case "$(cat "$D/brain/people/jen.md")" in
  *"### "*) fail "9: per-entity page should not contain `### ` entry headers" ;;
esac
pass "9: --page creates per-entity page with Mention bullet"

# 10. --page appends to existing page (does not scaffold over)
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --page jen --type people --text "lunch friday" --no-commit >/dev/null 2>&1
n=$(grep -c "^- " "$D/brain/people/jen.md")
[ "$n" -ge 2 ] || fail "10: expected >=2 mention bullets, got $n"
grep -q "lunch friday" "$D/brain/people/jen.md" || fail "10: second mention missing"
pass "10: --page appends Mention bullet to existing page"

# 11. --page invalid type rejected
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --page jen --type bogus --text "x" --no-commit >/dev/null 2>&1 \
  && fail "11: invalid --type accepted"
pass "11: rejects invalid --type"

# 12. --page invalid slug rejected
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --page "jen wang" --type people --text "x" --no-commit >/dev/null 2>&1 \
  && fail "12: spaced slug accepted"
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --page "../etc" --type people --text "x" --no-commit >/dev/null 2>&1 \
  && fail "12: traversal slug accepted"
pass "12: rejects invalid slugs"

# 13. --page projects routes to brain/projects/<slug>.md
BRAIN_DIR="$D" NANOBRAIN_DIR="$ROOT" \
  bash "$SAVE" --page ghx-cto --type projects --text "Steve Jackson call confirmed" --no-commit >/dev/null 2>&1
[ -f "$D/brain/projects/ghx-cto.md" ] || fail "13: projects per-entity not created"
grep -q "Steve Jackson" "$D/brain/projects/ghx-cto.md" || fail "13: projects mention missing"
pass "13: --page projects routes to brain/projects/<slug>.md"

# 14. --page mirrors to raw.md
grep -q "coffee tuesday" "$D/brain/raw.md" || fail "14: per-entity mention not mirrored to raw.md"
pass "14: --page mirrors to raw.md"

rm -rf "$D"
printf 'pass=%d fail=%d\n' "$TPASS" "$TFAIL"
