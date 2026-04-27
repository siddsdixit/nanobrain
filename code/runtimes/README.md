# code/runtimes/ — capture for non-Claude agents

The Stop hook lives in Claude Code today. Other agent CLIs (Codex, Gemini, Aider) have no equivalent. `runtimes/wrap.sh` is the universal workaround: a tiny bash script that wraps any CLI, captures the conversation transcript on exit, and fires `capture.sh` with the same hook payload Claude Code would have sent.

## Install (once per CLI)

Add aliases to your shell rc:

```bash
# ~/.zshrc or ~/.bashrc
alias codex='$HOME/nanobrain/code/runtimes/wrap.sh codex'
alias gemini='$HOME/nanobrain/code/runtimes/wrap.sh gemini'
alias aider='$HOME/nanobrain/code/runtimes/wrap.sh aider'
```

Reload your shell. Now every `codex` / `gemini` / `aider` invocation auto-captures.

## How it works

1. `wrap.sh <cli> [args...]` runs the CLI, tee'ing its output to a temp transcript file.
2. On CLI exit, wrap.sh synthesizes a Claude-Code-shaped hook payload (`session_id`, `transcript_path`, `hook_event_name: SessionEnd`).
3. The payload is piped to `capture.sh`, which runs the same throttled, secrets-redacted, lock-protected pipeline as the native Claude Code hook.
4. The transcript is deleted after capture reads it.

## Per-runtime notes

| Runtime | Subfolder | Notes |
|---|---|---|
| Codex CLI | `codex-cli/` | Tested. Output is plain text; transcript renders cleanly. |
| Gemini CLI | `gemini-cli/` | Tested. Add `--silent` flag to suppress duplicate Google branding in transcript. |
| Aider | `aider/` | Tested. Aider's own `/save` command and our wrapper coexist; nanobrain captures the full conversation regardless. |
| Cursor | `cursor/` | No CLI to wrap. See `cursor/README.md` for the `AGENTS.md` + MCP server pattern. |

## Verify a wrapper works

```bash
echo "test session" | codex --version    # whatever returns >500 bytes
tail -3 $HOME/brain/data/_logs/capture.log
# Expect: ok: committed → <sha>   OR  ok: nothing worth keeping in delta
```

## Override per-invocation

```bash
NANOBRAIN_NO_CAPTURE=1 codex chat        # skip capture this run
NANOBRAIN_RUNTIME=codex-experimental codex chat   # tag the runtime differently
```

## Build a wrapper for a new CLI

If your tool prints conversation to stdout and runs to completion (most CLIs do), the generic `wrap.sh` already supports it. Just add an alias.

If your tool stays interactive forever (REPL, no clean exit), use the manual `/brain-checkpoint` command from inside the session instead.
