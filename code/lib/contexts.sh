#!/usr/bin/env bash
# contexts.sh -- load and validate brain/_contexts.yaml.
# v2 schema is intentionally tiny: version, contexts (work|personal),
# resolvers per source, and an optional defaults block.

set -eu

contexts_file() {
  printf '%s' "${BRAIN_DIR:-$HOME/brain}/brain/_contexts.yaml"
}

# Parse the file once, cache JSON in $_CTX_JSON for the calling process.
contexts_load() {
  local file="${1:-$(contexts_file)}"
  if [ ! -f "$file" ]; then
    _CTX_JSON='{}'
    export _CTX_JSON
    return 0
  fi
  if [ -z "${_CTX_JSON:-}" ]; then
    _CTX_JSON=$(yq -o=json '.' "$file" 2>/dev/null || printf '{}')
    export _CTX_JSON
  fi
}

contexts_validate() {
  local file="${1:-$(contexts_file)}"
  local json ver names ctx
  [ -f "$file" ] || { echo "[contexts] not found: $file" >&2; return 1; }
  json=$(yq -o=json '.' "$file" 2>/dev/null) || { echo "[contexts] malformed YAML" >&2; return 1; }
  ver=$(printf '%s' "$json" | jq -r '.version // empty')
  [ "$ver" = "1" ] || { echo "[contexts] version must be 1 (got: ${ver:-missing})" >&2; return 1; }
  names=$(printf '%s' "$json" | jq -r '.contexts // {} | keys[]')
  [ -n "$names" ] || { echo "[contexts] no contexts defined" >&2; return 1; }
  while IFS= read -r ctx; do
    case "$ctx" in
      work|personal) ;;
      *) echo "[contexts] only work|personal allowed (got: $ctx)" >&2; return 1 ;;
    esac
  done <<EOF
$names
EOF
  local count
  count=$(printf '%s' "$json" | jq '.contexts | length')
  echo "OK: $count contexts"
}

# Allow direct CLI use; do nothing when sourced.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  case "${1:-}" in
    validate) shift; contexts_validate "$@" ;;
    load)     shift; contexts_load "$@"; printf '%s\n' "$_CTX_JSON" ;;
    "")       echo "usage: contexts.sh {validate|load} [file]" >&2; exit 64 ;;
    *)        echo "usage: contexts.sh {validate|load} [file]" >&2; exit 64 ;;
  esac
fi
