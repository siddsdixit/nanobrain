# Compatibility — bringing nanobrain to other agents

The framework has two halves:

1. **Read side**: agents read `brain/*.md` to load context at session start.
2. **Capture side**: when a session ends, the conversation is distilled into the brain.

The read side is vendor-neutral and works almost anywhere markdown is consumable. The capture side uses Claude Code's `Stop` hook natively, and a generic wrapper (`code/runtimes/wrap.sh`) for any other CLI.

## Today

| Tool | Reads brain | Captures sessions | Status |
|---|:---:|:---:|---|
| **Claude Code** (CLI) | ✅ via `CLAUDE.md` `@`-import | ✅ Stop / SessionEnd / PreCompact hooks | shipping |
| **Codex CLI** | ✅ via `AGENTS.md` ([spec](https://agents.md)) | ✅ via `runtimes/wrap.sh` | shipping |
| **Gemini CLI** | ✅ via `GEMINI.md` | ✅ via `runtimes/wrap.sh` | shipping |
| **Aider** | ✅ via `AGENTS.md` | ✅ via `runtimes/wrap.sh` | shipping |
| **Cursor** | ✅ via `AGENTS.md` or `.cursorrules` | ⚠️ via MCP `brain_add_to_inbox` (manual) | shipping (read), partial (capture) |
| **Claude desktop / web** | ✅ via MCP server | ⚠️ manual paste OR upcoming browser ext | partial |
| **ChatGPT (desktop)** | ✅ via MCP server | ❌ no session-end hook | partial |
| **ChatGPT (web)** | ⚠️ via custom GPT files | ❌ no filesystem | browser-ext only |
| **Gemini (web)** | ⚠️ via custom Gem instructions | ❌ no filesystem | browser-ext only |
| **Any MCP-capable client** | ✅ via the nanobrain MCP server | ⚠️ if client has session-end hook | depends |

## Read side — how each tool loads your brain

### Claude Code (the reference)

`install.sh` symlinks `~/.claude/CLAUDE.md` → repo's `claude-config/CLAUDE.md`, which `@`-imports your private `brain/*.md`. Stop hook in `~/.claude/settings.json` runs `capture.sh` on every assistant turn (throttled).

### Codex CLI / Gemini CLI / Aider / Cursor

These tools all honor `agents.md` or close variants. The repo ships top-level `AGENTS.md`, `GEMINI.md`, and `.cursorrules`. Symlink to your private brain repo:

```bash
cd <your-project>
ln -s $HOME/my-brain/AGENTS.md ./AGENTS.md          # Codex, Aider, Cursor (modern)
ln -s $HOME/my-brain/GEMINI.md ./GEMINI.md          # Gemini CLI
ln -s $HOME/my-brain/.cursorrules ./.cursorrules    # Cursor (legacy versions)
```

### Web Claude / ChatGPT / Gemini

Three options:

1. **Project files / custom GPT files**: upload `brain/*.md` as project context. Stale by definition; re-upload after each compact / evolve.
2. **MCP via desktop bridge** (best): ChatGPT desktop and Claude desktop support MCP. Run the nanobrain MCP server locally; the desktop reads via stdio. Live, no uploads.
3. **Browser extension** (roadmap): scrape the conversation DOM, fire capture.sh.

## Capture side — `runtimes/wrap.sh`

The capture pipeline takes a JSON payload:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript",
  "stop_hook_active": false,
  "hook_event_name": "SessionEnd"
}
```

…piped into `code/hooks/capture.sh` on stdin.

### Universal wrapper (recommended)

`code/runtimes/wrap.sh <cli> [args...]` runs any CLI, tee's its output to a temp transcript, and fires capture.sh on exit. Add aliases:

```bash
# ~/.zshrc or ~/.bashrc
alias codex='$HOME/nanobrain/code/runtimes/wrap.sh codex'
alias gemini='$HOME/nanobrain/code/runtimes/wrap.sh gemini'
alias aider='$HOME/nanobrain/code/runtimes/wrap.sh aider'
```

Tested in CI against mock CLIs. See `code/runtimes/README.md` for details.

### MCP-write pattern (Cursor, ChatGPT desktop, anything MCP-capable)

The MCP server exposes `brain_add_to_inbox(source, content, metadata)`. The client calls this at session end with the conversation as `content`. Distillation runs separately (`/brain distill <source>`) on cron.

### Browser extension (web tools, roadmap)

`nanobrain-web` will scrape the DOM, post to `http://localhost:7777/capture`. Local server runs `capture.sh`.

## Adding a new agent runtime

Recipe:

1. **Read side**: add a top-level activation file at the repo root (e.g. `OPENCODE.md`) mirroring `AGENTS.md`.
2. **Capture side**: if the runtime is a CLI, `wrap.sh` already handles it via alias. If it's a GUI without a CLI, document the MCP-write pattern in `code/runtimes/<name>/README.md`.
3. Add a row to the table at the top of this file.
4. Add a smoke-test case in `test/smoke.sh` T9 with a mock binary.
5. Open a PR.

## Verifying capture works

Regardless of runtime:

```bash
# 1. Start a session in the wrapped CLI
codex chat
# ... do some work, exit ...

# 2. Check the capture log
tail -3 $HOME/brain/data/_logs/capture.log
# Expect: "ok: committed → <sha>"  OR  "ok: nothing worth keeping in delta"

# 3. Check the brain repo
cd $HOME/my-brain
git log --oneline -5
```
