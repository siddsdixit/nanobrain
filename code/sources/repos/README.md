# Source: repos — git repository activity rollup

Pulls activity across all of the user's git repos into `data/repos/INBOX.md` and distills into `brain/repos.md`, `brain/projects.md`, `brain/raw.md`.

**Frequency:** daily cron or manual `/brain ingest repos`
**Auth required:** `gh auth login` already done (uses existing GitHub CLI session)
**Volume estimate:** ~50 lines/day across all active repos

## Why ingest it

A power user can commit across dozens of repos. The brain needs to know what's active, what's stale, what changed. Without this, `brain/repos.md` and `brain/projects.md` go stale within a week.

## Where ingested data lands

`$HOME/brain/data/repos/INBOX.md` (append-only, shell-only, never Read in full).

## Where distilled signal lands

- `brain/repos.md` — stale-detection (mark any repo not seen in 60+ days)
- `brain/projects.md` — auto-update status for active repos
- `brain/raw.md` — cross-source mirror

## Auth / setup

```bash
gh auth status                # confirm gh auth status
which gh git                  # confirm both on PATH
```

No tokens needed. `gh` and `git` use existing local creds.

## Privacy filters

- Skip private repo *contents* — only commit metadata (sha, message, file count, branch).
- Strip any commit message matching `password|token|api[_-]?key|secret|sk-|Bearer` (case-insensitive).
- Never include diff content in the INBOX. Only the commit summary line.
