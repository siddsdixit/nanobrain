#!/usr/bin/env bash
# autosave.sh -- 30-min commit+push safety net. Tool-agnostic.
# Exits 0 even if there is nothing to commit (safe in cron and tests).

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
[ -d "$BRAIN_DIR" ] || { echo "[autosave] BRAIN_DIR missing: $BRAIN_DIR" >&2; exit 0; }
cd "$BRAIN_DIR"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "[autosave] not a git repo, skipping" >&2; exit 0; }

logs_dir="$BRAIN_DIR/data/_logs"
mkdir -p "$logs_dir"
push_fail_marker="$logs_dir/push_failed.txt"

if [ -n "$(git status --porcelain)" ]; then
  git add -A
  git commit -m "autosave: $(date '+%Y-%m-%d %H:%M')" >/dev/null
  if git remote get-url origin >/dev/null 2>&1; then
    push_err=$(mktemp)
    if git push --quiet origin HEAD 2>"$push_err"; then
      rm -f "$push_err" "$push_fail_marker"
      echo "[autosave] committed + pushed"
    else
      err_msg=$(cat "$push_err")
      rm -f "$push_err"
      ts=$(date '+%Y-%m-%d %H:%M')
      printf '%s\n%s\n' "$ts" "$err_msg" > "$push_fail_marker"
      echo "[autosave] committed locally but PUSH FAILED -- see $push_fail_marker" >&2
      echo "[autosave] error: $err_msg" >&2
    fi
  else
    echo "[autosave] committed (no remote configured)"
  fi
else
  echo "[autosave] clean"
fi
exit 0
