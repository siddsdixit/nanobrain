# claude-config — synced Claude Code config

Files here are the canonical source for your Claude Code setup across all machines. `install.sh` symlinks them into `~/.claude/` so editing in this repo and pushing = every machine gets the change on next pull.

## Contents

- `CLAUDE.md` — global rules. Symlinked to `~/.claude/CLAUDE.md`.
- `settings.json` — Claude Code settings (Stop hook for brain capture). Merged into `~/.claude/settings.json` (not replaced — preserves machine-local permissions).

## How it stays synced

1. Edit any file in this folder.
2. `cd $HOME/brain && git add claude-config/ && git commit -m "config: ..." && git push`
3. On any other machine: `cd $HOME/brain && git pull`. Symlinked files take effect immediately.

## What's NOT synced (intentionally)

- `~/.claude/.env` — API keys, machine-local secrets
- `~/.claude/projects/` — per-project session data
- Machine-local permissions in `settings.local.json`

If you add new global rules, edit `CLAUDE.md` here. If you add a new hook, update `settings.json` here. Keep machine-specific stuff in `~/.claude/settings.local.json`.
