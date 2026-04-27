# SAFETY — invariants the brain must never break

The brain edits its own code (via `/brain-evolve`) and runs hooks that touch shell + git. This file lists the hard invariants. **Any change that violates one of these must be reverted immediately.** `/brain-evolve` reads this file before proposing any edit and refuses to weaken these rules.

## Load-bearing safety guards (never weaken)

### S1. Recursion guard in `code/hooks/capture.sh`
- The `NANOBRAIN_CAPTURING=1` env-var check at the top must remain.
- The `stop_hook_active` check via jq must remain.
- These prevent the Stop hook from infinitely re-triggering when it spawns `claude -p`.

### S2. Append-only firehoses
- `brain/raw.md`, `brain/interactions.md`, `data/<source>/INBOX*.md` must NEVER be Read in full or Edited.
- All writes use shell append (`>>`). Never `>`. Never `tee` without `-a`.
- The `brain` skill, the `brain-save` skill, and the Stop hook protocol all enforce this.
- `/brain-evolve` must NOT add a step that reads these files in full.

### S2a. Mirror rule — every `brain/` write also lands in `raw.md`
Any entry written to `brain/<category>.md` (self, goals, projects, people, learnings, decisions, repos) MUST also be shell-appended to `brain/raw.md` with a `### YYYY-MM-DD HH:MM — <category> — <title>` header. raw.md is the faithful firehose of every signal that entered the brain. Skipping the mirror breaks the audit trail and means raw.md no longer represents truth.

Exception: bulk rewrites (rare, manual) may use a single summary entry in raw.md pointing at the commit SHA, instead of mirroring every line. Default is full mirror.

### S3. Categorized brain content is user-and-hook-owned
- `brain/{self,goals,projects,people,learnings,decisions}.md` — `/brain-evolve` cannot bulk-rewrite these.
- It may propose ONE specific edit (e.g. promoting a recurring learning to `self.md` as a principle), but never restructure or remove existing entries.

## Tenets-derived invariants (S10–S29) — locked by ADR-0013

### S10. Scale infinitely
Architecture must support 50+ years. No data structure that breaks past 1M files / 10GB / 100K entries per file. Markdown + git scale; vector DBs and proprietary stores don't.

### S11. Scale with sources
New source must NEVER touch existing source code. Recipe: copy `code/sources/_TEMPLATE/`, fill in. If a new source needs to modify another source's files, the design is wrong.

### S12. Five memory stages (ADR-0016)
Working / short-term / long-term episodic / long-term semantic / procedural. Every brain file maps to exactly one. Mixing stages is a design violation.

### S13. ISO 8601 timestamps
Every captured fact uses `YYYY-MM-DD` (or `YYYY-MM-DD HH:MM` for firehose). No relative dates ("yesterday", "last week").

### S14. Compaction preserves date spans
Refining N raw observations into 1 principle records `first observed` and `refined at` dates.

### S15. Single source of truth per fact
Per-entity files (`brain/person/<slug>.md`, `brain/project/<slug>.md`, etc.) own content. Indexes link, don't duplicate.

### S16. Detectable corruption
`BRAIN_HASH.txt` regenerated on `/brain-compact`. Mismatch on session start = alarm. `/brain status` surfaces it.

### S17. Reversibility
Every change is a git commit. No state outside git except secrets and ephemeral logs.

### S18. Four-tier sensitivity
Public framework / Personal / Confidential (frontmatter) / Sensitive (encrypted, gitignored). Sensitive content NEVER mirrors to `raw.md`.

### S19. Public framework, private content
`nanobrain` (public, MIT) holds framework. `<user>/<your-brain>` (private) holds content. They never merge.

### S20. Local-first AI
Content never leaves machine without explicit per-action approval. `claude -p` reading local files allowed; sending `data/` to third-party services requires explicit user invocation.

### S21. Defense in depth on capture
Every source ingest applies regex secrets filter (`password|token|api[_-]?key|secret|sk-|Bearer\s+`) before writing.

### S22. Tool self-creation gated
`/brain-evolve` proposes new skills/sources/agents in `_proposed/` folders. No silent activation. The operator moves to active.

### S23. Templates over from-scratch
New sources/agents/skills start from `_TEMPLATE/`. Custom-from-scratch requires ADR.

### S24. Backwards-compatible schema
Adding optional frontmatter fields is allowed. Removing/renaming forbidden.

### S25. Markdown + YAML only in `brain/`
No JSON, SQLite, binary. Structured data → YAML frontmatter.

### S26. No vendor lock
Brain works without Claude, GitHub, or any specific tool. Markdown + git is the only required dependency.

### S27. Plain-English readable
`brain/README.md` understandable by non-engineers. `cat brain/self.md` works without any tool.

### S28. Determinism
Re-running capture/compact/evolve on same input → identical output. Locks + watermarks enforce.

### S29. Agent scope enforced
Agents declare `reads:` / `writes:` at spawn. Brain refuses access outside scope. Brain-spawned agents require approval to activate.

---

## Original invariants (S1–S9, M1–M5)

### S3a. Compaction-protected files (the principle + the list)

**Principle:** compaction destroys signal in files where every entry is load-bearing. Only **insight-and-decision** files get compacted. **Registries, logs, history, and append-only firehoses are protected.**

**Test:** can you safely lose, merge, or refine an arbitrary entry in this file? If no, protect it.

**Protected (never compact):**

Inside `brain/`:
- `raw.md` — cross-source firehose
- `interactions.md` — append-only log of who-when-what
- `people.md` — contact index (names accumulate; relationships don't dedupe)
- `people/<slug>.md` — per-person detail
- `repos.md` — repo registry (compacting drops repos from the map)
- `archive/**` — already archived
- Any future timeline/log/history file: `calendar.md`, `timeline.md`, `health.md`, `financials.md`, `contracts.md`, etc. New files of this shape are protected by default.

Outside `brain/` (compaction shouldn't reach these anyway, but for clarity):
- `data/**` — all source firehoses
- `data/_sensitive/**` — gitignored sensitive content
- `docs/adr/**` — architecture decision records (append-only; supersede with new ADRs, never rewrite old ones)
- `code/**` — machinery
- `claude-config/**` — synced settings
- Top-level pointers: `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `CONTEXT.md`, `ROADMAP.md`, `SOURCES.md`, `SCHEMA.md`, `README.md`, `plan.md`

**Compactable (refine / dedupe / archive stale):**
- `brain/learnings.md` — promote raw observations to principles
- `brain/decisions.md` — archive superseded decisions
- `brain/projects.md` — archive completed, mark stale
- `brain/goals.md` — replace stale quarterly goals
- `brain/self.md` — minimal touch only; identity is stable

**Default for new brain/ files:** treat as protected unless you can articulate why dedupe/refinement adds value without losing signal.

### S4. No file deletion
- `/brain-evolve` and any other automated process must never `rm` files.
- Stale content moves to `brain/archive/<filename>-<YYYY-MM>.md` instead.
- Source INBOXes rotate to `INBOX-<YYYY-MM>.md`, never deleted.

### S5. Secrets never enter the repo
- No file in this repo (under any path) may contain: API keys, OAuth tokens, passwords, bearer tokens, JWTs, private keys, OAuth refresh tokens.
- All secrets live in `~/.claude/.env` (gitignored, machine-local).
- Each source's ingest script must apply privacy filters BEFORE writing to `data/<source>/`.

### S6. Token-budget protections
- `/brain` query mode loads only `brain/{self,goals,projects,people,learnings,decisions}.md` plus `CONTEXT.md`. Never `raw.md`. Never `data/`.
- `/brain-evolve` may not raise this. May only further restrict.

### S7. Recursion-safe git
- Stop hook commits with `--quiet` and falls back to `|| true` so a git failure never blocks session end.
- Never `git push --force` to `main` from automated code. (`/brain-evolve` may use `--force-with-lease` only after amending its own commit, never on others.)

### S8. install.sh is idempotent and reversible
- Every modification to `~/.claude/` must back up the prior file (`<file>.local-backup-<timestamp>`) so re-running install.sh never silently destroys local config.
- install.sh may NOT modify any file outside `~/.claude/`, `$HOME/brain/`, or known temp paths.

### S9. Sensitive folders
- `data/_sensitive/` (when it exists) is gitignored.
- Contracts, NDAs, medical records, legal correspondence go here, never in `brain/raw.md` or `data/<other-source>/`.

## Self-modification rules (`/brain-evolve` specific)

### M1. One change per run
- A single targeted edit. No sweeping refactors.

### M2. Always commit, always push
- Every `evolve:` change is a commit. `git revert <sha>` undoes it.
- Push to `main` (no PR ceremony for a personal repo), but commit messages start with `evolve:` for greppability.

### M3. Validate before committing
Before any commit, `/brain-evolve` must:
- Confirm `code/hooks/capture.sh` still has the recursion guard (S1).
- Confirm `brain/{self,goals,projects,people,learnings,decisions,raw,interactions}.md` all still exist.
- Confirm `code/install.sh` is still executable and contains the skill symlink loop.
- If any check fails, abort and report.

### M4. Refuse out-of-scope edits
`/brain-evolve` may not edit:
- Captured user content (`brain/learnings.md`, `decisions.md`, `projects.md`, `goals.md`, `people.md`, `interactions.md`).
- `brain/raw.md` (firehose).
- `data/**` (raw ingestion).
- `brain/archive/**`.
- This file (`SAFETY.md`) — only the operator edits this.

### M5. Backup before risky edits
Before modifying `code/install.sh` or `code/hooks/capture.sh`, save the prior version to `code/_backup/<filename>-<timestamp>` (gitignored). On failure of the next session's hook, manual restore is one `cp` away.

## What corruption looks like (red flags)

- `brain/raw.md` shrinks → write happened with `>` instead of `>>`. Restore from git.
- `code/hooks/capture.sh` runs forever or never → recursion guard broken. Restore from `_backup/`.
- A `brain/*.md` file disappears → S4 violated. Restore from git.
- A secret appears in any committed file → S5 violated. Force-push remediation, rotate the secret.
- `~/.claude/CLAUDE.md` is missing or pointing nowhere → install.sh corrupted; restore from `.local-backup-*`.

## Recovery

Every state in this brain is recoverable from git:

```bash
cd $HOME/brain
git log --oneline -50           # find a known-good commit
git checkout <sha> -- <file>    # restore a single file
git revert <sha>                # undo a specific commit (keeps history)
```

For lost local state: `gh repo clone <user>/<your-brain-repo>` always returns the canonical version.
