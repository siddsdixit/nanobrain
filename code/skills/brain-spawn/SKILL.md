---
name: brain-spawn
description: Spawn a context-scoped agent. Drafts code/agents/<slug>.md from _TEMPLATE.md.
---

# /brain-spawn

Create a specialized agent on demand. The agent reads a whitelisted set of brain files and is filtered by context (work | personal | both).

## Usage

```
spawn.sh --slug <kebab> --role "<one-line>" --reads "<file1,file2>" --context <work|personal|both> [--install-symlink]
```

Env-driven (for tests):
- `NANOBRAIN_SPAWN_SLUG`, `NANOBRAIN_SPAWN_ROLE`, `NANOBRAIN_SPAWN_READS`, `NANOBRAIN_SPAWN_CONTEXT`
- `BRAIN_DIR` and `NANOBRAIN_DIR` to redirect filesystem.

## Refusals

- Slug already exists at `code/agents/<slug>.md`.
- Slug contains spaces or non-kebab characters.
- `reads` includes `raw.md` or `interactions.md`.

## v2 simplification

Dropped from v0.x: `sensitivity_max`, `ownership_in`. Frontmatter is just `slug`, `reads.files`, `reads.filter.context_in`.

## After spawn

Symlinks into `~/.claude/agents/<slug>.md` only with `--install-symlink`. Tests skip this by default.
