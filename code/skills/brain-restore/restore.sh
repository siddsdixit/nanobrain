#!/usr/bin/env bash
# restore.sh -- non-destructive restore. Branches; never resets.

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
TARGET=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --brain-dir) BRAIN_DIR="$2"; shift 2 ;;
    --target)    TARGET="$2";    shift 2 ;;
    --hard|--force|--reset)
      echo "[brain-restore] $1 is refused; brain-restore is non-destructive." >&2
      exit 65
      ;;
    *) echo "[brain-restore] unknown arg: $1" >&2; exit 64 ;;
  esac
done

cd "$BRAIN_DIR" || { echo "[brain-restore] not a directory: $BRAIN_DIR" >&2; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "[brain-restore] not a git repo" >&2; exit 1; }

echo "tags:"
git tag --sort=-creatordate | head -n 10 | sed 's/^/  /' || true
echo "recent commits:"
git log --oneline -n 20 | sed 's/^/  /'

if [ -z "$TARGET" ]; then
  printf 'restore to (sha or tag, blank to abort): '
  read -r TARGET || TARGET=""
fi
[ -n "$TARGET" ] || { echo "[brain-restore] aborted"; exit 0; }

# Verify target.
sha=$(git rev-parse --verify "$TARGET" 2>/dev/null || true)
[ -n "$sha" ] || { echo "[brain-restore] unknown target: $TARGET" >&2; exit 1; }

short=$(printf '%s' "$sha" | cut -c1-7)
branch="restore/$short"
git checkout -b "$branch" "$sha"
echo "[brain-restore] checked out $branch at $sha (no destructive ops performed)"
bash "${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}/code/lib/log_op.sh" \
  restore "branch=$branch from=$short"
