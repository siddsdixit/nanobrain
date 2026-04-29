#!/usr/bin/env bash
# graph.sh -- regenerate brain/_graph.md from [[ ]] references. Idempotent.

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
SCAN_DIR="$BRAIN_DIR/brain"
GRAPH="$SCAN_DIR/_graph.md"

[ -d "$SCAN_DIR" ] || { echo "[brain-graph] no brain dir: $SCAN_DIR" >&2; exit 2; }

TMP=$(mktemp)
REFS=$(mktemp)
trap 'rm -f "$TMP" "$REFS"' EXIT

TS=$(date '+%Y-%m-%d %H:%M')

{
  echo "# Brain Graph (auto-generated)"
  echo
  echo "_Last regenerated: $TS. Built by code/skills/brain-graph/graph.sh. Do not hand-edit._"
  echo
} > "$TMP"

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
          print lower "\t" ent "\t" FILENAME ":" FNR
        }
        line = substr(line, RSTART + RLENGTH)
      }
    }
  ' 2>/dev/null | sort > "$REFS"

if [ -s "$REFS" ]; then
  # Aggregate by entity. Use a non-newline sentinel for multi-line refs so the
  # while-read loop below sees one record per entity (newlines would split it).
  awk -F'\t' '
    {
      key = $1
      if (!(key in display)) display[key] = $2
      count[key]++
      refs[key] = (refs[key] ? refs[key] "<NL>" : "") "- " $3
    }
    END {
      for (k in count) print count[k] "\t" display[k] "\t" refs[k]
    }
  ' "$REFS" \
  | sort -t"$(printf '\t')" -k1,1 -rn -k2,2 \
  | while IFS="$(printf '\t')" read -r cnt disp rs; do
      printf '## [[%s]] (%s refs)\n\n' "$disp" "$cnt" >> "$TMP"
      # Expand the <NL> sentinel back into real newlines, then strip BRAIN_DIR prefix.
      printf '%s' "$rs" \
        | awk -v RS='<NL>' '{print}' \
        | sed "s|$BRAIN_DIR/||g" >> "$TMP"
      printf '\n' >> "$TMP"
    done
else
  echo "_(no [[ ]] references found yet)_" >> "$TMP"
  echo >> "$TMP"
fi

mv "$TMP" "$GRAPH"
trap - EXIT
rm -f "$REFS"

ENT=$(grep -c '^## \[\[' "$GRAPH" 2>/dev/null || echo 0)
echo "[brain-graph] regenerated: $ENT entities -> $GRAPH"
bash "${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}/code/lib/log_op.sh" \
  graph "rebuilt _graph.md ($ENT entities)"
