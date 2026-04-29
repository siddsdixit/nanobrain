# gdrive distill

Read `data/gdrive/INBOX.md`. Convert document signals into:

- decisions documented in a doc (`brain/decisions.md`)
- project artifacts (`brain/projects.md`)
- learnings or shared docs (`brain/learnings.md`)

Each block: `target_path: ...` first line, `{source_id, context}` in body. Blocks separated by `>>>`. Drop ambiguous.
