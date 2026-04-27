# ADR-0006: Shell-only writes to raw firehoses

**Status:** Accepted
**Date:** 2026-04-26

## Context

Files like `brain/raw.md`, `brain/interactions.md`, and `data/<source>/INBOX.md` accumulate every captured signal. They will eventually be huge. Two destructive scenarios were considered:
1. An automated process uses the Edit tool, miscounts lines, and silently deletes a chunk of history.
2. A script uses `>` instead of `>>` and overwrites the file with a single line.

## Decision

All writes to firehose files use `printf '...' >>` or `cat >> file`. Specifically forbidden:
- `>` (overwrite)
- `tee` without `-a`
- The Edit, Write, or NotebookEdit tools when the target is a firehose

Skill protocols (`STOP.md`, `brain-save/SKILL.md`, source `ingest.md`/`distill.md`) and `code/SAFETY.md` invariant S2 enforce this.

## Consequences

- Files cannot be silently truncated.
- Append operations are atomic enough at this scale (POSIX guarantees small `>>` writes are atomic).
- Tradeoff: editing an existing entry requires manual hand-editing in a text editor. Acceptable: firehose entries are append-only by design.

## Alternatives considered

- **Use Edit tool with line-anchored insertion.** Rejected: Edit tool reads the whole file first. Token burn + corruption risk.
- **Write a custom append wrapper as a tool.** Rejected: shell `>>` is already the right tool.
