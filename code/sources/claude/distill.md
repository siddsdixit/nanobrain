# claude distill

Read `data/claude/INBOX.md`. Each entry is the tail of a Claude Code session.

Emit blocks for:

- decisions made in the session (`brain/decisions.md`)
- learnings, lessons, gotchas (`brain/learnings.md`)
- project status updates (`brain/projects.md`)

`target_path` first line, `{source_id, context}` in body, `>>>` separators.
