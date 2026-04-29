---
name: brain-graph
description: Regenerate brain/_graph.md from [[entity]] backlinks across brain/*.md.
---

# /brain-graph

Scans `brain/*.md` for `[[entity]]` references, groups by normalized (lowercase, trimmed) entity name, writes `brain/_graph.md` with one section per entity listing `file:line` backlinks.

Excluded from scan: `raw.md`, `interactions.md`, `_graph.md` itself, and `archive/`.

## Usage

```
graph.sh
```

Honors `BRAIN_DIR` env (default `$HOME/brain`). Idempotent.
