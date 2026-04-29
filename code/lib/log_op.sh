#!/usr/bin/env bash
# log_op.sh -- thin helper for source/skill scripts to emit a brain/log.md entry.
#
# Usage:
#   bash code/lib/log_op.sh <op> "<title>"
#
# Resolves NANOBRAIN_DIR -> $NANOBRAIN_DIR/code/skills/brain-log/log.sh and calls
# it with BRAIN_DIR forwarded. No-op if the log skill is missing (older installs).

set -u

op="${1:-}"
title="${2:-}"
[ -n "$op" ] || { echo "[log_op] usage: log_op.sh <op> \"<title>\"" >&2; exit 0; }
[ -n "$title" ] || title="(no title)"

NANOBRAIN_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_SH="$NANOBRAIN_DIR/code/skills/brain-log/log.sh"

if [ -x "$LOG_SH" ]; then
  BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}" bash "$LOG_SH" "$op" "$title" 2>/dev/null || true
fi
