# ADR-0013: Tenets and hard truths (the lockdown)

**Status:** Accepted
**Date:** 2026-04-26

## Context


## Decision

Adopt 8 stated tenets + 24 derived hard truths. After this ADR, **architecture is frozen.** Future structural changes require a new ADR with explicit operator sign-off.

### Tenets

1. Scale infinitely (50+ years, lifetime).
2. Scale with sources (plug-in pattern).
3. Never corrupt (data integrity is non-negotiable).
4. Act like a human brain (working / short-term / long-term / procedural / episodic).
5. Compact insights, never relationships or people.
6. Self-improve / evolve / spawn small tools.
7. Security-focused.
8. Public / sharable (framework public, content private).

### Derived hard truths

**Memory architecture (T9–T11)**
- T9: Five memory stages with different rules — working (CONTEXT.md), short-term (data inboxes + raw.md), long-term episodic (decisions, interactions), long-term semantic (concepts, learnings, self/goals), procedural (skills/agents/sources).
- T10: Sleep cycles — daily capture; weekly `/brain-compact`; monthly `/brain-evolve`.
- T11: Recall O(1), encoding can be slow.

**Time (T12–T13)**
- T12: Every fact carries an immutable ISO 8601 timestamp.
- T13: Compaction never drops dates (records date span when refining).

**Truth + integrity (T14–T16)**
- T14: Single source of truth per fact (per-entity files; indexes link, never duplicate content).
- T15: Detectable corruption — `BRAIN_HASH.txt` regenerated on compaction; mismatch alarm.
- T16: Reversibility — every change is a git commit. `git revert` undoes anything.

**Security tiers (T17–T20)**
- T17: Four tiers — Framework (public) / Personal (private) / Confidential (sensitivity flag) / Sensitive (encrypted at rest, gitignored).
- T19: Local-first AI; opt-in cloud only with per-action approval.
- T20: Defense in depth on capture — secrets regex filter + final audit pass.

**Self-improvement (T21–T22)**
- T21: Brain creates its own tools, gated by operator approval (M1–M5).
- T22: New tools start as templates, not from-scratch (`code/sources/_TEMPLATE/`, `code/agents/_TEMPLATE.md`).

**Format invariants (T23–T25)**
- T23: Backwards-compatible schema forever (add optional, never remove/rename).
- T24: Markdown + YAML only in `brain/`. No JSON, SQLite, binary.
- T25: No vendor lock anywhere in the data path.

**Inheritance (T26–T27)**
- T26: Anyone with the repo can read the brain (`cat brain/self.md` works).
- T27: `brain/README.md` is plain English; readable by non-engineers.

**Determinism (T28–T29)**
- T28: Re-running operations produces identical results.
- T29: No race conditions (locks + watermarks).

**Agent foundry (T30–T32)**
- T30: Agents are markdown, not code. Vendor-neutral.
- T31: Agents declare `reads:` / `writes:` scope at spawn time. Brain enforces.
- T32: Brain-spawned agents need explicit human approval before activation.

## Consequences

- Architecture frozen. Future changes require new ADRs.
- Contributors / forkers know the rules — same set of invariants applies to their derived brains.
- `/brain-evolve` reads SAFETY.md (which encodes T9–T32 as S10–S29) before any edit; refuses to weaken any.

## Alternatives considered

- **No lockdown, iterate freely.** Rejected. That's how we got here. Drift is the cost.
- **Lighter set of tenets (8 only).** Rejected. The 24 derived truths follow inevitably from the 8 — making them implicit invites re-derivation each time.
- **Heavier set with enforcement (e.g., schema validation, signed commits).** Rejected for now. Add only when actual problem surfaces.

## Related

- `code/SAFETY.md` invariants S1–S29 (S10–S29 added by this ADR)
- ADR-0014 (Agent foundry, T30–T32)
- ADR-0015 (Public / private repo split, T17–T18)
- ADR-0016 (Memory architecture, T9–T11)
