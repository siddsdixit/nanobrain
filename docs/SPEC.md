# SPEC v1.0 — multi-source ingest, multi-axis tagging, MCP-aware onboarding

> **Note:** This document describes the v1.0 design. The shipped v2.0 simplified to **two contexts** (work / personal) and dropped sensitivity / ownership axes. See [adr/0001-v2-lean-design.md](adr/0001-v2-lean-design.md) for what changed.


**Status:** Engineering-ready, draft 1.
**Owner:** Sid Dixit ([siddsdixit](https://github.com/siddsdixit)).
**Source PRD:** `docs/PRD.md` (sections 6, 7, 8, 12, 13).
**Scope:** v1.0 milestone only. v0.x ships today. v1.5 (cross-tool, Linux) and v2.0 (graph, embeddings, restore) are out of scope here.
**Process:** Spec → Design → Architecture → Development Plan → Tested Deployed Code. This is the spec.

---

## 0. Summary

v1.0 ships:

1. Five new ingest sources: `gmail`, `gcal`, `gdrive`, `slack`, `ramp`.
2. Multi-axis tagging on every ingested entry: `context` (named), `sensitivity` (3 tiers), `ownership` (optional).
3. New skills: `/brain-doctor`, `/brain-init`, `/brain-ingest <source>`, `/brain-distill <source>`, `/brain-distill-all`, `/brain-restore`.
4. `brain/_contexts.yaml` as the single source of truth for context/sensitivity/ownership resolution.
5. Agent scope filters (`reads:` block) enforced at read time by the brain MCP server.
6. Per-source launchd plists.
7. Pre-commit mirror enforcement (S2a).

Story count: 27. Estimated LoC: ~2.5k bash + ~600 yaml + ~400 markdown protocol. No new daemons. No new languages.

---

## 1. Open product decisions (resolved here, awaiting confirmation)

| # | Question | Spec recommendation | Confirm? |
|---|---|---|---|
| O-1 | Ownership tier in v1.0? | Include as **optional, default-unset**. Resolver writes `ownership:` only when `_contexts.yaml` declares an owner for the resolved context. Solo users never see it. (Matches PRD §13.2; overrides simulation §3.4.) | yes |
| O-2 | Pre-commit mirror enforcement | Ship a git pre-commit hook in v1.0 that rejects any commit touching `brain/{self,goals,projects,people,learnings,decisions,repos}.md` without a corresponding append to `brain/raw.md` in the same commit. Bypass: `MIRROR_OK=1 git commit ...` for documented bulk rewrites. (PRD §13.4.) | yes |
| O-3 | Vendor-neutral distill runner | **Defer to v1.5.** v1.0 hard-codes `claude -p`. (PRD §13.3.) | yes |
| O-4 | Slack channel-level overrides | Ship `channel_overrides:` in `_contexts.yaml`. Resolver checks channel rule before workspace rule. (Sim P5.) | yes |
| O-5 | Drive folder-glob overrides | Ship `folder_overrides:` with glob match. (Sim P5.) | yes |
| O-6 | Gmail two-pass bootstrap | Pass 1: 9 days work-window for fast first impression. Pass 2 (background): 2y personal-window. Watermark advances per pass. | yes |
| O-7 | `/brain-restore` in v1.0 vs v2.0 | PRD §6 UC-8 marks it v1.0; PRD §12 v2.0 lists it. **Spec ships in v1.0** as a thin skill (no new code paths, just structured git operations). | yes |
| O-8 | Where does the MCP read-server live | Extends existing `code/mcp-server/` (already scaffolded). Ship new tool `read_brain_file` with scope enforcement. No separate process. | yes |
| O-9 | What happens when `_contexts.yaml` returns no match | Default to `(context: personal, sensitivity: private, ownership: unset)`. Log to stderr. Never block ingest. | yes |

---

## 2. Data model — entities and CRUD chains

### 2.1 `brain/_contexts.yaml`

Single source of truth for context resolution. User-edited via text editor. No GUI (refuse list §9.9).

**Schema (YAML):**

```yaml
version: 1
contexts:
  <name>:                       # key: arbitrary slug, lowercase, no spaces
    sensitivity_default: public | private | confidential
    ownership: mine | employer:<slug> | client:<slug>   # optional; omit for solo
    description: <free text>    # optional, for human reference

resolvers:
  gmail:
    - match: { domain: <regex> }
      context: <name>
    - match: { account: <email> }
      context: <name>
  gcal:
    - match: { calendar_id: <id> }
      context: <name>
  gdrive:
    folder_overrides:
      - match: { path_glob: "/Personal/sideproj-a/**" }
        context: <name>
      - match: { path_glob: "/<root>/**" }
        context: <name>
  slack:
    workspace:
      - match: { team_id: <id> }
        context: <name>
    channel_overrides:           # consulted BEFORE workspace
      - match: { team_id: <id>, channel_name: <regex> }
        context: <name>
  ramp:
    - match: { account: <id> }
      context: <name>
  repos:                         # already shipping; keep schema
    - match: { owner: <gh_login> }
      context: <name>

defaults:
  context: personal
  sensitivity: private
  ownership: unset
```

**Validation rules:**

- `version` required, integer.
- Every `context: <name>` referenced by any resolver MUST exist in `contexts:`.
- `sensitivity_default` ∈ {`public`, `private`, `confidential`}.
- `ownership` if present must match `mine` | `employer:.+` | `client:.+`.
- Duplicate keys forbidden (yaml-strict).
- File MUST end with newline.

**CRUD:**

| Op | Owner | Mechanism | Notes |
|---|---|---|---|
| Create | `/brain-init` (skill) | Iterative wizard; writes initial file | Idempotent; refuses overwrite if file exists |
| Read | resolvers (every ingest), `/brain` query, `/brain-doctor` | `yq` or shell parse | Cached for the duration of one ingest run |
| Update | user (text editor); `/brain-init --add-context <name>` (sub-mode) | Direct edit; wizard appends without rewriting existing entries | Validation runs on next ingest |
| Delete | user only (text editor) | Manual | Skill never deletes |

**Migration:** v0.x had no file. First `/brain-init` creates it. No legacy schema.

---

### 2.2 `data/<source>/INBOX.md`

Per-source firehose. Append-only. Never read in full (S2, S7).

**Entry format (v1.0, multi-axis):**

```
### YYYY-MM-DD HH:MM — <source>: <subject>
context: <name>
sensitivity: public | private | confidential
ownership: mine | employer:<slug> | client:<slug>      # line omitted when unset
source_id: <stable_id>                                  # message-id, event-id, file-id

<body, max 500 chars, truncated with "...">
```

**Validation:** `ingest.sh` runs `redact.sh` regex (S5/S21 secrets pattern) before append. If regex matches, the offending field is replaced with `[REDACTED]` and the count is logged to stderr.

**CRUD:**

| Op | Owner | Mechanism |
|---|---|---|
| Create (append) | `code/sources/<source>/ingest.sh` only | Shell `>>` |
| Read | distill (watermark-tail), `/brain-doctor` (last-line health check) | `awk` from `.distill_watermark`; never `cat` whole file |
| Update | none. Entries are immutable | n/a |
| Delete | none. Rotation moves to `INBOX-YYYY-MM.md` when >10MB | manual or sleep-cycle |

---

### 2.3 `data/<source>/.watermark` and `data/<source>/.distill_watermark`

**Schema:** single line, ISO 8601 timestamp `YYYY-MM-DDTHH:MM:SSZ`.

**`.watermark`** — last item the ingest script pulled (per source upstream timestamp).
**`.distill_watermark`** — last INBOX entry the distiller has processed (local capture timestamp).

**CRUD:**

| Op | Owner | Mechanism |
|---|---|---|
| Create | `ingest.sh` first run; `distill.md` first run | `echo > file` |
| Read | every ingest / distill | `cat` |
| Update | end of each successful run | atomic write via temp file + `mv` |
| Delete | never (forces full re-bootstrap) | n/a |

**Idempotency:** running twice within the same minute is safe. Watermark advances only on successful append.

---

### 2.4 Agent scope filter (`reads:` block in `code/agents/<slug>.md`)

Front-matter YAML in agent definition file. Read by brain MCP server before any tool call.

**Schema:**

```yaml
---
slug: <agent-slug>
role: <one-line description>
model: claude-opus | claude-sonnet | claude-haiku
tools: [Read, Grep, Glob]                   # standard CC tools
reads:
  paths:                                    # explicit allow-list
    - brain/projects.md
    - brain/people/<slug>.md
  context_in: [<name>, <name>]              # any-of match
  sensitivity_max: public | private | confidential
  ownership_in: [mine, client:<slug>]       # optional
writes:
  paths: []                                 # default empty; must be explicit
sensitivity: public | private | confidential   # the agent's own classification
---
```

**Operators:**

- `paths` — exact path or glob; `**` allowed.
- `context_in` — list, OR-match. Empty = all contexts allowed.
- `sensitivity_max` — single value, hierarchical. `private` allows `public` and `private`; `public` allows only `public`.
- `ownership_in` — list, OR-match. Empty = all ownerships allowed.

**Enforcement layer:** `code/mcp-server/index.js` exposes `read_brain_file(agent_slug, path)`. The server:

1. Reads `code/agents/<agent_slug>.md` front-matter.
2. Confirms `path` matches `reads.paths` (else `ERR_SCOPE_PATH`).
3. Reads file, parses entries.
4. Filters out any entry whose front-matter `context` ∉ `context_in`, `sensitivity` > `sensitivity_max`, or `ownership` ∉ `ownership_in`.
5. Returns the filtered content.

**CRUD:**

| Op | Owner |
|---|---|
| Create | `/brain-spawn` writes draft to `code/agents/_proposed/<slug>.md`; user `mv` activates (S22) |
| Read | brain MCP server on every read tool call |
| Update | user direct edit; `/brain-evolve` may propose in `_proposed/` |
| Delete | user only |

---

## 3. Skill API surface

All skills are markdown protocol files at `code/skills/<name>/SKILL.md`. Slash command invokes the skill; Claude Code reads protocol and executes.

### 3.1 `/brain-doctor`

**Inputs:** none.
**Files read:** `~/.claude/.mcp.json` (MCP server config), `brain/_contexts.yaml` (if present), `data/*/.watermark` (mtime check).
**Output:**

```
nanobrain doctor — 2026-04-27 18:42

MCPs detected:
  gmail       ✓ configured
  gcal        ✓ configured
  gdrive      ✗ not configured (skip)
  slack       ✓ configured
  ramp        ✗ not configured (skip)

Sources status:
  claude      last ingest 2m ago    INBOX 2.1MB  ✓
  repos       last ingest 14h ago   INBOX 0.4MB  ✓
  granola     last ingest 3d ago    INBOX 0.1MB  ⚠ stale
  gmail       not yet bootstrapped              ✗
  gcal        not yet bootstrapped              ✗

_contexts.yaml: missing  → run /brain-init
Pre-commit hook: installed  ✓
BRAIN_HASH:   matches      ✓

Next: /brain-init  (configure contexts and bootstrap detected sources)
```

**Exit codes:** 0 on success (even with warnings), 1 only on read error.
**Idempotency:** read-only.
**Error modes:** missing `~/.claude/.mcp.json` → report "no MCPs configured" and continue.

---

### 3.2 `/brain-init`

**Inputs:** interactive prompts; honors auto mode if user says `non-interactive` (uses defaults).
**Files written:** `brain/_contexts.yaml` (create or `--add-context` append), per-source `.watermark` initial values.
**Behavior:**

1. Run `/brain-doctor` checks internally.
2. If `_contexts.yaml` missing, prompt single-account-detected fast path: "Looks like one Gmail, one Slack workspace. Tag everything `personal`? [Y/n]" (sim P1 fix).
3. Otherwise iterative loop:
   - "Add a context. Name? (e.g. work, client-acme)"
   - "What sensitivity default? [public / private / confidential]"
   - "Ownership? [mine / employer:<slug> / client:<slug> / skip]"
   - "Add resolver — gmail domain? gmail account? gcal calendar id? gdrive folder glob? slack team id? slack channels?"
   - "Add another context? [y/N]"
4. Write `_contexts.yaml`.
5. For each detected source with `.watermark` missing, offer to bootstrap (`/brain-ingest <source> --bootstrap`).

**Output:** path to written file, count of contexts, count of resolvers per source.
**Exit codes:** 0 success, 2 user abort, 1 write failure.
**Idempotency:** if `_contexts.yaml` exists, default behavior is `--add-context` mode. Refuses to overwrite without `--force`.

---

### 3.3 `/brain-ingest <source>`

**Inputs:** `<source>` ∈ {claude, repos, granola, gmail, gcal, gdrive, slack, ramp}. Optional `--bootstrap` flag.
**Files read:** `data/<source>/.watermark`, `brain/_contexts.yaml`.
**Files written:** `data/<source>/INBOX.md` (append), `data/<source>/.watermark`.
**Behavior:** thin shell wrapper that delegates to `code/sources/<source>/ingest.sh` with env vars. Captures stdout, ensures lock file (`.ingest.lock`) prevents concurrent runs (S28 determinism).
**Output:** one line per source: `ingest <source>: N appended, watermark <ts>`.
**Exit codes:** 0 success or no new items, 2 lock held, 3 missing MCP, 4 auth expired.
**Error modes:**

- Missing MCP → exit 3, message: `run /brain-doctor`.
- Auth expired → exit 4, message: `refresh <source> credentials`.
- Source unreachable → 3 retries with backoff; exit 0 silently if still failing (don't break pipeline).

**Idempotency:** running twice in a row produces 0 net new entries (watermark advanced).

---

### 3.4 `/brain-distill <source>`

**Inputs:** `<source>`.
**Files read:** `data/<source>/INBOX.md` from `.distill_watermark` to EOF (awk-tail), `data/<source>/distill.md` (protocol).
**Files written:** `brain/{learnings,decisions,projects,people,interactions,...}.md` (append per S2a), `brain/raw.md` (mirror), `data/<source>/.distill_watermark`.
**Behavior:** invokes `claude -p` with `distill.md` as system prompt and the INBOX delta as input. Output is parsed as a series of routed entries.
**Output:** `distill <source>: N entries → {decisions: x, learnings: y, projects: z, ...}`.
**Exit codes:** 0 success, 2 lock held, 5 distill malformed (entries kept in INBOX, watermark NOT advanced).
**Idempotency:** watermark advances only after all routes succeed AND mirror succeeds. Failure leaves INBOX in known state.

---

### 3.5 `/brain-distill-all`

Runs `/brain-distill` for every source with new INBOX content. Used by nightly launchd. Exits non-zero if ANY source distill fails (per-source error swallowed for the cron path; manual run surfaces).

---

### 3.6 `/brain-restore`

**Inputs:** none (interactive).
**Files read:** `git log`, `git tag`.
**Files written:** none directly. Creates a branch `restore/<timestamp>` and checks out the chosen state into it.
**Behavior:**

1. List last 20 capture commits (`git log --grep '^capture:' -20`) plus all tags matching `pre-evolve-*`.
2. Prompt user to pick.
3. `git checkout -b restore/$(date +%s) <sha>`. Never `reset --hard`.
4. Print: "Restored to branch `restore/<ts>`. Inspect, then `git checkout main && git merge restore/<ts>` to apply."

**Exit codes:** 0 success, 2 user abort.
**Idempotency:** safe to run any number of times. Each run creates a new branch.

---

## 4. Resolver contract

Every source has `code/sources/<source>/context_resolver.sh`. Pure function:

**Input (positional args):**

```
$1 = source key (gmail|gcal|...)
$2 = resolver-specific lookup key (e.g. sender-domain for gmail, calendar-id for gcal)
$3 = optional secondary key (e.g. slack channel name)
```

**Output (stdout, single line, tab-separated):**

```
<context>\t<sensitivity>\t<ownership>
```

Example: `work\tconfidential\temployer:bigco`. When ownership unset: `work\tconfidential\tunset`.

**Default behavior (no match):**

```
personal\tprivate\tunset
```

…and log `[resolver:<source>] no match for <key>` to stderr (visible in launchd logs but not in INBOX).

**Determinism:** for the same `_contexts.yaml` + same input → same output. Cached per ingest run via in-memory associative array.

**Implementation:** thin bash; reads `brain/_contexts.yaml` via `yq` (declared in `requires.yaml`).

**Test harness:** `code/sources/<source>/test_resolver.sh` — table-driven cases (input → expected output). Runs in CI (`bash test_*.sh`).

---

## 5. Per-source ingest specifications

All five sources follow `code/sources/_TEMPLATE/` structure: `ingest.sh`, `ingest.md`, `distill.md`, `requires.yaml`, `context_resolver.sh`, `test_resolver.sh`.

### 5.1 gmail

**MCP required:** `mcp__gmail__*` (search, get_thread, list_messages).
**`requires.yaml`:**

```yaml
mcp: gmail
binaries: [yq, jq]
```

**Bootstrap (two-pass):**

- Pass 1 (work window): query last 9 days across all labels. Watermark = now() − 9d on entry, advances on success.
- Pass 2 (personal window, async): if `_contexts.yaml` declares any context with `sensitivity_default: private`, bootstrap last 2 years for that context's resolved gmail domain/account. Runs in background; writes to same INBOX with timestamps preserved (resolver still runs per message).

**Incremental cadence:** every 4h via launchd plist `com.nanobrain.ingest.gmail.plist`. Pulls messages with `internalDate > .watermark`.

**Resolver inputs:** `(source=gmail, key=sender_domain, key2=recipient_account)`. Returns `(context, sensitivity, ownership)`.

**INBOX entry format:**

```
### 2026-04-27 09:13 — gmail: Re: investor intro
context: side-proj-a
sensitivity: confidential
ownership: mine
source_id: <Message-ID@mail.gmail.com>

From: vc@firm.com → maya@gmail.com
Subject: Re: investor intro
Body (excerpt, 500c max): ...
```

**Distill routing rules:** investor/customer/board emails → `decisions.md` or `interactions.md`; receipts/notifications → drop (don't distill, INBOX-only); personal correspondence → `interactions.md`. Confidence scoring per `STOP.md`.

**Privacy filter:** S21 regex applied to subject + body before append.

---

### 5.2 gcal

**MCP required:** `mcp__gcal__*`.
**`requires.yaml`:** `mcp: gcal`.
**Bootstrap:** last 9 days + next 30 days, all calendars the user owns or accepts.
**Incremental cadence:** daily 06:00 via `com.nanobrain.ingest.gcal.plist`. Pulls events with `updated > .watermark`.
**Resolver inputs:** `(source=gcal, key=calendar_id)`.
**INBOX entry format:**

```
### 2026-04-28 14:00 — gcal: Board call (side-proj-a)
context: side-proj-a
sensitivity: confidential
source_id: <event-id>

Calendar: sid@gmail.com
Attendees: 4 (board-member-1@..., ...)
Description excerpt: ...
```

**Distill routing:** future meetings → `interactions.md` with date forward-reference; past meetings with notes → `decisions.md` if action items detected, else `interactions.md`.

---

### 5.3 gdrive

**MCP required:** `mcp__gdrive__*`.
**`requires.yaml`:** `mcp: gdrive`.
**Bootstrap:** files modified in last 30 days, capped at 500 entries.
**Incremental cadence:** daily 07:00. Pulls files with `modifiedTime > .watermark`.
**Resolver inputs:** `(source=gdrive, key=folder_path)`. Folder-glob match per `_contexts.yaml`.
**INBOX entry format:**

```
### 2026-04-27 11:30 — gdrive: pricing.md (modified)
context: work
sensitivity: confidential
ownership: employer:bigco
source_id: <file-id>

Path: /BigCo/Strategy/pricing.md
Mime: text/markdown
Modified by: sid@bigco.com
First 500 chars of diff or content snippet: ...
```

**Distill routing:** product docs → `projects.md`; meeting notes → `interactions.md`; legal/contracts → drop to `data/_sensitive/` if classified `sensitive` (S9, S18).

---

### 5.4 slack

**MCP required:** `mcp__slack__*`.
**`requires.yaml`:** `mcp: slack`.
**Bootstrap:** last 9 days of DMs and channels the user is in.
**Incremental cadence:** every 2h via `com.nanobrain.ingest.slack.plist`. Pulls messages with `ts > .watermark`.
**Resolver inputs:** `(source=slack, team_id, channel_name)`. Channel rule consulted before workspace rule (sim P5 fix).
**INBOX entry format:**

```
### 2026-04-27 10:00 — slack: T_BIGCO #budget-2026
context: work
sensitivity: confidential
ownership: employer:bigco
source_id: <ts>.<channel>

Channel: #budget-2026
From: cfo@bigco
Excerpt (500c): ...
```

**Distill routing:** DMs from coworkers → `interactions.md` + `people/<slug>.md`; channel announcements → `decisions.md` if "decision" keyword; jokes/casual → drop.

---

### 5.5 ramp

**MCP required:** `mcp__ramp__*` (or HTTP API if no MCP).
**`requires.yaml`:** `mcp: ramp` OR `env: RAMP_API_KEY`.
**Bootstrap:** last 90 days of transactions.
**Incremental cadence:** weekly Mon 06:00 via `com.nanobrain.ingest.ramp.plist`.
**Resolver inputs:** `(source=ramp, account_id)`. Always work-context for the typical case (Jordan, both have ramp at employer only).
**INBOX entry format:**

```
### 2026-04-27 12:30 — ramp: Lunch — Acme Cafe — $42.50
context: work
sensitivity: confidential
ownership: employer:bigco
source_id: <txn-id>

Vendor: Acme Cafe
Amount: $42.50
Category: Meals
Memo: Team lunch with eng leads
```

**Distill routing:** transactions → drop from `brain/` (financial-record, not signal). INBOX retains them. Aggregates only surface in `learnings.md` if pattern detected (e.g. "spending above policy three weeks running"). Per S3a.

---

## 6. Stories

ID range: NBN-101 through NBN-127. S/M/L = small (≤2h), medium (2-6h), large (6h+).

### Phase A — Foundations (no source code yet)

#### NBN-101 — `_contexts.yaml` schema + validator
**As a** brain operator
**I want** a schema-validated context file
**So that** resolvers behave deterministically across sources.

**Acceptance:**
- Given a valid `_contexts.yaml`, When `code/lib/validate_contexts.sh` runs, Then exit 0 and prints `OK: N contexts, M resolvers`.
- Given an unknown context referenced by a resolver, When validator runs, Then exit 1 with line number.
- Given duplicate context keys, When validator runs, Then exit 1.

**Files:** create `code/lib/validate_contexts.sh`, `examples/_contexts.example.yaml`, `tests/test_validate_contexts.sh`.
**Deps:** none.
**Complexity:** S.

#### NBN-102 — `redact.sh` extension for multi-axis fields
**As a** source ingestor
**I want** secrets stripped before any append
**So that** S5/S21 hold under richer entry headers.

**Acceptance:**
- Given a string containing `sk-abc123`, When `redact.sh` filters it, Then output replaces with `[REDACTED]` and prints count to stderr.
- Given a multiline entry with secret in body and clean header, Then header preserved, body redacted.

**Files:** modify `code/lib/redact.sh`; add `tests/test_redact.sh` cases.
**Complexity:** S.

#### NBN-103 — Resolver library `code/lib/resolve_context.sh`
**As a** source ingestor
**I want** a shared resolver helper
**So that** every source resolves the same way.

**Acceptance:**
- Given source=gmail, key=`bigco.com`, with `_contexts.yaml` mapping that domain to `work`, When called, Then stdout is `work\tconfidential\temployer:bigco`.
- Given no match, Then stdout is `personal\tprivate\tunset` and stderr logs "no match".
- Given missing `_contexts.yaml`, Then stdout is the default tuple and stderr logs once.

**Files:** create `code/lib/resolve_context.sh`, `tests/test_resolve_context.sh`.
**Deps:** NBN-101.
**Complexity:** M.

#### NBN-104 — INBOX entry writer `code/lib/write_inbox.sh`
**As a** source ingestor
**I want** a shared INBOX-append helper
**So that** entry formatting is identical and S2 holds.

**Acceptance:**
- Given a structured entry, When called, Then a single `>>` append happens with the v1.0 multi-axis header.
- Given a body containing a secret, Then `redact.sh` runs first.
- Given two parallel calls, Then `flock` serializes (no interleaving).

**Files:** create `code/lib/write_inbox.sh`, `tests/test_write_inbox.sh`.
**Deps:** NBN-102.
**Complexity:** S.

---

### Phase B — Skills

#### NBN-105 — `/brain-doctor` skill
See §3.1.

**Acceptance:**
- Given `~/.claude/.mcp.json` declares gmail and slack only, Then output lists both ✓ and the others ✗.
- Given `data/repos/INBOX.md` mtime >24h, Then `repos` shows ⚠ stale.
- Given `_contexts.yaml` missing, Then "Next:" line suggests `/brain-init`.

**Files:** `code/skills/brain-doctor/SKILL.md`, `code/skills/brain-doctor/check.sh`.
**Complexity:** M.

#### NBN-106 — `/brain-init` skill
See §3.2.

**Acceptance:**
- Given fresh install, no `_contexts.yaml`, single Gmail single Slack detected, When run, Then offers `personal`-only fast path; one `[Y]` accepts it; file written with one context.
- Given multi-context user, When loop runs, Then each "add another?" cycle appends to file without rewriting prior entries.
- Given `_contexts.yaml` exists, When run without `--force`, Then prompts `--add-context` mode; never overwrites.

**Files:** `code/skills/brain-init/SKILL.md`, `code/skills/brain-init/wizard.sh`.
**Deps:** NBN-105, NBN-101.
**Complexity:** L.

#### NBN-107 — `/brain-ingest <source>` dispatcher
See §3.3.

**Acceptance:**
- Given valid source, When invoked, Then dispatches to `code/sources/<source>/ingest.sh` with `BRAIN_DIR` env.
- Given concurrent invocation, Then second instance exits 2 within 1s (lock).
- Given `<source>` not in allow-list, Then exit 1 with message.

**Files:** `code/skills/brain-ingest/SKILL.md`, `code/skills/brain-ingest/dispatch.sh`.
**Complexity:** S.

#### NBN-108 — `/brain-distill <source>` dispatcher
See §3.4. Same shape as NBN-107 but invokes `claude -p` with `distill.md`.

**Acceptance:**
- Given INBOX has 5 new entries, When run, Then `claude -p` is invoked with delta as input, distillation routes to brain files, raw.md mirrors all 5, watermark advances.
- Given malformed distill output, Then watermark NOT advanced; exit 5.

**Files:** `code/skills/brain-distill/SKILL.md`, `code/skills/brain-distill/dispatch.sh`.
**Complexity:** M.

#### NBN-109 — `/brain-distill-all`
See §3.5.

**Files:** `code/skills/brain-distill-all/SKILL.md`, `code/skills/brain-distill-all/run.sh`.
**Deps:** NBN-108.
**Complexity:** S.

#### NBN-110 — `/brain-restore`
See §3.6.

**Acceptance:**
- Given history of 30 capture commits, When run, Then prompt lists last 20 + tags.
- Given user picks a sha, Then `git checkout -b restore/<ts> <sha>` runs; main untouched; never `reset --hard`.
- Given user aborts, Then no branch created, exit 2.

**Files:** `code/skills/brain-restore/SKILL.md`, `code/skills/brain-restore/restore.sh`.
**Complexity:** M.

---

### Phase C — Source ingestors (one story each, parallelizable after Phase A/B)

Each story has the same shape: `ingest.sh`, `ingest.md`, `distill.md`, `requires.yaml`, `context_resolver.sh`, `test_resolver.sh`, launchd plist. Acceptance tests below are illustrative; full per-source spec in §5.

#### NBN-111 — gmail source
**As a** user with Gmail MCP
**I want** Gmail messages ingested with multi-axis tags
**So that** investor/customer/personal correspondence shows up in the brain.

**Acceptance:**
- Given Gmail MCP configured + `_contexts.yaml` mapping `bigco.com` → `work/confidential/employer:bigco`, When `/brain-ingest gmail --bootstrap` runs, Then INBOX gains last-9d messages tagged correctly.
- Given a secret in a message body, Then INBOX shows `[REDACTED]` for that span.
- Given Pass 2 (personal 2y) running in background, Then bootstrap exit doesn't block on it; eventual messages show up with original timestamps.

**Files:** `code/sources/gmail/{ingest.sh, ingest.md, distill.md, requires.yaml, context_resolver.sh, test_resolver.sh}`, `code/cron/com.nanobrain.ingest.gmail.plist`.
**Deps:** NBN-103, NBN-104.
**Complexity:** L.

#### NBN-112 — gcal source
See §5.2. Files: `code/sources/gcal/*`, `code/cron/com.nanobrain.ingest.gcal.plist`.
**Complexity:** M.

#### NBN-113 — gdrive source
See §5.3. Files: `code/sources/gdrive/*`, `code/cron/com.nanobrain.ingest.gdrive.plist`.
**Complexity:** L.

#### NBN-114 — slack source
See §5.4. Honors channel-level overrides (sim P5). Files: `code/sources/slack/*`, `code/cron/com.nanobrain.ingest.slack.plist`.
**Complexity:** L.

#### NBN-115 — ramp source
See §5.5. Files: `code/sources/ramp/*`, `code/cron/com.nanobrain.ingest.ramp.plist`.
**Complexity:** M.

---

### Phase D — Agent scope enforcement

#### NBN-116 — Agent template extension for `reads:` filters
**As an** agent author
**I want** the template to declare context/sensitivity/ownership filters
**So that** spawn produces scope-correct agents.

**Acceptance:**
- Given `code/agents/_TEMPLATE.md` updated with new front-matter, When `/brain-spawn` reads it, Then the wizard prompts for `context_in`, `sensitivity_max`, `ownership_in`.
- Given an agent missing required `reads:`, When validation runs, Then refuses to symlink.

**Files:** modify `code/agents/_TEMPLATE.md`, `code/skills/brain-spawn/spawn.sh`.
**Complexity:** S.

#### NBN-117 — Brain MCP server `read_brain_file` tool
**As an** agent invoking a Read tool through the brain MCP
**I want** the server to filter content by my declared scope
**So that** I cannot exfiltrate out-of-scope material even if I try.

**Acceptance:**
- Given agent A with `context_in: [side-proj-a]` and `sensitivity_max: private`, When A calls `read_brain_file` on `brain/projects.md`, Then returned content includes only entries whose front-matter matches.
- Given a path not in `reads.paths`, Then server returns `ERR_SCOPE_PATH`.
- Given a `confidential` entry in `projects.md`, When A reads, Then that entry is omitted (sensitivity ceiling).

**Files:** modify `code/mcp-server/index.js`, `code/mcp-server/lib/scope.js` (new), `tests/mcp/test_scope.sh`.
**Deps:** NBN-116.
**Complexity:** L.

#### NBN-118 — Leak-prevention test suite
**As a** maintainer
**I want** automated tests proving the filter works
**So that** regressions are caught.

**Acceptance:**
- Test fixture: a fake brain with 4 entries spanning 2 contexts × 2 sensitivities.
- For each of 6 filter combinations, the test asserts exact returned entries.
- CI fails if any filter combination leaks.

**Files:** `tests/mcp/fixtures/brain/`, `tests/mcp/test_leak.sh`.
**Deps:** NBN-117.
**Complexity:** M.

---

### Phase E — Pre-commit + housekeeping

#### NBN-119 — Pre-commit mirror enforcement hook
See O-2.

**Acceptance:**
- Given staged change to `brain/decisions.md` without a corresponding `brain/raw.md` change, When `git commit` runs, Then the hook rejects with non-zero exit and a clear message.
- Given both files staged, Then commit proceeds.
- Given env `MIRROR_OK=1`, Then hook bypassed.

**Files:** `code/hooks/pre-commit-mirror.sh`, `install.sh` symlinks it into `.git/hooks/pre-commit`.
**Complexity:** S.

#### NBN-120 — INBOX rotation helper
**As a** maintainer
**I want** rotation when INBOX >10MB
**So that** firehoses don't bloat git.

**Acceptance:**
- Given an INBOX at 10.5MB, When `code/lib/rotate_inbox.sh data/<source>` runs, Then file moves to `INBOX-YYYY-MM.md` and a fresh `INBOX.md` is created.
- Watermark unaffected.

**Files:** `code/lib/rotate_inbox.sh`, `tests/test_rotate.sh`.
**Complexity:** S.

#### NBN-121 — launchd plist installer
**As an** installer
**I want** all per-source plists wired by `install.sh`
**So that** scheduled ingest works after install without manual steps.

**Acceptance:**
- Given the 5 new plists in `code/cron/`, When `install.sh` runs, Then `launchctl load` succeeds for each, and `launchctl list | grep nanobrain` shows all.
- Re-running `install.sh` is idempotent (reload not duplicate-load).

**Files:** modify `install.sh`; new plists per Phase C stories.
**Complexity:** S.

---

### Phase F — Migration / docs

#### NBN-122 — Migrate existing claude/repos/granola entries to multi-axis schema
**As a** v0.x user upgrading
**I want** new entries to carry multi-axis tags
**So that** queries and agents work uniformly.

**Acceptance:**
- Old INBOX entries (no `context:` line) are read with default `(personal/private/unset)` by resolvers.
- New entries written by upgraded ingestors include the full header.
- No retroactive rewriting of historical INBOX (S24 backwards-compat).

**Files:** modify `code/sources/{claude,repos,granola}/ingest.sh` to use NBN-104.
**Complexity:** M.

#### NBN-123 — Update `STOP.md` to consume multi-axis headers
**As a** distiller
**I want** to read entry tags
**So that** routing respects sensitivity (e.g. confidential never flows to public-tagged brain entries).

**Acceptance:**
- Given an INBOX entry with `sensitivity: confidential`, When distilled, Then resulting brain entry inherits the tag in front-matter.
- Given `sensitivity: sensitive` (legal/medical), Then routed only to `data/_sensitive/`, never to `brain/`.

**Files:** modify `code/hooks/STOP.md`.
**Complexity:** M.

#### NBN-124 — README rewrite around leak-and-capture frame
**As a** new visitor on GitHub
**I want** the README to land the wedge in 30 seconds
**So that** I install.

**Acceptance:** README includes the "5-minute oh moment" path verbatim from PRD §5; comparison table from §3; install one-liner.

**Files:** `README.md`.
**Complexity:** S.

#### NBN-125 — `examples/starter-brain` updated for v1.0
**As a** new user cloning the example
**I want** a working `_contexts.yaml`
**So that** I can run `/brain-doctor` and see green.

**Files:** `examples/starter-brain/_contexts.yaml`, `examples/starter-brain/data/<source>/.gitkeep`.
**Complexity:** S.

#### NBN-126 — ADR-0017 multi-axis tagging decision
**As a** maintainer
**I want** the ADR recording why we have 3 axes (and dropped them in the simulation, then re-added)
**So that** future evolve runs don't try to "simplify" them away.

**Files:** `docs/adr/0017-multi-axis-tagging.md`.
**Complexity:** S.

#### NBN-127 — End-to-end smoke test
**As a** maintainer
**I want** a single bash script that bootstraps a fake brain, ingests, distills, and asserts
**So that** any contributor can confirm the pipeline before PR.

**Acceptance:**
- Script seeds a temp `BRAIN_DIR`, runs `/brain-init` non-interactively (env-driven), runs `/brain-ingest claude` with a fixture transcript, runs `/brain-distill claude`, asserts `brain/raw.md` has the expected mirror entry.
- Runs in <60s on dev hardware.

**Files:** `tests/e2e/smoke.sh`, `tests/e2e/fixtures/`.
**Complexity:** M.

---

## 7. Test plan

### 7.1 Unit (per story)

Each `code/lib/*.sh` and each `code/sources/<source>/context_resolver.sh` ships with `tests/test_*.sh`. Pattern:

```bash
test_resolves_work_for_bigco_domain() {
  RESULT=$(BRAIN_DIR=$FIXTURE bash code/lib/resolve_context.sh gmail bigco.com)
  [ "$RESULT" = "work	confidential	employer:bigco" ] || fail
}
```

Run via `bash tests/run_all.sh`. Required green for PR merge.

### 7.2 Integration (per source)

`tests/integration/<source>.sh`:
1. Mocks the MCP via `tests/mocks/mcp_<source>.sh` (returns canned JSON).
2. Runs full ingest + distill cycle against a fixture `_contexts.yaml`.
3. Asserts INBOX entries, watermark advance, raw.md mirror, brain file routes.

### 7.3 Acceptance (per PRD success metric)

| PRD metric | Test |
|---|---|
| §10 capture commit rate ≥80% | `tests/acceptance/capture_rate.sh` runs 10 mocked sessions, expects ≥8 commits |
| §10 0 secret leaks | `tests/acceptance/secret_leak.sh` injects 20 secrets across all sources, asserts 0 land in INBOX or brain |
| §10 time-to-magic-moment ≤5min | manual checklist: `tests/acceptance/MAGIC_MOMENT.md` |
| §10 restore success ≤10min | `tests/acceptance/restore.sh` corrupts a brain, runs `/brain-restore`, asserts recovery |

### 7.4 Leak prevention (agent scope)

`tests/mcp/test_leak.sh` per NBN-118. Required green.

---

## 8. Dependency graph (build order)

```
NBN-101 ─┬─> NBN-103 ──> NBN-111..NBN-115 ─┐
NBN-102 ─┴─> NBN-104 ──> NBN-122           │
            │                              ├─> NBN-127 (smoke)
NBN-105 ────> NBN-106                      │
NBN-107 ──┬─> NBN-111..NBN-115 ────────────┤
NBN-108 ──┘                                │
NBN-109                                    │
NBN-110                                    │
NBN-116 ──> NBN-117 ──> NBN-118            │
NBN-119                                    │
NBN-120                                    │
NBN-121 (after all plists exist)           │
NBN-123 (parallel with sources)            │
NBN-124, NBN-125, NBN-126 (anytime)        │
```

Critical path: NBN-101 → NBN-103 → NBN-111 → NBN-127. Roughly 3-4 dev days end-to-end if sources are parallelized; 2 weeks calendar with one engineer.

---

## 9. Out of scope (do not build in v1.0)

- Cross-tool capture (cursor, aider, gemini-cli, codex). v1.5.
- Linux systemd timers. v1.5.
- Vendor-neutral distill runner. v1.5.
- Embeddings, vector search, graph queries beyond `_graph.md`. v2.0.
- Public agent registry. v2.0.
- Mobile, web UI, hosted version, multiplayer. Refuse list (PRD §9).
- Schema-validation linter beyond `validate_contexts.sh` for `_contexts.yaml`. PRD §9.7.
- GUI for `_contexts.yaml`. PRD §9.9.

---

## 10. Sign-off checklist

Before declaring v1.0 done:

- [ ] All 27 stories merged with green CI.
- [ ] `/brain-doctor` reports all 5 new sources ✓ on a real machine with MCPs configured.
- [ ] One full day of real ingest produces healthy INBOX entries with correct multi-axis tags across all 5 personas' resolver patterns (test on the author's brain).
- [ ] Leak test (NBN-118) green.
- [ ] Pre-commit hook rejects an intentional missing-mirror commit.
- [ ] `BRAIN_HASH.txt` regenerated after migration.
- [ ] ADR-0017 merged.
- [ ] README rewrite landed; `gh repo view` shows the new pitch.

---

## 11. References

- PRD: `docs/PRD.md`
- Architecture: `<repo>/docs/ARCHITECTURE.md` (note: framework repo path; mirror in private brain if missing)
- Schema: `<repo>/SCHEMA.md`
- Safety: `<repo>/code/SAFETY.md`
- Source template: `<repo>/code/sources/_TEMPLATE/`
- Reference impls: `<repo>/code/sources/{repos,granola}/`
- Persona simulation: `<archived persona simulation>`
