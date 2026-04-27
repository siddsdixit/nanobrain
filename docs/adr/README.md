# Architecture Decision Records

Append-only log of major design decisions. Inspired by Tolaria's 85-ADR practice (https://github.com/refactoringhq/tolaria).

Each ADR follows a fixed structure: Context, Decision, Consequences, Alternatives. Read the ADR before changing the thing it documents. Don't edit accepted ADRs — supersede them with a new ADR if a decision changes.

## Index

| # | Title | Status |
|---|---|---|
| [0001](0001-three-tier-architecture.md) | Three-tier architecture (brain / data / code) | Accepted |
| [0002](0002-append-only-firehoses.md) | Append-only firehoses | Accepted |
| [0003](0003-prompt-type-stop-hook.md) | Stop hook is a `command` type running `claude -p` | Accepted |
| [0004](0004-recursion-guard.md) | Stop-hook recursion guard | Accepted |
| [0005](0005-token-budget-isolation.md) | Token-budget isolation for /brain queries | Accepted |
| [0006](0006-shell-only-raw-writes.md) | Shell-only writes to raw firehoses | Accepted |
| [0007](0007-multi-vendor-activation-files.md) | Multi-vendor activation files | Accepted |
| [0008](0008-source-template-pattern.md) | Source template pattern | Accepted |
| [0009](0009-capture-hardening.md) | Capture-hook hardening | Accepted |
| [0010](0010-long-session-capture.md) | Long-running session capture (throttle + delta + checkpoint) | Accepted |
| [0011](0011-mirror-rule.md) | Mirror rule — every `brain/` write also lands in `raw.md` | Accepted |
| [0012](0012-compaction-protected-files.md) | Compaction-protected files (people, repos, interactions, raw) | Accepted |
| [0013](0013-tenets-and-hard-truths.md) | Tenets and hard truths (the lockdown) | Accepted |
| [0014](0014-agent-foundry.md) | Agent foundry — brain spawns its own agents | Accepted |
| [0016](0016-memory-architecture.md) | Memory architecture — five stages mapped to file types | Accepted |

## When to write a new ADR

- Changing or adding to `code/SAFETY.md` invariants.
- Restructuring directory layout.
- Switching capture / distill / query mechanism.
- Adding a major new dependency or framework.
- Reversing a previous ADR (mark old one as `Superseded by ADR-NNNN`).

## Template

```markdown
# ADR-NNNN: Short title

**Status:** Proposed | Accepted | Superseded by ADR-MMMM
**Date:** YYYY-MM-DD

## Context
What's the situation? What forces are at play?

## Decision
What did we decide?

## Consequences
What changes? What's the trade-off?

## Alternatives considered
What did we reject and why?
```
