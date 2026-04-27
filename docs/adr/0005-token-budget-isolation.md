# ADR-0005: Token-budget isolation for /brain queries

**Status:** Accepted
**Date:** 2026-04-26

## Context

`/brain <question>` should answer instantly with a small, predictable token cost regardless of how much raw data the brain has accumulated. Without explicit isolation, /brain could be tempted to load `raw.md` (eventually GBs) or scan all of `data/` to "be thorough."

## Decision

`/brain` query mode loads ONLY:
- `$HOME/brain/CONTEXT.md`
- `$HOME/brain/brain/{self,goals,projects,people,learnings,decisions}.md`
- `$HOME/brain/ROADMAP.md` only if question touches future plans

It MUST NOT load:
- `brain/raw.md` (cross-source firehose)
- `brain/interactions.md` (use `grep`/`tail` instead)
- `data/**` (any source firehose; use `grep`/`tail` instead)
- `brain/archive/**` unless explicitly requested

`code/SAFETY.md` invariant S6 codifies this. `/brain-evolve` cannot raise the limit.

## Consequences

- /brain query cost is bounded: roughly 10KB of clean files, regardless of total brain size after years of capture.
- Distillation discipline: the categorized files must be kept lean (compaction-driven) so they're enough on their own.
- Tradeoff: /brain occasionally can't answer "find every interaction with X across all time" without an explicit `grep` step. Acceptable: those queries explicitly opt into a larger budget.

## Alternatives considered

- **No isolation.** Rejected: token costs become unbounded as data accumulates.
- **Vector embedding + retrieval.** Rejected: complexity, vendor coupling, lossy.
- **Summary regeneration on every query.** Rejected: latency, cost, and same problem at a different layer.
