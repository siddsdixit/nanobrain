# ADR-0004: Stop-hook recursion guard

**Status:** Accepted
**Date:** 2026-04-26

## Context

The Stop hook runs `claude -p` to extract session signal. The spawned `claude -p` process completes and triggers its own Stop hook. Without a guard, this is infinite recursion — every session spawns infinite sub-sessions until the user kills the terminal.

## Decision

Two-layer guard in `code/hooks/capture.sh`:

1. **Environment variable.** Before doing anything, check `[ "${NANOBRAIN_CAPTURING:-0}" = "1" ] && exit 0`. The script exports `NANOBRAIN_CAPTURING=1` before spawning `claude -p`, so the inner process's hook sees the var and exits cleanly.

2. **`stop_hook_active` payload check.** Claude Code passes `stop_hook_active: true` in the hook stdin JSON when the assistant is responding to a hook-injected prompt. The script checks this via jq and exits if true.

Both guards are listed in `code/SAFETY.md` as invariant S1. `/brain-evolve` is forbidden from weakening either.

## Consequences

- Recursion is bounded to depth 1 (the spawned `claude -p` will not spawn another).
- Belt-and-suspenders: either guard alone would suffice, but both are cheap and reduce reliance on any one mechanism.
- Tradeoff: if Claude Code ever changes the env-var or payload semantics, the guards may need updating. SAFETY.md M3 requires `/brain-evolve` to verify these fields exist before any commit.

## Alternatives considered

- **Single guard.** Rejected: too brittle. Two cheap layers cost nothing.
- **File lock (`flock`).** Rejected: overkill for a single-user single-machine scenario, adds Linux-only complexity.
- **Counter file.** Rejected: state on disk that could leak into git commits.
