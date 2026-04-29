# gmail distill

Read `data/gmail/INBOX.md`. For each entry, decide whether it represents:

- a **decision** the user made or is being asked to make
- a **person** worth tracking (recurring sender, new contact)
- a **project** signal (meeting, milestone, blocker)
- noise (drop)

Output one block per signal, blocks separated by `>>>`. First line of each block:
`target_path: brain/<file>.md`. Body must include `{source_id: <id>, context: <work|personal>}` so the line can be traced back to its INBOX entry.

Allowed target paths: `brain/decisions.md`, `brain/people.md`, `brain/projects.md`, `brain/learnings.md`. Anything else is rejected by `brain-distill`.

Do not invent facts. If the INBOX entry is ambiguous, emit nothing.
