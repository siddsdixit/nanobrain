#!/usr/bin/env bash
# filter.sh -- exit 0 if sender should be DROPPED, 1 if kept.
# Patterns come from requires.yaml; we hard-code the same list to avoid yq at hot path.

set -eu
sender="${1:-}"
[ -n "$sender" ] || { exit 0; }

case "$sender" in
  *noreply*|*no-reply*|*notifications*|*automated*|*newsletter*) exit 0 ;;
  *@github.com|*@github.com\>) exit 0 ;;
esac
exit 1
