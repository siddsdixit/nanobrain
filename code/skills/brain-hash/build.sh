#!/usr/bin/env bash
# build.sh — compute brain integrity hash. Regenerate (default) or verify.
# Per ADR-0013 T15 + SAFETY.md S16.

set -euo pipefail

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
HASH_FILE="$BRAIN_DIR/BRAIN_HASH.txt"
MODE="${1:-build}"

# Files to include in hash: stable distilled corpus only.
# Exclude firehoses (raw.md, interactions.md), auto-generated (_graph.md), archive/.
compute_hash() {
  find "$BRAIN_DIR/brain" -type f -name '*.md' \
    ! -name 'raw.md' \
    ! -name 'interactions.md' \
    ! -name '_graph.md' \
    ! -path '*/archive/*' \
    -print0 \
  | xargs -0 shasum -a 256 \
  | awk '{print $1}' \
  | sort \
  | shasum -a 256 \
  | awk '{print $1}'
}

case "$MODE" in
  build|regenerate)
    NEW="$(compute_hash)"
    {
      echo "# Brain integrity hash"
      echo
      echo "Generated: $(date +%Y-%m-%dT%H:%M:%S)"
      echo "Algorithm: SHA-256 of sorted SHA-256s of stable corpus files"
      echo "Files included: brain/**/*.md EXCEPT raw.md, interactions.md, _graph.md, archive/*"
      echo
      echo "$NEW"
    } > "$HASH_FILE"
    echo "[brain-hash] hash regenerated: ${NEW:0:16}..."
    ;;
  verify|check)
    if [ ! -f "$HASH_FILE" ]; then
      echo "[brain-hash] no hash file at $HASH_FILE — run without --verify to create one"
      exit 1
    fi
    STORED="$(grep -E '^[a-f0-9]{64}$' "$HASH_FILE" | head -1)"
    NEW="$(compute_hash)"
    if [ "$STORED" = "$NEW" ]; then
      echo "[brain-hash] OK — corpus matches stored hash (${STORED:0:16}...)"
      exit 0
    else
      echo "[brain-hash] MISMATCH — corruption alarm"
      echo "  stored: ${STORED:0:16}..."
      echo "  current: ${NEW:0:16}..."
      echo "  inspect: cd $BRAIN_DIR && git status && git diff brain/"
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 [build|verify]"
    exit 2
    ;;
esac
