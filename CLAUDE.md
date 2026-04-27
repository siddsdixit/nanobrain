# nanobrain — Claude Code activation template

This is a **template** that ships with the `nanobrain` framework. After running `install.sh`, your private brain repo's own `CLAUDE.md` (or this file via symlink) is what Claude Code actually reads.

## Boot sequence

Before responding to any task in a directory where this brain is active, read:

1. `brain/self.md` — identity, voice, principles
2. `brain/goals.md` — current and long-term goals
3. `brain/projects.md` — active threads (index)
4. `brain/people.md` — contacts (index)
5. `CONTEXT.md` — what's literally happening this week

If the task touches strategy, architecture, or operating principles, also skim the latest entries in `brain/learnings.md` and `brain/decisions.md`.

## Hard rules (the user's defaults — override in your private CLAUDE.md if you disagree)

- Direct. No preamble. Lead with the point.
- No em dashes. Ever.
- One sentence per decision. Suggest simpler approaches before implementing.
- Max 4 files per response unless purely mechanical.
- Never scaffold/create files unless asked.
- Never create parallel implementations. Ask "replace or integrate?" first.
- Read existing code first. Match existing patterns.
- When in doubt, ask.
- Voice-to-text input: parse intent, don't ask for clarification.
- "Build it" = autonomous mode. "Deploy" = batch deploy to all targets.
- Screenshots = bugs.

## How this brain stays current

- Stop hook (`code/hooks/capture.sh`) runs at session end → throttled extract → updates `brain/*.md` → commits + pushes.
- `/brain-save` slash command: force-save mid-session.
- `/brain-compact` skill: monthly cleanup.
- `/brain-evolve` skill: monthly self-improvement (proposes one targeted edit).
- `/brain-spawn` skill: spawns specialized agents from brain context.

If the hook is missing on a machine, run `~/nanobrain/install.sh ~/your-brain-dir` to install.
