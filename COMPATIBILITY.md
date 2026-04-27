# Compatibility — bringing nanobrain to other agents

The framework has two halves:

1. **Read side**: agents read `brain/*.md` to load context at session start.
2. **Capture side**: when a session ends, the conversation is distilled into the brain.

The read side is vendor-neutral and works almost anywhere markdown is consumable. The capture side currently relies on Claude Code's `Stop` hook.

## Today

| Tool | Reads brain | Captures sessions | Effort |
|---|:---:|:---:|---|
| **Claude Code** (CLI) | ✅ via `CLAUDE.md` `@`-import | ✅ Stop / SessionEnd / PreCompact hooks | shipping |
| **Codex CLI** | ✅ via `AGENTS.md` ([spec](https://agents.md)) | ❌ no native hook | wrapper script |
| **Gemini CLI** | ✅ via `GEMINI.md` | ❌ no native hook | wrapper script |
| **Cursor** | ✅ via `AGENTS.md` or `.cursorrules` | ❌ no native hook | extension |
| **Aider** | ✅ via `AGENTS.md` | ⚠️ `/save` is manual | low |
| **Claude desktop / web** | ⚠️ via Project files or paste | ❌ no filesystem access | browser ext |
| **ChatGPT (web)** | ⚠️ via custom GPT files / Actions | ❌ no filesystem access | custom GPT + Actions |
| **ChatGPT desktop** | ✅ via Files connector (filesystem MCP) | ❌ no native hook | MCP-only |
| **Any MCP-capable client** | ✅ via the nanobrain MCP server | ⚠️ if client has session-end hook | depends |

## How each one works today

### Claude Code (the reference)

`install.sh` symlinks `~/.claude/CLAUDE.md` → repo's `claude-config/CLAUDE.md`, which `@`-imports the user's private `brain/*.md`. Stop hook in `~/.claude/settings.json` runs `capture.sh` on every assistant turn (throttled).

### Codex CLI / Gemini CLI / Aider / Cursor (read-side already works)

These tools all honor the `agents.md` convention or close variants. The repo ships top-level `AGENTS.md` and `GEMINI.md` that mirror the boot sequence in `CLAUDE.md`. Drop those files into the user's private brain repo (or symlink) and the agent will load `brain/self.md`, `brain/goals.md`, etc. on session start.

For Cursor specifically, `AGENTS.md` is honored in recent versions; for older versions, also create `.cursorrules` with the same content.

### Web Claude / ChatGPT / Gemini web

No filesystem access. Three options:

1. **Project files / custom GPT files**: upload the `brain/*.md` files as project context. Stale by definition (you have to re-upload after each compact / evolve).
2. **MCP via desktop bridge**: ChatGPT desktop and Claude desktop both support MCP. Run the nanobrain MCP server locally; the desktop app reads via stdio. This gives live read access without uploads.
3. **Browser extension** (planned, not shipped): scrape the conversation, post to a local endpoint, run `capture.sh` with a synthesized payload.

## Adding capture support to a new tool

The capture pipeline takes a JSON payload like:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "stop_hook_active": false,
  "hook_event_name": "Stop"
}
```

…pipes it into `code/hooks/capture.sh` on stdin. That's it. Any tool that can:

1. Detect a session ending,
2. Write the conversation to a file,
3. Run a shell command,

…can drive the capture pipeline. Reference patterns:

### Wrapper-script pattern (Codex / Gemini / Aider)

Wrap the agent's CLI:

```bash
#!/usr/bin/env bash
# ~/bin/codex-with-brain
TRANSCRIPT="$(mktemp -t codex-session.XXXXXX.jsonl)"
codex "$@" | tee "$TRANSCRIPT"

SESSION_ID="$(uuidgen)"
PAYLOAD=$(jq -n \
  --arg sid "$SESSION_ID" --arg tp "$TRANSCRIPT" \
  '{session_id: $sid, transcript_path: $tp, stop_hook_active: false, hook_event_name: "SessionEnd"}')

echo "$PAYLOAD" | bash $HOME/brain/code/hooks/capture.sh
```

### MCP-write pattern (any MCP-capable client)

The MCP server exposes `brain_add_to_inbox(source, content, metadata)`. A long-conversation client can call this at session end with the conversation as `content`. Distillation runs separately (`/brain distill <source>`) on cron.

### Browser extension pattern (web tools)

A browser extension scrapes the DOM, posts the conversation to `http://localhost:<port>/capture` on a tiny local HTTP server. The local server invokes `capture.sh`. Adds a "Save to brain" button to the UI of Claude / ChatGPT / Gemini web.

This is the highest-leverage missing piece since most casual users live in the web UIs. Roadmap below.

## Roadmap

- [ ] **`code/agents/wrappers/` directory** with reference wrapper scripts for Codex CLI, Gemini CLI, Aider.
- [ ] **`code/agents/cursor/` extension** that fires capture on chat-window close.
- [ ] **`nanobrain-web`** browser extension (Chromium + Firefox) that captures from `claude.ai`, `chatgpt.com`, `gemini.google.com`. Posts to `localhost:7777/capture`.
- [ ] **MCP server: real implementations** for `brain_search`, `brain_get_entity`, `brain_relationships`, `brain_query_graph` (currently stubs).
- [ ] **Remote MCP option** — host nanobrain MCP on a small FaaS endpoint with auth so you can hit it from Claude.ai's Project tools without running anything locally.

## Questions / contribute

If you want to add a new agent runtime, the recipe is:

1. Add a top-level activation file at the repo root (e.g. `OPENCODE.md`) mirroring `AGENTS.md`.
2. Add a wrapper script under `code/agents/wrappers/<name>.sh` if the runtime is a CLI without a session-end hook.
3. Add a row to the table at the top of this file.
4. Open a PR with a 60-second screen recording showing the capture round-trip.

The fastest contribution is a wrapper script for whichever CLI you actually use.
