# code/sources/ — ingest + distill protocols per source

Every external source has a folder here. Folder = one source. Adding a source = copying `_TEMPLATE/` and filling it in.

```
code/sources/
├── README.md              ← this file
├── _TEMPLATE/             ← copy this when adding a new source
│   ├── README.md
│   ├── ingest.md          ← protocol Claude follows to pull data → data/<source>/
│   └── distill.md         ← protocol Claude follows to extract signal → brain/
├── claude/                ← already wired (Stop hook → brain/raw.md + data/claude/)
├── slack/                 ← Slack workspaces
├── granola/               ← Granola.ai meeting transcripts
├── repos/                 ← git activity across all the user's repos
├── gmail/                 ← (future)
├── gcal/                  ← (future)
├── linkedin/              ← (future, 6-month export pattern)
├── imessage/              ← (future)
├── financial/             ← (future, bank/credit exports, transactions)
├── health/                ← (future, Apple Health, sleep, fitness)
└── voice/                 ← (future, iPhone shortcut → Whisper → transcript)
```

## How to add a new source (recipe)

1. **Pick a slug.** Lowercase, hyphens. Example: `notion`, `pocket`, `strava`, `ynab`.

2. **Stamp the source folders:**
   ```bash
   slug=NEW_SOURCE_SLUG
   cp -R $HOME/brain/code/sources/_TEMPLATE $HOME/brain/code/sources/$slug
   mkdir -p $HOME/brain/data/$slug
   echo "# data/$slug/ — <source description>" > $HOME/brain/data/$slug/README.md
   ```

3. **Fill in `code/sources/<slug>/`:**
   - `README.md` — what this source is, why it's worth ingesting, auth requirements
   - `ingest.md` — exact steps Claude follows to pull data into `data/<slug>/INBOX.md`
   - `distill.md` — exact steps to extract signal into `brain/` files (interactions, people, learnings, decisions)

4. **Wire ingestion mechanism:**
   - **MCP-based** (preferred when available) → register server in `claude-config/mcp.json`
   - **Cron-based** → script in `code/sources/<slug>/ingest.sh`, install with launchd plist (`code/sources/<slug>/cron.plist.tmpl`)
   - **Manual** → just runs when the user types `/brain ingest <slug>`

5. **Test once:**
   ```
   /brain ingest <slug>      # pull raw → data/<slug>/INBOX.md
   /brain distill <slug>     # signal → brain/
   /brain "<query>"          # verify it answers from new source
   ```

6. **Commit and push.** `/brain-evolve` will surface improvements over time.

## Hard rules for any source

- **Append-only writes to `data/<slug>/`.** Shell `>>`. Never Edit. Never Read in full.
- **Distillation always cross-mirrors to `brain/raw.md`** (cross-source firehose) so a single grep finds everything.
- **No secrets in markdown.** Tokens, passwords, OAuth refresh stay in `~/.claude/.env` or a per-source secret store. Never in the repo.
- **Privacy filter at ingest time.** Strip `password|token|api_key|sk-|Bearer ` patterns before writing to `data/`.
- **Source-specific compaction.** Sources with high volume (Slack, Granola, gmail) rotate INBOX monthly: `INBOX-<YYYY-MM>.md`.
- **Distillation is explicit.** Never auto-distill on ingest. Run distill on cadence (`/brain distill <slug>` or weekly cron).

## What goes in `brain/` vs `data/`

- `brain/people.md`, `people/<slug>.md` — distilled people index + profiles
- `brain/interactions.md` — distilled interaction log (cross-source)
- `brain/learnings.md`, `decisions.md`, `projects.md`, `goals.md`, `self.md` — distilled signal
- `brain/raw.md` — cross-source distilled firehose (every distilled item also lands here)
- `data/<slug>/INBOX.md` — raw ingestion per source (huge, shell-only)
