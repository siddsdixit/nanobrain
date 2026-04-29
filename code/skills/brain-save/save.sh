#!/usr/bin/env bash
# save.sh -- write one entry to brain/<category>.md and mirror to raw.md.
#
# Usage:
#   save.sh --category <name> --text "<body>" [--context work|personal] [--brain-dir DIR] [--no-commit]
#
# --category: decisions | learnings | projects | people | goals | self
# --context:  work | personal (default: personal)
# --no-commit: skip the git commit (used by tests)

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
NANOBRAIN_DIR="${NANOBRAIN_DIR:-$HOME/Documents/nanobrain-v2}"
REDACT="$NANOBRAIN_DIR/code/lib/redact.sh"

CATEGORY=""
TEXT=""
CONTEXT="personal"
COMMIT=1
PAGE=""
PAGE_TYPE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --category)  CATEGORY="$2"; shift 2 ;;
    --text)      TEXT="$2"; shift 2 ;;
    --context)   CONTEXT="$2"; shift 2 ;;
    --brain-dir) BRAIN_DIR="$2"; shift 2 ;;
    --no-commit) COMMIT=0; shift ;;
    --page)      PAGE="$2"; shift 2 ;;
    --type)      PAGE_TYPE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0 ;;
    *) echo "[brain-save] unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$TEXT" ] || { echo "[brain-save] --text required" >&2; exit 2; }

case "$CONTEXT" in
  work|personal) ;;
  *) echo "[brain-save] invalid context: $CONTEXT (work|personal)" >&2; exit 2 ;;
esac

# Two modes: category mode (default) or per-entity page mode.
if [ -n "$PAGE" ] || [ -n "$PAGE_TYPE" ]; then
  [ -n "$PAGE" ]      || { echo "[brain-save] --page <slug> required with --type" >&2; exit 2; }
  [ -n "$PAGE_TYPE" ] || { echo "[brain-save] --type people|projects required with --page" >&2; exit 2; }
  case "$PAGE_TYPE" in
    people|projects) ;;
    *) echo "[brain-save] invalid --type: $PAGE_TYPE (people|projects)" >&2; exit 2 ;;
  esac
  case "$PAGE" in
    ""|*/*|*..*) echo "[brain-save] invalid --page slug: $PAGE" >&2; exit 2 ;;
    *[!a-z0-9_-]*) echo "[brain-save] invalid --page slug: $PAGE (use lowercase a-z 0-9 _ -)" >&2; exit 2 ;;
  esac
else
  [ -n "$CATEGORY" ] || { echo "[brain-save] --category required" >&2; exit 2; }
  case "$CATEGORY" in
    decisions|learnings|projects|people|goals|self) ;;
    *) echo "[brain-save] invalid category: $CATEGORY (decisions|learnings|projects|people|goals|self)" >&2; exit 2 ;;
  esac
fi

mkdir -p "$BRAIN_DIR/brain"
RAW="$BRAIN_DIR/brain/raw.md"

if [ -x "$REDACT" ]; then
  TEXT=$(printf '%s' "$TEXT" | bash "$REDACT")
fi

TS=$(date '+%Y-%m-%d %H:%M')
SUMMARY=$(printf '%s' "$TEXT" | head -1 | cut -c1-60)
SOURCE_ID="save-$(date +%s)-$$"

if [ -n "$PAGE" ]; then
  TARGET="$BRAIN_DIR/brain/$PAGE_TYPE/$PAGE.md"
  REL="brain/$PAGE_TYPE/$PAGE.md"
  mkdir -p "$BRAIN_DIR/brain/$PAGE_TYPE"
  if [ ! -f "$TARGET" ]; then
    # Scaffold a minimal per-entity page (no YAML frontmatter).
    title=$(printf '%s' "$PAGE" | sed 's/[-_]/ /g')
    {
      printf '# %s\n\n' "$title"
      printf '## Context\n{context: %s}\n\n' "$CONTEXT"
      printf '## Mentions\n\n'
      printf '## See also\n'
    } > "$TARGET"
  fi
  # Append a Mention bullet under `## Mentions`. Use awk to insert after the heading.
  TMP=$(mktemp)
  awk -v line="- $TS -- $SUMMARY (source_id: $SOURCE_ID)" '
    {
      print
      if (!added && $0 == "## Mentions") {
        print line
        added = 1
      }
    }
    END {
      if (!added) {
        # No Mentions section; append one at end.
        print ""
        print "## Mentions"
        print line
      }
    }
  ' "$TARGET" > "$TMP"
  mv "$TMP" "$TARGET"
  printf '\n## %s -- mention on %s\n{context: %s, source_id: %s}\n\n%s\n' "$TS" "$REL" "$CONTEXT" "$SOURCE_ID" "$TEXT" >> "$RAW"
  echo "[brain-save] mention appended to $REL and mirrored to raw.md"
  LOG_LABEL="$REL: $SUMMARY"
  COMMIT_FILES="$REL brain/raw.md"
else
  TARGET="$BRAIN_DIR/brain/$CATEGORY.md"
  REL="brain/$CATEGORY.md"
  ENTRY=$(printf '\n### %s -- save: %s\n{context: %s, source_id: %s}\n\n%s\n' "$TS" "$SUMMARY" "$CONTEXT" "$SOURCE_ID" "$TEXT")
  printf '%s' "$ENTRY" >> "$TARGET"
  printf '%s' "$ENTRY" >> "$RAW"
  echo "[brain-save] wrote to brain/$CATEGORY.md and mirrored to raw.md"
  LOG_LABEL="$CATEGORY: $SUMMARY"
  COMMIT_FILES="$REL brain/raw.md"
fi

LOG_SH="$NANOBRAIN_DIR/code/skills/brain-log/log.sh"
if [ -x "$LOG_SH" ]; then
  BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" save "$LOG_LABEL" || true
fi

if [ "$COMMIT" -eq 1 ] && [ -d "$BRAIN_DIR/.git" ]; then
  cd "$BRAIN_DIR"
  git add $COMMIT_FILES >/dev/null 2>&1
  git commit -q -m "save: $SUMMARY" 2>/dev/null \
    && echo "[brain-save] commit: $(git rev-parse --short HEAD)" \
    || echo "[brain-save] (no commit; nothing changed?)"
fi
