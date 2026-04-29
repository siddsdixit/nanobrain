#!/usr/bin/env bash
# server.sh -- minimal MCP stdio JSON-RPC server. Implements:
#   tools/list  -> manifest tools
#   tools/call  -> read_brain_file (only)
# Reads one JSON-RPC request per line from stdin, writes one JSON response per line.

set -eu

MCP_DIR="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$MCP_DIR/manifest.json"

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
log_dir="$BRAIN_DIR/data/_mcp"
mkdir -p "$log_dir"
LOG="$log_dir/access.log"

emit() {
  printf '%s\n' "$1"
}

handle() {
  local line="$1"
  local id method params
  id=$(printf '%s' "$line" | jq -r '.id // null')
  method=$(printf '%s' "$line" | jq -r '.method // ""')
  params=$(printf '%s' "$line" | jq -c '.params // {}')

  printf '%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S')" "rpc method=$method" >> "$LOG"

  case "$method" in
    tools/list)
      tools=$(jq -c '.tools' "$MANIFEST")
      emit "$(jq -nc --argjson id "$id" --argjson tools "$tools" '{jsonrpc:"2.0", id:$id, result:{tools:$tools}}')"
      ;;
    tools/call)
      local name args agent file out
      name=$(printf '%s' "$params" | jq -r '.name')
      args=$(printf '%s' "$params" | jq -c '.arguments // {}')
      if [ "$name" != "read_brain_file" ]; then
        emit "$(jq -nc --argjson id "$id" --arg n "$name" '{jsonrpc:"2.0", id:$id, error:{code:-32601, message:("unknown tool: " + $n)}}')"
        return
      fi
      agent=$(printf '%s' "$args" | jq -r '.agent')
      file=$(printf '%s' "$args" | jq -r '.file')
      if out=$(bash "$MCP_DIR/read_brain_file.sh" --agent "$agent" --file "$file" 2>&1); then
        emit "$(jq -nc --argjson id "$id" --arg t "$out" '{jsonrpc:"2.0", id:$id, result:{content:[{type:"text", text:$t}]}}')"
      else
        emit "$(jq -nc --argjson id "$id" --arg t "$out" '{jsonrpc:"2.0", id:$id, error:{code:-32000, message:$t}}')"
      fi
      ;;
    *)
      emit "$(jq -nc --argjson id "$id" --arg m "$method" '{jsonrpc:"2.0", id:$id, error:{code:-32601, message:("method not found: " + $m)}}')"
      ;;
  esac
}

while IFS= read -r line; do
  [ -n "$line" ] || continue
  handle "$line"
done
