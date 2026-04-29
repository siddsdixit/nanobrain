#!/usr/bin/env bash
# dispatch.sh -- distill INBOX into brain files via claude -p (or stub).

set -eu

src="${1:-}"
[ -n "$src" ] || { echo "usage: dispatch.sh <source>" >&2; exit 64; }

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"

inbox="$BRAIN_DIR/data/$src/INBOX.md"
[ -f "$inbox" ] || { echo "[distill] no INBOX for $src: $inbox" >&2; exit 0; }

distill_md="$FRAMEWORK_DIR/code/sources/$src/distill.md"
[ -f "$distill_md" ] || { echo "[distill] missing distill.md for $src" >&2; exit 64; }

raw_out=""
if [ -n "${NANOBRAIN_DISTILL_STUB:-}" ]; then
  [ -f "$NANOBRAIN_DISTILL_STUB" ] || { echo "[distill] stub missing" >&2; exit 3; }
  # Execute the stub (it's a bash script that produces the distill output on stdout,
  # mirroring the claude -p contract). cat-ing would dump source code including
  # heredoc terminators like EOM into the brain.
  if [ -x "$NANOBRAIN_DISTILL_STUB" ]; then
    raw_out=$(printf '' | "$NANOBRAIN_DISTILL_STUB")
  else
    raw_out=$(printf '' | bash "$NANOBRAIN_DISTILL_STUB")
  fi
else
  if ! command -v claude >/dev/null 2>&1; then
    echo "[distill] claude CLI not found and no NANOBRAIN_DISTILL_STUB set" >&2
    exit 3
  fi
  prompt=$(cat "$distill_md"; echo; echo "INBOX content follows:"; echo; cat "$inbox")
  raw_out=$(printf '%s' "$prompt" | claude -p 2>/dev/null || true)
fi

[ -n "$raw_out" ] || { echo "[distill] empty output, nothing to do"; exit 0; }

allowed_targets="brain/decisions.md brain/learnings.md brain/people.md brain/projects.md"
# Per-entity pages allowed under brain/people/<slug>.md and brain/projects/<slug>.md.
is_allowed_target() {
  local t="$1"
  for a in $allowed_targets; do
    [ "$a" = "$t" ] && return 0
  done
  case "$t" in
    brain/people/*.md|brain/projects/*.md)
      # slug must be safe: lowercase letters, digits, dashes, underscores.
      local slug
      slug=${t##*/}
      slug=${slug%.md}
      case "$slug" in
        ""|*/*|*..*) return 1 ;;
        *)
          case "$slug" in
            *[!a-z0-9_-]*) return 1 ;;
            *)             return 0 ;;
          esac ;;
      esac ;;
  esac
  return 1
}
mkdir -p "$BRAIN_DIR/brain"
raw_mirror="$BRAIN_DIR/brain/raw.md"

written_files=""
ts=$(date '+%Y-%m-%d %H:%M')

# Parse blocks separated by lines containing only '>>>'.
# Use awk to split into temp files.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

printf '%s\n' "$raw_out" | awk -v d="$tmpdir" '
  BEGIN { n = 0; f = sprintf("%s/blk.%03d", d, n) }
  /^>>>[[:space:]]*$/ { close(f); n++; f = sprintf("%s/blk.%03d", d, n); next }
  { print > f }
'

for blk in "$tmpdir"/blk.*; do
  [ -s "$blk" ] || continue
  target=$(awk -F': ' '/^target_path:/ {print $2; exit}' "$blk" | tr -d '\r')
  if [ -z "$target" ]; then
    continue
  fi
  if ! is_allowed_target "$target"; then
    echo "[distill] rejecting disallowed target: $target" >&2
    continue
  fi
  outfile="$BRAIN_DIR/$target"
  mkdir -p "$(dirname "$outfile")"
  # Body: skip the target_path line. Distill is responsible for emitting its
  # own headers; do not double-wrap with a dispatcher-level "## TS (from src)".
  # Provenance lives in raw.md mirror and the source_id tag inside the entry.
  {
    printf '\n'
    awk 'NR==1 && /^target_path:/ {next} {print}' "$blk"
  } >> "$outfile"
  # raw.md mirror keeps full provenance header (dispatcher provides this).
  {
    printf '\n## %s (from %s, target=%s)\n' "$ts" "$src" "$target"
    awk 'NR==1 && /^target_path:/ {next} {print}' "$blk"
  } >> "$raw_mirror"
  written_files="$written_files $outfile"
done

if [ -n "$written_files" ]; then
  ( cd "$BRAIN_DIR" && git add -A && git commit -m "distill: $src" >/dev/null 2>&1 ) || true
  echo "[distill] wrote:$written_files"
  count=$(printf '%s\n' "$written_files" | wc -w | tr -d ' ')
  LOG_SH="$FRAMEWORK_DIR/code/skills/brain-log/log.sh"
  [ -x "$LOG_SH" ] && BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" distill "$src: $count brain files updated" || true
else
  echo "[distill] no valid blocks parsed"
fi
