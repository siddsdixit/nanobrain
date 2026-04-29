#!/usr/bin/env bash
# write_inbox.sh -- atomic append to data/<source>/INBOX.md.
# Required env: INBOX, SOURCE, SUBJECT, CONTEXT, SOURCE_ID.
# Optional env: SENDER, BODY (else stdin).
# Every entry includes captured-at timestamp + provenance, redacted.

set -eu

: "${INBOX:?INBOX path required}"
: "${SOURCE:?SOURCE required}"
: "${SUBJECT:?SUBJECT required}"
: "${CONTEXT:?CONTEXT required}"
: "${SOURCE_ID:?SOURCE_ID required}"
: "${SENDER:=unknown}"

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
REDACT="$LIB_DIR/redact.sh"

if [ -z "${BODY:-}" ]; then
  BODY=$(cat)
fi

clean=$(printf '%s' "$BODY" | bash "$REDACT")
if [ "${#clean}" -gt 500 ]; then
  clean="$(printf '%s' "$clean" | cut -c1-500)..."
fi

ts=$(date '+%Y-%m-%d %H:%M')

mkdir -p "$(dirname "$INBOX")"
LOCK_DIR="${INBOX}.lock.d"
tries=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  tries=$((tries + 1))
  [ "$tries" -gt 200 ] && { echo "[write_inbox] lock timeout: $LOCK_DIR" >&2; exit 75; }
  sleep 0.05
done
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

{
  # Karpathy-style ### YYYY-MM-DD HH:MM | <source>: <subject> header.
  # Greppable with `grep "^### " INBOX.md`. Matches log.md format convention.
  printf '### %s | %s: %s\n' "$ts" "$SOURCE" "$SUBJECT"
  printf 'sender: %s\n' "$SENDER"
  printf 'source_id: %s\n' "$SOURCE_ID"
  printf '{context: %s}\n' "$CONTEXT"
  printf '\n'
  printf '%s\n\n' "$clean"
} >> "$INBOX"
