# ADR-0002: Append-only firehoses

**Status:** Accepted
**Date:** 2026-04-26

## Context

`brain/raw.md`, `brain/interactions.md`, and `data/<source>/INBOX.md` will grow indefinitely. If automated processes Read or Edit these files, two failure modes emerge:
1. Token burn — reading a multi-MB file eats the context window.
2. Corruption — an Edit tool that miscounts lines could silently truncate years of history.

## Decision

These files are **shell-append only**:
- Writes use `printf '...' >>` or `cat >>`. Never `>`. Never the Edit tool. Never the Write tool.
- Reads use `grep`, `tail`, `awk` from a watermark, or `head -n <small>`. Never the Read tool on the whole file.
- Every skill (`brain`, `brain-save`, `brain-compact`, `brain-evolve`) and the Stop hook protocol enforce this rule explicitly.

## Consequences

- Files cannot be silently corrupted by tool errors.
- Token cost of any operation against these files is bounded.
- History is preserved. Every entry survives forever.
- Tradeoff: structured edits to old entries are not possible. Acceptable: the design treats firehoses as immutable history. Distillation pulls signal *out* without modifying source.

## Alternatives considered

- **JSONL with structured edits.** Rejected: same corruption risk, plus JSON parse overhead, plus loses pasteable-into-LLM property.
- **SQLite.** Rejected: vendor lock-in (in spirit), loses git-diff readability, requires a query layer for what `grep` already does.
- **Vector DB.** Rejected: complexity overkill for personal-scale corpus, vendor-coupled.
