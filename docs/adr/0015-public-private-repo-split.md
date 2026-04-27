
**Status:** Accepted
**Date:** 2026-04-26

## Context

Tenet 8: brain framework should be public/sharable; the user's content stays private. Today everything lives in one private repo at `<your-brain-repo>`. That blocks sharing — anyone forking gets the user's identity, projects, decisions, contacts, job pipeline.

## Decision

**Two repos. Permanent split.**

### `nanobrain` (public, MIT)

The framework. Open source. Karpathy LLM-wiki idea, operationalized. Anyone can fork to bootstrap their own private brain.

```
nanobrain/
├── README.md                  ← public-facing pitch + bootstrap guide
├── LICENSE                    ← MIT
├── CONTRIBUTING.md
├── CHANGELOG.md
├── SCHEMA.md                  ← canonical semantic vocabulary
├── SOURCES.md                 ← source roadmap (pluggable)
├── CLAUDE.md                  ← activation template
├── AGENTS.md                  ← Codex/Cursor template
├── GEMINI.md                  ← Gemini template
├── install.sh                 ← bootstraps a private brain repo
├── code/
│   ├── SAFETY.md              ← invariants (S1–S29, M1–M5)
│   ├── hooks/                 ← capture.sh + STOP.md
│   ├── skills/                ← brain, brain-save, brain-compact, brain-evolve, brain-checkpoint, brain-spawn
│   ├── agents/                ← _TEMPLATE.md (no instantiated agents)
│   ├── sources/               ← _TEMPLATE/ + reference impls (claude, repos)
│   └── mcp-server/            ← MCP server scaffold
├── claude-config/             ← synced settings/hooks/mcp templates
├── docs/
│   ├── adr/                   ← all ADRs (architecture decisions are public)
│   ├── ARCHITECTURE.md
│   ├── GETTING-STARTED.md
│   └── VISION.md
└── examples/
    └── starter-brain/         ← anonymized example of what a fresh private brain looks like
```

### `<your-brain-repo>` (private)

The user's content. Never goes public.

```
brain-repo/
├── README.md                  ← "this is my private brain content"
├── CONTEXT.md                 ← this week's focus
├── ROADMAP.md                 ← user's source priorities
├── plan.md                    ← user's plan history
├── brain/                     ← THE CORPUS (per-entity files, indexes, firehoses)
├── data/                      ← raw ingestions per source (gitignored sensitive folder)
└── BRAIN_HASH.txt             ← integrity audit
```

### How they connect (no submodule)

`install.sh` (in nanobrain) takes a path to the private brain dir as argument:

```bash
# Bootstrap a new brain
gh repo create my-brain --private
gh repo clone myuser/my-brain ~/my-brain
gh repo clone <user>/nanobrain ~/nanobrain
~/nanobrain/install.sh ~/my-brain   # symlinks framework into ~/.claude/, content stays in ~/my-brain
```

`install.sh` symlinks:
- `~/nanobrain/code/skills/*` → `~/.claude/skills/*`
- `~/nanobrain/code/hooks/capture.sh` → `~/.claude/hooks/capture.sh`
- `~/nanobrain/claude-config/CLAUDE.md` → `~/.claude/CLAUDE.md` (with content brain import line)
- `~/.claude/settings.json` ← merged hooks (Stop, SessionEnd, PreCompact)

Hooks reference content path via `BRAIN_DIR` env var (or default `$HOME/brain`).

### Migration from current state

1. Keep current `<your-brain-repo>` repo as the private content side.
2. New public `nanobrain` repo (created 2026-04-26) gets framework files.
6. Add LICENSE (MIT), CONTRIBUTING.md, CHANGELOG.md, public README.md to nanobrain.
7. `install.sh` updated to take private content dir as argument and symlink across both repos.

## Consequences

- Framework can be shared, contributed to, starred.
- Content stays private forever.
- Two clones to set up a machine, but one command (`install.sh <path>`) wires them.
- Updates to framework (ship a new skill, fix capture.sh) flow to all forks via `git pull` on nanobrain.
- `/brain update` runs `git pull` on both repos.

## Alternatives considered

- **Single repo with .gitignore-based public/private split.** Rejected. Operationally fragile; one missed gitignore = leaked content.
- **Submodule (private brain inside public framework).** Rejected. Submodules are operationally fragile (clone, init, update three-step).
- **Single private repo, never go public.** Rejected per Tenet 8. The framework should be shareable.
- **Private content repo embedded in public framework as `/example`.** Rejected. Same content-leak risk.

## Related

- Tenet 8 (public/sharable)
- T17 (four-tier security)
- T18 (two repos)
- ADR-0013 (lockdown)
