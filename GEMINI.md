# nanobrain — Gemini CLI activation

This file tells Gemini CLI how to use the brain repo. Gemini CLI auto-loads `GEMINI.md` from the working directory.

## Boot sequence

Before responding to any task, read these files from the brain root:

1. `brain/self.md` — identity, voice, principles
2. `brain/goals.md` — current and long-term goals
3. `brain/projects.md` — active threads (index)
4. `brain/people.md` — contacts (index)
5. `CONTEXT.md` — what's literally happening this week

For per-entity detail, read the linked file under `brain/people/<slug>.md` or `brain/projects/<slug>.md`.

## Query the brain via MCP

`code/mcp-server/` exposes `read_brain_file` with context-filter enforcement.

Configure Gemini CLI's MCP support per [Gemini CLI docs](https://github.com/google-gemini/gemini-cli). The server entry point is `code/mcp-server/server.sh`.

## Hard rules

- Direct. No preamble. Lead with the point.
- No em dashes. Use commas, periods, parentheses.
- One sentence per decision. Suggest simpler approaches before implementing.
- Max 4 files per response unless purely mechanical.
- Never scaffold/create files unless asked.
- Never create parallel implementations. Ask "replace or integrate?" first.
- Read existing code first. Match existing patterns.
- When in doubt, ask.

## Capture (today vs. tomorrow)

Gemini CLI does not yet emit a session-end hook usable by nanobrain. To capture a Gemini session into the brain today, run:

```bash
/brain-save --text "<key takeaways from this session>"
```

A wrapper script for automatic capture lands in v2.2. Track progress at [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md).
