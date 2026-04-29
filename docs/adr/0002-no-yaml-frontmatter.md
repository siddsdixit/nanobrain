# ADR-0002: No YAML frontmatter on brain pages

## Status
Accepted (2026-04-28)

## Context
Karpathy's LLM Wiki gist (https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
prescribes YAML frontmatter on every page (tags, dates, source counts) so Obsidian's
Dataview plugin can run structured queries. v2 declined this prescription.

## Decision
Brain pages stay plain markdown. Per-entry tagging is a single inline block:
`{context: <work|personal>, source_id: <id>}`. No YAML, no Dataview-shaped metadata.

## Rationale
- The framework is a CLI second brain, not an Obsidian app. Dataview is Obsidian-specific.
- YAML frontmatter introduces a per-page schema users must learn and maintain. v2's value
  proposition is "cat-readable, agent-readable, no surprises."
- Adding YAML reopens the axis-creep problem we explicitly closed (see ADR-0001).
- `git log` + `brain/log.md` cover the operational metadata Dataview would surface.

## Consequences
- No Dataview queries.
- No per-page tag taxonomy beyond `{context: ...}`.
- Per-entity pages (brain/people/<slug>.md) stay free-form markdown.
- Future option (NOT in v2): opt-in YAML on per-entity pages where they function as
  artifacts rather than entries. Defer until a real user asks.

## Linked
- ADR-0001: v2 lean design (3 axes -> 1 axis).
- Karpathy LLM Wiki gist (referenced above).
