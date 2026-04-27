---
name: brain-checkpoint
description: Force an immediate capture of the current Claude session, bypassing the throttle. Use when wrapping up a long session or after a meaningful chunk of work even if you'll keep the session open.
---

# /brain-checkpoint (also via /brain checkpoint)

The Stop hook is throttled (only fires when 5KB+ of new content OR 4h+ since last capture). For long-running sessions where you want to mark "this chunk is done, capture it now," use checkpoint.

## What it does

1. Sets `FORCE_CAPTURE=1` in the env.
2. Invokes `$HOME/brain/code/hooks/capture.sh` with a synthetic payload referencing the current session's transcript.
3. Bypasses the throttle, runs the same protocol the Stop hook runs.
4. Updates the session watermark so the next throttled capture starts from the new offset.

## Implementation

```bash
# Find the current session's transcript path. Claude Code stores transcripts at:
#   ~/.claude/projects/<project-slug>/<session-id>.jsonl
# The user is currently in cwd → CWD slug uniquely picks the project.
TRANSCRIPT="$(ls -t ~/.claude/projects/*/*.jsonl 2>/dev/null | head -1)"
SESSION_ID="$(basename "$TRANSCRIPT" .jsonl)"

# Synthesize hook payload and pipe in
FORCE_CAPTURE=1 $HOME/brain/code/hooks/capture.sh <<EOF
{
  "session_id": "$SESSION_ID",
  "transcript_path": "$TRANSCRIPT",
  "hook_event_name": "manual_checkpoint",
  "stop_hook_active": false
}
EOF
```

## When to use

- About to step away from a long session for hours → checkpoint.
- Just made a material decision and want it captured before context drifts.
- Session has been quiet (under throttle thresholds) but the conversation included something worth saving.
- Before running `/brain compact` or `/brain evolve` (so they see the latest signal).

## When NOT to use

- After every assistant turn. The throttle is there for a reason.
- Mid-debug-loop with errors flying. Wait until you've recovered, then checkpoint.

## Verification

After running, tail the log:
```bash
tail -3 $HOME/brain/data/_logs/capture.log
```

Should show `run: reason=force` and either `ok: committed → <sha>` or `ok: nothing worth keeping`.
