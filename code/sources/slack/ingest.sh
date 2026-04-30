#!/usr/bin/env bash
# ingest.sh -- slack source. Resolver key = workspace_id (no channel overrides in v2).
# Window: 30d for both contexts. Stub: NANOBRAIN_SLACK_STUB.
# Message shape:
# { "id": "m1", "workspace_id": "T123", "channel": "general",
#   "user": "@maya", "ts": "2026-04-25T16:01:00Z", "text": "..." }

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
LIB_DIR="$FRAMEWORK_DIR/code/lib"
SRC_DIR="$FRAMEWORK_DIR/code/sources/slack"

DATA_DIR="$BRAIN_DIR/data/slack"
INBOX="$DATA_DIR/INBOX.md"
mkdir -p "$DATA_DIR"

fetch_msgs() {
  if [ -n "${NANOBRAIN_SLACK_STUB:-}" ]; then
    [ -f "$NANOBRAIN_SLACK_STUB" ] || { echo "[slack] stub missing" >&2; exit 3; }
    cat "$NANOBRAIN_SLACK_STUB"
    return 0
  fi
  local fetch_sh="$SRC_DIR/fetch.sh"
  [ -f "$fetch_sh" ] || { echo "[slack] fetch.sh missing" >&2; exit 3; }
  bash "$fetch_sh"
}

WINDOW_DAYS=30

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
  local d="$1" e n
  e=$(to_epoch "$d"); n=$(date +%s)
  [ $(( n - e )) -le $(( WINDOW_DAYS * 86400 )) ]
}

already_in_inbox() {
  [ -f "$INBOX" ] && grep -Fq "source_id: $1" "$INBOX"
}

append_msg() {
  local row="$1" id ws ch user ts text ctx
  id=$(printf '%s' "$row" | jq -r '.id')
  ws=$(printf '%s' "$row" | jq -r '.workspace_id')
  ch=$(printf '%s' "$row" | jq -r '.channel')
  user=$(printf '%s' "$row" | jq -r '.user')
  ts=$(printf '%s' "$row" | jq -r '.ts')
  text=$(printf '%s' "$row" | jq -r '.text')

  ctx=$(bash "$LIB_DIR/resolve.sh" slack "$ws")
  within_window "$ts" || return 3
  already_in_inbox "$id" && return 4

  INBOX="$INBOX" SOURCE="slack" SUBJECT="#${ch}" CONTEXT="$ctx" \
    SOURCE_ID="$id" SENDER="$user" BODY="$text" \
    bash "$LIB_DIR/write_inbox.sh"
}

main() {
  local json; json=$(fetch_msgs)
  local n i; n=$(printf '%s' "$json" | jq 'length'); i=0
  local appended=0 outside=0 dup=0
  while [ "$i" -lt "$n" ]; do
    local row; row=$(printf '%s' "$json" | jq -c ".[$i]")
    if append_msg "$row"; then
      appended=$((appended + 1))
    else
      case $? in 3) outside=$((outside + 1)) ;; 4) dup=$((dup + 1)) ;; esac
    fi
    i=$((i + 1))
  done
  echo "[slack] appended=$appended outside_window=$outside dup=$dup"
  bash "${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}/code/lib/log_op.sh" \
    ingest "slack: appended=$appended dup=$dup"
}

main "$@"
