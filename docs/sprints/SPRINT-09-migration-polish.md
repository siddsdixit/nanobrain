# SPRINT-09 — Migration, distill consumer, README, examples, ADR, smoke test

## Goal

Close v1.0. Migrate the three v0.x sources (claude, repos, granola) onto the multi-axis schema, teach the distiller to consume the new headers, ship the public-facing surfaces (README, starter-brain example, ADR), and prove the whole pipeline works end to end with one smoke script.

## Stories

- **NBN-122** — migrate existing claude/repos/granola entries to multi-axis schema (medium)
- **NBN-123** — update `STOP.md` to consume multi-axis headers (medium)
- **NBN-124** — README rewrite around leak-and-capture frame (small)
- **NBN-125** — `examples/starter-brain` updated for v1.0 (small)
- **NBN-126** — ADR-0017 multi-axis tagging decision (small)
- **NBN-127** — end-to-end smoke test (medium)

## Pre-conditions

- All prior sprints (S01-S08) merged.
- Real brain on the maintainer's machine has a non-empty `_contexts.yaml` (run `/brain-init` once if not).

## Detailed steps

Each step labels the **public framework** (`~/Documents/nanobrain/`) vs **private corpus** (`~/your-brain/`).

### 1. NBN-122 — migrate existing sources (public framework)

Three existing ingest scripts use direct `>>` append. Switch them to `code/lib/write_inbox.sh` so every entry carries multi-axis headers. No retroactive rewrite of historical INBOX (S24).

#### Files to modify

- `code/sources/claude/ingest.sh` — currently appends Claude-Code session signals; wire through `write_inbox.sh`. Resolver call: `code/lib/resolve_context.sh claude "$SESSION_PROJECT_PATH"` (a new lookup key; map nothing for now → defaults to `personal\tprivate\tunset`, which is the right answer for personal projects). Inline flag: claude resolver lookup is by project path; `_contexts.yaml.resolvers.claude:` is reserved but unused in v1.0 starter examples.
- `code/sources/repos/ingest.sh` — already has a resolver concept (gh-owner). Migrate to call shared `code/lib/resolve_context.sh repos "$OWNER"` and `code/lib/write_inbox.sh`. Existing INBOX entries unchanged; new entries gain the header.
- `code/sources/granola/ingest.sh` — similar migration. Resolver lookup by meeting attendee domain (closest analog to gmail). Calls `resolve_context.sh granola "$DOMAIN"`. Reserve `resolvers.granola:` in the schema even though no example uses it.

#### Schema extension

Update `examples/_contexts.example.yaml` to add `resolvers.claude:` and `resolvers.granola:` blocks (empty arrays for now), so users can see they exist. Update `code/lib/validate_contexts.sh`'s allowed-resolver-source set to include `claude` and `granola`.

#### Backward compatibility

`code/mcp-server/lib/parse_entries.js` (S07) already tolerates v0.x entries missing front-matter — it defaults to `(personal, private, unset)`. Confirm this is exercised: add a fixture entry without front-matter to `tests/mcp/fixtures/brain/projects.md`, re-run leak suite, assert it gets the defaults.

### 2. NBN-123 — STOP.md consumes multi-axis headers (public framework)

#### File to modify

`code/hooks/STOP.md` (the system prompt the capture hook hands to `claude -p`).

#### Changes

1. Update the section that describes input format to show the v1.0 entry shape (the `### YYYY-MM-DD HH:MM — <source>: <subject>\ncontext: ...\nsensitivity: ...\nownership: ...\nsource_id: ...\n\nbody`).
2. Add an instruction block: "Each routed entry you emit MUST carry frontmatter with `context`, `sensitivity`, and (when not unset) `ownership`, inherited from the originating INBOX entry. Never demote sensitivity. If an INBOX entry is `confidential`, the routed brain entry stays `confidential`."
3. Add a refusal rule: "If `sensitivity == sensitive`, route the entry to `data/_sensitive/<source_id>.md` as full-body markdown, not to `brain/`. Spec §5.3."
4. Add an output-format reminder: every routed entry begins with `>>>` delimiter line, then `target_path: <relative/path.md>`, then a blank line, then the entry content.

Same change applies in spirit to each per-source `distill.md`. Audit each (`code/sources/*/distill.md`) for the inheritance rule. The five v1.0 source `distill.md` files were authored already aware of this; the three v0.x source `distill.md` files (`claude`, `repos`, `granola`) need patching to match.

#### Test

`tests/test_distill_inheritance.sh` — feed `claude -p --dry-run` (use a stub if no API access) a fixture INBOX with a `confidential` entry, assert the emitted brain entry frontmatter has `sensitivity: confidential`. If `claude -p` is unavailable in CI, instead assert the prompt text in `STOP.md` and per-source `distill.md` contains the inheritance rule via `grep -q`.

### 3. NBN-124 — README rewrite (public framework)

#### File to modify

`README.md` at repo root.

#### Structure

1. **Headline + tagline** (1 line each): "nanobrain — your second brain in markdown." Subline: "AI agents leak context across tools. nanobrain captures it once, makes it queryable forever."
2. **The 5-minute oh moment** (verbatim from PRD §5; copy from `docs/PRD.md`): walks a new user from clone to first `/brain-doctor` green to first ingest to first agent reading scoped content.
3. **Comparison table** (PRD §3): nanobrain vs Mem.ai vs Notion AI vs vector DBs. 6 rows, 4 columns. Markdown table.
4. **Install one-liner**: ```bash
   git clone https://github.com/siddsdixit/nanobrain && ~/nanobrain/install.sh ~/your-brain
   ```
5. **What ships in v1.0**: bulleted list of 5 sources, 6 skills, 3-axis tagging, MCP scope enforcement, pre-commit mirror.
6. **Architecture link**: one line pointing to `docs/ARCHITECTURE.md` and `docs/SPEC-v1.0.md`.
7. **Refuse list**: short. "What nanobrain will never become: hosted, multiplayer, web UI, daemon, vector DB."
8. **License + contact**: MIT, the maintainer's email or GitHub handle.

Length target: under 250 lines including tables. The wedge in the first 30 seconds; depth one click away.

### 4. NBN-125 — `examples/starter-brain` (public framework)

#### Files

```
examples/starter-brain/
  brain/
    _contexts.yaml             # full-featured: 3 contexts (personal, work, side-proj-a)
    self.md                    # one-paragraph stub
    goals.md                   # one-paragraph stub
    projects.md                # 1 sample entry with v1.0 headers
    people.md                  # 1 sample entry
    raw.md                     # mirror seed
    learnings.md, decisions.md # empty placeholders
  data/
    claude/.gitkeep
    repos/.gitkeep
    granola/.gitkeep
    gmail/.gitkeep
    gcal/.gitkeep
    gdrive/.gitkeep
    slack/.gitkeep
    ramp/.gitkeep
  README.md                    # explains: clone this, point install.sh at it, you're done
```

`_contexts.yaml` content: copy `examples/_contexts.example.yaml` (the schema fixture from S01) and rename slugs to neutral examples (`personal`, `work-employer`, `side-project`).

`brain/projects.md` sample entry with proper v1.0 frontmatter so the leak-test fixture pattern is visible.

`README.md`: "Clone or copy this directory to your private brain location, then run `~/Documents/nanobrain/install.sh /path/to/this/dir`. Edit `_contexts.yaml` to match your accounts, then `/brain-doctor`."

### 5. NBN-126 — ADR-0017 (public framework)

#### File

`docs/adr/0017-multi-axis-tagging.md`.

#### Body

Standard ADR shape:

- **Status:** accepted (2026-04-27).
- **Context:** v0.x had implicit single-axis tagging (source = context). The Q1 2026 simulation tried collapsing to one axis, which broke the recruiter-leakage and investor-confidentiality use cases. PRD §13.2 reintroduced three axes; sim P5 added channel-level overrides; spec O-1/O-9 locked semantics.
- **Decision:** every ingested entry carries `(context, sensitivity, ownership)`. Resolution via `brain/_contexts.yaml`. Defaults `(personal, private, unset)`. Hierarchical sensitivity ranks. Optional ownership omitted from solo users' entries.
- **Consequences:**
  - Resolver per source. Caching mandatory for performance.
  - Distill must propagate, never demote.
  - Agent scope filter has 3 dimensions to honor (NBN-117).
  - Future evolve runs must not "simplify" away axes; this ADR is the no-go signal.
- **Alternatives considered:** flat tags (rejected — collisions); single sensitivity dimension (rejected — investor + employer cases need separation); per-entry ad-hoc fields (rejected — non-deterministic, breaks resolver caching).

### 6. NBN-127 — end-to-end smoke test (public framework)

#### File

`tests/e2e/smoke.sh`.

#### Behavior

Runs in <60s on dev hardware. Self-cleaning. No real MCPs.

```bash
#!/usr/bin/env bash
set -euo pipefail
SB=$(mktemp -d)
trap 'rm -rf "$SB"' EXIT
export BRAIN_DIR="$SB"
export BRAIN_FRAMEWORK="$PWD"

# 1. seed brain dir
mkdir -p "$SB/brain" "$SB/data"
cd "$SB" && git init -q && cd - >/dev/null

# 2. brain-init non-interactive
BI_CONTEXT_NAME=work BI_SENSITIVITY=confidential BI_OWNERSHIP=employer:bigco \
  BI_GMAIL_DOMAIN='bigco\.com$' \
  bash code/skills/brain-init/wizard.sh --non-interactive
bash code/lib/validate_contexts.sh "$SB/brain/_contexts.yaml"

# 3. install (without launching plists)
bash install.sh "$SB" --skip-cron

# 4. ingest a fixture claude session
mkdir -p "$SB/data/claude"
cp tests/e2e/fixtures/claude_session.md "$SB/data/claude/INBOX.md"
echo "2026-04-27T00:00:00Z" > "$SB/data/claude/.distill_watermark"

# 5. distill (use stub claude-p that echoes a routed entry)
PATH="$PWD/tests/e2e/stubs:$PATH" bash code/skills/brain-distill/dispatch.sh claude

# 6. assert mirror
grep -q '^### .* — claude:' "$SB/brain/raw.md" || { echo "raw.md mirror missing"; exit 1; }
grep -q '^context:' "$SB/brain/raw.md" || { echo "multi-axis header missing in raw.md"; exit 1; }

# 7. assert pre-commit hook armed
[ -L "$SB/.git/hooks/pre-commit" ] || { echo "pre-commit not symlinked"; exit 1; }

# 8. assert MCP read filtering
node code/mcp-server/index.js --self-test --brain "$SB" --agent tests/mcp/fixtures/agents/agent-c.md
# (--self-test asserts agent-c sees zero entries given fixture)

echo "smoke: PASS in $SECONDS s"
```

#### Stubs

`tests/e2e/stubs/claude` — script in PATH that intercepts `claude -p`, returns a hardcoded routed entry that exercises the distill format. Just enough for the smoke to pass without an API key.

#### Fixtures

`tests/e2e/fixtures/claude_session.md` — 1 INBOX entry with v1.0 multi-axis header.

#### CI hook

Add `tests/e2e/smoke.sh` to `tests/run_all.sh` so every PR exercises the full pipeline.

`install.sh --skip-cron`: small flag added to S08's installer; gates the `launchctl load` loop. Implement in this sprint.

### 7. Private corpus updates

After all of the above lands in the public framework and `~/your-brain/install.sh` is re-run, do one operational pass on the private brain:

- **Private corpus**: ensure `~/your-brain/brain/_contexts.yaml` matches the maintainer's real accounts. If absent, run `/brain-init` end-to-end interactively. (No file commits expected unless the resolver shape changed for the maintainer.)
- **Private corpus**: regenerate `BRAIN_HASH.txt` after migration so the integrity baseline reflects v1.0 entry headers. Spec §10 sign-off line.

```bash
cd ~/your-brain
~/Documents/nanobrain/install.sh ~/your-brain
bash ~/Documents/nanobrain/code/skills/brain-hash/generate.sh > BRAIN_HASH.txt
git add BRAIN_HASH.txt
git commit -m "chore: regenerate BRAIN_HASH for v1.0 multi-axis schema"
git push
```

## Reference patterns

- `docs/adr/0010-*.md` (or whichever is the most recent ADR) for ADR shape.
- `tests/test_validate_contexts.sh` for fixture-driven test harness style.
- `examples/_contexts.example.yaml` (S01) as the seed for starter-brain.

## Testing

```bash
cd ~/Documents/nanobrain

# 1. migrated v0.x sources still work
BRAIN_DIR=/tmp/sb-migrate bash code/skills/brain-ingest/dispatch.sh repos
grep '^context:' /tmp/sb-migrate/data/repos/INBOX.md
# Expect: every new entry has the header.

# 2. distill respects sensitivity inheritance
bash tests/test_distill_inheritance.sh

# 3. starter-brain validates
bash code/lib/validate_contexts.sh examples/starter-brain/brain/_contexts.yaml

# 4. ADR present and parseable
head -3 docs/adr/0017-multi-axis-tagging.md
# Expect: # ADR-0017 ... \n Status: accepted ...

# 5. smoke test
bash tests/e2e/smoke.sh
# Expect: smoke: PASS in <60s.

# 6. README sanity
grep -q "5-minute oh moment" README.md
grep -q "MIT" README.md
wc -l README.md
# Expect: under 250.

# 7. full suite
bash tests/run_all.sh
# Expect: every test green.
```

## Definition of done

- [ ] All three v0.x sources (claude, repos, granola) emit v1.0 entry headers.
- [ ] `STOP.md` and per-source `distill.md` files instruct sensitivity inheritance.
- [ ] `README.md` rewritten; under 250 lines; install one-liner present.
- [ ] `examples/starter-brain/` complete and validates green.
- [ ] `docs/adr/0017-multi-axis-tagging.md` merged.
- [ ] `tests/e2e/smoke.sh` runs in under 60s, asserts all 8 invariants.
- [ ] `install.sh --skip-cron` flag present.
- [ ] `tests/run_all.sh` green end-to-end.
- [ ] Private brain: `BRAIN_HASH.txt` regenerated; pre-commit hook armed; one real ingest cycle ran clean.

## Commit / push

Multi-commit, mostly public framework:

```bash
cd ~/Documents/nanobrain

git add code/sources/claude/ingest.sh code/sources/repos/ingest.sh code/sources/granola/ingest.sh \
        examples/_contexts.example.yaml code/lib/validate_contexts.sh
git commit -m "feat: migrate v0.x sources to multi-axis write_inbox (NBN-122)"

git add code/hooks/STOP.md code/sources/*/distill.md tests/test_distill_inheritance.sh
git commit -m "feat: distill propagates sensitivity, never demotes (NBN-123)"

git add README.md
git commit -m "docs: README rewrite — leak-and-capture wedge (NBN-124)"

git add examples/starter-brain
git commit -m "examples: starter-brain seed for v1.0 (NBN-125)"

git add docs/adr/0017-multi-axis-tagging.md
git commit -m "docs: ADR-0017 multi-axis tagging decision (NBN-126)"

git add tests/e2e install.sh
git commit -m "test: end-to-end smoke pipeline (NBN-127)"

git push
```

Then on the maintainer's machine, the private-corpus operational pass:

```bash
cd ~/your-brain
~/Documents/nanobrain/install.sh ~/your-brain
bash ~/Documents/nanobrain/code/skills/brain-hash/generate.sh > BRAIN_HASH.txt
git add BRAIN_HASH.txt
git commit -m "chore: regenerate BRAIN_HASH for v1.0 multi-axis schema"
git push
```

## Estimated time

6 hours. ~1.5h source migration + tests, ~1h STOP.md and per-source distill audits, ~1h README + starter-brain, ~30min ADR, ~1.5h smoke test (stubs, fixtures, --skip-cron flag), ~30min private-corpus operational pass.
