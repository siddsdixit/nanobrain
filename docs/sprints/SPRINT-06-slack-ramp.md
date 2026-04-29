# SPRINT-06 — Slack + Ramp sources

## Goal

Ship the last two ingest sources. Slack tests the channel-level resolver override (sim P5 fix) and is the only source where two keys (team_id + channel_name) flow through the resolver. Ramp tests a work-only, weekly-cadence, high-sensitivity financial source with no `brain/` routing.

## Stories

- **NBN-114** — slack source (large)
- **NBN-115** — ramp source (medium)

## Pre-conditions

- SPRINT-04 merged (gmail = template).
- SPRINT-05 merged (gcal/gdrive prove the template generalizes; channel/folder overrides patterns reused).
- `mcp__slack__*` configured. Ramp: either `mcp__ramp__*` MCP, or `RAMP_API_KEY` env (sprint supports both, decision below).

## Detailed steps

All paths in **public framework** (`~/Documents/nanobrain/`).

### 1. NBN-114 — slack source

#### Files

```
code/sources/slack/
  ingest.sh
  ingest.md
  distill.md
  requires.yaml
  context_resolver.sh
  test_resolver.sh
code/cron/com.nanobrain.ingest.slack.plist
tests/mocks/mcp_slack.sh
tests/integration/slack.sh
```

#### `requires.yaml`

```yaml
source: slack
mcp: slack
binaries: [yq, jq]
windows:
  bootstrap_days: 30           # slack history is volatile; 30d is the cap most workspaces allow without enterprise
cadence:
  cron_expr: "0 */2 * * *"     # every 2h, 24/7 (slack signal arrives off-hours too)
limits:
  bootstrap_max_messages: 2000
  body_excerpt_chars: 500
```

Inline flag on bootstrap window: spec §5.4 said 9d, sprint ships 30d. Slack channel history caps at 90d on Pro tier; 30d gives meaningful onboarding signal. Pull this back to 9d in `requires.yaml` if rate-limit complaints arrive post-launch.

#### `context_resolver.sh`

Two-key resolver. Channel rule consulted before workspace rule (the resolver lib already does this; the wrapper just passes both keys).

```bash
#!/usr/bin/env bash
# Usage: context_resolver.sh <team_id> <channel_name>
set -euo pipefail
TEAM="${1:-}"
CHAN="${2:-}"
exec bash "${BRAIN_FRAMEWORK:-$HOME/.nanobrain}/code/lib/resolve_context.sh" slack "$TEAM" "$CHAN"
```

#### `test_resolver.sh` cases

Use `examples/_contexts.example.yaml` (T_BIGCO workspace=work, channel `^random$`=personal override).

- `T_BIGCO #budget-2026` → `work\tconfidential\temployer:bigco` (workspace rule).
- `T_BIGCO #random` → `personal\tprivate\tunset` (channel override beats workspace).
- `T_BIGCO #eng-leads` → `work\tconfidential\temployer:bigco` (workspace fallback).
- `T_PERSONAL #general` (no resolver entry) → `personal\tprivate\tunset` (defaults).
- DM (channel name is user id like `D012ABC`) → workspace rule applies; no override matches a DM channel name. `T_BIGCO D012ABC` → `work\tconfidential\temployer:bigco`.

#### `ingest.sh` behavior

1. Bootstrap: list workspaces accessible to the MCP (`mcp__slack__list_teams` or single-workspace MCPs default to one team). For each:
   - List channels user is a member of (public, private, DMs, MPDMs). Cap at 200 channels. If exceeded, log and stop with user-actionable message.
   - For each channel, fetch messages from last 30d. Cap 2000 total messages per bootstrap (per `requires.yaml`); when reached, log "bootstrap cap reached, advance watermark and re-run for older history".
2. Incremental: same loop, but per-channel `oldest = max(channel_watermark, run_watermark)`. Per-channel watermarks live in `data/slack/.watermarks/<team_id>__<channel_id>` (one tiny file each). Run-level watermark in `data/slack/.watermark` is the latest message ts seen in the run.
3. Per-message processing:
   - Skip bot messages (`subtype == "bot_message"`) unless from a known integration whitelist (initially empty; users add via env `SLACK_BOT_ALLOWLIST`).
   - Skip `subtype == "channel_join"`, `channel_leave`, `pinned_item`, `bot_add`.
   - Skip messages older than `now - bootstrap_days` even if returned by the API.
   - Resolve via `context_resolver.sh "$TEAM_ID" "$CHANNEL_NAME"`.
   - Compose entry: `<ts> — slack: <team_short> #<channel>`. Body: `Channel: #<name>`, `From: <user_real_name>`, `Excerpt (500c): <text>`. Replace `<@U...>` mentions with usernames before truncating.
   - SOURCE_ID = `<message_ts>.<channel_id>` (per spec §5.4 format).
   - Call `write_inbox.sh`.
4. Watermark advances to max ts on success.

#### `distill.md` routing

- DM from a person → `brain/people/<slug>.md` (slug from real name) + `brain/interactions.md`.
- Channel announcement (text starts with `[ANNOUNCEMENT]`, `Heads up:`, contains `we've decided`/`decision:` keyword) → `brain/decisions.md` + `brain/interactions.md`.
- Channel banter / casual → drop (INBOX-only).
- Cross-context handling: a `personal`-tagged message in a `work` workspace (channel override fired) routes to personal `brain/people/` only, never `brain/projects.md`.

#### Plist

`com.nanobrain.ingest.slack.plist` — every 2h via `StartInterval = 7200`. (Calendar-interval array would need 12 entries; `StartInterval` is cleaner here.)

### 2. NBN-115 — ramp source

#### Files

```
code/sources/ramp/
  ingest.sh
  ingest.md
  distill.md
  requires.yaml
  context_resolver.sh
  test_resolver.sh
code/cron/com.nanobrain.ingest.ramp.plist
tests/mocks/mcp_ramp.sh
tests/integration/ramp.sh
```

#### `requires.yaml`

```yaml
source: ramp
mcp_or_env:
  - mcp: ramp
  - env: RAMP_API_KEY              # fallback when no MCP exists; ingest.sh probes both
binaries: [yq, jq, curl]
windows:
  bootstrap_days: 90
cadence:
  cron_expr: "0 9 * * 0"           # weekly Sunday 09:00 local
```

Decision: support both MCP and direct `curl` to the Ramp API. Probe order: if `mcp__ramp__list_transactions` is callable, use MCP; else if `RAMP_API_KEY` set, use `curl https://api.ramp.com/developer/v1/transactions`; else exit 3. Document both paths in `ingest.md`. The shared `dispatch.sh` already returns exit 3 with the right message.

#### `context_resolver.sh`

```bash
#!/usr/bin/env bash
# Usage: context_resolver.sh <ramp_account_id>
set -euo pipefail
ACCT="${1:-}"
exec bash "${BRAIN_FRAMEWORK:-$HOME/.nanobrain}/code/lib/resolve_context.sh" ramp "$ACCT"
```

#### `test_resolver.sh` cases

- `bigco-ramp` → `work\tconfidential\temployer:bigco`.
- `personal-ramp` (no entry) → `personal\tprivate\tunset`. Realistically users only have work-Ramp; this case proves the default works.

#### `ingest.sh` behavior

1. Probe MCP vs env (above). On both missing → exit 3 with `run /brain-doctor`.
2. Fetch transactions in window (last 90d on bootstrap; `from = .watermark` on incremental).
3. Per-transaction loop:
   - Skip declined/voided (`state != "CLEARED"`).
   - Resolve via `context_resolver.sh "$ACCOUNT_ID"`.
   - Compose entry: `<txn.user_transaction_time> — ramp: <merchant_name> — $<amount>`. Body: `Vendor: ...`, `Amount: $...`, `Category: <merchant_category>`, `Memo: <user_memo>`, `Card: ...4242`.
   - SOURCE_ID = transaction id.
   - Call `write_inbox.sh`.
4. Watermark = max `user_transaction_time`.

#### `distill.md` routing

Per spec §5.5: **transactions never enter `brain/`.** INBOX retains them. The distiller emits zero routed entries by default. Exception (the only `brain/` write): if rolling 4-week analysis detects a recurring pattern (e.g. same vendor 4+ times, or category spend exceeds the user's running average by >2σ), the distiller writes a single learning entry to `brain/learnings.md`. Implementation: keep the analyzer simple — count vendors/categories in the delta plus prior 28d INBOX, threshold-based.

In v1.0, ship the distiller protocol with the analyzer skeleton commented and a one-line route: `# v1.0: ramp distill emits 0 brain entries by default. Pattern-detection learning route reserved for v1.1.` This honors spec §5.5 ("aggregates only surface in learnings.md if pattern detected") while keeping v1.0 scope tight. Inline flag.

#### Plist

`com.nanobrain.ingest.ramp.plist` — Sunday 09:00 via `StartCalendarInterval = { Weekday = 0; Hour = 9; Minute = 0; }`.

### 3. Mocks and integration tests

- `tests/mocks/mcp_slack.sh` — fixture: 5 messages across 3 channels (budget-2026 work, random personal-override, eng-leads work, DM, bot_message to be filtered).
- `tests/mocks/mcp_ramp.sh` — fixture: 4 transactions (3 cleared, 1 declined to be filtered).
- `tests/integration/slack.sh` — bootstrap, assert 4 INBOX entries (bot filtered), `#random` entry tagged `personal`, others tagged `work`, per-channel watermarks created.
- `tests/integration/ramp.sh` — bootstrap, assert 3 INBOX entries, all tagged `work\tconfidential\temployer:bigco`, distill produces 0 `brain/` entries on first run.

## Reference patterns

- `code/sources/gmail/` and `code/sources/gdrive/` — file shape, two-key resolver flow (gdrive's folder-glob is structurally similar to slack's channel override).
- For `curl`-fallback API path in ramp, reference `code/sources/repos/ingest.sh` which already shells out to `gh` CLI similarly.

## Testing

```bash
cd ~/Documents/nanobrain

# unit
bash code/sources/slack/test_resolver.sh
bash code/sources/ramp/test_resolver.sh

# integration
bash tests/integration/slack.sh
bash tests/integration/ramp.sh

# plist syntax
plutil -lint code/cron/com.nanobrain.ingest.slack.plist
plutil -lint code/cron/com.nanobrain.ingest.ramp.plist

# real-MCP smoke
BRAIN_DIR=$HOME/your-brain bash code/skills/brain-ingest/dispatch.sh slack --bootstrap
BRAIN_DIR=$HOME/your-brain bash code/skills/brain-ingest/dispatch.sh ramp --bootstrap

# verify channel override actually fired (the high-risk regression)
grep -B1 '#random' $HOME/your-brain/data/slack/INBOX.md | head -20
# Expect: associated `context: personal` line.
```

## Definition of done

- [ ] Both source dirs complete (six files each).
- [ ] Both plists `plutil -lint` clean.
- [ ] Slack resolver test: all 5 cases including channel-override-beats-workspace.
- [ ] Ramp resolver test: 2 cases.
- [ ] Slack integration: bot/system messages filtered, channel override applied, per-channel watermarks under `data/slack/.watermarks/`.
- [ ] Ramp integration: declined txns filtered, 0 entries routed to `brain/` on default distill run.
- [ ] Ramp ingest probes MCP first then env `RAMP_API_KEY`; clean exit 3 when both absent.
- [ ] `chmod +x` on all new shell files.
- [ ] Real-MCP smoke run on the maintainer's machine; channel override visually verified in INBOX.

## Commit / push

Two commits, public framework only:

```bash
cd ~/Documents/nanobrain

git add code/sources/slack code/cron/com.nanobrain.ingest.slack.plist \
        tests/mocks/mcp_slack.sh tests/integration/slack.sh
git commit -m "feat: slack source with channel-level overrides (NBN-114)"

git add code/sources/ramp code/cron/com.nanobrain.ingest.ramp.plist \
        tests/mocks/mcp_ramp.sh tests/integration/ramp.sh
git commit -m "feat: ramp source, work-only weekly cadence (NBN-115)"

git push
```

## Estimated time

6 hours. ~3h slack (channel override is the subtle bit, per-channel watermarks are new), ~2h ramp (MCP-or-env probe, simple distill), ~1h mocks + integration tests + smoke.
