# ADR-0001: Three-tier architecture (brain / data / code)

**Status:** Accepted
**Date:** 2026-04-26

## Context

The brain mixes raw firehose streams (potentially gigabytes from Slack, Granola, Gmail, etc.) with distilled queryable content with self-modifying machinery. If everything lives in one folder, three things go wrong:
1. Loading `brain/*` into a new LLM session blows the context window.
2. It's unclear what an automated process can safely edit vs what's human-curated.
3. Adding a new source forces structural changes touching everything.

## Decision

Split the repo into three parallel hierarchies:
- `brain/` — clean, distilled, queryable corpus. ~10KB total. Loaded into every Claude session.
- `data/<source>/` — raw, append-only firehose per source. Never Read in full.
- `code/` — all machinery: hooks, skills, source protocols, safety rules, install scripts.

Plus `claude-config/` for synced Claude Code settings (CLAUDE.md, settings.json, mcp.json).

## Consequences

- Adding a new source = adding a folder. Existing flow untouched.
- `/brain` queries have a constant token cost regardless of how much raw data has accumulated.
- Distillation becomes an explicit step (not a side-effect of capture), making it auditable and replayable.
- Tradeoff: more directories to learn at first glance. Mitigated by `README.md` at root and per-folder.

## Alternatives considered

- **Flat vault** (Tolaria-style, all markdown at root with type in YAML frontmatter). Rejected: optimal for human note-taking UI, wrong for capture systems with high-volume streams.
- **Single monolithic file** (one `brain.md`). Rejected: doesn't scale past a few hundred entries.
- **Per-project folders only**. Rejected: cross-cutting content (people, learnings, decisions) lives across projects.
