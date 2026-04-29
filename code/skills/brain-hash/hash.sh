#!/usr/bin/env bash
# hash.sh -- build/verify SHA-256 over stable brain corpus.

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
HASH_FILE="$BRAIN_DIR/BRAIN_HASH.txt"
MODE="${1:-build}"

# Pick a portable SHA-256 tool.
if command -v shasum >/dev/null 2>&1; then
  SHA_CMD="shasum -a 256"
elif command -v sha256sum >/dev/null 2>&1; then
  SHA_CMD="sha256sum"
else
  echo "[brain-hash] need shasum or sha256sum" >&2
  exit 2
fi

compute_hash() {
  if [ ! -d "$BRAIN_DIR/brain" ]; then
    echo "[brain-hash] no brain dir: $BRAIN_DIR/brain" >&2
    return 2
  fi
  find "$BRAIN_DIR/brain" -type f -name '*.md' \
    ! -name 'raw.md' \
    ! -name 'interactions.md' \
    ! -name '_graph.md' \
    ! -path '*/archive/*' \
    -print0 2>/dev/null \
  | xargs -0 $SHA_CMD 2>/dev/null \
  | awk '{print $1}' \
  | sort \
  | $SHA_CMD \
  | awk '{print $1}'
}

case "$MODE" in
  build|regenerate)
    NEW=$(compute_hash) || exit $?
    [ -n "$NEW" ] || { echo "[brain-hash] empty corpus, cannot hash" >&2; exit 2; }
    {
      echo "# Brain integrity hash"
      echo
      echo "Generated: $(date '+%Y-%m-%dT%H:%M:%S')"
      echo "Algorithm: SHA-256 over sorted file SHA-256s (stable corpus)"
      echo
      echo "$NEW"
    } > "$HASH_FILE"
    echo "[brain-hash] hash built: ${NEW:0:16}..."
    ;;
  verify|check)
    if [ ! -f "$HASH_FILE" ]; then
      echo "[brain-hash] no baseline at $HASH_FILE" >&2
      exit 1
    fi
    STORED=$(grep -E '^[a-f0-9]{64}$' "$HASH_FILE" | head -1)
    NEW=$(compute_hash) || exit $?
    if [ "$STORED" = "$NEW" ]; then
      echo "[brain-hash] OK ${STORED:0:16}..."
      exit 0
    else
      echo "[brain-hash] DRIFT"
      echo "  stored:  ${STORED:0:16}..."
      echo "  current: ${NEW:0:16}..."
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 [build|verify]" >&2
    exit 2 ;;
esac
