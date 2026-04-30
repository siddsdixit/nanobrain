# granola distill

Read `data/granola/INBOX.md`. Each entry is a meeting note from Granola. For each entry, extract:

- **decisions** made in the meeting (commitments, choices, agreed actions)
- **people** worth tracking (new contacts, key attendees)
- **project** signals (blockers, milestones, next steps)
- noise (skip stand-ups, cancelled meetings, empty notes)

Output one block per signal, blocks separated by `>>>`. First line of each block:
`target_path: brain/<file>.md`. Body must include `{source_id: <id>, context: <work|personal>}`.

Allowed target paths: `brain/decisions.md`, `brain/people.md`, `brain/projects.md`, `brain/learnings.md`.

Do not invent facts. If the meeting note is too sparse to extract signal, emit nothing.
