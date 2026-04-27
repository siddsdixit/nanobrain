#!/usr/bin/env bash
# install.sh — one-shot setup for your nanobrain instance. Idempotent. Per-machine $HOME-aware.
#
# Usage:
#   install.sh [<brain-dir>] [--dry-run] [--read-only]
#
# Flags:
#   --dry-run     Print what would happen, change nothing on disk.
#   --read-only   Only set up the brain dir scaffold. Skip the Stop hook
#                 registration and skill/agent symlinks (no ~/.claude mutation).
#                 Lets you evaluate the framework without granting write access
#                 to your Claude Code config.
#
# Default: full install (symlinks skills/agents/CLAUDE.md, registers Stop hook).

set -euo pipefail

BRAIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_DIR="$HOME/.claude"
DRY_RUN=0
READ_ONLY=0

# Parse flags + optional brain-dir override (kept for backwards compat —
# the script still resolves BRAIN_DIR from its own location)
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --read-only) READ_ONLY=1 ;;
    --help|-h)
      sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '  [dry-run] %s\n' "$*"
  else
    eval "$@"
  fi
}

echo "→ nanobrain install from: $BRAIN_DIR"
[ "$DRY_RUN" = "1" ]   && echo "  mode: DRY RUN (no changes)"
[ "$READ_ONLY" = "1" ] && echo "  mode: READ-ONLY (no ~/.claude mutation)"
echo ""

# Always-on setup (even in read-only): brain scaffold dirs
run "mkdir -p '$BRAIN_DIR/data/claude' '$BRAIN_DIR/code/_backup'"
run "chmod +x '$BRAIN_DIR/code/hooks/capture.sh' 2>/dev/null || true"
run "chmod +x '$BRAIN_DIR/code/hooks/redact.sh' 2>/dev/null || true"

# Read-only mode stops here. The user gets a brain repo they can populate
# manually; no hooks fire, no ~/.claude touched.
if [ "$READ_ONLY" = "1" ]; then
  echo ""
  echo "✓ read-only setup complete."
  echo "  brain dir scaffold ready: $BRAIN_DIR/data/claude/, $BRAIN_DIR/code/_backup/"
  echo "  to upgrade later: $0"
  exit 0
fi

run "mkdir -p '$CLAUDE_DIR/skills'"
run "mkdir -p '$CLAUDE_DIR/agents'"

# 1. Symlink the skills (brain, brain-save, brain-compact, brain-evolve,
#    brain-checkpoint, brain-spawn, brain-graph, brain-hash, brain-redact)
for SKILL in brain brain-save brain-compact brain-evolve brain-checkpoint brain-spawn brain-graph brain-hash brain-redact; do
  [ -d "$BRAIN_DIR/code/skills/$SKILL" ] || continue
  run "ln -sf '$BRAIN_DIR/code/skills/$SKILL' '$CLAUDE_DIR/skills/$SKILL'"
  echo "  ✓ skill: ~/.claude/skills/$SKILL"
done

# 1b. Symlink any active agents (skip _TEMPLATE and README)
if [ -d "$BRAIN_DIR/code/agents" ]; then
  for AGENT in "$BRAIN_DIR/code/agents"/*.md; do
    [ -f "$AGENT" ] || continue
    NAME="$(basename "$AGENT" .md)"
    case "$NAME" in
      _TEMPLATE|README) continue ;;
    esac
    run "ln -sf '$AGENT' '$CLAUDE_DIR/agents/$NAME.md'"
    echo "  ✓ agent: ~/.claude/agents/$NAME.md"
  done
fi

# 2. Symlink global CLAUDE.md
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
SYNCED_CLAUDE_MD="$BRAIN_DIR/claude-config/CLAUDE.md"
if [ -L "$GLOBAL_CLAUDE_MD" ] && [ "$(readlink "$GLOBAL_CLAUDE_MD")" = "$SYNCED_CLAUDE_MD" ]; then
  echo "  ✓ ~/.claude/CLAUDE.md already symlinked"
else
  if [ -e "$GLOBAL_CLAUDE_MD" ] && [ "$DRY_RUN" = "0" ]; then
    BACKUP="$GLOBAL_CLAUDE_MD.local-backup-$(date +%Y%m%d-%H%M%S)"
    mv "$GLOBAL_CLAUDE_MD" "$BACKUP"
    echo "  ✓ backed up existing CLAUDE.md → $BACKUP"
  fi
  run "ln -s '$SYNCED_CLAUDE_MD' '$GLOBAL_CLAUDE_MD'"
  echo "  ✓ symlinked ~/.claude/CLAUDE.md → $SYNCED_CLAUDE_MD"
fi

# 3. Merge Stop hook into ~/.claude/settings.json with $HOME substituted to absolute path
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_CMD="$BRAIN_DIR/code/hooks/capture.sh"
if ! command -v jq >/dev/null 2>&1; then
  echo "  ! jq not installed (brew install jq). Add this manually to $SETTINGS:"
  echo "    \"hooks\": { \"Stop\": [ { \"matcher\": \"\", \"hooks\": [ { \"type\": \"command\", \"command\": \"$HOOK_CMD\" } ] } ] }"
else
  if [ "$DRY_RUN" = "0" ]; then
    [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
    TMP="$(mktemp)"
    # Register all three lifecycle events. Stop fires every turn (throttled).
    # SessionEnd + PreCompact force-capture (safety nets).
    jq --arg cmd "$HOOK_CMD" '
      .hooks.Stop = [{matcher: "", hooks: [{type: "command", command: $cmd}]}]
      | .hooks.SessionEnd = [{matcher: "", hooks: [{type: "command", command: $cmd}]}]
      | .hooks.PreCompact = [{matcher: "", hooks: [{type: "command", command: $cmd}]}]
    ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
    echo "  ✓ Stop + SessionEnd + PreCompact hooks wired in ~/.claude/settings.json"
  else
    echo "  [dry-run] would merge Stop+SessionEnd+PreCompact hooks into $SETTINGS"
  fi
fi

# 4. Merge MCP server registry into ~/.claude/mcp.json (auth tokens stay in ~/.claude/.env)
MCP_LOCAL="$CLAUDE_DIR/mcp.json"
MCP_SYNCED="$BRAIN_DIR/claude-config/mcp.json"
if [ -f "$MCP_SYNCED" ] && command -v jq >/dev/null 2>&1; then
  if [ "$DRY_RUN" = "0" ]; then
    [ -f "$MCP_LOCAL" ] || echo '{}' > "$MCP_LOCAL"
    TMP="$(mktemp)"
    jq -s '.[0] * .[1]' "$MCP_LOCAL" "$MCP_SYNCED" > "$TMP" && mv "$TMP" "$MCP_LOCAL"
    echo "  ✓ MCP registry merged into ~/.claude/mcp.json"
  else
    echo "  [dry-run] would merge MCP registry into $MCP_LOCAL"
  fi
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
if [ "$DRY_RUN" = "1" ]; then
  echo "✓ dry-run complete. No files were modified."
  echo "  re-run without --dry-run to apply."
else
  echo "✓ brain installed."
  echo "  Test: open Claude Code anywhere and type /brain who am I"
fi
