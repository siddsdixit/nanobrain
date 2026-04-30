#!/usr/bin/env bash
# install.sh -- register launchd plists. Flags:
#   --dry-run           Print what would happen, do nothing.
#   --skip-cron         Render plists into ~/Library/LaunchAgents but do not load them.
#   --brain-dir DIR     Brain directory (default: $BRAIN_DIR or $HOME/brain).

set -eu

DRY=0
SKIP_CRON=0
BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)   DRY=1; shift ;;
    --skip-cron) SKIP_CRON=1; shift ;;
    --brain-dir) BRAIN_DIR="$2"; shift 2 ;;
    *) echo "[cron install] unknown arg: $1" >&2; exit 64 ;;
  esac
done

CRON_DIR="$(cd "$(dirname "$0")" && pwd)"
LA_DIR="$HOME/Library/LaunchAgents"

run() {
  if [ "$DRY" -eq 1 ]; then
    echo "DRY: $*"
  else
    eval "$@"
  fi
}

mkdir -p "$BRAIN_DIR/data/_logs"
run "mkdir -p '$LA_DIR'"

for src in autosave distill-drainer ingest.gmail ingest.gcal ingest.gdrive ingest.slack; do
  in="$CRON_DIR/com.nanobrain.$src.plist"
  out="$LA_DIR/com.nanobrain.$src.plist"
  [ -f "$in" ] || { echo "[cron install] missing template: $in" >&2; continue; }

  if [ "$DRY" -eq 1 ]; then
    echo "DRY: render $in -> $out (BRAIN_DIR=$BRAIN_DIR)"
  else
    sed "s|__BRAIN_DIR__|$BRAIN_DIR|g; s|__HOME__|$HOME|g" "$in" > "$out"
    echo "[cron install] rendered $out"
  fi

  if [ "$SKIP_CRON" -eq 0 ] && [ "$DRY" -eq 0 ]; then
    launchctl unload "$out" 2>/dev/null || true
    launchctl load "$out"
    echo "[cron install] loaded com.nanobrain.$src"
  fi
done

if [ "$SKIP_CRON" -eq 1 ]; then
  echo "[cron install] --skip-cron: plists rendered, not loaded."
fi
