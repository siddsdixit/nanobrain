# gcal distill

Read `data/gcal/INBOX.md`. Convert events into:

- meeting attendees worth tracking (`brain/people.md`)
- decisions about scheduling or commitments (`brain/decisions.md`)
- project milestones (`brain/projects.md`)

Each emitted block: `target_path: ...` first line, body includes `{source_id, context}`. Blocks separated by `>>>`. Drop noise.
