# nanobrain MCP server

Exposes the brain as native tools to any agent that speaks MCP (Cursor, Codex, Claude Code, Gemini CLI). Programmatic access without going through `/brain` slash commands.

## Locked tool surface (ADR-0014, ADR-0015)

The 7 tools are interface-locked. Implementation iterates; signatures don't change.

| Tool | Signature | Returns | Use case |
|---|---|---|---|
| `brain_search` | `(query: string, filter?: {type, status, sensitivity, source})` | `[{path, snippet, date, score}]` | Full-text search across `brain/{self,goals,projects,people,learnings,decisions,repos}.md` and `brain/{person,project,decision,concept}/*.md`. Never reads raw.md or data/. |
| `brain_get_entity` | `(type: string, slug: string)` | `{frontmatter, body, backlinks}` | Read a single per-entity file (e.g., `brain_get_entity("person", "jane-doe")`). Returns frontmatter + body + backlinks from `_graph.md`. |
| `brain_list_by_type` | `(type: string, filter?: {status})` | `[{slug, title, status, date}]` | Enumerate entities of a type ("show me all active projects"). |
| `brain_relationships` | `(slug: string)` | `{incoming: [...], outgoing: [...]}` | What links to / from this entity. |
| `brain_query_graph` | `(query: string)` | `{nodes, edges}` | Graph queries ("all decisions related to <project-slug>"). |
| `brain_add_to_inbox` | `(source: string, content: string, metadata?: object)` | `{path, success}` | Append to `data/<source>/INBOX.md`. The only WRITE tool. Read-only otherwise. |
| `brain_status` | `()` | `{vault_health, last_capture, hash_match, pending_inboxes}` | Diagnostics. |

## What this MCP server does NOT do

- **No raw.md / interactions.md reads.** Token-budget protection (S6).
- **No file deletion.** Archive only.
- **No bulk rewrites.** Single-entity edits only via `brain_add_to_inbox`.
- **No agent spawning.** That's `/brain spawn` (slash command, requires user approval per T32).

## Install

```bash
cd $HOME/brain/code/mcp-server
npm install
```

Register in `~/.claude/mcp.json`:

```json
{
  "mcpServers": {
    "my-brain": {
      "command": "node",
      "args": ["$HOME/brain/code/mcp-server/index.js"],
      "env": {
        "BRAIN_DIR": "$HOME/brain"
      }
    }
  }
}
```

## Status

**Skeleton.** Tool signatures locked. Implementations are stubs returning placeholder data. Iterate without changing signatures.

## Linked

- ADR-0014 (agent foundry — MCP exposes brain to other agents)
- ADR-0015 (public/private split — MCP is part of public framework)
- `code/SAFETY.md` invariants S2 (no firehose reads), S6 (token budget), S29 (scope enforcement)
