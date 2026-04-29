# gmail source

Single-pass ingest. Sender domain resolves to `work` or `personal` via `_contexts.yaml`. Per-context window (work=9d, personal=1095d) controls what the bootstrap fetches.

Filtered out: `noreply`, `notifications`, `automated`, `@github.com`, `newsletter`.

Writes to `$BRAIN_DIR/data/gmail/INBOX.md`. Idempotent: existing `source_id` is skipped.

For tests / CI: set `NANOBRAIN_GMAIL_STUB=/path/to/threads.json`.
