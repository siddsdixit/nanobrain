---
name: brain-compact
---

# /brain-compact

Run this monthly (or when any compactable `brain/*.md` exceeds ~500 lines). Keeps the corpus dense and pasteable.

## Files this skill operates on

### Compactable (refine / dedupe / archive stale)
- `brain/learnings.md` — promote raw observations to principles, dedupe
- `brain/decisions.md` — archive superseded decisions, mark closed loops
- `brain/projects.md` — mark stale projects, archive completed ones
- `brain/goals.md` — replace stale quarterly goals
- `brain/self.md` — minimal touch only; identity is stable

### Protected (NEVER compact)

**Principle:** anything where every entry is load-bearing — registries, logs, history, firehoses. Test: can you safely lose, merge, or refine an arbitrary entry? If no, protected.

Inside `brain/`:
- `raw.md` — long-term uncompacted firehose
- `interactions.md` — append-only log of who-when-what
- `people.md` — contact index. Names accumulate, you don't dedupe relationships. Stale-looking pipeline dates next to a name are NOT a signal to remove the person.
- `people/<slug>.md` — per-person detail
- `repos.md` — git repo registry. Compacting drops repos from the map.
- `archive/*` — already archived
- Any future timeline/log file (`calendar.md`, `timeline.md`, `health.md`, `financials.md`, `contracts.md`, etc.) — protected by default

Outside `brain/`:
- Everything in `data/`, `docs/adr/`, `code/`, `claude-config/`, and the top-level pointer files (CLAUDE.md, AGENTS.md, GEMINI.md, CONTEXT.md, ROADMAP.md, SOURCES.md, SCHEMA.md, README.md, plan.md). Compaction operates only inside `brain/`.

**Default for any new `brain/*.md` file:** treat as protected unless you can articulate why dedupe/refinement adds value without losing signal.

## Steps

1. **Read compactable files only.** Cat each file in the compactable list. Do NOT read protected files.

2. **Dedupe and merge.** If two entries say the same thing, merge them. If three learnings circle the same principle, refactor into one stronger statement.

3. **Refine raw → principle.** Raw learnings often start as observations. Promote them: "I noticed X" → "When Y happens, do Z."

4. **Demote stale.** Anything older than 90 days that isn't load-bearing for current work moves to `$HOME/brain/brain/archive/<file>-<YYYY-MM>.md`. Don't delete. Archive.

5. **Verify projects.md.** Mark stale projects as `archived` or remove them. Surface anything in `projects.md` that hasn't been touched in 60 days for the user to confirm.

6. **Mirror to raw.md** (per ADR-0011). Single summary entry pointing at the compaction commit:
   ```bash
   printf '\n\n### %s — compact — %s\n\n%s\n' "$(date +%Y-%m-%d\ %H:%M)" "<YYYY-MM>" "Compacted learnings / decisions / projects / goals / self. Archived <N> entries to brain/archive/. Commit: <sha>" >> $HOME/brain/brain/raw.md
   ```

7. **Re-read top-down.** Each compacted file should still be self-contained, readable in one sitting, and dense.

8. **Commit:**
   ```bash
   cd $HOME/brain
   git add -A
   git -c user.email=you@example.com -c user.name="Your Name" commit -m "compact: <YYYY-MM> — dedupe / refine / archive"
   git push
   ```

## Rules

- **Never touch protected files** (raw, interactions, people.md, people/, repos.md, archive/, future timeline/log files). See list above.
- **Never compact `people.md` or `people/*.md`.** People are append-only. Don't dedupe, merge, demote, or archive entries about humans. Stale dates are not a reason to remove the person.
- **Never lose signal.** When in doubt, archive instead of delete.
- **No re-writing in your own voice.** Preserve the user's voice. No em dashes. Short imperative sentences.
- **Don't add new content.** Compaction is reorganization, not authoring.
- **Show diff before committing if any file shrinks by more than 30%.** The user should approve big cuts.
- **Mirror summary to raw.md** (S2a invariant).

## When to escalate

If you find:
- A project stale 90+ days but might still be active → ask the user.
- A "learning" that contradicts a more recent one → ask which is current.
- Decisions that were never closed → flag in `CONTEXT.md`.
- A protected file growing past 1000 lines → flag, but never compact.
