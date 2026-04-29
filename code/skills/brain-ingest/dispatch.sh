#!/usr/bin/env bash
# dispatch.sh -- run code/sources/<src>/ingest.sh.

set -eu
src="${1:-}"
[ -n "$src" ] || { echo "usage: dispatch.sh <source> [args]" >&2; exit 64; }
shift || true
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
ing="$FRAMEWORK_DIR/code/sources/$src/ingest.sh"
[ -f "$ing" ] || { echo "[brain-ingest] unknown source: $src" >&2; exit 64; }

bash "$ing" "$@"
rc=$?

LOG_SH="$FRAMEWORK_DIR/code/skills/brain-log/log.sh"
if [ -x "$LOG_SH" ] && [ "$rc" -eq 0 ]; then
  BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}" bash "$LOG_SH" ingest "$src ingest completed" || true
fi
exit "$rc"
