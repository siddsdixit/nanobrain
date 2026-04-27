#!/usr/bin/env bash
# build.sh — regenerate brain/_graph.md from [[ ]] backlinks across brain/*.md.
# Idempotent. macOS bash 3.2 compatible.

set -euo pipefail

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
SCAN_DIR="$BRAIN_DIR/brain"
GRAPH="$SCAN_DIR/_graph.md"
TMP="$(mktemp)"
REFS="$(mktemp)"
TS="$(date +%Y-%m-%d\ %H:%M)"

cleanup() { rm -f "$TMP" "$REFS"; }
trap cleanup EXIT

# Header
{
  echo "# Brain Graph (auto-generated)"
  echo
  echo "_Last regenerated: $TS. Built by \`code/skills/brain-graph/build.sh\`. Never hand-edit. See SKILL.md for the \`[[ ]]\` convention._"
  echo
  echo "## Entities (sorted by reference count)"
  echo
} > "$TMP"

# Find files to scan and extract [[entity]] references with file:line.
# Skip: raw.md, interactions.md, _graph.md, archive/.
find "$SCAN_DIR" -maxdepth 2 -name '*.md' \
  ! -name 'raw.md' \
  ! -name 'interactions.md' \
  ! -name '_graph.md' \
  ! -path '*/archive/*' \
  -print0 2>/dev/null \
| xargs -0 awk '
    {
      line = $0
      while (match(line, /\[\[[^\]]+\]\]/)) {
        ent = substr(line, RSTART+2, RLENGTH-4)
        lower = tolower(ent)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", lower)
        if (length(lower) > 0 && length(lower) < 80) {
          print lower "\t" ent "\t" FILENAME ":" NR
        }
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' 2>/dev/null | sort > "$REFS"

# Group by entity, count, emit sections sorted by count desc
if [ -s "$REFS" ]; then
  awk -F'\t' '
    {
      key = $1
      if (!(key in display)) display[key] = $2
      count[key]++
      refs[key] = (refs[key] ? refs[key] "\n" : "") "- " $3
    }
    END {
      for (k in count) print count[k] "\t" display[k] "\t" refs[k]
    }
  ' "$REFS" \
  | sort -t$'\t' -k1,1 -rn -k2,2 \
  | while IFS=$'\t' read -r cnt disp rs; do
      printf '### [[%s]] (%s)\n\n' "$disp" "$cnt" >> "$TMP"
      printf '%b\n\n' "$rs" | sed "s|$BRAIN_DIR/||g" >> "$TMP"
    done
else
  echo "_(no \`[[ ]]\` references found yet — start adding them in brain entries)_" >> "$TMP"
  echo >> "$TMP"
fi

# Footer
{
  echo
  echo "## How to query"
  echo
  echo '`/brain links <entity name>` — returns the section above for that entity.'
  echo
  echo '`grep -A5 "^### \[\[" brain/_graph.md | less` — manual scan.'
} >> "$TMP"

mv "$TMP" "$GRAPH"

ENT_COUNT="$(grep -c '^### \[\[' "$GRAPH" 2>/dev/null || echo 0)"
echo "[brain-graph] regenerated: $ENT_COUNT entities → $GRAPH"
