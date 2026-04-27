# Capture protocol — invoked by capture.sh

This file is invoked from one of three Claude Code hook events:

1. **`Stop`** — fires every assistant turn. Throttled by `capture.sh`: skips unless 5KB+ new content OR 30 min+ since last capture.
2. **`SessionEnd`** — fires when the session truly closes. Force-captures regardless of throttle.
3. **`PreCompact`** — fires before Claude Code auto-compacts long context. Force-captures so signal isn't lost.

The header that `capture.sh` prepends (`# Session capture context`) tells you which event triggered this run, how many captures already happened, and whether you're seeing a delta or a full transcript.

## Mirror rule — anything that lands in `brain/` also lands in `raw.md`

This is non-negotiable. `raw.md` is the faithful firehose of every signal that ever entered the brain. If you Edit a file in `brain/<category>.md`, you MUST also shell-append a corresponding entry to `brain/raw.md`. Otherwise raw is no longer the source of truth, and the audit trail breaks.

The same rule applies to `/brain save` and any manual brain-population work.

## Routing — every capture lands in 3-4 places

For each item worth keeping:

1. **The right categorized file** in `brain/`:
   - `self.md` — identity, voice, style, principle correction
   - `goals.md` — new or shifted goal
   - `projects.md` — project status change, new project, paused project
   - `people.md` — new contact (one-liner; promote to `people/<slug>.md` if recurring)
   - `learnings.md` — non-obvious insight, hard-earned principle (`### YYYY-MM-DD — title`)
   - `decisions.md` — material decision with rationale (`## YYYY-MM-DD — title`)
   - `repos.md` — new repo, status change on an existing one

2. **`brain/raw.md`** — cross-source firehose, shell-append only:
   ```bash
   printf '\n\n### %s — %s — %s\n\n%s\n' "$(date +%Y-%m-%d\ %H:%M)" "<category>" "<title>" "<entry>" >> $HOME/brain/brain/raw.md
   ```

3. **`data/claude/INBOX.md`** — Claude-source-specific firehose:
   ```bash
   printf '\n\n### %s — %s — %s\n\n%s\n' "$(date +%Y-%m-%d\ %H:%M)" "<category>" "<title>" "<entry>" >> $HOME/brain/data/claude/INBOX.md
   ```

4. **`brain/interactions.md`** — IF a person was named in this session:
   ```bash
   printf '\n\n### %s — %s — claude — %s\n' "$(date +%Y-%m-%d\ %H:%M)" "<name>" "<one-line about what we discussed>" >> $HOME/brain/brain/interactions.md
   ```

## Steps

1. **Skim this session.** What's worth keeping? Be ruthless.
2. **For each keepable item: route to all destinations above.** Use Edit for categorized files, shell `>>` for firehoses.
3. **Commit and push** — single commit covers all destinations:
   ```bash
   cd $HOME/brain
   git add brain/ data/claude/
   git -c user.email=you@example.com -c user.name="Your Name" commit -m "capture: <YYYY-MM-DD> — <one-line summary>" 2>/dev/null || true
   git push 2>/dev/null || true
   ```
4. **Stay silent.** No "I captured X" reports. Git log is the audit trail.

## Hard rules (see `code/SAFETY.md` for full list)

- **No em dashes.** Use commas, periods, parentheses.
- **Never read `raw.md`, `interactions.md`, or `data/**/INBOX.md` in full.** Shell-append only.
- **Don't invent.** If you didn't see it in this session, don't write it.
- **Don't capture session mechanics.** Tool errors, retries, scaffolding decisions, skip.
- **Don't capture this protocol itself.** No meta-entries.
- **Cap at ~200 words appended per categorized file per session.** Firehoses have no cap.
- **Skip if `stop_hook_active` is true** (already inside a hook turn).

## Protected files (do not append to)

- Top-level: `README.md`, `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `CONTEXT.md`, `ROADMAP.md`, `SOURCES.md`, `plan.md`
- `brain/CLAUDE.md`, `brain/people/README.md`
- `brain/archive/**` (read-only)
- `code/SAFETY.md`
- Anything outside `brain/` and `data/claude/`

## When to skip the entire capture

- Session was under 5 turns.
- Session was purely debugging or routine config.
- Session was a `/brain-compact` or `/brain-evolve` run.
- Stop-hook recursion detected (`stop_hook_active` true OR `NANOBRAIN_CAPTURING=1`).
- The repo working tree was dirty before the hook ran (`capture.sh` already auto-stashed manual edits, but if the stash itself fails the script bails — don't try to work around it).

## You may receive a delta, not the full transcript

For long-running sessions (the user keeps tabs open for days/weeks), `capture.sh` only invokes you when there's been a meaningful gap (5KB+ new content OR 4h+ since last capture). The payload it pipes in includes:

- A `# Session capture context` header with `capture_count_before`, `hours_since_last`, and a note if prior captures already extracted earlier signal.
- The protocol (this file).
- Only the NEW transcript bytes since the last capture (a delta).

When `capture_count_before > 0`, **only extract signal from the new content**. Don't re-capture decisions or learnings already saved earlier in the session. The watermark and prior commits in `git log` are your reference for what's been captured before.

## What "success" means

The hook's `capture.sh` wrapper checks `git rev-parse HEAD` before and after. If HEAD moved → committed and logged `ok: committed → <sha>`. If you appended to files but didn't commit, the wrapper reverts your half-done changes and logs a warning. **Either commit cleanly or do nothing.** No half-states.

If you genuinely have nothing to save, do not commit. The wrapper will log `ok: nothing worth keeping this session`. That's the correct outcome for trivial sessions.

## Audit trail

Every hook run appends one line to `$HOME/brain/data/_logs/capture.log` with the session id, decision, and outcome. Inspect via:
```bash
tail -20 $HOME/brain/data/_logs/capture.log
```

`/brain status` surfaces the last few entries automatically.
