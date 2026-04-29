---
name: brain-evolve
description: Monthly self-improvement. Reads last 30 days of learnings + decisions, drafts ONE proposed brain edit to code/agents/_proposed/.
---

# /brain-evolve

Reads last-30-day entries from `brain/learnings.md` and `brain/decisions.md`. Asks `claude -p` (or `NANOBRAIN_DISTILL_STUB` for tests) for a single targeted edit proposal. Writes the proposal to `code/agents/_proposed/evolve-<timestamp>.md`. Does not apply.

## Usage

```
evolve.sh
```

## Env

- `BRAIN_DIR` (default `$HOME/brain`)
- `NANOBRAIN_DIR` (default `$HOME/Documents/nanobrain-v2`)
- `NANOBRAIN_DISTILL_STUB` -- path to a script that reads stdin and writes proposal to stdout. When set, `claude` is not invoked.

## Output

```
[brain-evolve] proposal written: <path>
```
