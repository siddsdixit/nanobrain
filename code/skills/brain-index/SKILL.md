---
name: brain-index
description: Regenerate brain/index.md catalog of all brain pages and sources.
---

# brain-index

Auto-generates `brain/index.md`, the table of contents for the whole brain. Karpathy-prescribed catalog page; counterpart to `brain/log.md` (chronological op log) and `brain/_graph.md` (cross-references).

Three sections:
1. **Categorized files** -- table of `self.md`, `goals.md`, `decisions.md`, `learnings.md`, `projects.md`, `people.md`, `interactions.md` with entry count and last-touched date.
2. **Per-entity pages** -- bulleted list of `brain/people/*.md` and `brain/projects/*.md` with first-line summary.
3. **Sources** -- table of every `data/<source>/INBOX.md` with entry count and last ingest timestamp.

## Usage

```
bash code/skills/brain-index/build.sh
```

Reads `BRAIN_DIR` (default `~/brain`). Idempotent: re-running overwrites `brain/index.md`. Skips silently if no brain dir.

Logs to `brain/log.md` via brain-log.

## Excluded

- `raw.md`, `interactions.md` (firehoses, but interactions is included as a category file with count)
- `_graph.md`, `log.md`, `index.md` itself
- `archive/`, `_sensitive/`, `_contexts.yaml`
