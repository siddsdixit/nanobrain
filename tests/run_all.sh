#!/usr/bin/env bash
# run_all.sh -- discover and run every test_*.sh, then run smoke.

set -u
TDIR="$(cd "$(dirname "$0")" && pwd)"
total_pass=0
total_fail=0
suites=0

for t in "$TDIR"/test_*.sh; do
  [ -f "$t" ] || continue
  suites=$((suites + 1))
  out=$(bash "$t" 2>&1) || true
  printf '%s\n' "$out"
  # Extract last "pass=N fail=M" line.
  line=$(printf '%s\n' "$out" | awk '/^pass=[0-9]+ fail=[0-9]+/ {l=$0} END{print l}')
  p=$(printf '%s' "$line" | awk -F'[= ]' '{print $2}')
  f=$(printf '%s' "$line" | awk -F'[= ]' '{print $4}')
  total_pass=$((total_pass + ${p:-0}))
  total_fail=$((total_fail + ${f:-0}))
done

# Smoke at the end.
if [ -f "$TDIR/e2e/smoke.sh" ]; then
  suites=$((suites + 1))
  out=$(bash "$TDIR/e2e/smoke.sh" 2>&1) || true
  printf '%s\n' "$out"
  line=$(printf '%s\n' "$out" | awk '/^pass=[0-9]+ fail=[0-9]+/ {l=$0} END{print l}')
  p=$(printf '%s' "$line" | awk -F'[= ]' '{print $2}')
  f=$(printf '%s' "$line" | awk -F'[= ]' '{print $4}')
  total_pass=$((total_pass + ${p:-0}))
  total_fail=$((total_fail + ${f:-0}))
fi

echo "==============================================="
echo "suites=$suites pass=$total_pass fail=$total_fail"
[ "$total_fail" -eq 0 ] && echo "ALL GREEN" || echo "FAIL"
[ "$total_fail" -eq 0 ]
