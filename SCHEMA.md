# SCHEMA — semantic vocabulary

Controlled vocabulary for fields agents use to navigate the brain. Adopted gradually: new captures use these values; old entries don't need migration.

Inspired by Tolaria's `docs/ABSTRACTIONS.md`. The point: an agent can answer "show me everything captured from Slack with high confidence in the last week" by filtering on these fields, no prose interpretation needed.

---

## Fields

### `status:` — capture lifecycle

| Value | Meaning |
|---|---|
| `inbox` | Just landed in `data/<source>/INBOX.md`, not yet distilled |
| `indexed` | Distilled into the right `brain/<category>.md`, mirrored to `raw.md` |
| `synthesized` | Promoted into a refined principle / decision / ADR (compaction step) |
| `archived` | Moved to `brain/archive/`, no longer load-bearing for current work |

### `source:` — origin of a captured entry

| Value | Meaning |
|---|---|
| `claude` | Captured from a Claude Code session via Stop hook |
| `slack` | Slack workspace (sub-tagged `slack:work`, `slack:personal`, etc.) |
| `granola` | Granola.ai meeting transcript |
| `repos` | Git repository activity (commit, branch, PR) |
| `gmail` | Gmail thread |
| `gcal` | Google Calendar event |
| `linkedin` | LinkedIn 6-month export (DMs, connections, invitations) |
| `imessage` | iMessage `chat.db` extract |
| `whatsapp` | WhatsApp chat export |
| `voice` | iPhone voice memo via Whisper |
| `manual` | `/brain-save` direct entry |

### `category:` — destination brain file

| Value | Lands in |
|---|---|
| `self` | `brain/self.md` |
| `goals` | `brain/goals.md` |
| `projects` | `brain/projects.md` |
| `people` | `brain/people.md` and `brain/people/<slug>.md` |
| `learnings` | `brain/learnings.md` |
| `decisions` | `brain/decisions.md` |
| `repos` | `brain/repos.md` |
| `interactions` | `brain/interactions.md` (always shell-append) |
| `raw` | `brain/raw.md` (cross-source mirror, always) |

### `confidence:` — how sure the capture is

| Value | Meaning |
|---|---|
| `high` | the user said it explicitly or the source is unambiguous |
| `medium` | Reasonable inference from one source |
| `low` | Speculation; flag for confirmation on next interaction |

Distillation drops `low` confidence captures from `brain/` and only keeps them in `raw.md` and source INBOX.

### `sensitivity:` — privacy level

| Value | Meaning |
|---|---|
| `public` | OK to share, link to in marketing, post on LinkedIn |
| `personal` | Default. Stays in private repo. |
| `confidential` | Business-sensitive (board materials, customer data). Don't paste to third-party LLMs without explicit user authorization. |
| `sensitive` | Legal/medical/contracts. Lives in `data/_sensitive/` (gitignored). NEVER mirror to `brain/raw.md`. |

---

## Format conventions

### Front-matter on captured entries

When the Stop hook or `/brain-save` writes a categorized entry, prefix the markdown block with a small fenced metadata block (optional but encouraged):

```yaml
---
status: indexed
source: claude
category: decisions
confidence: high
sensitivity: personal
---
```

For raw firehose entries (`raw.md`, `interactions.md`, `data/<source>/INBOX.md`), the date+category header is sufficient — no YAML overhead per entry.

### Tag any unusual sensitivity in the header

If an entry is `confidential` or `sensitive`, the heading must include the tag:

```
### 2026-04-26 — decisions — [confidential] enterprise contract reframing
```

Distillation routines check for `[confidential]` or `[sensitive]` and route accordingly (the latter goes to `data/_sensitive/` only, never to `brain/`).

---

## Adoption

- New captures (Stop hook, `/brain-save`, source distillers): use these fields starting now.
- Old captures: no migration required. They predate the schema and remain valid.
- `/brain-evolve`: when proposing edits to skill protocols, reference these field names. Suggest enforcement only after 2-3 weeks of voluntary adoption.

## Why this and not Tolaria's full schema

Tolaria's schema is rich because Tolaria is a UI app with type-driven rendering. nanobrain only needs enough vocabulary to support querying ("show me high-confidence decisions from Slack last quarter"). Keep this lean. Add fields only when an actual query needs them.
