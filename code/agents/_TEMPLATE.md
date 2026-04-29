---
slug: example-agent
reads:
  files:
    - brain/decisions.md
    - brain/projects.md
  filter:
    context_in:
      - work
---

# Example agent

Describe what this agent does. The frontmatter above is enforced by `code/mcp-server/read_brain_file.sh`:

- `reads.files` whitelists which brain files the agent can read.
- `reads.filter.context_in` restricts to entries whose `{context: ...}` marker matches.

Firehoses (`raw.md`, `interactions.md`, any `INBOX.md`) are unreadable from agents.
