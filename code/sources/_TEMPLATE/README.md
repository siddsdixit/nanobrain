# <Source name>

Copy this whole folder when adding a new source. Rename `<source>` everywhere.

**What this source provides:** <one-line>
**Frequency of ingest:** <real-time MCP / hourly cron / daily / on-demand>
**Auth required:** <none / OAuth / API token / bearer>
**Volume estimate:** <messages per day, MB per month>

## Why ingest it

<2-3 sentences on the signal value: what does this give the brain that other sources don't?>

## Where ingested data lands

`$HOME/brain/data/<source>/INBOX.md` (or `INBOX.jsonl` if structured)

Append-only, shell-only, never Read in full.

## Where distilled signal lands

- `brain/people.md` and `brain/people/<slug>.md`
- `brain/interactions.md` (always)
- `brain/learnings.md` (when applicable)
- `brain/decisions.md` (when applicable)
- `brain/raw.md` (cross-source mirror, always)

## Auth / setup notes

<step-by-step: how to get tokens, where they go (~/.claude/.env), how to revoke>

## Privacy filters

Pre-write filter: regex strip these before any data hits disk:
- `password|passwd|pwd`
- `token|api[_-]?key|secret`
- `Bearer\s+[A-Za-z0-9._-]+`
- `sk-[A-Za-z0-9]{20,}`
- Anything the user flags as sensitive (case by case)
