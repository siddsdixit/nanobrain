# ADR-0011: Mirror rule — every `brain/` write also lands in `raw.md`

**Status:** Accepted
**Date:** 2026-04-26

## Context

`brain/raw.md` is the cross-source uncompacted firehose, designed as the long-term audit trail of every signal that ever entered the brain. Until today the rule was implicit: the Stop hook (`STOP.md`) and `/brain-save` both wrote to `raw.md`, but manual edits to `brain/<category>.md` (user hand-editing, or assistant-driven population from a machine scan) sometimes skipped the mirror.

This breaks the contract. If `raw.md` doesn't faithfully reflect everything that landed in `brain/`, then `/brain` queries grepping `raw.md` for historical context will miss content. The audit trail isn't an audit trail.

Rule: if you wrote something into a categorized brain file, write it into raw also. Always.

## Decision

**Any write to `brain/<category>.md` MUST be mirrored to `brain/raw.md` via shell-append.**

This applies to:
- Stop-hook captures (already complied)
- `/brain save` slash command (already complied)
- `/brain-save` skill protocol (already complied)
- Manual edits Claude makes to brain files (now required)
- Source distillation (`code/sources/<slug>/distill.md`) — already required by template, now hard-stated

Format mirrored to raw.md:
```
### YYYY-MM-DD HH:MM — <category> — <title>

<the content, or a 1-2 line summary if the categorized entry is long>
```

**Exception for bulk rewrites.** When restructuring an entire categorized file (rare, manual), use a single summary entry in raw.md pointing at the git commit SHA. This avoids spamming raw.md with thousands of duplicate lines.

Codified as `S2a` in `code/SAFETY.md`.

## Consequences

- `raw.md` becomes a faithful firehose. Greppable for any historical question: "when did this first show up in the brain?"
- Token cost of writing is slightly higher (one shell-append per categorized write).
- Distillation tools (`/brain-compact`) that rewrite categorized files only need to summarize their pass into raw.md once, not mirror every change.
- `/brain-evolve` can detect drift: if a categorized file has entries `raw.md` doesn't, the mirror rule was violated.

## Alternatives considered

- **Skip the mirror; rebuild raw.md from categorized files.** Rejected. Categorized files get compacted; raw.md is supposed to outlive compaction. You can't reconstruct the firehose from the post-compaction view.
- **Make raw.md a derived view (not source of truth).** Rejected. Then we lose the immutable-history property.
- **Per-category raw files (raw-decisions.md, raw-people.md, etc.).** Rejected. The cross-cutting cross-source firehose is the whole point.

## Related

- ADR-0002 (append-only firehoses)
- ADR-0006 (shell-only firehose writes)
- `code/SAFETY.md` invariants S2, S2a
