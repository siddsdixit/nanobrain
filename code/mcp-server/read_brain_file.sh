#!/usr/bin/env bash
# read_brain_file.sh -- CLI: --agent <path> --file <brain-relative-path>.
# Parses the agent's YAML frontmatter (slug, reads.files, reads.filter.context_in),
# refuses firehoses (raw.md, interactions.md, INBOX.md), and emits only entries
# whose `{context: ...}` block matches the agent's context_in list.

set -eu

AGENT=""
FILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --file)  FILE="$2";  shift 2 ;;
    *) echo "usage: read_brain_file.sh --agent PATH --file BRAIN_RELATIVE" >&2; exit 64 ;;
  esac
done

[ -n "$AGENT" ] && [ -n "$FILE" ] || { echo "[read_brain_file] need --agent and --file" >&2; exit 64; }
[ -f "$AGENT" ] || { echo "[read_brain_file] agent not found: $AGENT" >&2; exit 1; }

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"

case "$FILE" in
  *raw.md|*interactions.md|*INBOX.md|*/INBOX.md)
    echo "[read_brain_file] refused firehose: $FILE" >&2
    exit 1
    ;;
esac

# Parse YAML frontmatter (between leading --- and next ---).
fm=$(awk '
  BEGIN{in_fm=0}
  NR==1 && /^---[[:space:]]*$/ {in_fm=1; next}
  in_fm && /^---[[:space:]]*$/ {exit}
  in_fm {print}
' "$AGENT")

ctx_filter=$(printf '%s\n' "$fm" | yq -o=tsv '.reads.filter.context_in // [] | .[]' 2>/dev/null | tr '\n' ' ')
allowed_files=$(printf '%s\n' "$fm" | yq -o=tsv '.reads.files // [] | .[]' 2>/dev/null | tr '\n' ' ')

# Whitelist check before file existence (so unauthorized targets get a consistent error).
if [ -n "$(echo "$allowed_files" | tr -d ' ')" ]; then
  ok=0
  for f in $allowed_files; do
    [ "$f" = "$FILE" ] && ok=1 && break
  done
  if [ "$ok" -eq 0 ]; then
    echo "[read_brain_file] $FILE not in agent's reads.files" >&2
    exit 1
  fi
fi

target="$BRAIN_DIR/$FILE"
[ -f "$target" ] || { echo "[read_brain_file] brain file not found: $target" >&2; exit 1; }

# If no context_in declared, pass through the whole file (header passthrough).
if [ -z "$(echo "$ctx_filter" | tr -d ' ')" ]; then
  cat "$target"
  exit 0
fi

# Filter entries by their {context: ...} marker. We treat blank lines as separators.
# Each block is included if it contains a `{context: X}` where X is in $ctx_filter.
awk -v ctxs="$ctx_filter" '
  function include_block() {
    for (i = 1; i <= cnt; i++) print buf[i]
  }
  BEGIN {
    cnt = 0
    n = split(ctxs, arr, " ")
    for (i = 1; i <= n; i++) if (arr[i] != "") allowed[arr[i]] = 1
    keep = 0
  }
  /^[[:space:]]*$/ {
    if (cnt > 0 && keep) include_block()
    if (cnt > 0) print ""
    cnt = 0; keep = 0
    next
  }
  {
    cnt++; buf[cnt] = $0
    # Use a brace-free pattern: BSD awk treats { } as interval-expression metachars.
    if (match($0, /context: *[a-z]+/)) {
      tok = substr($0, RSTART, RLENGTH)
      sub(/context: */, "", tok)
      if (tok in allowed) keep = 1
    }
  }
  END {
    if (cnt > 0 && keep) include_block()
  }
' "$target"

# Log access.
log_dir="$BRAIN_DIR/data/_mcp"
mkdir -p "$log_dir"
printf '%s\tagent=%s\tfile=%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "$AGENT" "$FILE" >> "$log_dir/access.log"
