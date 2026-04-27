# Changelog

All notable changes to nanobrain are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org).

## [0.1.0] — 2026-04-26

Initial public release.

### Added
- Three-tier architecture (`brain/` corpus + `data/` firehoses + `code/` machinery)
- 8 slash commands: `/brain`, `/brain-save`, `/brain-compact`, `/brain-evolve`, `/brain-checkpoint`, `/brain-spawn`, `/brain-graph`, `/brain-hash`
- Hardened capture pipeline (Stop + SessionEnd + PreCompact hooks; recursion guard; lock; timeout; atomic verify; audit log)
- Per-entity file pattern (`brain/{person,project,decision,concept}/<slug>.md`)
- Cross-linking graph with `[[wikilinks]]`
- Agent foundry — `code/agents/` with `_TEMPLATE.md` and scope-declared spawning
- MCP server skeleton with 7 locked tool signatures
- Sleep cycles (launchd plists for weekly compact, monthly evolve)
- BRAIN_HASH.txt integrity audit
- 16 ADRs documenting architecture decisions
- 29 SAFETY invariants (S1–S29) + 5 self-modification rules (M1–M5)
- Multi-vendor activation (CLAUDE.md, AGENTS.md, GEMINI.md)
- Source plugin pattern (`code/sources/_TEMPLATE/`)
- Reference source: `code/sources/repos/` (live)

### Inspiration
- [Karpathy's LLM wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) (April 2025)
- [Karpathy's autoresearch](https://github.com/karpathy/autoresearch)
- [Tolaria](https://github.com/refactoringhq/tolaria)
- Vannevar Bush, "As We May Think" (1945) — the original memex
