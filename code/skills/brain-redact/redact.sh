#!/usr/bin/env bash
# redact.sh -- scan brain for secrets, or scrub a regex from git history.

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
MODE="scan"
PATTERN=""
FORCE_PUSH=0

while [ $# -gt 0 ]; do
  case "$1" in
    --scan)        MODE="scan"; shift ;;
    --scrub)       MODE="scrub"; PATTERN="${2:-}"; shift 2 ;;
    --force-push)  FORCE_PUSH=1; shift ;;
    -h|--help)     sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "[brain-redact] unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Patterns mirror code/lib/redact.sh.
PATTERNS='sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{36,}|eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|[Bb]earer[[:space:]]+[A-Za-z0-9._-]{20,}|(password|passwd|pwd|token|api[_-]?key|secret)[[:space:]]*[:=][[:space:]]*[^[:space:]]+'

case "$MODE" in
  scan)
    SCAN_DIR="$BRAIN_DIR/brain"
    [ -d "$SCAN_DIR" ] || { echo "[brain-redact] no brain dir: $SCAN_DIR" >&2; exit 2; }
    HITS=$(grep -REn -- "$PATTERNS" "$SCAN_DIR" 2>/dev/null || true)
    if [ -n "$HITS" ]; then
      echo "[brain-redact] secret patterns found:"
      printf '%s\n' "$HITS"
      exit 1
    fi
    echo "[brain-redact] clean"
    exit 0
    ;;
  scrub)
    [ -n "$PATTERN" ] || { echo "[brain-redact] --scrub needs a regex" >&2; exit 2; }
    [ -d "$BRAIN_DIR/.git" ] || { echo "[brain-redact] not a git repo: $BRAIN_DIR" >&2; exit 2; }

    cd "$BRAIN_DIR"
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      echo "[brain-redact] working tree dirty, commit or stash first" >&2
      exit 3
    fi

    if [ "$FORCE_PUSH" -eq 0 ]; then
      MATCHES=$(git log --all -p -S "$PATTERN" --pickaxe-regex 2>/dev/null | grep -cE "$PATTERN" || true)
      echo "[brain-redact] DRY RUN: pattern=$PATTERN, history matches=$MATCHES"
      echo "[brain-redact] re-run with --force-push to rewrite history"
      exit 0
    fi

    export FILTER_BRANCH_SQUELCH_WARNING=1
    # Use sed in tree-filter; portable across macOS bash 3.2.
    git filter-branch -f --tree-filter \
      "find . -type f -not -path './.git/*' -exec sed -i.bak -E 's|$PATTERN|[REDACTED]|g' {} \\; ; find . -name '*.bak' -delete" \
      --tag-name-filter cat -- --all >/dev/null 2>&1 \
      || { echo "[brain-redact] filter-branch failed" >&2; exit 4; }

    # Drop refs/original and gc the unreachable blobs.
    for r in $(git for-each-ref --format='%(refname)' refs/original/ 2>/dev/null); do
      git update-ref -d "$r" 2>/dev/null || true
    done
    git reflog expire --expire=now --all >/dev/null 2>&1 || true
    git gc --prune=now --aggressive >/dev/null 2>&1 || true

    echo "[brain-redact] history rewritten. Force-push manually if origin exists:"
    echo "  git -C $BRAIN_DIR push origin --force --all"

    LOG_SH="${NANOBRAIN_DIR:-$HOME/Documents/nanobrain-v2}/code/skills/brain-log/log.sh"
    if [ -x "$LOG_SH" ]; then
      BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" scrub "history rewritten for pattern" || true
    fi
    exit 0
    ;;
esac
