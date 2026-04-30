#!/usr/bin/env bash
# ingest.sh -- gcal source. Resolver key = calendar_id.
# Stub: NANOBRAIN_GCAL_STUB. Event shape:
# { "id": "e1", "calendar_id": "user@company.com", "organizer": "...",
#   "start": "2026-04-29T17:00:00Z", "title": "...", "description": "..." }

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
LIB_DIR="$FRAMEWORK_DIR/code/lib"
SRC_DIR="$FRAMEWORK_DIR/code/sources/gcal"

DATA_DIR="$BRAIN_DIR/data/gcal"
INBOX="$DATA_DIR/INBOX.md"
mkdir -p "$DATA_DIR"

fetch_events() {
  if [ -n "${NANOBRAIN_GCAL_STUB:-}" ]; then
    [ -f "$NANOBRAIN_GCAL_STUB" ] || { echo "[gcal] stub missing" >&2; exit 3; }
    cat "$NANOBRAIN_GCAL_STUB"
    return 0
  fi
  local fetch_sh="$SRC_DIR/fetch.sh"
  [ -f "$fetch_sh" ] || { echo "[gcal] fetch.sh missing" >&2; exit 3; }
  bash "$fetch_sh"
}

window_days_for() {
  case "$1" in work) echo 9 ;; personal) echo 1095 ;; *) echo 9 ;; esac
}

to_epoch() {
  local d="${1:-}" clean
  [ -n "$d" ] || { echo 0; return; }
  clean=$(printf '%s' "$d" | sed -E 's/\.[0-9]+Z?$//; s/Z$//')
  if date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" >/dev/null 2>&1; then
    date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s"
  else
    date -d "$d" +%s 2>/dev/null || echo 0
  fi
}

within_window() {
  local d="$1" days="$2" e n
  e=$(to_epoch "$d"); n=$(date +%s)
  # Allow future events too: window covers events whose start is at most $days in the past
  # OR any time in the future.
  if [ "$e" -ge "$n" ]; then return 0; fi
  [ $(( n - e )) -le $(( days * 86400 )) ]
}

already_in_inbox() {
  [ -f "$INBOX" ] && grep -Fq "source_id: $1" "$INBOX"
}

append_event() {
  local row="$1" id cal org start title desc ctx days
  id=$(printf '%s' "$row" | jq -r '.id')
  cal=$(printf '%s' "$row" | jq -r '.calendar_id')
  org=$(printf '%s' "$row" | jq -r '.organizer')
  start=$(printf '%s' "$row" | jq -r '.start')
  title=$(printf '%s' "$row" | jq -r '.title')
  desc=$(printf '%s' "$row" | jq -r '.description // ""')

  ctx=$(bash "$LIB_DIR/resolve.sh" gcal "$cal")
  days=$(window_days_for "$ctx")
  within_window "$start" "$days" || return 3
  already_in_inbox "$id" && return 4

  INBOX="$INBOX" SOURCE="gcal" SUBJECT="$title" CONTEXT="$ctx" \
    SOURCE_ID="$id" SENDER="$org" BODY="$desc" \
    bash "$LIB_DIR/write_inbox.sh"
}

main() {
  local json; json=$(fetch_events)
  local n i; n=$(printf '%s' "$json" | jq 'length'); i=0
  local appended=0 outside=0 dup=0
  while [ "$i" -lt "$n" ]; do
    local row; row=$(printf '%s' "$json" | jq -c ".[$i]")
    if append_event "$row"; then
      appended=$((appended + 1))
    else
      case $? in 3) outside=$((outside + 1)) ;; 4) dup=$((dup + 1)) ;; esac
    fi
    i=$((i + 1))
  done
  echo "[gcal] appended=$appended outside_window=$outside dup=$dup"
  bash "${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}/code/lib/log_op.sh" \
    ingest "gcal: appended=$appended dup=$dup"
}

main "$@"
