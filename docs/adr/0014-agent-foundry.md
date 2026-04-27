# ADR-0014: Agent foundry — brain spawns its own agents

**Status:** Accepted
**Date:** 2026-04-26

## Context

A power user can run dozens of active threads at once. When a recurring task pattern emerges (e.g., "I keep refining brand voice across ProjectA + ProjectB content"), the brain should be able to spawn a specialized agent — like other agent runtimes spawn sub-agents — without the user hand-writing the agent definition.

Reference implementations of hand-written agents (build, ship, design, etc.). Standard Anthropic frontmatter format: `name`, `description`, `model`, `tools`, body is the system prompt.

The brain needs a meta-skill that produces agents on demand, with appropriate brain context, gated by user approval, scope-limited at spawn time.

## Decision

Add `code/agents/` foundry to the framework:

### Structure

```
code/agents/
├── README.md                   ← what agents are, how spawning works
├── _TEMPLATE.md                ← Anthropic-standard frontmatter + scope fields
├── _proposed/                  ← brain-evolve drops proposed agents here
└── <slug>.md                   ← approved agents (one per file)

code/skills/brain-spawn/
└── SKILL.md                    ← /brain spawn <name> meta-skill
```

### Agent frontmatter (extends Anthropic standard with scope + audit)

```yaml
---
# Anthropic standard
name: branding
description: "Brand Voice Agent — keeps the user's external content on-brand"
model: sonnet
tools: Read, Edit, Write, WebFetch
maxTurns: 30

# Scope (T31)
reads:                          # consent at spawn time
  - brain/self.md#voice
  - brain/concept/projecta-brand.md
  - brain/concept/projectb-brand.md
writes:
  - data/agents/branding/INBOX.md

# Audit (T32)
spawned_at: 2026-04-26
spawned_by: user                 # or brain-evolve
sensitivity: personal
---

You are the Branding agent for [[the user]]. ...
```

### `/brain spawn <slug>` flow

1. User: `/brain spawn branding`
2. Brain asks: "What should this agent do?"
3. Brain asks (or infers from task description): "Which brain files should it read?"
4. Brain drafts `code/agents/<slug>.md` from `_TEMPLATE.md`, filling in role, scope, system prompt.
5. **If user spawned:** save directly, symlink to `~/.claude/agents/`, commit.
6. **If brain-evolve spawned:** save to `code/agents/_proposed/<slug>.md`. The user moves to `code/agents/<slug>.md` to approve. No silent activation.

### Hard rules (T30–T32)

- **T30:** Agents are markdown only. No bash, no JS in agent definitions. Vendor-neutral so they work with Claude / Codex / Cursor / Gemini.
- **T31:** Brain enforces `reads:` and `writes:` scope. An agent reading anything not in its `reads:` list is a bug, not a feature.
- **T32:** Brain-spawned agents land in `_proposed/`. The user approves by `mv` to active. `/brain-evolve` cannot silently activate agents.

### When agents feed back to brain

If an agent's `writes:` scope includes `data/agents/<slug>/INBOX.md`, the brain treats that path like any other source. `code/sources/_TEMPLATE/` recipe applies: ingest → distill → categorized brain files. So an agent's outputs become part of the corpus.

## Consequences

- The brain becomes a **factory of factories** — it builds the tools it needs to handle the user's recurring patterns.
- Agents inherit voice and rules from the brain (via their `reads:` scope including `self.md`).
- Scope-limiting prevents agents from accessing sensitive content unless declared.
- Approval gating prevents runaway self-expansion.
- Agents are portable: any user forking nanobrain can spawn agents with their own brain context.

## Alternatives considered

- **No agent foundry; users hand-write agents.** Rejected. Doesn't scale. Pattern-recognition opportunity from `/brain-evolve` is wasted.
- **Brain manages agent lifecycle (auto-update, retire).** Deferred. Add only when manual proves painful.
- **Agents in JS/TS instead of markdown.** Rejected per T30. Vendor-neutrality matters more than expressiveness.
- **Allow brain-evolve to silently activate.** Rejected per T32. Human in the loop for any new permanent tool.

## Related

- ADR-0008 (Source template pattern — same recipe shape)
- ADR-0013 (Tenets, T30–T32 codified)
- `code/SAFETY.md` invariants M1–M5 (self-modification rules)
- Existing reference agents — model for frontmatter
