#!/usr/bin/env bash
# ingest.sh -- granola source. Consumes meeting notes from fetch.sh.
# Meeting shape:
# { "id": "...", "title": "...", "date": "ISO8601", "attendees": ["..."],
#   "body": "...", "context": "work|personal" }

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
LIB_DIR="$FRAMEWORK_DIR/code/lib"
SRC_DIR="$FRAMEWORK_DIR/code/sources/granola"

DATA_DIR="$BRAIN_DIR/data/granola"
INBOX="$DATA_DIR/INBOX.md"
mkdir -p "$DATA_DIR"

fetch_meetings() {
  if [ -n "${NANOBRAIN_GRANOLA_STUB:-}" ]; then
    [ -f "$NANOBRAIN_GRANOLA_STUB" ] || { echo "[granola] stub missing" >&2; exit 3; }
    cat "$NANOBRAIN_GRANOLA_STUB"
    return 0
  fi
  local fetch_sh="$SRC_DIR/fetch.sh"
  [ -f "$fetch_sh" ] || { echo "[granola] fetch.sh missing" >&2; exit 3; }
  bash "$fetch_sh"
}

already_in_inbox() {
  [ -f "$INBOX" ] && grep -Fq "source_id: $1" "$INBOX"
}

append_meeting() {
  local row="$1" id title date attendees body ctx
  id=$(printf '%s' "$row" | jq -r '.id')
  title=$(printf '%s' "$row" | jq -r '.title')
  date=$(printf '%s' "$row" | jq -r '.date')
  attendees=$(printf '%s' "$row" | jq -r '.attendees | join(", ")')
  body=$(printf '%s' "$row" | jq -r '.body')
  ctx=$(printf '%s' "$row" | jq -r '.context // "personal"')

  already_in_inbox "$id" && return 4

  INBOX="$INBOX" SOURCE="granola" SUBJECT="$title" CONTEXT="$ctx" \
    SOURCE_ID="$id" SENDER="$attendees" BODY="$body" \
    bash "$LIB_DIR/write_inbox.sh"
}

main() {
  local json; json=$(fetch_meetings)
  local n i; n=$(printf '%s' "$json" | jq 'length'); i=0
  local appended=0 dup=0
  while [ "$i" -lt "$n" ]; do
    local row; row=$(printf '%s' "$json" | jq -c ".[$i]")
    if append_meeting "$row"; then
      appended=$((appended + 1))
    else
      case $? in 4) dup=$((dup + 1)) ;; esac
    fi
    i=$((i + 1))
  done
  echo "[granola] appended=$appended dup=$dup"
  bash "${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}/code/lib/log_op.sh" \
    ingest "granola: appended=$appended dup=$dup"
}

main "$@"
