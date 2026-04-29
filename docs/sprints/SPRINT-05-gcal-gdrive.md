# SPRINT-05 — Calendar + Drive sources

## Goal

Ship Google Calendar and Google Drive ingestors using the gmail-source pattern locked in S04. These two share a vendor (Google), share resolver shapes (calendar-id and folder-glob), and share a once-daily cadence. Doing them together amortizes the boilerplate and verifies the per-source template generalizes.

## Stories

- **NBN-112** — gcal source (medium)
- **NBN-113** — gdrive source (large)

## Pre-conditions

- SPRINT-04 merged. The gmail source is the reference; this sprint copies its layout file-for-file.
- `mcp__gcal__*` and `mcp__gdrive__*` configured in `~/.claude/.mcp.json` on the dev machine. If absent, mocks under `tests/mocks/` cover the integration path.

## Detailed steps

All paths in **public framework** (`~/Documents/nanobrain/`).

### 1. NBN-112 — gcal source

#### Files

```
code/sources/gcal/
  ingest.sh
  ingest.md
  distill.md
  requires.yaml
  context_resolver.sh
  test_resolver.sh
code/cron/com.nanobrain.ingest.gcal.plist
tests/mocks/mcp_gcal.sh
tests/integration/gcal.sh
```

#### `requires.yaml`

```yaml
source: gcal
mcp: gcal
binaries: [yq, jq]
windows:
  bootstrap_work_days: 9
  bootstrap_personal_days: 1095
cadence:
  cron_expr: "15 6 * * *"   # daily 06:15 local
```

#### `context_resolver.sh`

```bash
#!/usr/bin/env bash
# Usage: context_resolver.sh <calendar_id>
set -euo pipefail
CAL="${1:-}"
exec bash "${BRAIN_FRAMEWORK:-$HOME/.nanobrain}/code/lib/resolve_context.sh" gcal "$CAL"
```

#### `test_resolver.sh` cases

- `sid@bigco.com` → `work\tconfidential\temployer:bigco`.
- `sid@gmail.com` (no resolver match) → `personal\tprivate\tunset`.
- `founder-cal@side-proj-a.com` (added to fixture `_contexts.yaml`) → `side-proj-a\tconfidential\tmine`.

If the example `_contexts.yaml` doesn't have a side-proj-a gcal entry, extend `examples/_contexts.example.yaml` in this sprint to add it. Inline flag: keep example richer than minimum so downstream tests have data.

#### `ingest.sh` behavior

1. Read `.watermark` (ISO 8601). Missing + `--bootstrap` → window = now − 9d through now + 30d.
2. Enumerate calendars the user owns or has accepted (`mcp__gcal__list_calendars`). Per calendar, query events with `updated > .watermark`.
3. Per-event loop:
   - Skip if `status == "cancelled"`.
   - Skip if event is a recurring-instance materialization with no edits since the master (avoid duplicate noise).
   - Skip if event is all-day with no description (low signal).
   - Resolve via `context_resolver.sh "$CALENDAR_ID"`.
   - Compose entry: `<start_time> — gcal: <summary> (<calendar_id_short>)`. Body: `Calendar: <id>`, `Attendees: N`, `Location: ...`, `Description excerpt (500c): ...`.
   - Call `write_inbox.sh`.
4. Watermark advances to max `updated` timestamp seen.
5. Single-pass bootstrap (no Pass 2). Personal calendars share the same window — gcal volume is low enough that 1095d is fine in one pass. Cap at 500 events per bootstrap; if exceeded, log warning and stop (user can re-run).

#### `distill.md` routing

- Future meeting (start_time > now) → `brain/interactions.md` with forward-reference (`will meet`).
- Past meeting + description has action items keywords (`AI:`, `TODO:`, `decision:`) → `brain/decisions.md` + `brain/interactions.md`.
- Past meeting plain → `brain/interactions.md`.
- Per-attendee detection: if attendee email maps to a `brain/people/<slug>.md`, append a one-line entry there too.

#### Plist

`com.nanobrain.ingest.gcal.plist` — daily 06:15. ProgramArguments → `dispatch.sh gcal`. StandardOutPath logs.

### 2. NBN-113 — gdrive source

#### Files

```
code/sources/gdrive/
  ingest.sh
  ingest.md
  distill.md
  requires.yaml
  context_resolver.sh
  test_resolver.sh
code/cron/com.nanobrain.ingest.gdrive.plist
tests/mocks/mcp_gdrive.sh
tests/integration/gdrive.sh
```

#### `requires.yaml`

```yaml
source: gdrive
mcp: gdrive
binaries: [yq, jq]
windows:
  bootstrap_work_days: 9
  bootstrap_personal_days: 730
cadence:
  cron_expr: "0 22 * * *"   # daily 22:00 local
limits:
  bootstrap_max_files: 500
  body_excerpt_chars: 500
```

#### `context_resolver.sh`

```bash
#!/usr/bin/env bash
# Usage: context_resolver.sh <full_path>
set -euo pipefail
PATH_ARG="${1:-}"
exec bash "${BRAIN_FRAMEWORK:-$HOME/.nanobrain}/code/lib/resolve_context.sh" gdrive "$PATH_ARG"
```

The shared resolver already handles the gdrive `folder_overrides` glob walk (S01).

#### `test_resolver.sh` cases

- `/BigCo/Strategy/pricing.md` → `work\tconfidential\temployer:bigco`.
- `/Personal/sideproj-a/PRD.md` → `side-proj-a\tconfidential\tmine`.
- `/random/note.md` → `personal\tprivate\tunset`.
- glob-edge: `/BigCo/` (no file segment) → `work\tconfidential\temployer:bigco` (the glob `/BigCo/**` matches).

#### `ingest.sh` behavior

1. Bootstrap window = last 9d work / 730d personal. Decision (inline flag): personal-window 2y for gdrive vs 3y gmail. Drive carries fewer high-signal artifacts farther back; 2y is enough.
2. List configured root folders. Source root list from `_contexts.yaml`'s `resolvers.gdrive.folder_overrides[].match.path_glob`, stripping `/**` to get folders. If no overrides defined, fall back to listing the user's "My Drive" root with `modifiedTime > .watermark`.
3. For each candidate file: query `mcp__gdrive__list_files` with `modifiedTime > .watermark` filter, `pageSize=200`, paginated.
4. Per-file loop:
   - Skip if mime type not in: `text/markdown, text/plain, application/vnd.google-apps.document, application/pdf, application/vnd.google-apps.spreadsheet`. Log skips count.
   - Skip if filename matches `\.(tmp|bak|~lock\.)`.
   - Resolve via `context_resolver.sh "$FULL_PATH"`.
   - Fetch first 500 chars of content (Google Docs → export as text/plain; Sheets → first sheet first 50 cells; PDF → first page text via MCP if supported, else placeholder `[PDF content not extracted]`).
   - Compose entry: `<modifiedTime> — gdrive: <filename> (modified)`. Body: `Path: <full>`, `Mime: <type>`, `Modified by: <email>`, `Excerpt: ...`.
   - Call `write_inbox.sh`.
5. Watermark = max `modifiedTime`. Cap at 500 files per bootstrap (per `requires.yaml`).
6. **Sensitive routing:** if resolver returns `confidential` AND filename matches `(NDA|contract|MSA|SOW|legal|cap.?table)` (case-insensitive), set `SENSITIVITY=sensitive` in the write call. Spec §5.3 + S9/S18: `sensitive`-tagged entries are routed by distill into `data/_sensitive/` only, never `brain/`.

#### `distill.md` routing

- Product / strategy docs in `work` context → `brain/projects.md`.
- Meeting notes (filename starts `Meeting -` or `Notes -`) → `brain/interactions.md`.
- `sensitive`-tagged entries → drop to `data/_sensitive/<source_id>.md` (full body, not 500c excerpt). Never reach `brain/`.
- Anything else → drop (INBOX retains).

#### Plist

`com.nanobrain.ingest.gdrive.plist` — daily 22:00. Same shape as gmail/gcal plists.

### 3. Mocks and integration tests

- `tests/mocks/mcp_gcal.sh` — three canned events (work calendar, personal, side-proj-a board call).
- `tests/mocks/mcp_gdrive.sh` — four canned files (BigCo strategy doc, NDA in BigCo folder for sensitive routing, personal note, gibberish .tmp for filter check).
- `tests/integration/gcal.sh` — bootstrap, assert 3 entries, correct contexts, watermark advanced.
- `tests/integration/gdrive.sh` — bootstrap, assert 2 entries (NDA routed to `_sensitive`, .tmp filtered, strategy + personal in INBOX), `data/_sensitive/` directory created and populated.

## Reference patterns

- `code/sources/gmail/` (S04 output) — file-for-file template. Copy and modify.
- `code/sources/repos/ingest.sh` — pagination + watermark-mv pattern.
- `code/cron/com.nanobrain.ingest.gmail.plist` — plist boilerplate.

## Testing

```bash
cd ~/Documents/nanobrain

# unit
bash code/sources/gcal/test_resolver.sh
bash code/sources/gdrive/test_resolver.sh

# integration
bash tests/integration/gcal.sh
bash tests/integration/gdrive.sh

# dispatcher hand-off
BRAIN_DIR=/tmp/sb-test bash code/skills/brain-ingest/dispatch.sh gcal
BRAIN_DIR=/tmp/sb-test bash code/skills/brain-ingest/dispatch.sh gdrive

# plist syntax
plutil -lint code/cron/com.nanobrain.ingest.gcal.plist
plutil -lint code/cron/com.nanobrain.ingest.gdrive.plist

# real-MCP smoke (dev machine with both MCPs configured)
BRAIN_DIR=$HOME/your-brain bash code/skills/brain-ingest/dispatch.sh gcal --bootstrap
BRAIN_DIR=$HOME/your-brain bash code/skills/brain-ingest/dispatch.sh gdrive --bootstrap
```

## Definition of done

- [ ] Both source dirs complete (six files each).
- [ ] Both plists `plutil -lint` clean.
- [ ] Resolver tests green (3 cases gcal, 4 cases gdrive).
- [ ] Integration tests green; gdrive sensitive-routing verified (`data/_sensitive/` populated, `brain/` clean).
- [ ] gdrive mime-filter verified (.tmp file rejected before resolve).
- [ ] gcal recurring-instance dedupe verified.
- [ ] Both sources `chmod +x` on shell files.
- [ ] Real-MCP smoke run on the maintainer's machine; INBOX entries inspected for tag correctness.

## Commit / push

Two commits, public framework only:

```bash
cd ~/Documents/nanobrain

git add code/sources/gcal code/cron/com.nanobrain.ingest.gcal.plist \
        tests/mocks/mcp_gcal.sh tests/integration/gcal.sh
git commit -m "feat: gcal source (NBN-112)"

git add code/sources/gdrive code/cron/com.nanobrain.ingest.gdrive.plist \
        tests/mocks/mcp_gdrive.sh tests/integration/gdrive.sh
git commit -m "feat: gdrive source with sensitive-routing for legal docs (NBN-113)"

git push
```

## Estimated time

6 hours. ~1.5h gcal (mostly clone-from-gmail), ~3h gdrive (folder enumeration, mime filter, sensitive routing is new), ~1h mocks + integration tests, ~30min plists and real-MCP smoke.
