#!/usr/bin/env bash
# ingest.sh -- gmail source. Single-pass bootstrap respecting per-context window.
# Window: work=9d, personal=1095d. Resolved per thread from sender domain.
# Stub mode: NANOBRAIN_GMAIL_STUB=/path/to/threads.json.
# Live mode: caller (skill or MCP wrapper) pipes JSON to NANOBRAIN_GMAIL_STUB.
#
# Thread shape:
#   { "id": "t1", "from": "vc@firm.com", "to": "user@gmail.com",
#     "date": "2026-04-27T09:13:00Z", "subject": "...", "body": "..." }

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
LIB_DIR="$FRAMEWORK_DIR/code/lib"
SRC_DIR="$FRAMEWORK_DIR/code/sources/gmail"

DATA_DIR="$BRAIN_DIR/data/gmail"
INBOX="$DATA_DIR/INBOX.md"
WATERMARK="$DATA_DIR/.watermark"

mkdir -p "$DATA_DIR"

fetch_threads() {
  if [ -n "${NANOBRAIN_GMAIL_STUB:-}" ]; then
    [ -f "$NANOBRAIN_GMAIL_STUB" ] || { echo "[gmail] stub missing: $NANOBRAIN_GMAIL_STUB" >&2; exit 3; }
    cat "$NANOBRAIN_GMAIL_STUB"
    return 0
  fi
  local fetch_sh="$SRC_DIR/fetch.sh"
  [ -f "$fetch_sh" ] || { echo "[gmail] fetch.sh missing" >&2; exit 3; }
  bash "$fetch_sh"
}

already_in_inbox() {
  [ -f "$INBOX" ] && grep -Fq "source_id: $1" "$INBOX"
}

window_days_for() {
  case "$1" in
    work) echo 9 ;;
    personal) echo 1095 ;;
    *) echo 9 ;;
  esac
}

# Date "YYYY-MM-DD..." -> epoch (gnu / bsd both via cut + date -j on bsd).
to_epoch() {
  local d="${1:-}"
  [ -n "$d" ] || { echo 0; return; }
  # Strip subseconds / Z; keep YYYY-MM-DDTHH:MM:SS.
  local clean
  clean=$(printf '%s' "$d" | sed -E 's/\.[0-9]+Z?$//; s/Z$//')
  if date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" >/dev/null 2>&1; then
    date -j -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s"
  else
    date -d "$d" +%s 2>/dev/null || echo 0
  fi
}

now_epoch() { date +%s; }

within_window() {
  local date="$1" days="$2" e n diff
  e=$(to_epoch "$date")
  n=$(now_epoch)
  diff=$(( n - e ))
  [ "$diff" -le $(( days * 86400 )) ]
}

append_row() {
  local row="$1"
  local id from to date subj body ctx
  id=$(printf '%s' "$row" | jq -r '.id')
  from=$(printf '%s' "$row" | jq -r '.from')
  to=$(printf '%s' "$row" | jq -r '.to')
  date=$(printf '%s' "$row" | jq -r '.date')
  subj=$(printf '%s' "$row" | jq -r '.subject')
  body=$(printf '%s' "$row" | jq -r '.body')

  # Filter sender.
  if bash "$SRC_DIR/filter.sh" "$from" >/dev/null 2>&1; then
    return 2
  fi

  ctx=$(bash "$LIB_DIR/resolve.sh" gmail "$from")
  local days; days=$(window_days_for "$ctx")
  if ! within_window "$date" "$days"; then
    return 3
  fi
  if already_in_inbox "$id"; then
    return 4
  fi

  INBOX="$INBOX" SOURCE="gmail" SUBJECT="$subj" CONTEXT="$ctx" \
    SOURCE_ID="$id" SENDER="$from" BODY="$body" \
    bash "$LIB_DIR/write_inbox.sh"
}

main() {
  local json; json=$(fetch_threads)
  local n i; n=$(printf '%s' "$json" | jq 'length'); i=0
  local appended=0 filtered=0 outside=0 dup=0
  while [ "$i" -lt "$n" ]; do
    local row; row=$(printf '%s' "$json" | jq -c ".[$i]")
    if append_row "$row"; then
      appended=$((appended + 1))
    else
      case $? in
        2) filtered=$((filtered + 1)) ;;
        3) outside=$((outside + 1)) ;;
        4) dup=$((dup + 1)) ;;
      esac
    fi
    i=$((i + 1))
  done
  echo "[gmail] appended=$appended filtered=$filtered outside_window=$outside dup=$dup"
  bash "${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}/code/lib/log_op.sh" \
    ingest "gmail: appended=$appended filtered=$filtered dup=$dup"
}

main "$@"
