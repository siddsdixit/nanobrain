#!/usr/bin/env bash
# contexts.sh -- load and validate brain/_contexts.yaml.
# v2 schema is intentionally tiny: version, contexts (work|personal),
# resolvers per source, and an optional defaults block.

set -eu

contexts_file() {
  printf '%s' "${BRAIN_DIR:-$HOME/brain}/brain/_contexts.yaml"
}

contexts_require_tools() {
  command -v yq >/dev/null 2>&1 || { echo "[contexts] yq required" >&2; return 1; }
  command -v jq >/dev/null 2>&1 || { echo "[contexts] jq required" >&2; return 1; }
}

contexts_json() {
  local file="$1"
  contexts_require_tools || return 1
  yq -o=json '.' "$file" 2>/dev/null || { echo "[contexts] malformed YAML" >&2; return 1; }
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
    contexts_validate "$file" >/dev/null || return 1
    _CTX_JSON=$(contexts_json "$file") || return 1
    export _CTX_JSON
  fi
}

contexts_validate() {
  local file="${1:-$(contexts_file)}"
  local json ver names ctx defaults_ctx bad_sources bad_shapes bad_matches bad_contexts count resolver_count
  [ -f "$file" ] || { echo "[contexts] not found: $file" >&2; return 1; }
  json=$(contexts_json "$file") || return 1

  printf '%s' "$json" | jq -e 'type == "object"' >/dev/null 2>&1 \
    || { echo "[contexts] root must be a YAML object" >&2; return 1; }

  ver=$(printf '%s' "$json" | jq -r '.version // empty | tostring')
  [ "$ver" = "1" ] || { echo "[contexts] version must be 1 (got: ${ver:-missing})" >&2; return 1; }

  printf '%s' "$json" | jq -e '.contexts | type == "object" and length > 0' >/dev/null 2>&1 \
    || { echo "[contexts] contexts must be a non-empty object" >&2; return 1; }

  names=$(printf '%s' "$json" | jq -r '.contexts | keys[]')
  [ -n "$names" ] || { echo "[contexts] no contexts defined" >&2; return 1; }
  while IFS= read -r ctx; do
    case "$ctx" in
      work|personal) ;;
      *) echo "[contexts] only work|personal allowed (got: $ctx)" >&2; return 1 ;;
    esac
  done <<EOF
$names
EOF

  defaults_ctx=$(printf '%s' "$json" | jq -r '.defaults.context // empty')
  if [ -n "$defaults_ctx" ]; then
    printf '%s' "$json" | jq -e --arg c "$defaults_ctx" '.contexts[$c] != null' >/dev/null 2>&1 \
      || { echo "[contexts] defaults.context references unknown context: $defaults_ctx" >&2; return 1; }
  fi

  if printf '%s' "$json" | jq -e '.resolvers != null' >/dev/null 2>&1; then
    printf '%s' "$json" | jq -e '.resolvers | type == "object"' >/dev/null 2>&1 \
      || { echo "[contexts] resolvers must be an object" >&2; return 1; }

    bad_sources=$(printf '%s' "$json" | jq -r '
      (.resolvers // {}) | keys[]
      | select((. == "gmail" or . == "gcal" or . == "gdrive" or . == "slack" or . == "claude" or . == "granola") | not)
    ')
    [ -z "$bad_sources" ] || { echo "[contexts] unknown resolver source: $(printf '%s' "$bad_sources" | head -1)" >&2; return 1; }

    bad_shapes=$(printf '%s' "$json" | jq -r '
      (.resolvers // {}) | to_entries[]
      | select(.value | type != "array")
      | .key
    ')
    [ -z "$bad_shapes" ] || { echo "[contexts] resolver must be an array: $(printf '%s' "$bad_shapes" | head -1)" >&2; return 1; }

    bad_matches=$(printf '%s' "$json" | jq -r '
      def allowed($src; $key):
        if $src == "gmail" then ($key == "from" or $key == "to" or $key == "account" or $key == "sender_domain")
        elif $src == "gcal" then ($key == "calendar_id")
        elif $src == "gdrive" then ($key == "path_glob")
        elif $src == "slack" then ($key == "workspace_id" or $key == "channel" or $key == "channel_name")
        elif $src == "claude" then ($key == "path_glob")
        elif $src == "granola" then ($key == "attendee_domain" or $key == "calendar_id" or $key == "email")
        else false end;
      (.resolvers // {}) | to_entries[] as $src
      | $src.value[]
      | select(
          (type != "object") or
          (.context | type != "string") or
          (.match | type != "object") or
          (.match | length != 1) or
          ((.match | to_entries[0].value | type) != "string") or
          (allowed($src.key; (.match | keys[0])) | not)
        )
      | $src.key
    ')
    [ -z "$bad_matches" ] || { echo "[contexts] invalid resolver rule for source: $(printf '%s' "$bad_matches" | head -1)" >&2; return 1; }

    bad_contexts=$(printf '%s' "$json" | jq -r '
      . as $root
      | (.resolvers // {}) | to_entries[]
      | .value[]
      | .context as $ctx
      | select(($ctx | type == "string") and (($root.contexts[$ctx] // null) == null))
      | $ctx
    ')
    [ -z "$bad_contexts" ] || { echo "[contexts] resolver references unknown context: $(printf '%s' "$bad_contexts" | head -1)" >&2; return 1; }
  fi

  count=$(printf '%s' "$json" | jq '.contexts | length')
  resolver_count=$(printf '%s' "$json" | jq '[ (.resolvers // {})[]? | length ] | add // 0')
  echo "OK: $count contexts, $resolver_count resolvers"
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
