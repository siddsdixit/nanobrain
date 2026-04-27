#!/usr/bin/env bash
# /brain-redact — scrub a regex pattern from the brain repo AND its git history.
# Usage: bash redact.sh '<regex-pattern>'

set -euo pipefail

PATTERN="${1:-}"
BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
STATE_DIR="${NANOBRAIN_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/nanobrain}"
LOG="$STATE_DIR/redactions.log"

if [ -z "$PATTERN" ]; then
  echo "usage: $0 '<regex-pattern>'" >&2
  echo "       e.g. $0 'sk-[A-Za-z0-9]{40,}'" >&2
  exit 2
fi

cd "$BRAIN_DIR"

# Refuse if working tree is dirty
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo "✗ working tree has uncommitted changes. Commit or stash first." >&2
  exit 3
fi

mkdir -p "$STATE_DIR"
TS="$(date +%Y%m%d-%H%M%S)"
BACKUP="$STATE_DIR/redact-backup-$TS"
mkdir -p "$BACKUP"

# Snapshot pre-rewrite HEAD for emergency rollback
git rev-parse HEAD > "$BACKUP/HEAD"
git bundle create "$BACKUP/repo.bundle" --all
echo "→ backup at $BACKUP (HEAD = $(cat "$BACKUP/HEAD"))"

# Count current matches across all history (just for the log)
MATCH_COUNT="$(git log --all -p -S "$PATTERN" --pickaxe-regex 2>/dev/null | grep -cE "$PATTERN" || echo 0)"

# Rewrite
if command -v git-filter-repo >/dev/null 2>&1; then
  echo "→ using git filter-repo"
  printf 'regex:%s==><<REDACTED:secret>>\n' "$PATTERN" > "$BACKUP/replacements.txt"
  git filter-repo --replace-text "$BACKUP/replacements.txt" --force
else
  echo "→ git filter-repo not found; falling back to git filter-branch (slow)"
  echo "  install with: brew install git-filter-repo"
  export FILTER_BRANCH_SQUELCH_WARNING=1
  git filter-branch --tree-filter \
    "find . -type f -not -path './.git/*' -exec sed -i.bak -E 's/$PATTERN/<<REDACTED:secret>>/g' {} \\; ; find . -name '*.bak' -delete" \
    --tag-name-filter cat -- --all
fi

# Force-push if origin exists
if git remote get-url origin >/dev/null 2>&1; then
  echo "→ force-pushing rewritten history"
  git push origin --force --all
  git push origin --force --tags 2>/dev/null || true
else
  echo "  (no origin remote; skipping push)"
fi

# Log the redaction (never the secret value)
{
  echo "$(date -Iseconds) pattern_hash=$(echo "$PATTERN" | shasum | awk '{print $1}') matches=$MATCH_COUNT backup=$BACKUP"
} >> "$LOG"

echo ""
echo "✓ redaction complete"
echo "  matches scrubbed: $MATCH_COUNT"
echo "  log:    $LOG"
echo "  backup: $BACKUP (kept for 30 days; safe to delete after)"
echo ""
echo "Next steps:"
echo "  1. Rotate the underlying credential at the source"
echo "  2. Notify any collaborators to re-clone or hard-reset"
