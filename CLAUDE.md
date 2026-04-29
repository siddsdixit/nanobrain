# nanobrain — Claude Code activation

This file tells Claude Code how to use the brain repo it's running inside. After `install.sh`, your private brain repo gets a copy of this file (or a symlink to it).

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

Configure once in `~/.claude/settings.json` under `mcpServers`. After that, queries like "what's connected to project-x" route through MCP.

## Hard rules (override in your private CLAUDE.md if you disagree)

- Direct. No preamble. Lead with the point.
- No em dashes. Use commas, periods, parentheses.
- One sentence per decision. Suggest simpler approaches before implementing.
- Max 4 files per response unless purely mechanical.
- Never scaffold/create files unless asked.
- Never create parallel implementations. Ask "replace or integrate?" first.
- Read existing code first. Match existing patterns.
- When in doubt, ask.
- Voice-to-text input: parse intent, don't ask for clarification.
- "Build it" = autonomous mode. "Deploy" = batch deploy to all targets.
- Screenshots = bugs.

## How the brain stays current

- Stop hook (`code/hooks/capture.sh`) runs at session end. Throttled (30 min / 5KB delta). Secrets redacted before any transcript leaves your machine.
- `/brain-save` — force-save mid-session
- `/brain-compact` — weekly cleanup
- `/brain-evolve` — monthly self-improvement (proposes one targeted edit per cycle)
- `/brain-spawn` — mint a new context-scoped agent

If the hook isn't firing, run `/brain-doctor` to diagnose.

## Session maintenance

- At the start of every session, read `TODO.md` in the project root if it exists.
- At the end of every session, update `TODO.md`: check off completed items, add new ones discovered.
