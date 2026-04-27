# ADR-0003: Stop hook is a `command` type running `claude -p`

**Status:** Accepted (revised from earlier prompt-type attempt)
**Date:** 2026-04-26

## Context

End-of-session capture must read the just-completed transcript and route signal to brain files. Three implementation options were considered:
1. Bash script that calls Anthropic API directly with `ANTHROPIC_API_KEY`.
2. `prompt`-type Stop hook that injects a directive into the just-ending session.
3. `command`-type Stop hook running a small bash script that pipes a protocol into `claude -p` (Claude Code's CLI subprocess).

Option 1 requires API key management per machine. Option 2 was attempted but Claude Code's actual hook schema is `matcher + hooks[]`, and `prompt` type isn't well-supported in current versions.

## Decision

Use `command`-type Stop hook configured as:
```json
{"hooks": {"Stop": [{"matcher": "", "hooks": [{"type": "command", "command": "$HOME/brain/code/hooks/capture.sh"}]}]}}
```

The `capture.sh` script:
1. Checks recursion guards (env var + `stop_hook_active`).
2. Pipes `code/hooks/STOP.md` to `claude -p`.
3. Claude Code login auths the subprocess (no API key needed).

## Consequences

- Zero secret management per machine. `claude` CLI's existing login is reused.
- Recursion guard (`NANOBRAIN_CAPTURING=1`) prevents the spawned `claude -p` from re-triggering the hook.
- Cost is one `claude -p` invocation per session end, billed against existing Claude Code subscription.
- Tradeoff: depends on `claude` being on PATH. Install script verifies this.

## Alternatives considered

- See above. Option 1 rejected for secret friction. Option 2 attempted, abandoned after schema error.
