# nanobrain MCP server

Minimal stdio JSON-RPC server. One method that matters: `tools/call` for `read_brain_file`. Refuses firehoses (`raw.md`, `interactions.md`, any `INBOX.md`). Filters returned entries by the calling agent's `reads.filter.context_in`.

CLI fallback (no MCP needed):

```
bash code/mcp-server/read_brain_file.sh --agent code/agents/example.md --file brain/decisions.md
```
