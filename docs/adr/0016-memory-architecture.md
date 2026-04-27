# ADR-0016: Memory architecture — five stages mapped to file types

**Status:** Accepted
**Date:** 2026-04-26

## Context

Tenet 4: brain should act like a human brain — recall, short-term, long-term, etc. Without explicit mapping, "where does this go?" becomes a per-capture decision and creates drift.

Cognitive science distinguishes:
- Working memory (current focus, ~7 items, ephemeral)
- Short-term memory (recent, raw, decays without consolidation)
- Long-term episodic (specific events, dated)
- Long-term semantic (general knowledge, principles)
- Procedural (how to do things — skills, habits)

Sleep consolidates short → long. Patterns surface, noise drops.

## Decision

Map cognitive stages to concrete file types. Each stage has its own retention, access, and compaction rules.

### Working memory

**File:** `CONTEXT.md` (top-level)
**Contents:** This week's focus. Open loops. Active priorities. ~1KB.
**Refresh:** Manual or via `/brain-checkpoint`. Not auto-grown.
**Read:** Loaded into every Claude session.
**Write:** The user edits directly. Skills can update specific sections.
**Compaction:** N/A. Replaced wholesale when focus shifts.

### Short-term memory

**Files:**
- `data/<source>/INBOX*.md` — sensory input per source (Claude sessions, Slack, Granola, repos, voice, etc.). Append-only, shell-only.
- `brain/raw.md` — cross-source firehose. Append-only, shell-only.
- `brain/interactions.md` — interaction log (who/when/what/channel). Append-only, shell-only.

**Retention:** Forever. Never dropped. Source of truth for re-distillation.
**Read:** Never in full. Always `grep` / `tail` / source-specific awk.
**Compaction:** **Forbidden.** These are firehoses (S2, S3a).
**Sleep role:** What gets consolidated INTO long-term during compaction.

### Long-term episodic memory

**Files:**
- `brain/decision/<YYYY-MM-DD>-<slug>.md` — one file per major decision
- `brain/interactions.md` (overlap — interactions are episodic but stored as a log for grep efficiency)

**Format:** Frontmatter `type: decision`, `date: YYYY-MM-DD`. Body: context + decision + rationale + outcome.
**Read:** Loaded as needed when decisions are queried.
**Compaction:** Archive superseded decisions (keep, don't delete).
**Sleep role:** Created from short-term during compaction.

### Long-term semantic memory

**Files:**
- `brain/self.md` — identity, voice, principles
- `brain/goals.md` — quarterly + 1y + 5y aspirations
- `brain/learnings.md` — distilled principles
- `brain/concept/<slug>.md` — one file per named concept (a framework, a methodology, a mental model)
- `brain/person/<slug>.md` — one file per person
- `brain/project/<slug>.md` — one file per active project

**Format:** Frontmatter `type:` per category. Body: content.
**Read:** Loaded into every Claude session (via @-imports in CLAUDE.md).
**Compaction:** Refine learnings (raw observation → principle). NEVER compact people, project, concept files (T14, S3a).
**Sleep role:** Refined and reorganized during compaction.

### Procedural memory

**Files:** (in framework, not in `brain/`)
- `code/skills/<name>/SKILL.md` — what to do (e.g., `/brain compact`)
- `code/agents/<slug>.md` — specialized doers (e.g., `branding` agent)
- `code/sources/<source>/{ingest,distill}.md` — how to absorb new signal

**Format:** Markdown with Anthropic-standard frontmatter for skills/agents.
**Read:** Triggered by user invocation or hook event.
**Compaction:** Forbidden. Procedural memory is curated.
**Sleep role:** `/brain-evolve` may propose new procedures (M1–M5 gated).

### Sleep cycles (T10)

| Cycle | Frequency | What happens |
|---|---|---|
| **Capture** | Every Claude session end (throttled) | Stop hook → consolidate active context → append to short-term + categorize into long-term |
| **REM (compact)** | Weekly | `/brain-compact` — refine learnings, archive stale decisions, regenerate `_graph.md`, recompute `BRAIN_HASH.txt` |
| **Deep sleep (evolve)** | Monthly | `/brain-evolve` — review captures, propose ONE skill/agent/source improvement, commit on approval |

Implemented via launchd plists (macOS) or cron (Linux). Templates in `code/cron/`.

### Index files (a special category)

`brain/{people,projects,decisions,repos}.md` are **indexes** — thin, scannable lists pointing to per-entity files. They're refreshable (regenerated from per-entity files during compaction) but not compacted (T14: single source of truth lives in the per-entity file).

## Consequences

- "Where does this go?" has a clear answer for any new piece of signal.
- Compaction protections (S3a) align with the cognitive role of each file.
- New file types (e.g., `brain/calendar.md` for sleep schedule) inherit defaults from this taxonomy: append-only timeline file → protected from compaction.
- The brain has clear analogs to biological memory; future improvements (e.g., decay model, replay buffer) have natural homes.

## Alternatives considered

- **Flat memory model (one file).** Rejected. Doesn't scale, doesn't capture cognitive distinctions.
- **Folder-per-cognitive-stage.** Rejected. Cognitive stages aren't 1:1 with file types — short-term is split across data/ and brain/. The mapping (stage → files) is more useful than nesting.
- **Database-backed memory (sqlite, vector store).** Rejected per T24 (markdown only).

## Related

- ADR-0001 (three-tier brain/data/code split)
- ADR-0002 (append-only firehoses)
- ADR-0012 (compaction-protected files)
- ADR-0013 (tenets — T9–T11)
- ADR-0008 (source template pattern)
