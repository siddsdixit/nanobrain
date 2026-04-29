# brain-doctor

Read-only health check. Reports:

- `_contexts.yaml` validity (via `code/lib/contexts.sh validate`)
- which sources have `requires.yaml` and an `ingest.sh`
- whether stub env vars exist for each source (CI mode)
- MCP server reachability (does `code/mcp-server/server.sh tools/list` return 0)
- size of each `data/<source>/INBOX.md` and `brain/raw.md`

Run: `bash code/skills/brain-doctor/check.sh`
