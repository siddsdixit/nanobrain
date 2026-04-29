#!/usr/bin/env bash
# filter.sh -- exit 0 to drop, 1 to keep. Drops trash and templates.
set -eu
path="${1:-}"
case "$path" in
  *Trash*|*trash*|*Templates/*|*template_*) exit 0 ;;
esac
exit 1
