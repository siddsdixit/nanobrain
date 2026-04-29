# brain

The query gateway. Read the corpus, answer from cited files only.

## Usage

```
/brain <question>
```

Examples:

- `/brain who is Jen?`
- `/brain what did I decide about Idaho-craig?`
- `/brain status` -- print brain health (last commit, file sizes, source freshness).
- `/brain paths` -- print canonical brain file paths.

Without an argument, the skill loads the corpus into context and waits for a follow-up.

## What it reads

In order:
1. `$BRAIN_DIR/brain/self.md`
2. `$BRAIN_DIR/brain/goals.md`
3. `$BRAIN_DIR/brain/projects.md`
4. `$BRAIN_DIR/brain/people.md`
5. `$BRAIN_DIR/brain/learnings.md`
6. `$BRAIN_DIR/brain/decisions.md`

Never reads `raw.md`, `interactions.md`, or `data/<source>/INBOX.md`. Those are firehoses (S2 invariant). For provenance-style queries, point the user at git log.

## Hard rules

- Answer only from corpus. No invention.
- Always cite source file. Format: `(brain/decisions.md, 2026-04-28)`.
- One paragraph or tight bullets. No preamble.
- No em dashes.
- If the answer reveals a gap, suggest `/brain-save <text>`.

## Sub-commands

| First word | Action |
|---|---|
| `status` / `health` | Print last capture commit, file sizes, days since last source ingest |
| `paths` | Print canonical paths |
| `links <entity>` | Find `[[backlinks]]` to `<entity>` (greps brain/*.md) |
| anything else | Treat as a question against the corpus |

`status` is implemented by `query.sh status`; everything else is interpretation by the calling Claude session.
