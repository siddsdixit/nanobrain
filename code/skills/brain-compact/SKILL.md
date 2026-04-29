---
name: brain-compact
description: Weekly compaction. Dedupe duplicate dated headers, archive entries older than 365 days, regenerate graph, verify hash.
---

# /brain-compact

Operates on: `brain/decisions.md`, `brain/learnings.md`, `brain/projects.md`.

Never touches: `brain/raw.md`, `brain/people.md`, `data/**`.

## Steps

1. Dedupe duplicate `### YYYY-MM-DD ...` headers per file (keep first occurrence + body until next `### ` header).
2. Move entries with header date older than 365 days into `brain/archive/<basename>-<YYYY-MM>.md`.
3. Regenerate `brain/_graph.md` (invokes brain-graph).
4. Verify hash (invokes brain-hash); log drift but do not block.
5. Single git commit.

## Usage

```
compact.sh
```

Honors `BRAIN_DIR` (default `$HOME/brain`) and `NANOBRAIN_DIR` (default `$HOME/Documents/nanobrain-v2`). Idempotent.
