# brain-save

Manual force-capture. User says it; brain stores it.

## Usage

```
/brain-save <text>
```

Examples:

- `/brain-save Decided to pause Idaho-craig project for Q3`
- `/brain-save Met Jen for coffee Tuesday — friend, gmail, casual`
- `/brain-save Learned: launchd StartInterval is wall-clock seconds, not boot-relative`

The Claude session interprets the text, picks the right brain file (decisions / learnings / projects / people), routes it via `save.sh`, mirrors to `raw.md`, commits.

## What it writes

- One categorized brain file (`brain/{decisions,learnings,projects,people,goals,self}.md`)
- `brain/raw.md` (mirror, S2a)
- Single git commit with message `save: <first 60 chars of text>`

## Tag block

Every saved entry includes:

```
{context: <work|personal>}
```

If the user names a person or domain that matches `_contexts.yaml`, the resolver picks the context. Otherwise default `personal`.

## Hard rules

- Append-only. Never edit existing entries.
- Mirror to raw.md always.
- Commit always.
- Redact secrets before write (S5).
- No em dashes.
