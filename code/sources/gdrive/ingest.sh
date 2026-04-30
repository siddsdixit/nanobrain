#!/usr/bin/env bash
# ingest.sh -- gdrive source. Resolver key = folder_path (glob).
# Stub: NANOBRAIN_GDRIVE_STUB. Doc shape:
# { "id": "d1", "folder_path": "/Drive/work/...", "owner": "user@company.com",
#   "modified": "2026-04-25T...", "title": "...", "snippet": "..." }

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
LIB_DIR="$FRAMEWORK_DIR/code/lib"
SRC_DIR="$FRAMEWORK_DIR/code/sources/gdrive"

DATA_DIR="$BRAIN_DIR/data/gdrive"
INBOX="$DATA_DIR/INBOX.md"
mkdir -p "$DATA_DIR"

fetch_docs() {
  if [ -n "${NANOBRAIN_GDRIVE_STUB:-}" ]; then
    [ -f "$NANOBRAIN_GDRIVE_STUB" ] || { echo "[gdrive] stub missing" >&2; exit 3; }
    cat "$NANOBRAIN_GDRIVE_STUB"
    return 0
  fi
  local fetch_sh="$SRC_DIR/fetch.sh"
  [ -f "$fetch_sh" ] || { echo "[gdrive] fetch.sh missing" >&2; exit 3; }
  bash "$fetch_sh"
}

window_days_for() {
  case "$1" in work) echo 9 ;; personal) echo 730 ;; *) echo 9 ;; esac
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
  [ $(( n - e )) -le $(( days * 86400 )) ]
}

already_in_inbox() {
  [ -f "$INBOX" ] && grep -Fq "source_id: $1" "$INBOX"
}

append_doc() {
  local row="$1" id path owner mod title snip ctx days
  id=$(printf '%s' "$row" | jq -r '.id')
  path=$(printf '%s' "$row" | jq -r '.folder_path')
  owner=$(printf '%s' "$row" | jq -r '.owner')
  mod=$(printf '%s' "$row" | jq -r '.modified')
  title=$(printf '%s' "$row" | jq -r '.title')
  snip=$(printf '%s' "$row" | jq -r '.snippet // ""')

  if bash "$SRC_DIR/filter.sh" "$path" >/dev/null 2>&1; then
    return 2
  fi
  ctx=$(bash "$LIB_DIR/resolve.sh" gdrive "$path")
  days=$(window_days_for "$ctx")
  within_window "$mod" "$days" || return 3
  already_in_inbox "$id" && return 4

  INBOX="$INBOX" SOURCE="gdrive" SUBJECT="$title" CONTEXT="$ctx" \
    SOURCE_ID="$id" SENDER="$owner" BODY="$snip" \
    bash "$LIB_DIR/write_inbox.sh"
}

main() {
  local json; json=$(fetch_docs)
  local n i; n=$(printf '%s' "$json" | jq 'length'); i=0
  local appended=0 filtered=0 outside=0 dup=0
  while [ "$i" -lt "$n" ]; do
    local row; row=$(printf '%s' "$json" | jq -c ".[$i]")
    if append_doc "$row"; then
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
  echo "[gdrive] appended=$appended filtered=$filtered outside_window=$outside dup=$dup"
  bash "${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}/code/lib/log_op.sh" \
    ingest "gdrive: appended=$appended filtered=$filtered dup=$dup"
}

main "$@"
