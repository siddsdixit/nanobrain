# nanobrain — Gemini CLI activation template

For Google Gemini CLI and any Google-side agent that reads `GEMINI.md`.

This is a **template** that ships with the `nanobrain` framework. After running `install.sh`, your private brain repo's own `GEMINI.md` (or this file via symlink) is what Gemini actually reads.

## Boot sequence

Before responding to any task in a directory where a brain is active, read these files in order:

1. `brain/self.md` — identity, voice, style, principles
2. `brain/goals.md` — current and long-term goals
3. `brain/projects.md` — active project threads
4. `brain/people.md` — family, team, board, stakeholders
5. `CONTEXT.md` — what's literally happening this week

For tasks that touch strategy, architecture, or operating principles, also skim the latest entries in `brain/learnings.md` and `brain/decisions.md`.

## Voice and style defaults

- Direct. No preamble.
- No em dashes. Ever.
- Short sentences. One idea each. Imperative voice.
- "Fix and show," not "here are 3 options."
- Max 4 files per response unless purely mechanical.
- Don't scaffold files. Don't create parallel implementations.

## Voice-to-text

The user may use voice input frequently. Parse intent through typos and run-ons.
