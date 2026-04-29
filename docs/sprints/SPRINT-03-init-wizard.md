# SPRINT-03 — `/brain-init` wizard

## Goal

Ship the iterative onboarding wizard that writes the user's first `brain/_contexts.yaml`. This is the single biggest UX surface in v1.0; the 5-minute magic moment depends on it. Single-story sprint because the prompts are subtle (single-account fast path, idempotent re-run, `--add-context` mode) and one bug here ruins onboarding for every new user.

## Stories

- **NBN-106** — `/brain-init` skill (single, large)

## Pre-conditions

- SPRINT-01 (validator must run after wizard writes the file).
- SPRINT-02 (wizard re-runs `/brain-doctor` internally to detect MCPs).

## Detailed steps

All paths in **public framework** (`~/Documents/nanobrain/`).

### 1. Files to create

- `~/Documents/nanobrain/code/skills/brain-init/SKILL.md`
- `~/Documents/nanobrain/code/skills/brain-init/wizard.sh`

### 2. `SKILL.md` frontmatter

```yaml
---
name: brain-init
description: Iterative wizard to create or extend brain/_contexts.yaml. Detects MCPs, walks contexts, writes the file, optionally bootstraps detected sources. Idempotent: re-run prompts add-context mode.
---
```

Body: instructs Claude Code to invoke `bash $HOME/brain/code/skills/brain-init/wizard.sh "$@"` and surface its output. Important: this is **interactive**. Document that the user must run it from a terminal; if invoked from inside a non-interactive context, the wizard checks `[ -t 0 ]` and refuses with a one-line message.

### 3. `wizard.sh` behavior

**Args:**

- `--force` — overwrite existing `_contexts.yaml` (destructive; confirm twice).
- `--add-context [name]` — skip the file-exists check; jump to the per-context loop.
- `--non-interactive` — env-driven defaults for testing (see step 9).

**Flow:**

1. **TTY check:** `[ -t 0 ] && [ -t 1 ]` else exit 1 with "run /brain-init from a terminal".
2. **Internal doctor probe:** call `bash $HOME/brain/code/skills/brain-doctor/check.sh` and capture which MCPs are configured. Stash the list in a local var `DETECTED_MCPS`.
3. **File-exists branch:**
   - `_contexts.yaml` missing → "create" branch.
   - exists + no flag → prompt: "`_contexts.yaml` already present. Add a context? [Y/n], or pass --force to overwrite." Default Y goes to add-context mode.
   - exists + `--force` → prompt twice: "This will OVERWRITE existing contexts. Type the literal word `overwrite` to confirm:". On mismatch, exit 2.

4. **Single-account fast path** (only in create branch):
   - Probe: count Gmail accounts (one MCP server == one account assumption), count Slack workspaces, count gcal calendars the user owns.
   - If all are ≤1 and no other multi-account signals: prompt "Looks like one Gmail, one Slack workspace. Tag everything `personal`? [Y/n]". If Y, write a minimal `_contexts.yaml` with one `personal` context and resolvers that map the detected account/team_id to `personal`. Skip the loop. Jump to step 8.

5. **Per-context loop** (create branch beyond fast path, or add-context mode):

   ```
   Add a context.
     Name? (e.g. work, client-acme, side-proj-a) > _
     Sensitivity default? [public / private / confidential, default private] > _
     Ownership? [mine / employer:<slug> / client:<slug> / skip, default skip] > _
     Description (optional, free text) > _

   Add resolvers (press enter to skip any):
     gmail: sender domain regex (e.g. bigco\.com$) > _
     gmail: specific account email > _
     gcal: calendar id (e.g. sid@bigco.com) > _
     gdrive: folder path glob (e.g. /BigCo/**) > _
     slack: team_id (e.g. T_BIGCO) > _
     slack: channel-name regex override > _
     ramp: account id > _
     repos: github owner login > _

   Add another context? [y/N] > _
   ```

   For each filled-in resolver field, append the appropriate entry to the in-memory YAML structure. For unfilled, skip.

6. **`--add-context` mode** is the same loop but skips step 4 and reads the existing file first so new contexts append without rewriting prior entries. Use `yq -i` to add keys; never blat the whole file. Preserve user-edited comments by reading the file as text and inserting structured edits at the right location (use `yq -i '. *= load("/dev/stdin")'` pattern).

7. **Write** the file:
   - Validate via `bash code/lib/validate_contexts.sh /tmp/contexts.draft.yaml`. On failure, print errors and re-prompt the offending field.
   - Atomic write: tempfile + `mv`.
   - File ends with newline (per SPEC §2.1).
   - Backup any prior version to `<brain>/brain/_contexts.yaml.local-backup-<timestamp>` (S8 idempotency convention).

8. **Bootstrap offer** (always): for every source where `data/<source>/.watermark` is missing AND the source's MCP is in `DETECTED_MCPS`:
   - Prompt: "Bootstrap `<source>` now? (pulls last <window>) [Y/n]"
   - On Y: invoke `bash $HOME/brain/code/skills/brain-ingest/dispatch.sh <source> --bootstrap`.
   - On n: continue.

9. **Non-interactive mode** (`--non-interactive` for tests, NOT a user feature):
   - Read all answers from env vars: `BI_CONTEXT_NAME`, `BI_SENSITIVITY`, `BI_OWNERSHIP`, `BI_GMAIL_DOMAIN`, etc. Single-context only. Skip bootstrap.
   - Used by NBN-127 smoke test.

10. **Output on success:**
    ```
    wrote: $HOME/brain/brain/_contexts.yaml
    contexts: 3 (personal, work, side-proj-a)
    resolvers: gmail=2, gcal=1, gdrive=2, slack=2, ramp=1, repos=2
    next: /brain-doctor
    ```

### 4. Edge cases the wizard must handle

- User types empty name → re-prompt.
- User types name with spaces or uppercase → reject, suggest lowercase-slug version.
- User types `ownership: employer` without slug → reject, require `employer:<slug>`.
- File exists but malformed (validator fails) → wizard refuses to add-context; suggests `--force` after manual fix.
- Ctrl-C mid-loop → exit 2, no partial file written (we built in /tmp).

## Reference patterns

- `code/skills/brain-checkpoint/SKILL.md` for skill body shape.
- `code/sources/repos/ingest.sh` for `set -euo pipefail` and atomic-mv-watermark pattern (apply same to the YAML write).
- `code/install.sh` for `.local-backup-<timestamp>` naming convention.

## Testing

```bash
cd ~/Documents/nanobrain
# 1. Fast-path test
rm -rf /tmp/sb && BRAIN_DIR=/tmp/sb mkdir -p /tmp/sb/brain
yes Y | BRAIN_DIR=/tmp/sb bash code/skills/brain-init/wizard.sh
# Expect: minimal _contexts.yaml with personal, validates green.

# 2. Idempotency
BRAIN_DIR=/tmp/sb bash code/skills/brain-init/wizard.sh
# Expect: prompt "_contexts.yaml already present. Add a context?"

# 3. Force-overwrite without confirmation
echo "wrong" | BRAIN_DIR=/tmp/sb bash code/skills/brain-init/wizard.sh --force
# Expect: exit 2, file unchanged.

# 4. Non-interactive (used by smoke test)
rm -rf /tmp/sb2 && BRAIN_DIR=/tmp/sb2 mkdir -p /tmp/sb2/brain
BI_CONTEXT_NAME=work BI_SENSITIVITY=confidential BI_OWNERSHIP=employer:bigco \
  BI_GMAIL_DOMAIN='bigco\.com$' BRAIN_DIR=/tmp/sb2 \
  bash code/skills/brain-init/wizard.sh --non-interactive
bash code/lib/validate_contexts.sh /tmp/sb2/brain/_contexts.yaml
# Expect: OK: 1 contexts, 1 resolvers
```

## Definition of done

- [ ] Fast path writes a valid file in one keystroke when single Gmail + single Slack detected.
- [ ] Iterative loop appends without rewriting prior entries.
- [ ] `--force` requires typing `overwrite` literally; mismatch exits 2.
- [ ] Validator runs before file commit; failure re-prompts.
- [ ] Backup-on-overwrite convention honored.
- [ ] Bootstrap offer per detected MCP, always optional.
- [ ] `--non-interactive` env-driven mode works for smoke test.
- [ ] `chmod +x wizard.sh`.

## Commit / push

```bash
cd ~/Documents/nanobrain
git add code/skills/brain-init/
git commit -m "feat: /brain-init iterative wizard for _contexts.yaml"
git push
```

## Estimated time

6 hours. ~1h skill scaffold, ~3.5h interactive loop with all edge cases, ~1h non-interactive mode and tests, ~30min bootstrap offer integration.
