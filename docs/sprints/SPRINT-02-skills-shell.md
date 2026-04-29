# SPRINT-02 — Skills shell

## Goal

Ship the skill machinery that orchestrates v1.0 sources, even before any new source exists. After this sprint a user can run `/brain-doctor` (and see today's repos/granola/claude state) and `/brain-ingest <source>` / `/brain-distill <source>` (which dispatch to wherever the source code is — they will start working as each source lands).

## Stories

- **NBN-105** — `/brain-doctor` skill
- **NBN-107** — `/brain-ingest <source>` dispatcher
- **NBN-108** — `/brain-distill <source>` dispatcher
- **NBN-109** — `/brain-distill-all`

## Pre-conditions

- SPRINT-01 merged (resolver + write_inbox available; doctor reads watermarks they wrote).
- v0.x skills dir layout (`code/skills/<name>/SKILL.md`) understood. Reference: `code/skills/brain-checkpoint/SKILL.md`.

## Detailed steps

All paths in **public framework** (`~/Documents/nanobrain/`).

### 1. NBN-105 — `/brain-doctor`

**Files to create:**

- `~/Documents/nanobrain/code/skills/brain-doctor/SKILL.md`
- `~/Documents/nanobrain/code/skills/brain-doctor/check.sh`

**`SKILL.md` frontmatter:**

```yaml
---
name: brain-doctor
description: Inspect MCP availability, source health, _contexts.yaml presence, pre-commit hook, and BRAIN_HASH. Read-only, side-effect-free, exit 0 even on warnings.
---
```

The body of `SKILL.md` instructs Claude Code to invoke `bash $HOME/brain/code/skills/brain-doctor/check.sh` and return its stdout.

**`check.sh` behavior:**

1. Print header: `nanobrain doctor — $(date '+%Y-%m-%d %H:%M')`.
2. **MCPs detected** section. Read `~/.claude/.mcp.json` (or `~/.claude/mcp.json` — try both). For each of `gmail, gcal, gdrive, slack, ramp, claude (built-in), repos (gh CLI), granola (cache file)`, mark ✓ if discoverable, ✗ if not. Note: `claude` and `repos` and `granola` aren't MCPs proper; check by binary/path:
   - `claude`: `command -v claude` exists.
   - `repos`: `command -v gh` exists.
   - `granola`: `~/Library/Application Support/Granola/cache-v6.json` exists.
3. **Sources status** section. For every directory in `data/`, find newest mtime among `*.md` files. Format `last ingest <relative time>`, INBOX size, ✓ / ⚠ stale (>24h) / ✗ (no files yet).
4. **`_contexts.yaml`** line: present (run `validate_contexts.sh` quietly, ✓ on success, ⚠ with first-error line if invalid) or `missing → run /brain-init`.
5. **Pre-commit hook** line: check `<brain>/.git/hooks/pre-commit` exists and is the mirror-check symlink (deferred to S08; report ✗ until then is fine).
6. **BRAIN_HASH** line: run `bash code/skills/brain-hash/verify.sh` (existing v0.x skill) and surface its result.
7. **Next:** suggest the first missing thing (`_contexts.yaml` missing → `/brain-init`; else first stale source → `/brain-ingest <source>`).
8. Exit 0 even with warnings; exit 1 only on file-read errors that prevent the report.

**Output template** matches SPEC §3.1 verbatim so users see the example they read in docs.

### 2. NBN-107 — `/brain-ingest <source>` dispatcher

**Files to create:**

- `~/Documents/nanobrain/code/skills/brain-ingest/SKILL.md`
- `~/Documents/nanobrain/code/skills/brain-ingest/dispatch.sh`

**`SKILL.md` description:** "Pull deltas from `<source>` since `.watermark` and append to `data/<source>/INBOX.md`. Source ∈ {claude, repos, granola, gmail, gcal, gdrive, slack, ramp}. Optional `--bootstrap` flag for first run."

**`dispatch.sh` behavior:**

1. Args: `$1=source`, optional `$2=--bootstrap` (and other flags pass-through).
2. Allow-list: hardcode the 8 valid sources. Unknown → exit 1 with message.
3. Compute target: `${BRAIN_DIR:-$HOME/brain}/code/sources/$1/ingest.sh`. Missing → exit 3 with `source not yet implemented; run /brain-doctor`.
4. **Lock:** `flock -n -x ${BRAIN_DIR}/data/$1/.ingest.lock`. Held → exit 2 within 1s.
5. Forward env vars (`BRAIN_DIR`, `WORK_DOMAINS`, etc.) and pass remaining args.
6. Capture stdout, surface as-is. On exit 4, print `auth expired; refresh <source> credentials`.
7. On any exit code, release lock automatically (flock does this on process end).

### 3. NBN-108 — `/brain-distill <source>` dispatcher

**Files to create:**

- `~/Documents/nanobrain/code/skills/brain-distill/SKILL.md`
- `~/Documents/nanobrain/code/skills/brain-distill/dispatch.sh`

**Behavior:**

1. Args: `$1=source`.
2. Confirm `code/sources/$1/distill.md` exists. Missing → exit 3.
3. Read INBOX delta: `awk` from `data/$1/.distill_watermark` to EOF. If watermark missing, treat as start-of-file (full INBOX is fine on first run since INBOX is bounded by source bootstrap).
4. **No new content** → exit 0 silently.
5. Compose `claude -p` invocation: system prompt is the contents of `distill.md`; user input is the INBOX delta. Use `-p` (print mode, non-interactive). Capture stdout; tee to `data/$1/.distill.last.log` for debugging.
6. Parse `claude -p` output. Expected format: each routed entry is delimited by a `>>>` marker followed by `target_path:` and the markdown block. (This contract is owned by `STOP.md` and per-source `distill.md`; the dispatcher only needs to recognize the delimiter and apply.)
7. For each parsed entry, **shell-append** to the named brain file AND to `brain/raw.md` (mirror, S2a). Use `>>` only.
8. **Atomic watermark advance:** only after every route + mirror succeeds, write the new watermark via `mv` from a tempfile.
9. On any malformed parse → exit 5; do NOT advance watermark; print the offending block to stderr.
10. Print summary: `distill <source>: N entries → {decisions: x, learnings: y, projects: z, ...}`.

### 4. NBN-109 — `/brain-distill-all`

**Files to create:**

- `~/Documents/nanobrain/code/skills/brain-distill-all/SKILL.md`
- `~/Documents/nanobrain/code/skills/brain-distill-all/run.sh`

**Behavior:**

1. Iterate every `data/*/INBOX.md` whose mtime is newer than `data/*/.distill_watermark`.
2. For each, invoke `bash code/skills/brain-distill/dispatch.sh <source>`.
3. Aggregate exit codes. Print one summary line per source.
4. **Cron path** (env `CRON=1`): swallow per-source errors, exit 0 unless ALL fail.
5. **Manual path:** exit non-zero if any source failed.

## Reference patterns

- `code/skills/brain-checkpoint/SKILL.md` for the frontmatter style and how the body invokes a script.
- `code/hooks/capture.sh` for the recursion/lock pattern.
- For `claude -p` invocation pattern, grep existing skills: `grep -rn 'claude -p' code/`.

## Testing

```bash
cd ~/Documents/nanobrain

# 1. brain-doctor on the dev machine
BRAIN_DIR=$HOME/your-brain bash code/skills/brain-doctor/check.sh
# Expect: report listing claude/repos/granola ✓, others ✗ (no plists yet),
# _contexts.yaml ✗ (deferred to S03), pre-commit ✗ (deferred to S08).

# 2. ingest dispatcher with unknown source
bash code/skills/brain-ingest/dispatch.sh nope; echo "exit=$?"
# Expect: exit=1, "unknown source"

# 3. ingest dispatcher with not-yet-implemented gmail
bash code/skills/brain-ingest/dispatch.sh gmail; echo "exit=$?"
# Expect: exit=3, "source not yet implemented"

# 4. ingest dispatcher with existing repos source
bash code/skills/brain-ingest/dispatch.sh repos; echo "exit=$?"
# Expect: exit=0, "[ingest repos] ..." (this is the existing v0.x source)

# 5. distill dispatcher with no new content
touch $HOME/your-brain/data/repos/.distill_watermark
bash code/skills/brain-distill/dispatch.sh repos; echo "exit=$?"
# Expect: exit=0, no stdout (no new entries since touch).

# 6. distill-all
CRON=1 bash code/skills/brain-distill-all/run.sh
# Expect: one summary line per source, exit 0.
```

## Definition of done

- [ ] `/brain-doctor` produces the SPEC §3.1 output shape on a real brain dir.
- [ ] `/brain-ingest <source>` allow-list, lock, and exit codes (0/1/2/3/4) all behave.
- [ ] `/brain-distill <source>` advances watermark only on full success; exit 5 on malformed.
- [ ] `/brain-distill-all` iterates and aggregates.
- [ ] Both dispatchers `chmod +x`.
- [ ] `install.sh` symlink loop picks up the four new skills (verify by running `~/Documents/nanobrain/install.sh ~/your-brain` once and checking `~/.claude/skills/brain-doctor/` exists).

## Commit / push

```bash
cd ~/Documents/nanobrain
git add code/skills/brain-doctor code/skills/brain-ingest code/skills/brain-distill code/skills/brain-distill-all
git commit -m "feat: brain-doctor + ingest/distill dispatchers"
git push
```

## Estimated time

6 hours. `/brain-doctor` is the biggest piece (~2.5h, lots of small probes). The three dispatchers are ~1h each.
