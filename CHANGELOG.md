# Changelog

All notable changes to nanobrain are documented here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versioning: [SemVer](https://semver.org).

## [0.1.0] — 2026-04-27

Hardened release. Framework production-ready, MCP fully implemented, 66 smoke tests gate every commit.

### Added

- **`code/hooks/redact.sh`** — defense-in-depth secrets filter that strips OpenAI / Anthropic / GitHub / AWS / Slack tokens, JWTs, Bearer tokens, and inline `api_key=` / `password=` / `client_secret=` patterns from every transcript delta before it reaches `claude -p`.
- **`/brain-redact` skill** — 9th slash command. Last-resort secret scrubber: rewrites git history with `git filter-repo`, force-pushes, logs the redaction (never the secret itself), keeps a 30-day backup bundle.
- **MCP server real implementations.** All 7 tools (`brain_search`, `brain_get_entity`, `brain_list_by_type`, `brain_relationships`, `brain_query_graph`, `brain_add_to_inbox`, `brain_status`) do real filesystem queries. Previously 5 of 7 were stubs.
- **`code/runtimes/wrap.sh`** — generic wrapper that brings the capture loop to any agent CLI (Codex, Gemini, Aider, etc.). Per-runtime READMEs in `code/runtimes/{codex-cli,gemini-cli,aider,cursor}/`.
- **`install.sh --dry-run`** prints intended changes without modifying disk.
- **`install.sh --read-only`** scaffolds the brain dir only, skips `~/.claude` mutation. Lets evaluators try the framework without granting write access.
- **`test/smoke.sh`** harness — **66 checks** spanning install (full / dry-run / read-only), capture guards (recursion + payload + throttle), force-capture, watermark XDG location, redaction (8 secret types + end-to-end), MCP positive cases (real data from synthetic brain), MCP edge cases (empty brain, missing entity, invalid type, missing `_graph.md`, inbox write), runtime wrappers (codex/gemini/aider mocks + NO_CAPTURE override + missing CLI), config validity (JSON + plist + skill frontmatter), shellcheck.
- **`.github/workflows/ci.yml`** runs the smoke test on every push / PR.
- **`COMPATIBILITY.md`** matrix and recipes for Codex CLI, Gemini CLI, Cursor, Aider, web Claude / ChatGPT.
- **Populated `examples/starter-brain/`** with synthetic but realistic data so the README's `/brain who is jane` demo actually works.

### Changed

- **Watermark relocation.** Per-session capture state moved from `data/_logs/sessions/` (inside the brain repo) to `${XDG_STATE_HOME}/nanobrain/sessions/` (machine-local). Lock file moved alongside. Prevents the framework from polluting the user's brain repo with untracked state and stops cross-machine watermark conflicts.
- **Lock file timestamping.** Lock now stores `<pid> <epoch>`. A lock is considered held only if the PID is alive AND younger than 2× the timeout. Closes a macOS PID-reuse failure mode where a stale lock would silently wedge captures forever.
- **README rewritten.** Repositioned around vendor-neutrality vs Anthropic Memory / OpenAI Memory / Gemini Memory. New comparison table includes built-in Memory features.
- **MCP server SDK migration** to `@modelcontextprotocol/sdk@^1.0.0` API (`ListToolsRequestSchema`, `CallToolRequestSchema`). Old code crashed on startup against current SDK.
- **`install.sh`** now also symlinks `brain-graph`, `brain-hash`, and `brain-redact` skills (previously only 6 of 9 were wired).

### Fixed

- **`capture.sh` referenced unset `$HOURS_SINCE`.** Under `set -u`, the script crashed on the FORCE_CAPTURE path. Now computed alongside `$MINUTES_SINCE`.
- **`capture.sh` ran `git clean -fd data/`** after a no-op claude invocation, deleting its own log files and watermarks. Removed the `data/` arm; only `brain/` is cleaned now.
- **`.gitignore`** now excludes `data/_logs/`, `.capture.lock`, `node_modules`, the smoke-test scratch file, and `.cache/`.

### Security

- Personal information about the framework's author (project names, narrative attribution, environment variable prefixes) was scrubbed from the public framework repo. Env vars are `NANOBRAIN_*`, narrative references use `the user` / `the operator`, project examples use generic placeholders. Pre-v0.1 commit history was wiped via repo delete-and-recreate.

## [Unreleased]

Planned for v0.2:
- VHS-rendered demo GIF in README hero
- Granola source plugin completion
- Cursor extension prototype
- `nanobrain-web` browser extension scaffold (claude.ai / chatgpt.com / gemini.google.com)

### Inspiration

- [Karpathy's LLM wiki gist](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f) (April 2026)
- [Karpathy's autoresearch](https://github.com/karpathy/autoresearch)
- Vannevar Bush, "As We May Think" (1945) — the original memex
