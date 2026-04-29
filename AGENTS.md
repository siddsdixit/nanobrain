# nanobrain — agent activation

This file is the cross-tool agent context. It works for Codex CLI, Aider, and any tool that follows the [AGENTS.md convention](https://agents.md). Tool-specific files (`CLAUDE.md`, `GEMINI.md`, `.cursor/rules/`) inherit from this when present.

## Boot sequence

Before responding to any task, read these files from the brain root:

1. `brain/self.md` — identity, voice, principles
2. `brain/goals.md` — current and long-term goals
3. `brain/projects.md` — active threads (index)
4. `brain/people.md` — contacts (index)
5. `CONTEXT.md` — what's literally happening this week

If the task touches strategy, architecture, or operating principles, also skim the latest entries in `brain/learnings.md` and `brain/decisions.md`.

For per-entity detail, read the linked file under `brain/people/<slug>.md` or `brain/projects/<slug>.md`.

## Query the brain via MCP

`code/mcp-server/` exposes `read_brain_file` with context-filter enforcement. The agent declares which contexts it can see (`work`, `personal`, or both); the server refuses firehoses (`raw.md`, `INBOX.md`).

Most agentic CLIs (Codex, Cursor, Claude Code, Gemini CLI) speak MCP natively. Configure once per tool; queries route through it after that.

## Hard rules

- Direct. No preamble. Lead with the point.
- No em dashes. Use commas, periods, parentheses.
- One sentence per decision. Suggest simpler approaches before implementing.
- Max 4 files per response unless purely mechanical.
- Never scaffold/create files unless asked.
- Never create parallel implementations. Ask "replace or integrate?" first.
- Read existing code first. Match existing patterns.
- When in doubt, ask.
- "Build it" = autonomous mode. "Deploy" = batch deploy to all targets.

## Capture status

| Tool | Read brain (via MCP) | Capture session |
|---|---|---|
| Claude Code | ✅ | ✅ native Stop hook |
| Codex CLI | ✅ | 🟡 wrapper script (v2.2) |
| Cursor | ✅ | 🟡 wrapper script (v2.2) |
| Gemini CLI | ✅ | 🟡 wrapper script (v2.2) |
| Aider | ✅ | 🟡 wrapper script (v2.2) |

See [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) for setup per tool.

## Session maintenance

- At the start of every session, read `TODO.md` in the project root if it exists.
- At the end of every session, update `TODO.md`.
