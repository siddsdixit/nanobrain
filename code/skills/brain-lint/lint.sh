#!/usr/bin/env bash
# lint.sh -- quality report for a brain. No auto-fix.

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
NANOBRAIN_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"

STRICT=0
for a in "$@"; do
  case "$a" in
    --strict) STRICT=1 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "[brain-lint] unknown arg: $a" >&2; exit 2 ;;
  esac
done

SCAN="$BRAIN_DIR/brain"
if [ ! -d "$SCAN" ]; then
  echo "[brain-lint] no brain dir: $SCAN" >&2
  exit 0
fi

# Files to scan for issues (excludes raw/log/graph/index).
list_brain_files() {
  find "$SCAN" -maxdepth 2 -name '*.md' \
    ! -name 'raw.md' \
    ! -name 'log.md' \
    ! -name '_graph.md' \
    ! -name 'index.md' \
    ! -path '*/archive/*' \
    2>/dev/null
}

# All brain files used as ref targets (without exclusions, for [[ref]] resolution).
list_all_brain_files() {
  find "$SCAN" -maxdepth 2 -name '*.md' ! -path '*/archive/*' 2>/dev/null
}

ORPHANS=""
BROKEN=""
TODOS=""
DUPES=""
MISSING_CTX=""

# ---------- 1. Orphan pages ----------
collect_orphans() {
  for dir in people projects; do
    [ -d "$SCAN/$dir" ] || continue
    for f in "$SCAN/$dir"/*.md; do
      [ -f "$f" ] || continue
      slug=$(basename "$f" .md)
      # Title from first `# Title` line (used as alt match).
      title=$(awk '/^# / {sub(/^# /, ""); print; exit}' "$f")
      hits=0
      while IFS= read -r other; do
        [ -z "$other" ] && continue
        [ "$other" = "$f" ] && continue
        if grep -Eq "\[\[[^]]*$slug[^]]*\]\]" "$other" 2>/dev/null; then
          hits=$((hits+1))
        elif [ -n "$title" ] && grep -Fq "[[$title]]" "$other" 2>/dev/null; then
          hits=$((hits+1))
        fi
      done <<EOF
$(list_all_brain_files)
EOF
      if [ "$hits" -eq 0 ]; then
        ORPHANS="$ORPHANS${ORPHANS:+
}$dir/$slug.md"
      fi
    done
  done
}

# ---------- 2. Unresolved [[refs]] ----------
# A ref is "resolved" if its lower-cased token matches:
#   - a category page basename (self|goals|decisions|learnings|projects|people|interactions)
#   - an entity slug under brain/people/<slug>.md or brain/projects/<slug>.md
#   - the title (case-insensitive) of any per-entity page
#
# A ref that does NOT resolve is reported only if the same entity appears in
# 2+ distinct files (a network of mentions worth turning into a page). Single
# occurrences are not noise: someone literally named in passing, no page yet.
collect_broken_refs() {
  # Build a set of valid tokens.
  valid=$(mktemp); trap 'rm -f "$valid"' RETURN
  for n in self goals decisions learnings projects people interactions; do
    echo "$n" >> "$valid"
  done
  for dir in people projects; do
    [ -d "$SCAN/$dir" ] || continue
    for f in "$SCAN/$dir"/*.md; do
      [ -f "$f" ] || continue
      slug=$(basename "$f" .md)
      printf '%s\n' "$slug" >> "$valid"
      title=$(awk '/^# / {sub(/^# /, ""); print; exit}' "$f")
      [ -n "$title" ] && printf '%s\n' "$title" | tr '[:upper:]' '[:lower:]' >> "$valid"
    done
  done
  sort -u "$valid" -o "$valid"

  # Extract refs from scannable files.
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    awk '
      {
        line = $0
        while (match(line, /\[\[[^]]+\]\]/)) {
          ent = substr(line, RSTART+2, RLENGTH-4)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", ent)
          print ent
          line = substr(line, RSTART + RLENGTH)
        }
      }
    ' "$f" 2>/dev/null | while IFS= read -r ent; do
      [ -z "$ent" ] && continue
      lc=$(printf '%s' "$ent" | tr '[:upper:]' '[:lower:]')
      # Try exact lower-case match, or strip simple suffixes.
      if grep -Fxq "$lc" "$valid"; then
        :
      else
        # Try last word as slug (e.g. "Jane Doe" -> "jane-doe", or "doe").
        slugged=$(printf '%s' "$lc" | tr ' ' '-')
        if grep -Fxq "$slugged" "$valid"; then
          :
        else
          # Stage candidate. Final filter (multi-file occurrence) applied below.
          rel=${f#$BRAIN_DIR/}
          printf '%s\t%s: [[%s]]\n' "$lc" "$rel" "$ent" >> "$BROKEN_CAND"
        fi
      fi
    done
  done <<EOF
$(list_brain_files)
EOF
}

# ---------- 3. TODO/FIXME ----------
collect_todos() {
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    grep -nE '\b(TODO|FIXME|XXX)\b' "$f" 2>/dev/null | while IFS= read -r hit; do
      rel=${f#$BRAIN_DIR/}
      printf '%s:%s\n' "$rel" "$hit" >> "$TODOS_TMP"
    done
  done <<EOF
$(list_brain_files)
EOF
}

# ---------- 4. Duplicate entry headers ----------
collect_dupes() {
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    # Match `### YYYY-MM-DD HH:MM` prefix.
    grep -E '^### [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}' "$f" 2>/dev/null \
      | sort | uniq -c | awk '$1 > 1 { $1=""; sub(/^ +/, ""); print }' \
      | while IFS= read -r dupline; do
          [ -z "$dupline" ] && continue
          rel=${f#$BRAIN_DIR/}
          printf '%s: %s\n' "$rel" "$dupline" >> "$DUPES_TMP"
        done
  done <<EOF
$(list_brain_files)
EOF
}

# ---------- 5. Missing context tag ----------
# An "entry" is a `### ...` header. Each entry must have `{context: ...}`
# somewhere before the next `### ` header.
collect_missing_ctx() {
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    awk -v file="${f#$BRAIN_DIR/}" '
      /^### / {
        if (in_entry && !has_ctx) print file ": " title
        in_entry = 1; has_ctx = 0; title = $0
        next
      }
      /\{context:/ { if (in_entry) has_ctx = 1 }
      END {
        if (in_entry && !has_ctx) print file ": " title
      }
    ' "$f" 2>/dev/null >> "$MISSING_TMP"
  done <<EOF
$(list_brain_files)
EOF
}

BROKEN_TMP=$(mktemp); : > "$BROKEN_TMP"
BROKEN_CAND=$(mktemp); : > "$BROKEN_CAND"
TODOS_TMP=$(mktemp);  : > "$TODOS_TMP"
DUPES_TMP=$(mktemp);  : > "$DUPES_TMP"
MISSING_TMP=$(mktemp); : > "$MISSING_TMP"
trap 'rm -f "$BROKEN_TMP" "$BROKEN_CAND" "$TODOS_TMP" "$DUPES_TMP" "$MISSING_TMP"' EXIT

collect_orphans
collect_broken_refs
collect_todos
collect_dupes
collect_missing_ctx

# Filter unresolved refs: only those mentioned in 2+ distinct files become
# "broken" (worth surfacing). Single occurrences are quiet.
if [ -s "$BROKEN_CAND" ]; then
  # Count distinct files per lowercased entity. Format: "lc<TAB>rel: [[orig]]"
  awk -F'\t' '{ split($2, a, ":"); files[$1, a[1]] = 1; lc[$1]++; out[$1] = (out[$1] ? out[$1] "\n" : "") $2 }
              END {
                for (k in lc) {
                  cnt = 0
                  for (kk in files) { split(kk, parts, SUBSEP); if (parts[1] == k) cnt++ }
                  if (cnt >= 2) print out[k]
                }
              }' "$BROKEN_CAND" >> "$BROKEN_TMP"
fi

# Read tmp files into vars (for orphans we already built ORPHANS inline).
BROKEN=$(cat "$BROKEN_TMP")
TODOS=$(cat "$TODOS_TMP")
DUPES=$(cat "$DUPES_TMP")
MISSING_CTX=$(cat "$MISSING_TMP")

count_lines() { [ -z "$1" ] && echo 0 || printf '%s\n' "$1" | wc -l | tr -d ' '; }

n_orphans=$(count_lines "$ORPHANS")
n_broken=$(count_lines "$BROKEN")
n_todos=$(count_lines "$TODOS")
n_dupes=$(count_lines "$DUPES")
n_missing=$(count_lines "$MISSING_CTX")

total=$((n_orphans + n_broken + n_todos + n_dupes + n_missing))

print_section() {
  local title="$1" body="$2"
  printf '== %s ==\n' "$title"
  if [ -z "$body" ]; then
    echo "  (none)"
  else
    printf '%s\n' "$body" | sed 's/^/  /'
  fi
  printf '\n'
}

echo "== brain-lint =="
echo "BRAIN_DIR=$BRAIN_DIR"
echo

print_section "Orphan pages ($n_orphans)" "$ORPHANS"
print_section "Broken refs ($n_broken)" "$BROKEN"
print_section "TODO/FIXME ($n_todos)" "$TODOS"
print_section "Duplicate headers ($n_dupes)" "$DUPES"
print_section "Missing context tag (warn) ($n_missing)" "$MISSING_CTX"

echo "total issues: $total"

LOG_SH="$NANOBRAIN_DIR/code/skills/brain-log/log.sh"
if [ -x "$LOG_SH" ]; then
  BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" lint "$total issues" || true
fi

if [ "$STRICT" -eq 1 ] && [ "$total" -gt 0 ]; then
  exit 1
fi
exit 0
