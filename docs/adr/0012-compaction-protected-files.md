# ADR-0012: Compaction-protected files

**Status:** Accepted
**Date:** 2026-04-26

## Context

`/brain-compact` runs monthly to keep the corpus dense and pasteable. It dedupes, merges, refines, and archives stale entries. The original protocol said "compact every brain/*.md except raw.md."

But that's wrong for some files. Compaction destroys signal in files where every entry is load-bearing.

Should the brain ever compact people? No. Names, contacts, relationships, and history don't get compacted. Compaction would drop a contact, lose a relationship, or merge two distinct people. The same logic applies to other registry-style files.

## Decision

**Principle:** compaction destroys signal in files where every entry is load-bearing. Only **insight-and-decision** files get compacted. **Registries, logs, history, and append-only firehoses are protected.**

**Test for compactability:** can you safely lose, merge, or refine an arbitrary entry in this file? If no, protect it.

### Compactable (refine / dedupe / archive stale)
- `brain/learnings.md` — promote raw observations to principles
- `brain/decisions.md` — archive superseded
- `brain/projects.md` — archive completed
- `brain/goals.md` — replace stale quarterly
- `brain/self.md` — minimal touch only

### Protected (NEVER compact)

Inside `brain/`:
- `raw.md` — long-term firehose, immutable
- `interactions.md` — append-only who-when-what log
- `people.md` — contact index (names accumulate)
- `people/<slug>.md` — per-person detail
- `repos.md` — repo registry
- `archive/**` — already archived
- Any future timeline/log/history file: `calendar.md`, `timeline.md`, `health.md`, `financials.md`, `contracts.md`. New brain/ files of this shape are **protected by default**.

Outside `brain/`:
- `data/**` — source firehoses
- `data/_sensitive/**` — gitignored sensitive content
- `docs/adr/**` — append-only ADRs (supersede with new, never rewrite old)
- `code/**`, `claude-config/**` — machinery
- Top-level pointers: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `CONTEXT.md`, `ROADMAP.md`, `SOURCES.md`, `SCHEMA.md`, `README.md`, `plan.md`

Codified as `S3a` in `code/SAFETY.md` and listed in `code/skills/brain-compact/SKILL.md`.

## Consequences

- People and repos can grow as large as they need to. Never auto-pruned.
- Compaction's blast radius is bounded — it can't accidentally lose a contact or a repo.
- Tradeoff: protected files might bloat over years. Acceptable: scanning a 5000-line `people.md` is still cheap, and grep handles any size. If someday it really is too big, manual restructuring (not auto-compaction) is the answer.

## Alternatives considered

- **Compact everything except raw.md.** Rejected — risks dropping signal from registries.
- **Compact people.md but only by deduping clearly-identical entries.** Rejected — "clearly identical" is brittle (e.g., name spelled two ways, role changed). Easier to just protect.
- **Auto-archive people who haven't appeared in interactions.md in N years.** Rejected — too aggressive. The index should remain a memory aid even for distant contacts.

## Related

- ADR-0002 (append-only firehoses)
- ADR-0011 (mirror rule)
- `code/SAFETY.md` invariant S3a
