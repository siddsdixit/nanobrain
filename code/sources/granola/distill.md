# Distill protocol — granola

Triggered by `/brain distill granola` or weekly cron. Reads new entries from `data/granola/INBOX.md` and routes signal.

## Steps

1. **Read distill watermark.** `data/granola/.distill-watermark`.

2. **Tail new entries only.** awk-from-watermark over `INBOX.md`. Never `cat` the whole file.

3. **For each new meeting block, route signal:**

   ### `brain/people.md` updates
   - For each attendee not already in `people.md`: add a one-liner under the right bucket. Use Granola's calendar event for context (was it work, board, recruiter, founder?).
   - If attendee is already known: skip silently. Don't re-log every meeting.
   - Cap new-people additions at 5 per distill run. Append the rest to `data/granola/.unprocessed-people` for next run.

   ### `brain/projects.md` updates
   - If meeting title or calendar title matches an active project (cross-reference `brain/projects.md` and `brain/goals.md`): append a short status note under that project. Format: `_2026-04-26: meeting "<title>" with <attendees> — granola://notes/<id>_`
   - Cap at 3 status notes per project per distill run.

   ### `brain/raw.md` mirror
   - Always append to `brain/raw.md` via shell:
     ```bash
     printf '\n\n### %s — granola — %s\n\n%s\nGranola: %s\n' \
       "$(date +%Y-%m-%d\ %H:%M)" "<title>" "<attendees>" "<deeplink>" >> $HOME/brain/brain/raw.md
     ```

4. **Update distill watermark** to the latest meeting timestamp.

5. **Commit:**
   ```bash
   cd $HOME/brain
   git add brain/ data/granola/.distill-watermark
   git -c user.email=you@example.com -c user.name="Your Name" \
     commit -m "distill granola: $(date +%Y-%m-%d) — N meetings processed"
   git push
   ```

## Hard rules

- **Never `cat` the INBOX.** Always tail or awk-from-watermark.
- **Never capture note bodies.** They're not in the local cache anyway, and even if they were, the brain stays a thin pointer index. Full context lives in the Granola app.
- **Always preserve the deeplink.** `granola://notes/<id>` is the contract — every reference to a meeting in the brain must include it so the user can jump back in one click.
- **Don't write attendee emails to public-ish files.** Names go in `brain/people.md`, emails only if explicitly worth keeping.
- **Match the user's voice.** No em dashes. Short sentences. No summaries of meetings the brain doesn't have content for.

## Category field

Each INBOX entry carries `**Category:**` with one of:
- `work` — all attendee emails on a work domain (default `example.com`, override via `WORK_DOMAINS`).
- `personal` — no work-domain attendees, at least one external email.
- `mixed` — both work-domain and external attendees. These are the highest-signal entries: external partners, candidates, recruiters, board, customers. Distill these first.
- `unknown` — no attendees and no calendar event (scratchpad / solo notes). Skip in distill.

Routing by category:
- **mixed** → almost always belongs in `brain/people.md` (new external contact) and often `brain/projects.md` (the external thread). Highest priority.
- **work** → only distill if title matches an active project in `brain/projects.md`. Otherwise it's internal cadence noise.
- **personal** → route to `brain/people.md` and `brain/projects.md` Personal ventures section.
- **unknown** → skip.

## Source-specific extraction

- Recurring meeting (same title appears 3+ times): note it once under the project, mark cadence.
- Calendar event with external attendees (non-example.com domain): flag for `brain/people.md` review with company context from email domain.
- Meeting with a recruiter/PE contact already in `people.md` Career section: append to `projects.md` Active job search section, not as a new entry.
- Meeting title containing "1:1" or "weekly": skip — internal cadence, not signal worth distilling unless attendees are new.

## What this distill does NOT do

- Does not summarize meeting content (no content available locally).
- Does not extract action items (Granola already does this in-app — open the deeplink).
- Does not call Granola's backend API.
