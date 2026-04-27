# Ingest protocol — granola

Triggered by `/brain ingest granola` or daily cron. Runs `ingest.sh`.

## What `ingest.sh` does

1. **Read watermark.** `data/granola/.watermark` holds the last-seen ISO `created_at`. Default: 30 days ago.

2. **Read local Granola cache:**
   - Path: `~/Library/Application Support/Granola/cache-v6.json`
   - Field: `.cache.state.documents` (object keyed by doc id)
   - Filter: `created_at > watermark AND was_trashed != true AND deleted_at == null`

3. **For each meeting, append a block to `data/granola/INBOX.md`:**
   ```
   ### YYYY-MM-DD HH:MM — granola: <title>

   **Date:** YYYY-MM-DD
   **Attendees:** name1, name2, ...
   **Granola:** granola://notes/<doc-id>
   **Calendar:** https://calendar.google.com/...
   **Calendar title:** <if different from Granola title>
   **Source-doc-id:** <doc-id>
   ```

4. **Update watermark** to the latest `created_at` seen.

5. **Single shell-append write** to `data/granola/INBOX.md`. Never overwrite.

## Why this is index-only

Granola's local `cache-v6.json` holds metadata (title, date, attendees, calendar event) but **not the note bodies**. `summary`, `overview`, `notes_markdown`, `notes_plain` are all `null` locally — Granola fetches them from its server on demand.

So this ingest is intentionally a **pointer index**: each entry tells you the meeting happened and gives you a `granola://notes/<id>` deeplink that opens the meeting in the Granola desktop app for full notes, transcript, and AI chat. The Google Calendar `htmlLink` is the redundancy.

If Granola later exposes notes locally (or ships an export API), extend the jq pipeline to capture `notes_markdown` and write a separate `### note:` block. Don't reverse-engineer the Granola backend.

## When to rotate

If `INBOX.md` exceeds 5MB:
```bash
mv data/granola/INBOX.md data/granola/INBOX-$(date +%Y-%m).md
touch data/granola/INBOX.md
```

## Failure modes

- Granola not installed → cache file missing, exit 0 silently.
- `jq` parse error (cache schema changed) → exit 0, capture stderr to `data/_logs/`.
- Empty `documents` object → exit 0 silently.

## Output

One line on success:
```
[ingest granola] N meetings appended, watermark advanced to <ts>
```
