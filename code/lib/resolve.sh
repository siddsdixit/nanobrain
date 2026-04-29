#!/usr/bin/env bash
# resolve.sh -- resolve_context(source, key) -> work | personal.
# Default: personal. Fail-safe: any error returns the default.

set -eu

LIB_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$LIB_DIR/contexts.sh"

DEFAULT_CTX="personal"

resolve_context() {
  local source="${1:-}" key="${2:-}"
  [ -n "$source" ] || { echo "$DEFAULT_CTX"; return 0; }
  contexts_load
  # If no _contexts.yaml or no resolvers -> default.
  local rules
  rules=$(printf '%s' "$_CTX_JSON" | jq -c --arg s "$source" '.resolvers[$s] // [] | .[]' 2>/dev/null || true)
  [ -n "$rules" ] || { echo "$DEFAULT_CTX"; return 0; }
  local rule pat ctx
  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    pat=$(printf '%s' "$rule" | jq -r '.match | to_entries[0].value' 2>/dev/null || true)
    ctx=$(printf '%s' "$rule" | jq -r '.context' 2>/dev/null || true)
    [ -n "$pat" ] || continue
    [ -n "$ctx" ] || continue
    case "$source" in
      gdrive|claude)
        # path glob; ** -> *
        local glob
        glob=$(printf '%s' "$pat" | sed 's/\*\*/*/g')
        # shellcheck disable=SC2254
        case "$key" in
          $glob) printf '%s\n' "$ctx"; return 0 ;;
        esac
        ;;
      *)
        # regex via awk for portability.
        if printf '%s' "$key" | awk -v p="$pat" 'BEGIN{e=1} $0 ~ p {e=0} END{exit e}'; then
          printf '%s\n' "$ctx"
          return 0
        fi
        ;;
    esac
  done <<EOF
$rules
EOF
  printf '%s\n' "$DEFAULT_CTX"
}

# Allow direct CLI use.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  resolve_context "${1:-}" "${2:-}"
fi
