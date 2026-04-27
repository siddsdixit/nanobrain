# Ingest protocol — <source>

Triggered by `/brain ingest <source>` or by scheduled job (launchd / cron).

## Steps

1. **Auth check.** Confirm credentials are present (env var, OAuth token, MCP server reachable). If missing, abort with a clear message.

2. **Pull new content.** Pull only items newer than the last ingest watermark. Track watermark in `data/<source>/.watermark`.

3. **Apply privacy filters.** Strip secrets and patterns listed in `README.md`. If any filter triggers, log the count to stderr (not the content).

4. **Format.** Convert source format → uniform append-friendly markdown:
   ```
   ### YYYY-MM-DD HH:MM — <source>: <subject/title>

   <body, max 500 chars; truncate longer with "...">
   ```

5. **Append.** Single `>>` write to `data/<source>/INBOX.md`. Never `>` (would overwrite). Never edit existing entries.

6. **Update watermark.** Write the latest item's timestamp to `.watermark`.

7. **Mirror nothing yet.** Distillation is a separate step (see `distill.md`).

## When to rotate

If `INBOX.md` exceeds 10MB:
```bash
mv INBOX.md INBOX-$(date +%Y-%m).md
touch INBOX.md
```

## Failure modes

- **Auth expired** → fail loud, tell the user to refresh.
- **Source unreachable** → retry with backoff up to 3x, then exit 0 silently (don't break the pipeline).
- **Filter regex too aggressive** → log count, ingest still proceeds; review by hand if the user asks.

## Output

One line on success: `ingest <source>: N new items appended (watermark: YYYY-MM-DD HH:MM)`
