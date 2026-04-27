# code/agents/ — agent foundry

Spawnable agents created by `/brain spawn` or proposed by `/brain-evolve`. Each is a markdown file with Anthropic-standard frontmatter + scope declarations.

## Structure

```
code/agents/
├── README.md                ← this file
├── _TEMPLATE.md             ← starter for new agents
├── _proposed/               ← /brain-evolve drops proposals here for the user to approve
└── <slug>.md                ← active agents (one per file)
```

## How agents work (T30–T32)

- **T30:** Agents are markdown only. No bash, no JS in agent definitions. Vendor-neutral.
- **T31:** Agents declare `reads:` and `writes:` scope at spawn time. Brain enforces.
- **T32:** Brain-spawned agents land in `_proposed/`. The user moves to active by `mv`. No silent activation.

## Frontmatter (extends Anthropic standard with scope + audit)

```yaml
---
# Anthropic standard
name: <slug>
description: "<role> — <one-line value prop>"
model: opus | sonnet | haiku
tools: Read, Edit, Write, ...
maxTurns: <optional, default unlimited>

# Scope (T31)
reads:
  - brain/self.md
  - brain/concept/<relevant>.md
  - brain/people.md
writes:
  - data/agents/<slug>/INBOX.md      # if agent feeds back to brain

# Audit (T32)
spawned_at: YYYY-MM-DD
spawned_by: user | brain-evolve
sensitivity: personal | confidential
---

You are <role>. ...
```

## Spawn flow

```
User: /brain spawn branding
Brain: "What should this agent do?"
Brain: "Which brain files should it read?"
Brain: drafts code/agents/branding.md from _TEMPLATE.md
       (or to _proposed/ if brain-evolve initiated)
User:  approves
Brain: symlinks ~/.claude/agents/branding.md, commits
```

## When agents feed back to brain

If an agent's `writes:` scope includes `data/agents/<slug>/INBOX.md`, the brain treats that path like any other source. Recipe in `code/sources/_TEMPLATE/` applies: ingest → distill → categorized brain files. Agent outputs become part of the corpus.

## Hard rules

- Agent files don't get compacted. Procedural memory (T9) is curated, not refined.
- Agents must declare scope. Untyped agents are rejected.
- `_proposed/` is gitignored from the public framework — only your private brain carries proposals; the public template is in `_TEMPLATE.md`.
