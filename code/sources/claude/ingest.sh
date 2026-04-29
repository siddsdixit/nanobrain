#!/usr/bin/env bash
# ingest.sh -- claude source. Wraps a Claude Code Stop hook payload into an
# INBOX entry. The Stop hook (code/hooks/capture.sh) calls us with --transcript
# pointing to the session's transcript file. We resolve context from the
# project path and append a single entry.

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
LIB_DIR="$FRAMEWORK_DIR/code/lib"

DATA_DIR="$BRAIN_DIR/data/claude"
INBOX="$DATA_DIR/INBOX.md"
mkdir -p "$DATA_DIR"

PROJECT_PATH=""
TRANSCRIPT=""
SESSION_ID=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) PROJECT_PATH="$2"; shift 2 ;;
    --transcript) TRANSCRIPT="$2"; shift 2 ;;
    --session) SESSION_ID="$2"; shift 2 ;;
    *) echo "[claude] unknown arg: $1" >&2; exit 64 ;;
  esac
done

[ -n "$PROJECT_PATH" ] || PROJECT_PATH="${PWD:-unknown}"
[ -n "$SESSION_ID" ] || SESSION_ID="$(date +%s)"

ctx=$(bash "$LIB_DIR/resolve.sh" claude "$PROJECT_PATH")

body=""
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  body=$(tail -c 4000 "$TRANSCRIPT")
fi
[ -n "$body" ] || body="(no transcript)"

INBOX="$INBOX" SOURCE="claude" SUBJECT="session in $PROJECT_PATH" \
  CONTEXT="$ctx" SOURCE_ID="$SESSION_ID" SENDER="claude-code" BODY="$body" \
  bash "$LIB_DIR/write_inbox.sh"

echo "[claude] appended session=$SESSION_ID context=$ctx"
