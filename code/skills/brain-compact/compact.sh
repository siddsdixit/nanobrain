#!/usr/bin/env bash
# compact.sh -- dedupe dated headers, archive >365d entries, regen graph, verify hash, commit.

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
NANOBRAIN_DIR="${NANOBRAIN_DIR:-$HOME/Documents/nanobrain-v2}"
NO_COMMIT="${NANOBRAIN_COMPACT_NO_COMMIT:-0}"

[ -d "$BRAIN_DIR/brain" ] || { echo "[brain-compact] no brain dir: $BRAIN_DIR/brain" >&2; exit 2; }

ARCHIVE_DIR="$BRAIN_DIR/brain/archive"
mkdir -p "$ARCHIVE_DIR"

# 365 days ago in seconds (portable: macOS date -v vs GNU date -d).
if date -v-365d +%Y-%m-%d >/dev/null 2>&1; then
  CUTOFF=$(date -v-365d +%Y-%m-%d)
else
  CUTOFF=$(date -d '365 days ago' +%Y-%m-%d)
fi

process_file() {
  f="$1"
  [ -f "$f" ] || return 0
  base=$(basename "$f" .md)

  awk -v cutoff="$CUTOFF" -v archive_dir="$ARCHIVE_DIR" -v base="$base" '
    function flush_block(   archive_path) {
      if (cur_header == "") return
      key = cur_header
      # Dedupe: skip if header already seen.
      if (key in seen) return
      seen[key] = 1
      # Archive if cur_date is set and older than cutoff.
      if (cur_date != "" && cur_date < cutoff) {
        ym = substr(cur_date, 1, 7)
        archive_path = archive_dir "/" base "-" ym ".md"
        printf "%s\n", cur_block >> archive_path
        close(archive_path)
      } else {
        printf "%s\n", cur_block > out
      }
    }
    BEGIN {
      cur_header = ""; cur_block = ""; cur_date = ""
    }
    /^### / {
      if (cur_header != "") flush_block()
      cur_header = $0
      cur_block = $0
      cur_date = ""
      if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
        cur_date = substr($0, RSTART, RLENGTH)
      }
      next
    }
    {
      if (cur_header == "") {
        # Pre-header preamble; pass through unchanged.
        print > out
      } else {
        cur_block = cur_block "\n" $0
      }
    }
    END {
      if (cur_header != "") flush_block()
    }
  ' out="$f.tmp" "$f"

  if [ -f "$f.tmp" ]; then
    mv "$f.tmp" "$f"
  fi
}

for name in decisions learnings projects; do
  process_file "$BRAIN_DIR/brain/$name.md"
done

# Regenerate graph.
GRAPH_SH="$NANOBRAIN_DIR/code/skills/brain-graph/graph.sh"
if [ -x "$GRAPH_SH" ]; then
  BRAIN_DIR="$BRAIN_DIR" bash "$GRAPH_SH" >/dev/null 2>&1 || echo "[brain-compact] graph regen failed (non-fatal)"
fi

# Verify hash; drift logged not blocking.
HASH_SH="$NANOBRAIN_DIR/code/skills/brain-hash/hash.sh"
if [ -x "$HASH_SH" ] && [ -f "$BRAIN_DIR/BRAIN_HASH.txt" ]; then
  if ! BRAIN_DIR="$BRAIN_DIR" bash "$HASH_SH" verify >/dev/null 2>&1; then
    echo "[brain-compact] hash drift detected (expected after compaction; rebuild with hash.sh build)"
  fi
fi

LOG_SH="$NANOBRAIN_DIR/code/skills/brain-log/log.sh"
if [ -x "$LOG_SH" ]; then
  BRAIN_DIR="$BRAIN_DIR" bash "$LOG_SH" compact "dedupe + archive >365d" || true
fi

# Commit.
if [ "$NO_COMMIT" -eq 0 ] && [ -d "$BRAIN_DIR/.git" ]; then
  cd "$BRAIN_DIR"
  git add brain/ >/dev/null 2>&1
  git commit -q -m "compact: dedupe + archive >365d" 2>/dev/null \
    && echo "[brain-compact] commit: $(git rev-parse --short HEAD)" \
    || echo "[brain-compact] (no commit; nothing changed)"
else
  echo "[brain-compact] done (no commit)"
fi
