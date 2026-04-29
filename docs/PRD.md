# nanobrain — Product Requirements Document

> **Note:** This document describes the v1.0 design. The shipped v2.0 simplified to **two contexts** (work / personal) and dropped sensitivity / ownership axes. See [adr/0001-v2-lean-design.md](adr/0001-v2-lean-design.md) for what changed.


**Status:** Draft v0.1
**Last updated:** 2026-04-27
**Owner:** Sid Dixit ([siddsdixit](https://github.com/siddsdixit))
**Repo:** https://github.com/siddsdixit/nanobrain (MIT)

---

## 1. One-line pitch

**`.git` for your AI sessions.** Every AI coding session leaks context; nanobrain captures it into markdown in your own git repo so the next session, next tool, and next machine all start with what you taught the last one.

---

## 2. Problem

Developers using AI coding CLIs (Claude Code, Cursor, Aider, Gemini CLI, Codex CLI) explain the same architecture, decisions, and constraints to their AI partner over and over. Vendor "memory" features exist but are opaque, cloud-hosted, and locked to one vendor. Personal-knowledge tools (Obsidian, Logseq, Mem, Reflect, Notion AI) require human authorship or live in someone else's cloud. Nothing today is **agent-written, file-owned, and vendor-neutral at once**.

The gap: every developer who works with AI agents has a private context corpus living in their head, partially in their AI vendor's opaque memory, partially in scattered notes. None of it is portable, queryable, or trustworthy across tools and time.

---

## 3. Wedge

The combination of three properties, none of which competing products provide together:

| Property | Obsidian | Mem/Reflect | Vendor memory (Claude/Cursor) | nanobrain |
|---|---|---|---|---|
| Agent-written | ✗ human-authored | partial | ✓ but opaque | ✓ transparent markdown |
| File-owned | ✓ local files | ✗ their cloud | ✗ their cloud | ✓ your git repo |
| Vendor-neutral | ✓ | ✗ | ✗ locked | ✓ any CLI, any model |

**Defensibility:** the big players literally cannot ship this. Their business depends on lock-in. nanobrain's MIT license + markdown contract makes the substrate uncopyable as a moat.

---

## 4. Target users

Primary: **developers who already use AI coding CLIs and feel the context-leak pain**. Specifically:

- Solo founders building products with Claude Code / Cursor / Aider as their pair (P1 in personas)
- Salaried engineers using AI agents at work and on side projects (P2, P3)
- Independent consultants juggling multiple clients (P4)
- Researchers and PhD students using AI to assist their work (P5)

Secondary: **technical decision-makers** (CTOs, principal engineers) who need a private, durable record of strategic decisions across changing tools and time.

Non-users: anyone wanting a UI, anyone unwilling to use git, anyone who wants to share a brain with a team, anyone on mobile-only.

---

## 5. Critical-path user journey (the 5-minute "oh" moment)

A new user must hit the magic moment in 5 minutes or they bounce. The path:

1. `gh repo clone siddsdixit/nanobrain ~/nanobrain`
2. `~/nanobrain/install.sh ~/my-brain`
3. Open Claude Code in any project. Have one normal architectural conversation.
4. End the session.
5. `cat ~/my-brain/brain/decisions.md`

**The moment:** they see a decision they made out loud, distilled into three lines, in a file they own, that they did not write. Their actual brain, from their actual session, 30 seconds ago. Not a demo.

Everything else (sources, agents, skills, graph, multi-tool support) is post-moment. Don't show it before.

---

## 6. Use cases (ordered by frequency)

### UC-1 — Capture a Claude Code session
**Actor:** developer mid-work
**Trigger:** Stop hook fires at end of every assistant turn
**Flow:**
1. `capture.sh` reads transcript delta since last watermark
2. If 5KB+ new content OR 30+ min elapsed → run `claude -p` against `STOP.md`
3. Sub-Claude routes signal into `brain/{learnings,decisions,projects,...}.md`, mirrors to `raw.md`, appends to `data/claude/INBOX.md`
4. Single git commit, push to GitHub
**Frequency:** dozens per day for active users
**Success criteria:** at end of session, opening `git log --since=today` shows N capture commits with self-explanatory messages

### UC-2 — Query the brain
**Actor:** developer at start of new session
**Trigger:** `/brain who is jordan?` or `/brain what did I decide about auth?`
**Flow:**
1. `/brain` skill loads canonical files (`self`, `goals`, `projects`, `people`, `learnings`, `decisions`)
2. Answers from corpus only with citations
3. Suggests `/brain save` if a gap is found
**Frequency:** several per day
**Success criteria:** answer cites file:section, never invents

### UC-3 — Ingest from a non-Claude source
**Actor:** developer who connected an MCP (Gmail, Slack, Calendar, Drive, Ramp) or a local source (repos, Granola)
**Trigger:** scheduled launchd plist or `/brain ingest <source>`
**Flow:**
1. `code/sources/<source>/ingest.sh` pulls deltas since watermark
2. Resolver tags entries by context using `brain/_contexts.yaml`
3. Append to `data/<source>/INBOX.md` (firehose)
4. Watermark advances
**Frequency:** per source per cadence (calendar daily, gmail every 4h, slack every 2h, drive daily, ramp weekly)
**Success criteria:** INBOX append-only, no secrets leak (filter regex), context tag matches source account

### UC-4 — Distill INBOX into brain
**Actor:** scheduler (nightly 23:00) or manual `/brain distill <source>`
**Trigger:** time-based or explicit
**Flow:**
1. Read new INBOX entries since `.distill_watermark`
2. Run distill prompt for each, route to categorized brain files
3. Mirror to `raw.md`
4. Single commit
**Frequency:** nightly + on demand
**Success criteria:** each new entry routed exactly once per destination, no duplicates

### UC-5 — Spawn a context-scoped agent
**Actor:** developer wanting a specialized helper
**Trigger:** `/brain-spawn <slug>`
**Flow:**
1. Skill prompts for slug, role, reads scope (file list + tag filter), writes scope, sensitivity level, model, tools
2. Drafts `code/agents/<slug>.md` from `_TEMPLATE.md`
3. Symlinks into `~/.claude/agents/`
4. Commits + pushes
**Frequency:** rare (few per month)
**Success criteria:** agent invocable from any Claude Code session; cannot read content outside declared scope

### UC-6 — Cross-tool capture (Cursor, Aider, Gemini CLI, Codex)
**Actor:** developer using a non-Claude CLI
**Trigger:** session ends in that CLI
**Flow:**
1. Per-tool 5-line shim appends a session-ended record to `data/<tool>/INBOX.md`
2. Nightly distill picks it up alongside Claude entries
3. Same routing as UC-4
**Frequency:** per session per tool
**Success criteria:** signal from non-Claude tools lands in `brain/*.md` within 24h

### UC-7 — Compact and evolve (sleep cycles)
**Actor:** scheduler
**Trigger:** weekly Sun 02:00 (compact), monthly 1st 03:00 (evolve)
**Flow (compact):** dedupe, prune, archive >12mo content, regenerate `_graph.md`, verify `BRAIN_HASH.txt`
**Flow (evolve):** propose one targeted self-improvement edit (drops to `code/agents/_proposed/` for user `mv` approval)
**Success criteria:** brain stays under size budgets; evolve never auto-merges

### UC-8 — Restore from checkpoint *(planned, v1.0)*
**Actor:** developer after a bad commit or corruption
**Trigger:** `/brain-restore`
**Flow:** list git tags + recent commits, pick one, create restore branch, never `reset --hard`
**Success criteria:** no destructive ops, prior state always recoverable via git
**Note:** `brain-checkpoint` skill ships today (force-capture); `brain-restore` skill is v1.0 work.

---

## 7. Functional requirements

### FR-1: Markdown is the only storage format
All canonical content lives in plain markdown. No SQLite, no JSON databases, no binary formats. YAML frontmatter allowed; embedded YAML in entry headers permitted (the tag block).

### FR-2: Three persistence layers
- **Smart capture** (Stop hook): per AI CLI, throttled, distills via that CLI's available LLM
- **Dumb autosave** (launchd): every 30 min, tool-agnostic, just `git add -A && commit && push`
- **Sleep cycles** (launchd): weekly compact, monthly evolve

### FR-3: Multi-source ingest pipeline
Each source has `code/sources/<source>/{ingest.sh, ingest.md, distill.md, requires.yaml}`. Append to `data/<source>/INBOX.md`. Watermark per source. Source list at v1: claude, repos, granola, gmail, gcal, gdrive, slack, ramp.

### FR-4: Context tagging at ingest
Every new entry tagged with at minimum `context:` (work | personal | named-context). v1 also supports `sensitivity:` (public | private | confidential) and `ownership:` (mine | employer | client:<name>) per the persona-simulation findings. Resolvers are deterministic (sender domain, calendar ID, workspace ID, folder path) defined in `brain/_contexts.yaml`.

### FR-5: Agent foundry with scope enforcement
Agents are markdown files. Each declares `reads:` (file paths and tag filters). The brain MCP read-server enforces filters at read time so agents physically cannot exceed their scope. Spawning is via `/brain-spawn`; `_proposed/` requires user `mv` to activate.

### FR-6: Mirror rule
Every `brain/<file>.md` write also appends to `brain/raw.md` with `### YYYY-MM-DD HH:MM — <category> — <title>` header. Append-only. Enforced by pre-commit hook in v1.

### FR-7: Firehose protection
`brain/raw.md`, `brain/interactions.md`, `data/<source>/INBOX*.md` never read in full. Only shell-append `>>` or watermark-based `awk` tail. Enforced by skill-level guards.

### FR-8: Vendor-neutral distill
Distill prompt (`STOP.md`) is the contract. The runner that executes it is swappable. v1 ships with `claude -p`. v2 supports any LLM the user has configured.

### FR-9: Cross-machine sync
Every layer ends in `git push`. State on disk is the cache; GitHub is canonical. New machine: `gh repo clone <user>/<brain> ~/brain && ~/brain/code/install.sh`.

### FR-10: Local-first AI
No content leaves the user's machine without explicit per-action approval. No telemetry. No phone-home. Public framework code may be downloaded; private corpus never is.

---

## 8. Non-functional requirements

### NFR-1: Bootstrap install in ≤2 minutes
Single `install.sh` invocation. No interactive prompts beyond email-account onboarding (`/brain-init`). Idempotent.

### NFR-2: Loss window ≤30 minutes
Worst case from any tool, regardless of CLI or hook state, autosave commits within 30 min.

### NFR-3: Capture latency ≤90s end of session
Stop hook → committed to local git within 90 seconds. Push may be async.

### NFR-4: Brain query latency ≤2s
`/brain <question>` answers without blocking on slow operations. Reads canonical files only.

### NFR-5: No daemons, no servers
Everything is bash, markdown, git, launchd, and CLI invocations. No node/python services running in background.

### NFR-6: Cross-platform: macOS first, Linux second
v1 targets macOS (launchd). Linux support via systemd timers in v1.5. Windows out of scope until WSL is the primary path.

### NFR-7: Public framework + private content separation
nanobrain repo is MIT, framework only. User content lives in a private repo (e.g., `<user>-brain`). Never merged.

### NFR-8: Reproducibility
Capture decisions are deterministic given inputs (transcript + watermark + STOP.md). Two machines with the same state produce the same brain edits.

### NFR-9: Integrity
`BRAIN_HASH.txt` baseline + `/brain hash` verification detects drift. SAFETY.md invariants S1-S29 enforced by mechanism where possible.

---

## 9. Out of scope (explicit refuse list)

These will tempt us. We refuse on principle.

1. **Web UI to browse the brain.** Obsidian and `cat` exist.
2. **Hosted version / nanobrain Cloud.** Kills the wedge.
3. **Non-git sync backends** (Dropbox, S3, custom). Git is the contract.
4. **Mobile app.** Phones don't run AI CLIs.
5. **Embeddings / vector search in core.** Optional skill, not core. Core stays markdown + grep.
6. **Multiplayer / team brains.** Different product, different threat model.
7. **Schema validation linter beyond what `SCHEMA.md` declares.** Don't ship a linter; ship a habit.
8. **Auto-summarization-as-a-service / any phone-home feature.** Inference happens on user's machine via user's CLI.
9. **A GUI for `_contexts.yaml`.** Markdown + YAML in a text editor is the UI.
10. **Backwards-compat shims for legacy formats.** No legacy yet; refuse to create one preemptively.

**The pattern:** anything that adds a daemon, server, service, or vendor relationship is out.

---

## 10. Success metrics

### Adoption (12-month targets)
- 1,000+ GitHub stars on nanobrain
- 100+ users who installed and produced ≥1 capture commit
- 10+ user-contributed sources or skills

### Per-user health (after 30 days)
- ≥1 capture commit per active day
- ≥5 entries across `brain/{decisions,learnings}.md`
- ≥2 successful `/brain` queries per day (cited from corpus)
- 0 secret leaks in committed content

### Quality
- Time-to-magic-moment (install → first useful `cat decisions.md`) ≤5 min
- Capture commit rate ≥80% of expected throttle windows
- Restore-from-bad-state success ≤10 min

---

## 11. Risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Vendor-CLI hook API changes break capture | medium | medium | Multiple capture layers; autosave is vendor-independent |
| User commits a secret accidentally | medium | high | `redact.sh` regex pre-write; pre-commit hook in v1 |
| Sub-Claude misroutes content (wrong tag, wrong file) | high | low | Mirror to raw.md is fail-soft; nightly compact catches drift |
| GitHub becomes unavailable / changes terms | low | medium | Git remote is swappable; framework is host-neutral |
| `claude -p` deprecated or rate-limited | medium | medium | Vendor-neutral distill in v2; user-configured LLM |
| Brain grows past size budget | medium | low | Sleep-cycle compact; firehose rotation by year |
| Wrong context tag → cross-context leak | high (P3, P4) | high | Multi-axis tagging (FR-4); deterministic resolvers; agent scope enforcement |
| Toy-perception from "nano" prefix | medium | low | Production-quality README, ADRs, SAFETY invariants |

---

## 12. Roadmap

### v0.x (shipped, current)
- Claude Code Stop hook + autosave + compact + evolve
- Sources: claude, repos, granola (`data/slack/` is a scaffolded placeholder; no slack source code yet — v1.0 work)
- Skills (9): brain, brain-save, brain-compact, brain-evolve, brain-graph, brain-spawn, brain-hash, brain-redact, brain-checkpoint
- Public framework / private corpus split
- ARCHITECTURE.md
- BRAIN_HASH.txt integrity baseline

### v1.0 — multi-source ingest (Q2 2026)
- `/brain-doctor` MCP detection skill
- `/brain-init` iterative onboarding
- Sources: gmail, gcal, gdrive, slack, ramp
- Multi-axis tagging: context (named), sensitivity, ownership
- Per-source launchd plists
- Agent scope enforcement via brain MCP read-server
- Pre-commit mirror enforcement
- README rewrite around the leak-and-capture frame

### v1.5 — cross-tool (Q3 2026)
- Restructure `code/hooks/claude/`
- Per-tool capture shims: cursor, aider, gemini-cli, codex-cli
- Linux support (systemd timers)
- Firehose rotation by year
- Vendor-neutral distill runner

### v2.0 — graph + extensions (Q4 2026)
- Optional embeddings skill (not in core)
- Graph-aware queries
- Source-contribution template
- Public agent registry (markdown manifests, no hosting)
- `brain-restore` skill (UC-8)

### Not committed
- Mobile, web UI, cloud — refuse list
- Multiplayer, schema enforcement linter — refuse list

---

## 13. Open questions

1. **Cross-tool sequencing.** Idea agent's pushback: don't pivot to cross-tool until at least one new source (Gmail or Slack) is flowing end-to-end. v1.0 holds Gmail+Calendar; v1.5 picks up cross-tool. Locked.
2. **Ownership tier reinstatement.** Persona simulation argues yes (P3, P4 IP-leak risk). User said "uncomplicated." Resolution: include in v1.0 as optional (default unset; users with employer/client engagements opt in). Marked default-off so simple users don't see it.
3. **Vendor-neutral distill in v1 or v1.5?** Today `claude -p` is hard-coded. Punted to v1.5 unless an early user blocks on it.
4. **Pre-commit mirror enforcement.** Currently the mirror rule is sub-Claude-obedience-based. Mechanical enforcement (git pre-commit hook rejecting `brain/*.md` commits without raw.md additions) is straightforward. Ship in v1.0.
5. **Public agent registry.** v2 idea. Risk: if hosted, breaks refuse list. Resolution: registry is a markdown index in the nanobrain repo (`docs/AGENTS_REGISTRY.md`); each entry links to a user's repo. No central hosting.

---

## 14. Definitions

- **Brain corpus:** the set of canonical markdown files in `brain/` queried by `/brain`.
- **Firehose:** append-only files (`raw.md`, `interactions.md`, `data/<source>/INBOX.md`) that never get read in full.
- **Capture:** the act of running a distill against a session/source delta and writing to brain.
- **Distill:** transformation of a delta into structured brain entries via `STOP.md` protocol.
- **Mirror rule:** every brain edit also lands in `raw.md` (S2a invariant).
- **Sleep cycle:** scheduled maintenance pass (compact = weekly, evolve = monthly).
- **Source:** any upstream signal pipeline (Claude, Slack, Gmail, etc.) with `ingest.sh` + `distill.md`.
- **Skill:** markdown protocol invokable by slash command (`/brain`, `/brain-save`, etc.).
- **Agent:** markdown role file symlinked into `~/.claude/agents/` with declared `reads:` and `writes:` scope.

---

## 15. References

- `docs/ARCHITECTURE.md` — system + capture-flow diagrams
- `SAFETY.md` — invariants S1–S29
- `SCHEMA.md` — controlled vocabulary
- `docs/adr/0001-0016` — architecture decision records
- `code/hooks/STOP.md` — distill protocol contract
- Persona simulation: `<archived plan>`
- Multi-source plan: `<archived plan>`

---

## 16. Sign-off

| Role | Name | Status | Date |
|---|---|---|---|
| Owner | Sid Dixit | Approved (draft v0.1) | 2026-04-27 |
| Architect | n/a (single-author OSS) | n/a | n/a |
| Design | n/a | n/a | n/a |

This PRD is a living document. Material changes go through ADR (`docs/adr/`).
