# ADR-0008: Source template pattern (`code/sources/_TEMPLATE/`)

**Status:** Accepted
**Date:** 2026-04-26

## Context

`SOURCES.md` enumerates 30+ anticipated future sources (Slack, Granola, Gmail, LinkedIn, voice, financial, health, etc.). Without a standard pattern, each new source's integration would be bespoke, hard to compare, and inconsistent in privacy/safety hygiene.

## Decision

Every source follows the same three-file pattern:
- `code/sources/<slug>/README.md` — what this source is, why ingest it, auth requirements, privacy filters
- `code/sources/<slug>/ingest.md` — exact protocol Claude follows to pull data into `data/<slug>/INBOX.md`
- `code/sources/<slug>/distill.md` — exact protocol Claude follows to extract signal from INBOX into `brain/`

A `code/sources/_TEMPLATE/` folder holds drop-in starter versions of these three files. Adding a new source is `cp -R _TEMPLATE <slug>` followed by filling in source-specifics.

The recipe is documented in `code/sources/README.md`.

## Consequences

- Adding a new source is a 15-minute job, not a research project.
- All sources share privacy filters, watermark conventions, append-only INBOX rules.
- `/brain-evolve` can compare across sources to spot inconsistencies.
- Tradeoff: the template is opinionated. Sources that don't fit the ingest→distill model would need a different pattern. None encountered yet.

## Alternatives considered

- **Hand-write each source.** Rejected: no consistency, drift inevitable.
- **Code-generate sources from a JSON manifest.** Rejected: more complexity for marginal benefit at this scale.
