# Changelog

All notable changes to nanobrain. Format follows [Keep a Changelog](https://keepachangelog.com/).

## Unreleased

## v2.2.0 (2026-04-30)

### Added
- MCP fetch bridge: live API ingest for Gmail, Google Calendar, Google Drive, Slack via Claude Code MCPs.
- Granola source (meeting transcripts) using `public-api.granola.ai` with `grn_` API key.
- `brain-add <source>` skill: detect → prompt/configure → fetch → ingest → distill → register launchd.
- `code/lib/detect_mcp.sh`: detects which MCPs the user has connected.
- macOS Keychain fallback for the Granola API key.

### Fixed
- `claude` CLI not on launchd PATH — drainer was failing with `distill_rc=3` for every queue entry. Plist now sets explicit PATH.
- Bare `except:` in JSON extractors swallowed `SystemExit` from `sys.exit(0)`. Now `except Exception:`.
- Non-greedy regex `(\[.*?\])` in JSON extractor matched empty `{}` on nested payloads. Replaced with balanced-bracket scanner.
- `--output-format json` was returning the session JSON stream, not the assistant's text. Removed.
- Field normalization for actual MCP shapes: `sender`→`from`, `snippet`→`body`, `summary`→`title`, nested `start.dateTime`, `owners` list, `toRecipients` array.
- `install.sh` now registers brain skills as symlinks in `~/.claude/skills/` so `/brain`, `/brain-save`, etc. are visible to Claude Code.

## v2.1.2 (2026-04-29)

### Added
- Landing page at [nanobrain.app](https://nanobrain.app) (Cloudflare Pages).
- Site styling: 18px base font, content synced to v2.1.1 README.

## v2.1.1 (2026-04-29)

### Changed
- Split capture from distill. Stop hook is now a sub-50ms file append (previously a synchronous LLM call that hung for up to 14 minutes).
- Distill runs in a separate idle-gated drainer (every 30 min via launchd; only fires when keyboard idle 5+ min).

### Fixed
- 14-minute hang reported in v2.0 (synchronous LLM call inside the Stop hook).
- Drainer now kills grandchildren via `perl setpgrp` on timeout.

## v2.1.0 (2026-04-29)

### Added
- Multi-tool activation files: `AGENTS.md`, `GEMINI.md`, `.cursorrules`.
- Read-side support via MCP for Codex / Cursor / Gemini / Aider.

## v2.0.0 (2026-04-29)

Initial public release.

### Added
- 17 skills (`brain`, `brain-save`, `brain-checkpoint`, `brain-compact`, `brain-evolve`, `brain-distill`, `brain-doctor`, `brain-graph`, `brain-hash`, `brain-redact`, `brain-spawn`, `brain-init`, `brain-ingest`, `brain-index`, `brain-lint`, `brain-log`, `brain-restore`).
- 5 sources: gmail, gcal, gdrive, slack, claude (built-in capture).
- MCP server (`code/mcp-server/`) with `read_brain_file` and context-filter enforcement.
- Karpathy alignment: index, log, lint per the [LLM Wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).
- 173/173 tests green.
