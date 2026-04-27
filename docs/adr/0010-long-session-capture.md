# ADR-0010: Long-running session capture (throttle + delta + checkpoint)

**Status:** Accepted
**Date:** 2026-04-26

## Context

Claude Code's `Stop` hook fires when the assistant completes a turn — *not* when a session ends. Power users keep Claude Code sessions open for days or weeks. Without throttling, every assistant response would invoke `claude -p` on the entire transcript:

- 100-turn session → 100 redundant captures, each more expensive than the last
- Cost scales O(n²) with session length (each capture re-reads the whole transcript)
- `brain/raw.md` would get duplicate entries for the same conversation
- Token burn is severe for the most engaged sessions

There's no `SessionEnd` event in current Claude Code that maps cleanly to "user closed the tab," so we can't just defer to that.

## Decision

Three-part hardening:

### 1. Per-session watermark
Each session_id gets a JSON file at `data/_logs/sessions/<session_id>.json`:
```json
{
  "session_id": "...",
  "first_seen": "...",
  "last_capture": "...",
  "last_capture_epoch": 1714000000,
  "last_byte_offset": 12345,
  "capture_count": 3,
  "last_reason": "bytes=8200"
}
```

### 2. Throttle on Stop + safety-net hooks
`capture.sh` skips the Stop-hook capture unless one of:
- `FORCE_CAPTURE=1` in env (manual checkpoint)
- `hook_event_name` is `SessionEnd` / `PreCompact` / `Notification` (terminal events always force)
- `>= MIN_NEW_BYTES` of new transcript since last capture (default 5 KB)
- `>= MIN_MINUTES` since last capture AND there's some new content (default 30 min)

Tunables: `NANOBRAIN_MIN_BYTES`, `NANOBRAIN_MIN_MINUTES` env vars.

Settings.json registers three hook events:
- `Stop` — every turn, throttled
- `SessionEnd` — force capture when session truly closes
- `PreCompact` — force capture before Claude Code auto-compacts context

Unsupported events (depending on Claude Code version) are silently ignored.

### 3. Delta-only payload
When capture proceeds, pass `tail -c +<last_offset>` of the transcript to `claude -p`, not the whole thing. Prepended with session metadata so the inner Claude knows this is a continuation and avoids re-capturing already-saved signal. Update `last_byte_offset` on success.

### 4. Manual checkpoint command
`/brain checkpoint` (also `/brain-checkpoint` standalone skill) sets `FORCE_CAPTURE=1` and synthesizes a hook payload pointing at the current session's `~/.claude/projects/<slug>/<session_id>.jsonl`. Bypasses throttle, runs the same protocol.

## Consequences

- **Long sessions are cheap.** A week-long session with 200 turns triggers ~30 captures (every 4h or 5KB), not 200.
- **Each capture is small.** Delta payload means cost grows linearly with new content, not quadratically.
- **Explicit "I'm done with this chunk"** via checkpoint. The user retains control without needing to actually close the session.
- **Session memory.** The watermark file is the audit trail per session — see how often it captured, what triggered each one.
- **Tradeoff.** Watermark JSON files accumulate (one per session_id ever seen). At 1 KB each, 1000 sessions = 1 MB. Acceptable.

## Alternatives considered

- **Use `SessionEnd` only.** Rejected: long sessions span weeks; intermediate signal would be lost. (We use it as a safety net, not the primary trigger.)
- **Throttle on turn count instead of bytes.** Rejected: turn counts vary wildly with prompt complexity; bytes are a better proxy for "stuff happened."
- **Throttle on time only.** Rejected: a chatty 30-min session has more signal than a quiet 4-hour one.
- **Background daemon (launchd) that polls active transcripts.** Rejected: adds platform-specific infra; Stop hook is already the natural trigger.
- **Skip throttle, just make capture cheaper.** Rejected: even cheap captures × 200 turns × token costs = waste.

## Related

- ADR-0003 (Stop hook is `command` type running `claude -p`)
- ADR-0004 (recursion guard)
- ADR-0009 (capture-hook hardening)
- `code/SAFETY.md` invariants S1, S6, S7
