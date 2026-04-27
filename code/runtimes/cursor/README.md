# Cursor runtime

Cursor is a GUI editor. There's no CLI to wrap. Capture happens via the MCP server; read happens via `AGENTS.md` (or `.cursorrules` for older versions).

## Read side (works today)

Recent Cursor versions honor `AGENTS.md` per the [agents.md](https://agents.md) spec. Older versions read `.cursorrules`.

```bash
# In your project root, symlink BOTH (Cursor picks whichever it understands)
ln -s $HOME/my-brain/AGENTS.md ./AGENTS.md
cp $HOME/my-brain/AGENTS.md ./.cursorrules   # plain copy is fine; .cursorrules is unstructured
```

Cursor will read these on session start and apply your brain context.

## Capture side (via MCP)

Cursor supports MCP servers. The nanobrain MCP server runs locally over stdio and exposes 7 tools, including `brain_add_to_inbox`.

### One-time setup

1. Install nanobrain locally (`install.sh`).
2. In Cursor: Settings → MCP Servers → Add. Use:

```json
{
  "name": "nanobrain",
  "command": "node",
  "args": ["$HOME/nanobrain/code/mcp-server/index.js"],
  "env": { "BRAIN_DIR": "$HOME/my-brain" }
}
```

3. Restart Cursor.

### Capture pattern

Cursor doesn't fire on session end. Two options:

**Manual at the end of a chunk of work:**

In a Claude Code window (or via the MCP `brain_add_to_inbox` tool from Cursor itself), summarize the Cursor session and append to `data/cursor/INBOX.md`. Distillation runs on the same cadence as any other source (see `code/sources/_TEMPLATE`).

**Automated via post-task hook:**

Cursor's task system (`.cursor/tasks.json`) supports post-task hooks. Add:

```json
{
  "tasks": [{
    "label": "save to brain",
    "type": "shell",
    "command": "$HOME/nanobrain/code/runtimes/cursor/post-task.sh"
  }]
}
```

The script in `post-task.sh` (in this folder) reads Cursor's chat export and fires capture.sh.

## Roadmap

- Cursor extension: native button to capture the current chat to brain.
- Direct integration with Cursor's chat-export API (when stable).
