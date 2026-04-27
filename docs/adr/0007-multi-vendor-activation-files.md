# ADR-0007: Multi-vendor activation files (CLAUDE.md, AGENTS.md, GEMINI.md)

**Status:** Accepted
**Date:** 2026-04-26

## Context

A user may run Claude Code primarily but want the brain to work with Cursor, Codex, Gemini CLI, and whatever comes next. Each tool reads a different convention file at session start (Claude reads `CLAUDE.md`; Codex/Cursor read `AGENTS.md` per the agents.md spec; Gemini CLI reads `GEMINI.md`).

If the brain only ships `CLAUDE.md`, switching tools loses the personality, voice, rules, and brain-import directives.

## Decision

Ship three activation files at the repo root, all pointing at the same `brain/` corpus:
- `CLAUDE.md` — for Claude Code
- `AGENTS.md` — for any agents.md-spec-compliant tool (Codex, Cursor, Aider, OpenCode)
- `GEMINI.md` — for Google Gemini CLI

Each file imports the brain content (`@brain/self.md`, `@brain/goals.md`, etc.) and restates the user's voice rules. install.sh symlinks the synced version of `claude-config/CLAUDE.md` to `~/.claude/CLAUDE.md`; the AGENTS.md and GEMINI.md files are read in-place from any directory the agent is launched in.

## Consequences

- Switching tools doesn't lose context.
- New tools just need to add their convention file (one new ~50-line markdown file).
- Tradeoff: three slightly-different files to keep in sync. Mitigated: they share 90% of their content. `/brain-evolve` flags drift between them.

## Alternatives considered

- **Symlink the three files to a common source.** Rejected: each tool may want slightly different framing.
- **Single `CONTEXT.md` plus tool-specific tiny pointer files.** Could be done later if drift becomes painful.
