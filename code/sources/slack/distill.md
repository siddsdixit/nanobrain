# slack distill

Read `data/slack/INBOX.md`. Convert messages into:

- decisions surfaced in chat (`brain/decisions.md`)
- people worth tracking (`brain/people.md`)
- project signals (`brain/projects.md`)

Block format: `target_path: ...` first line, `{source_id, context}` in body. `>>>` between blocks.
