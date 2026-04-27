---
name: brain-graph
description: Build and query the cross-linking graph between brain entries. Recognizes [[Page Name]] backlinks, builds brain/_graph.md inverted index, answers relationship queries.
---

# /brain-graph

Cross-linking layer for the brain. Inspired by Obsidian / Roam / LLM-wiki conventions. Adopted Day 0 so the convention compounds from the start.

## The convention

In any compactable brain file (`self`, `goals`, `projects`, `people`, `learnings`, `decisions`) and in `interactions.md`, wrap **known entities** in `[[ ]]`:

```markdown
2026-04-26 — [[Example Corp]] interview moving forward. [[Recruiter Name]] confirmed
[[Hiring Manager]] call Apr 6, [[Investor Name]] (Example Capital) Apr 8.
Pipeline lives in [[Operations Log]].
```

A "known entity" is anything that has its own:
- Heading in `brain/people.md` (use the exact display name in the bullet — e.g. `[[Recruiter Name]]`)
- Heading in `brain/projects.md` (e.g. `[[Project Alpha]]`, `[[Internal Initiative]]`)
- Per-person file `brain/people/<slug>.md`

You can also link to **emergent concepts** that don't yet have a page (e.g. `[[Buyer/Seller Assistant]]`). The graph picks them up; if they recur, promote to `projects.md`.

## Steps to build / refresh

1. Run `bash $HOME/brain/code/skills/brain-graph/build.sh`. This:
   - Greps `\[\[([^\]]+)\]\]` across `brain/*.md` (excluding `raw.md`, `interactions.md`, `_graph.md`, `archive/`).
   - Normalizes entity names (case-insensitive, trim whitespace).
   - Writes `brain/_graph.md` with one section per entity listing every file:line that references it.
2. Commit the regenerated `_graph.md`.
3. Mirror a single summary entry to `brain/raw.md` (per ADR-0011).

## Steps for `/brain links <entity>`

1. Read `brain/_graph.md` (small, regenerated, not raw).
2. Find the entity (case-insensitive match).
3. Return its backlinks list with file:line citations.
4. If entity not found, suggest: "no backlinks. Add `[[<entity>]]` to a brain file to start tracking, or check spelling against `people.md` / `projects.md`."

## Run cadence

- **Manually** via `/brain links <name>` (rebuilds if stale).
- **Automatically** as part of `/brain compact` (monthly).
- **Auto-rebuild trigger:** if `_graph.md` is older than the most recent commit on `brain/`, rebuild before answering a `/brain links` query.

## Hard rules

- `_graph.md` is auto-generated. Never hand-edit.
- `_graph.md` is **compaction-protected** (it's a registry). See SAFETY.md S3a.
- Manual `[[ ]]` linking is voluntary. The graph is best-effort, not authoritative.
- Hook-driven captures and source distillations should wrap known entities automatically.
- No em dashes inside `[[ ]]`.

## Out of scope

- No graph visualization (this is markdown, not a graph DB).
- No rename refactoring (if a person changes name, manually grep+sed).
- No cross-machine name resolution (canonical names per `people.md` index).
