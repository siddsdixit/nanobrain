# Anticipated Sources — full life map

Every signal stream the brain might absorb over time. Not all need integration today. Folder structure is ready for any of them via the recipe in `code/sources/README.md`. Adding a new source = copy `_TEMPLATE/`, never restructure.

Each row: where the data lands, when it's worth doing, dependency.

## Communication (relationships + commitments)

| source | when | priority | notes |
|---|---|---|---|
| **claude** | done | live | Stop hook → `data/claude/INBOX.md` + `brain/raw.md` |
| **slack** (work + personal) | next | high | MCP. Per-workspace folder. |
| **granola** | next | high | MCP. Meeting summaries already structured. |
| **gmail** | soon | high | OAuth read-only. Daily batch. |
| **gcal** | soon | high | OAuth read-only. Daily batch. Pre-meeting prep. |
| **linkedin** | every 6mo | medium | Manual data export ZIP, parsed by script. |
| **imessage** | when needed | medium | Local SQLite read of `chat.db`. No cloud. |
| **whatsapp** | when needed | low | Periodic chat exports per conversation. |
| **telegram** | when needed | low | Bot/Telethon API. |
| **signal** | when needed | low | Local DB read. |
| **sms / mms** | nice-to-have | low | macOS handoff via iMessage already covers most. |
| **zoom / gmeet** | covered by granola | n/a | Granola records these. |
| **teams** | if your org uses it | low | TBD. |

## Knowledge work + code

| source | when | priority | notes |
|---|---|---|---|
| **repos** (git activity) | next | high | `gh` CLI + per-repo `git log` rollup → `data/repos/INBOX.md` |
| **github** (issues, PRs, notifications) | soon | medium | `gh` API. PR review state, issue mentions. |
| **jira** | soon | medium | REST API. Configure project key in your brain. |
| **notion** | maybe | low | API export. |
| **google docs / drive** | soon | medium | OAuth. Doc edits, comment mentions. |
| **confluence** (if your org uses) | maybe | low | REST API. |
| **figma** | maybe | low | Design comments and approvals. |

## Financial

| source | when | priority | notes |
|---|---|---|---|
| **bank accounts** (Plaid) | someday | medium | Aggregate balances, transactions. Privacy-sensitive. |
| **credit cards** | someday | medium | Same as banks. |
| **investments** (Schwab, Fidelity, Coinbase) | someday | medium | Holdings + dividends. |
| **expense apps** (Ramp, Brex if used) | someday | low | Receipts and categorization. |
| **personal venture P&L** | someday | medium | aggregate revenue/cost across personal projects. |
| **invoices** (Stripe, etc.) | someday | low | Per-product revenue ledgers. |

## Health + body

| source | when | priority | notes |
|---|---|---|---|
| **apple health** | someday | medium | Steps, HR, sleep. Local export. |
| **whoop / oura** | someday | medium | Sleep + recovery. API. |
| **strava** | someday | low | Workouts, routes. API. |
| **myfitnesspal / cronometer** | someday | low | Diet logs. |
| **continuous glucose monitor** | someday | low | If used. |
| **blood markers / labs** | someday | medium | Annual physical results. PDF parse. |
| **mental / mood journal** | someday | low | If kept. |

## Family

| source | when | priority | notes |
|---|---|---|---|
| **family milestones** | someday | medium | Calendar + photos + per-child agent logs. |
| **younger child milestones** | someday | medium | Same. |
| **spouse calendar coordination** | someday | low | Shared calendar parse. |

## Media + reading

| source | when | priority | notes |
|---|---|---|---|
| **kindle / readwise** | someday | medium | Highlights. Readwise has clean export. |
| **pocket / instapaper / matter** | someday | low | Read-later articles. |
| **podcast transcripts** | someday | low | Snipd / Pocket Casts highlights. |
| **substack / newsletters** | someday | low | Email-based, falls under gmail filter. |
| **youtube watch history** | someday | low | Google Takeout. |

## Social / personal brand

| source | when | priority | notes |
|---|---|---|---|
| **twitter / X archive** | someday | medium | Periodic export. Posts + DMs. |
| **threads / mastodon / bluesky** | someday | low | Whichever the user actually uses. |
| **personal blog posts** | someday | low | If the user starts one. |

## Travel + location

| source | when | priority | notes |
|---|---|---|---|
| **tripit** | someday | low | Itineraries. |
| **flight bookings (gmail-derived)** | someday | low | Falls under gmail. |
| **google location history** | someday | low | Privacy-heavy. |

## Personal capture

| source | when | priority | notes |
|---|---|---|---|
| **voice memos** (iPhone → Whisper) | next | high | iPhone Shortcut → Mac Mini endpoint → transcript. |
| **photos** (with on-device AI tags) | someday | low | Apple Photos export + face/location metadata. |
| **smart home** (HomeKit) | someday | low | Activity patterns. |
| **handwritten notes** (scanned + OCR) | someday | low | Optional. |

## Career / professional

| source | when | priority | notes |
|---|---|---|---|
| **linkedin DMs / connections** | covered above | medium | LinkedIn export. |
| **recruiter outreach** (gmail-tagged) | covered above | medium | Email filter. |
| **interview notes** | when relevant | low | Manual `/brain save`. |
| **references / testimonials** | when relevant | low | Manual. |
| **board materials** | when relevant | medium | Periodic, sensitive. Treat carefully. |

## News / strategic intelligence

| source | when | priority | notes |
|---|---|---|---|
| **AI Daily Brief** (NLW) | someday | medium | Subscribe via RSS, summarize daily. |
| **Stratechery / Ben Thompson** | someday | medium | Email-based, gmail filter. |
| **industry pubs** (Food, AI, Enterprise) | someday | low | RSS aggregation. |

## Legal / sensitive

| source | when | priority | notes |
|---|---|---|---|
| **contracts / NDAs** | special | high (when needed) | Encrypted at rest. Do NOT mirror to brain/raw.md. |
| **legal correspondence** | special | high (when needed) | Same. |
| **medical records** | special | high (when needed) | Same. |

These get a separate `data/_sensitive/` folder with stricter access (gitignored, optionally encrypted via age or git-crypt).

---

## Adding any of these

Follow `code/sources/README.md`. The recipe is the same regardless of source. Three steps: copy `_TEMPLATE/`, fill in `ingest.md` + `distill.md`, wire MCP / cron / manual. Done.
