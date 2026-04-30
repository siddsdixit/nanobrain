#!/usr/bin/env bash
# detect_mcp.sh -- given a source, determine if its MCP server is available.
# Exit 0 if configured, 1 if not. Quiet by default; set NANOBRAIN_DEBUG=1 for chatter.
#
# Detection order:
#   1. Map source -> MCP server name (claude.ai remote naming).
#   2. Check ~/.claude/settings.json mcpServers keys (jq).
#   3. Grep settings.json for mcp__<name> tool patterns.
#   4. Probe `claude -p` to see if the tool is visible to the CLI (claude.ai
#      remote MCPs auto-attach when logged in and don't appear in mcpServers).
# Any of (2), (3), (4) succeeding => configured.

set -eu

src="${1:-}"
[ -n "$src" ] || { echo "usage: detect_mcp.sh <source>" >&2; exit 64; }

dbg() { [ "${NANOBRAIN_DEBUG:-0}" = "1" ] && echo "[detect_mcp] $*" >&2 || true; }

# Granola uses local JWT auth, not MCP — check separately.
if [ "$src" = "granola" ]; then
  granola_state="$HOME/Library/Application Support/Granola/supabase.json"
  if [ -f "$granola_state" ]; then
    dbg "granola: local state found"
    exit 0
  fi
  dbg "granola: app not installed"
  exit 1
fi

# Map source -> mcp server name (claude.ai remote naming).
case "$src" in
  gmail)  mcp="claude_ai_Gmail" ;;
  gcal)   mcp="claude_ai_Google_Calendar" ;;
  gdrive) mcp="claude_ai_Google_Drive" ;;
  slack)  mcp="claude_ai_Slack" ;;
  *) echo "[detect_mcp] unknown source: $src" >&2; exit 64 ;;
esac

settings="$HOME/.claude/settings.json"

# (2) + (3): scan settings.json.
if [ -f "$settings" ]; then
  if command -v jq >/dev/null 2>&1; then
    if jq -e --arg k "$mcp" '.mcpServers[$k]? // empty' "$settings" >/dev/null 2>&1; then
      dbg "$mcp found in mcpServers"
      exit 0
    fi
  fi
  if grep -Fq "mcp__${mcp}" "$settings" 2>/dev/null; then
    dbg "$mcp found via mcp__ tool pattern"
    exit 0
  fi
  if grep -Fq "\"$mcp\"" "$settings" 2>/dev/null; then
    dbg "$mcp found as bare key in settings"
    exit 0
  fi
fi

# (4) Probe claude CLI. claude.ai remote MCPs auto-attach when logged in.
if command -v claude >/dev/null 2>&1; then
  probe=$(echo "" | claude -p "list available MCP tools as JSON array of names" 2>/dev/null || true)
  if printf '%s' "$probe" | grep -Fq "claude_ai_${mcp#claude_ai_}"; then
    dbg "$mcp visible to claude CLI"
    exit 0
  fi
  if printf '%s' "$probe" | grep -Fq "$mcp"; then
    dbg "$mcp visible to claude CLI"
    exit 0
  fi
fi

dbg "$mcp not configured"
exit 1
