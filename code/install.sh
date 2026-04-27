#!/usr/bin/env bash
# install.sh — one-shot setup for your nanobrain instance. Idempotent. Per-machine $HOME-aware.

set -euo pipefail

BRAIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "→ nanobrain install from: $BRAIN_DIR"

mkdir -p "$CLAUDE_DIR/skills"
mkdir -p "$BRAIN_DIR/data/claude" "$BRAIN_DIR/code/_backup"
chmod +x "$BRAIN_DIR/code/hooks/capture.sh" 2>/dev/null || true

mkdir -p "$CLAUDE_DIR/agents"

# 1. Symlink the skills (brain, brain-save, brain-compact, brain-evolve, brain-checkpoint, brain-spawn)
for SKILL in brain brain-save brain-compact brain-evolve brain-checkpoint brain-spawn; do
  ln -sf "$BRAIN_DIR/code/skills/$SKILL" "$CLAUDE_DIR/skills/$SKILL"
  echo "  ✓ skill: ~/.claude/skills/$SKILL"
done

# 1b. Symlink any active agents (skip _TEMPLATE and _proposed)
if [ -d "$BRAIN_DIR/code/agents" ]; then
  for AGENT in "$BRAIN_DIR/code/agents"/*.md; do
    [ -f "$AGENT" ] || continue
    NAME="$(basename "$AGENT" .md)"
    case "$NAME" in
      _TEMPLATE|README) continue ;;
    esac
    ln -sf "$AGENT" "$CLAUDE_DIR/agents/$NAME.md"
    echo "  ✓ agent: ~/.claude/agents/$NAME.md"
  done
fi

# 2. Symlink global CLAUDE.md (uses $HOME/brain/... paths so it works for any user)
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
SYNCED_CLAUDE_MD="$BRAIN_DIR/claude-config/CLAUDE.md"
if [ -L "$GLOBAL_CLAUDE_MD" ] && [ "$(readlink "$GLOBAL_CLAUDE_MD")" = "$SYNCED_CLAUDE_MD" ]; then
  echo "  ✓ ~/.claude/CLAUDE.md already symlinked"
else
  if [ -e "$GLOBAL_CLAUDE_MD" ]; then
    BACKUP="$GLOBAL_CLAUDE_MD.local-backup-$(date +%Y%m%d-%H%M%S)"
    mv "$GLOBAL_CLAUDE_MD" "$BACKUP"
    echo "  ✓ backed up existing CLAUDE.md → $BACKUP"
  fi
  ln -s "$SYNCED_CLAUDE_MD" "$GLOBAL_CLAUDE_MD"
  echo "  ✓ symlinked ~/.claude/CLAUDE.md → $SYNCED_CLAUDE_MD"
fi

# 3. Merge Stop hook into ~/.claude/settings.json with $HOME substituted to absolute path
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_CMD="$HOME/brain/code/hooks/capture.sh"
if ! command -v jq >/dev/null 2>&1; then
  echo "  ! jq not installed (brew install jq). Add this manually to $SETTINGS:"
  echo "    \"hooks\": { \"Stop\": [ { \"matcher\": \"\", \"hooks\": [ { \"type\": \"command\", \"command\": \"$HOOK_CMD\" } ] } ] }"
else
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  TMP="$(mktemp)"
  # Register all three lifecycle events. Stop fires every turn (throttled).
  # SessionEnd + PreCompact force-capture (safety nets). Unsupported events
  # are ignored by Claude Code, no harm in registering them.
  jq --arg cmd "$HOOK_CMD" '
    .hooks.Stop = [{matcher: "", hooks: [{type: "command", command: $cmd}]}]
    | .hooks.SessionEnd = [{matcher: "", hooks: [{type: "command", command: $cmd}]}]
    | .hooks.PreCompact = [{matcher: "", hooks: [{type: "command", command: $cmd}]}]
  ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  echo "  ✓ Stop + SessionEnd + PreCompact hooks wired in ~/.claude/settings.json"
fi

# 4. Merge MCP server registry into ~/.claude/mcp.json (auth tokens stay in ~/.claude/.env)
MCP_LOCAL="$CLAUDE_DIR/mcp.json"
MCP_SYNCED="$BRAIN_DIR/claude-config/mcp.json"
if [ -f "$MCP_SYNCED" ] && command -v jq >/dev/null 2>&1; then
  [ -f "$MCP_LOCAL" ] || echo '{}' > "$MCP_LOCAL"
  TMP="$(mktemp)"
  # Merge: synced template entries override; existing local entries with non-template keys preserved.
  jq -s '.[0] * .[1]' "$MCP_LOCAL" "$MCP_SYNCED" > "$TMP" && mv "$TMP" "$MCP_LOCAL"
  echo "  ✓ MCP registry merged into ~/.claude/mcp.json"
fi

# 5. Verify claude CLI is on PATH
if ! command -v claude >/dev/null 2>&1; then
  echo ""
  echo "  ! Claude Code CLI not on PATH."
  echo "    Install: https://claude.com/claude-code"
fi

# 6. Sanity-check git remote
cd "$BRAIN_DIR"
if git remote get-url origin >/dev/null 2>&1; then
  echo "  ✓ git remote: $(git remote get-url origin)"
fi

echo ""
echo "✓ brain installed."
echo "  Test: open Claude Code anywhere and type /brain who am I"
