---
name: brain-spawn
description: Spawn a new specialized agent from brain context. User describes role + scope; skill drafts agent .md, registers it, commits.
---

# /brain-spawn (also via `/brain spawn`)

Create a new specialized agent on demand. The agent reads from declared brain context, lives in `code/agents/<slug>.md`, and is symlinked to `~/.claude/agents/` so any Claude Code session can invoke it.

## When to use

- A pattern has emerged: "I keep doing X manually" → spawn an agent for X
- Need a specialist that has the user's voice + relevant context (e.g., branding agent that reads brand strategy)
- `/brain-evolve` proposes one (drops to `code/agents/_proposed/`); user reviews and `mv`s to activate

## Steps

### 1. Gather requirements

Ask:
- **Slug:** kebab-case name (e.g., `branding`, `recruiter-replies`, `board-prep`)
- **Role:** one-line description (e.g., "Brand Voice Agent that keeps ProjectA + ProjectB content on-brand")
- **Reads scope:** which brain files should the agent access?
  - Default: `brain/self.md` (always — for voice + style)
  - Optional: specific concepts, projects, people files
  - **Never:** `brain/raw.md`, `brain/interactions.md`, `data/**` (S2)
- **Writes scope:** if the agent produces output the brain should track, declare `data/agents/<slug>/INBOX.md`. Else `writes: []`.
- **Sensitivity:** `personal` (default), `confidential` (sensitive contexts), or `public` (only if agent will be open-sourced)
- **Model:** `sonnet` (default), `opus` (for high-stakes drafting), `haiku` (cheap classification)
- **Tools:** Read, Edit, Write, Glob, Grep (default). Add WebFetch / WebSearch if agent needs web. Add Bash only if agent needs to run scripts.

### 2. Draft from `_TEMPLATE.md`

Read `code/agents/_TEMPLATE.md`. Replace placeholders. Write the system prompt body based on the role description.

### 3. Save

- **If user invoked `/brain spawn`:** save to `code/agents/<slug>.md` directly.
- **If `/brain-evolve` proposed:** save to `code/agents/_proposed/<slug>.md` instead. The user approves by `mv code/agents/_proposed/<slug>.md code/agents/<slug>.md`.

### 4. Wire

After save (active path):
```bash
ln -sf $HOME/brain/code/agents/<slug>.md ~/.claude/agents/<slug>.md
mkdir -p $HOME/brain/data/agents/<slug>
touch $HOME/brain/data/agents/<slug>/INBOX.md  # only if writes scope is non-empty
```

### 5. Commit + mirror to raw.md

```bash
cd $HOME/brain
git add code/agents/<slug>.md $HOME/brain/data/agents/<slug>/.gitkeep
printf '\n\n### %s — agents — spawned %s\n\nReads: <list>\nWrites: <list>\nReason: <one-liner>\n' "$(date +%Y-%m-%d\ %H:%M)" "<slug>" >> brain/raw.md
git add brain/raw.md
git -c user.email=you@example.com -c user.name="Your Name" commit -m "spawn agent: <slug> — <role>"
git push
```

### 6. Verify

```bash
ls -la ~/.claude/agents/<slug>.md  # symlink exists
```

Tell user: "branding agent ready. Use as `/branding <task>` or invoke from any Claude session."

## Hard rules (S29, T30–T32)

- Agents are markdown only.
- `reads:` / `writes:` are enforced by the brain (T31).
- Brain-spawned agents require the user's `mv` approval before activation (T32).
- Never spawn an agent with broader scope than necessary.
- Never include secrets in the agent body.
- Match the user's voice in the system prompt: no em dashes, short imperative sentences.

## When to refuse

- Slug already exists: ask "update the existing agent or create a sibling with different slug?"
- Reads scope includes firehose paths (raw.md, interactions.md, data/): refuse, explain S2.
- Agent description is vague ("help with stuff"): ask for sharper role.

## Linked

- ADR-0014 (agent foundry)
- `code/SAFETY.md` invariants S22, S23, S29, M1–M5
- `code/agents/README.md` and `_TEMPLATE.md`
