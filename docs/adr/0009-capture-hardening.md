# ADR-0009: Capture-hook hardening

**Status:** Accepted
**Date:** 2026-04-26

## Context

The original `capture.sh` was 21 lines: a recursion guard, a `claude -p` invocation, and `|| true` to swallow errors. Several failure modes were possible without visibility:

1. **Trivial sessions still ran the hook.** A 1-turn lookup session would invoke `claude -p`, burn tokens, and decide nothing was worth keeping. Wasteful at scale.
2. **Concurrent runs.** Two terminals ending sessions simultaneously could race on git push.
3. **Hangs.** No timeout on `claude -p`. A network stall could keep the process alive indefinitely.
4. **Half-commits.** If the inner Claude appended to brain files but failed to commit, the working tree stayed dirty. Next run would see the orphan changes and either compound the mess or fail.
5. **Manual-edit clobbering.** If the user was hand-editing brain files when a Claude session ended elsewhere, the hook's commit could include their uncommitted work.
6. **Silent failures.** No log. If captures stopped working, you wouldn't know until you noticed `git log` was empty.

## Decision

Add five hardening layers to `code/hooks/capture.sh`:

1. **Pre-flight gates**: skip cleanly if `claude` missing, transcript absent or <500 bytes, or `STOP.md` not found. Each skip logs the reason.
2. **Lock file** at `$HOME/brain/.capture.lock` containing the holder PID. Stale lock detection via `kill -0`. `trap` ensures cleanup on exit.
3. **Timeout** of 90 seconds on the `claude -p` invocation via `timeout(1)`. Falls back to no-timeout on systems without it (still safer than the original because of the lock).
4. **Stash-protect manual edits**. Before invoking the inner Claude, `git stash push` any dirty state. After capture, `git stash pop`. Prevents the hook from committing the user's in-progress hand edits.
5. **Atomic verification + rollback**. Snapshot `git rev-parse HEAD` before and after. If HEAD moved → log success with subject. If HEAD unchanged but working tree is dirty → revert (`git checkout -- .` + `git clean -fd brain/ data/`). Either commit cleanly or do nothing.
6. **Structured log** at `$HOME/brain/data/_logs/capture.log`. Format: `<ts> [<session_id>] <decision/outcome>`. Underscore-prefixed folder so `/brain` skips it as a non-source.

`STOP.md` updated to reference the new audit trail. `/brain status` now tails the log and warns about stale locks.

## Consequences

- **Visibility.** Every hook run leaves a one-line trace. Silent failures are now noisy.
- **Reliability.** Race conditions, hangs, and orphan commits are bounded.
- **Cost.** Trivial sessions short-circuit before spending a `claude -p` invocation.
- **Tradeoff.** capture.sh grew from 21 to ~95 lines. Worth it for the failure-mode coverage. Each layer is independently understandable.

## Alternatives considered

- **Lock via `flock(1)`.** Rejected: not in default macOS PATH; PID-file lock is portable and self-clearing.
- **Background-queue capture (e.g. via launchd).** Rejected: adds infrastructure without solving the actual failure modes; hook running synchronously matches the natural "session ended" trigger.
- **Skip the lock, accept races.** Rejected: small but real corruption risk on concurrent commits.
- **Always commit, never rollback.** Rejected: dirty trees from half-runs would slowly accumulate, and `/brain-compact` would inherit garbage.

## Related

- `code/SAFETY.md` invariants S1 (recursion guard), S2 (append-only), S7 (recursion-safe git), S8 (idempotent install).
