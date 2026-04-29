# Compatibility — which AI tools work with nanobrain

Two operations matter: **read** (agent queries the brain) and **capture** (session signal lands back in the brain).

| Tool | Read | Capture | Activation file | Notes |
|---|---|---|---|---|
| Claude Code | ✅ MCP | ✅ native Stop hook | `CLAUDE.md` | First-class. Capture is throttled (30 min / 5KB). |
| Codex CLI | ✅ MCP | 🟡 wrapper (v2.2) | `AGENTS.md` | Reads work today via MCP; capture wrapper lands in v2.2. |
| Cursor | ✅ MCP | 🟡 wrapper (v2.2) | `.cursorrules` or `.cursor/rules/*.mdc` | MCP supported in Settings → Model Context Protocol. |
| Gemini CLI | ✅ MCP | 🟡 wrapper (v2.2) | `GEMINI.md` | MCP shipping per upstream roadmap. |
| Aider | ✅ MCP | 🟡 wrapper (v2.2) | `AGENTS.md` (inherited) | Add brain root to `read` list in `.aider.conf.yml`. |
| continue.dev | 🟡 partial | ❌ | `AGENTS.md` (inherited) | MCP support varies by version. |
| Web (`claude.ai`, `chatgpt.com`, `gemini.google.com`) | ❌ | ❌ | n/a | Browser extension on the v2.3 roadmap. |

## Setup per tool

### Claude Code (default)

Run `install.sh`. The Stop hook is wired into `~/.claude/settings.json` automatically.

### Codex CLI

Read side: configure MCP in Codex's settings, pointing at `<brain>/.nanobrain/code/mcp-server/server.sh`.

Capture side (until v2.2): run `/brain-save --text "<takeaways>"` after a meaningful session.

### Cursor

Read side: open Cursor → Settings → Features → Model Context Protocol → Add Server. Use `<brain>/.nanobrain/code/mcp-server/server.sh`.

Cursor will auto-load `.cursorrules` from the workspace root. Drop a symlink in your private brain repo:

```bash
ln -s .nanobrain/.cursorrules .cursorrules
```

### Gemini CLI

Read side: configure MCP per Gemini CLI's MCP docs. Server entry point: `<brain>/.nanobrain/code/mcp-server/server.sh`.

Gemini CLI auto-loads `GEMINI.md`.

### Aider

Read side: add the brain root to your `.aider.conf.yml`:

```yaml
read:
  - ~/your-brain/brain/self.md
  - ~/your-brain/brain/goals.md
  - ~/your-brain/brain/projects.md
  - ~/your-brain/CONTEXT.md
```

Or point Aider at MCP if your version supports it.

## Why context-filtered reads?

`read_brain_file` enforces context boundaries server-side. An agent declared as `context_in: [personal]` cannot read work entries even if it tries. This is the v2 substitute for v1's per-file sensitivity tagging — simpler, less leak-prone, easier to audit.

## Why no native capture for non-Claude tools today?

Each CLI has a different lifecycle hook (or none). Building five separate wrappers in v2.0 would have delayed shipping. v2.1 establishes the activation files (you can read the brain from any tool today). v2.2 adds the wrapper layer for capture.

The wrapper pattern: a small bash launcher (`nanobrain-codex`, `nanobrain-gemini`, etc.) that runs the underlying CLI, captures stdin/stdout to a transcript file, then runs `code/skills/brain-distill/dispatch.sh` at the end. Roughly 30 lines per tool. Track progress in [docs/sprints/](sprints/) once issued.
