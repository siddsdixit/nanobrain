#!/usr/bin/env bash
# spawn.sh -- draft a context-scoped agent into code/agents/<slug>.md.
#
# Args (or env): --slug, --role, --reads (comma list), --context (work|personal|both)
# Optional: --install-symlink

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
NANOBRAIN_DIR="${NANOBRAIN_DIR:-$HOME/Documents/nanobrain-v2}"

SLUG="${NANOBRAIN_SPAWN_SLUG:-}"
ROLE="${NANOBRAIN_SPAWN_ROLE:-}"
READS="${NANOBRAIN_SPAWN_READS:-brain/self.md}"
CONTEXT="${NANOBRAIN_SPAWN_CONTEXT:-personal}"
INSTALL_SYMLINK=0

while [ $# -gt 0 ]; do
  case "$1" in
    --slug)             SLUG="$2"; shift 2 ;;
    --role)             ROLE="$2"; shift 2 ;;
    --reads)            READS="$2"; shift 2 ;;
    --context)          CONTEXT="$2"; shift 2 ;;
    --install-symlink)  INSTALL_SYMLINK=1; shift ;;
    -h|--help)          sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "[brain-spawn] unknown arg: $1" >&2; exit 2 ;;
  esac
done

[ -n "$SLUG" ] || { echo "[brain-spawn] --slug required" >&2; exit 2; }
[ -n "$ROLE" ] || { echo "[brain-spawn] --role required" >&2; exit 2; }

# Slug must be kebab-case: lowercase letters, digits, hyphens. No spaces.
case "$SLUG" in
  *[!a-z0-9-]*|""|-*|*-) echo "[brain-spawn] invalid slug: $SLUG (kebab-case only)" >&2; exit 2 ;;
esac

case "$CONTEXT" in
  work|personal|both) ;;
  *) echo "[brain-spawn] invalid context: $CONTEXT (work|personal|both)" >&2; exit 2 ;;
esac

# Refuse firehose reads.
case ",$READS," in
  *,*raw.md*,*|*,*interactions.md*,*)
    echo "[brain-spawn] reads cannot include raw.md or interactions.md" >&2
    exit 2 ;;
esac

AGENT_DIR="$NANOBRAIN_DIR/code/agents"
TEMPLATE="$AGENT_DIR/_TEMPLATE.md"
TARGET="$AGENT_DIR/$SLUG.md"

[ -f "$TEMPLATE" ] || { echo "[brain-spawn] template missing: $TEMPLATE" >&2; exit 2; }
[ -f "$TARGET" ] && { echo "[brain-spawn] agent already exists: $TARGET" >&2; exit 3; }

# Build context_in list
if [ "$CONTEXT" = "both" ]; then
  CTX_LINES=$(printf '      - work\n      - personal')
else
  CTX_LINES="      - $CONTEXT"
fi

# Build reads.files list
READS_LINES=""
IFS=','
for f in $READS; do
  f_trim=$(printf '%s' "$f" | sed 's/^ *//; s/ *$//')
  [ -z "$f_trim" ] && continue
  if [ -z "$READS_LINES" ]; then
    READS_LINES="    - $f_trim"
  else
    READS_LINES="$READS_LINES
    - $f_trim"
  fi
done
unset IFS

mkdir -p "$AGENT_DIR"

{
  printf -- '---\n'
  printf 'slug: %s\n' "$SLUG"
  printf 'reads:\n'
  printf '  files:\n'
  printf '%s\n' "$READS_LINES"
  printf '  filter:\n'
  printf '    context_in:\n'
  printf '%s\n' "$CTX_LINES"
  printf -- '---\n\n'
  printf '# %s\n\n' "$SLUG"
  printf '%s\n\n' "$ROLE"
  printf 'Reads only the files listed in frontmatter, filtered to context: %s.\n' "$CONTEXT"
} > "$TARGET"

echo "[brain-spawn] wrote $TARGET"

if [ "$INSTALL_SYMLINK" -eq 1 ]; then
  mkdir -p "$HOME/.claude/agents"
  ln -sf "$TARGET" "$HOME/.claude/agents/$SLUG.md"
  echo "[brain-spawn] symlinked to ~/.claude/agents/$SLUG.md"
fi

LOG_SH="$NANOBRAIN_DIR/code/skills/brain-log/log.sh"
if [ -x "$LOG_SH" ]; then
  BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" spawn "$SLUG ($CONTEXT) $ROLE" || true
fi
