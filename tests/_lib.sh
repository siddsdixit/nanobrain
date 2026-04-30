#!/usr/bin/env bash
# _lib.sh -- shared test helpers.

set -eu

V2_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NANOBRAIN_DIR="$V2_DIR"

PASS=0
FAIL=0

# Use SECONDS-based randomness for tmp dir uniqueness.
make_tmp_brain() {
  local d
  d=$(mktemp -d "${TMPDIR:-/tmp}/nb2-test.XXXXXX")
  mkdir -p "$d/brain" "$d/data"
  cp "$V2_DIR/tests/fixtures/_contexts.yaml" "$d/brain/_contexts.yaml"
  ( cd "$d" && git init -q && git add -A && git commit -q -m init ) || true
  printf '%s' "$d"
}

iso_now_minus_days() {
  local days="$1" t
  t=$(( $(date +%s) - days * 86400 ))
  if date -r "$t" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null; then return 0; fi
  date -u -d "@$t" '+%Y-%m-%dT%H:%M:%SZ'
}

_pass() { PASS=$((PASS + 1)); if [ "${VERBOSE:-0}" = "1" ]; then printf '  PASS: %s\n' "$1"; fi; return 0; }
_fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1"; return 0; }

assert_eq() {
  if [ "$1" = "$2" ]; then _pass "$3"; else _fail "$3 (expected '$2' got '$1')"; fi
}

assert_contains() {
  case "$1" in
    *"$2"*) _pass "$3" ;;
    *)      _fail "$3 (haystack='$1' needle='$2')" ;;
  esac
}

assert_file_contains() {
  if [ -f "$1" ] && grep -Fq "$2" "$1"; then _pass "$3"; else _fail "$3 (file=$1 missing '$2')"; fi
}

report() {
  printf 'pass=%d fail=%d\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}
