# SPRINT-08 — Pre-commit mirror, INBOX rotation, plist installer, brain-restore

## Goal

Wire the four operational properties that keep v1.0 honest in production: every brain edit mirrors to `raw.md` (S2a enforced at commit time), INBOX files don't bloat git (rotation by year), every per-source plist actually loads after `install.sh`, and users have a one-command rollback path.

## Stories

- **NBN-119** — pre-commit mirror enforcement hook (small)
- **NBN-120** — INBOX rotation helper (small)
- **NBN-121** — launchd plist installer (small)
- **NBN-110** — `/brain-restore` skill (medium)

## Pre-conditions

- SPRINT-04, SPRINT-05, SPRINT-06 merged (all five new plists exist; rotation needs sources to populate INBOXes).
- `install.sh` exists in v0.x form (we're extending, not replacing).

## Detailed steps

All paths in **public framework** (`~/Documents/nanobrain/`) unless noted.

### 1. NBN-119 — pre-commit mirror enforcement

#### Files

```
code/hooks/pre-commit/mirror-check.sh        # new
install.sh                                   # modify (symlink the hook into private brain's .git/hooks/pre-commit)
tests/test_mirror_hook.sh                    # new
```

#### `mirror-check.sh` behavior

Runs as git pre-commit hook in the **private brain repo** (symlinked by `install.sh`). The framework repo's own commits don't need it.

1. Honor bypass: `[ "${MIRROR_OK:-}" = "1" ]` → exit 0.
2. Get staged file set: `git diff --cached --name-only`.
3. Define `BRAIN_FILES_REGEX = '^brain/(self|goals|projects|people|learnings|decisions|repos)\.md$|^brain/(person|project|decision|concept)/[^/]+\.md$'`.
4. If any staged file matches `BRAIN_FILES_REGEX`, then `brain/raw.md` MUST also be staged. If not → exit 1 with message:

```
pre-commit mirror check FAILED.
You staged a brain edit but did not stage brain/raw.md (S2a).
Either stage brain/raw.md too, or set MIRROR_OK=1 git commit ... for documented bulk rewrites.
Staged brain files:
  brain/decisions.md
  brain/projects/forgepoint.md
```

5. If no brain files staged, no-op exit 0.
6. If brain files AND `brain/raw.md` both staged, exit 0.

#### `install.sh` change

After existing skill-symlink loop, add:

```bash
if [ -d "$BRAIN_DIR/.git" ]; then
  HOOK="$BRAIN_DIR/.git/hooks/pre-commit"
  TARGET="$FRAMEWORK_DIR/code/hooks/pre-commit/mirror-check.sh"
  if [ -e "$HOOK" ] && [ ! -L "$HOOK" ]; then
    mv "$HOOK" "$HOOK.local-backup-$(date +%s)"
  fi
  ln -sf "$TARGET" "$HOOK"
  chmod +x "$TARGET"
  echo "installed pre-commit mirror hook"
fi
```

Backup-on-replace honors S8 idempotency.

#### Test

`tests/test_mirror_hook.sh` creates a temp git repo, symlinks the hook, makes 3 cases:

- Stage `brain/decisions.md` only → commit fails, exit 1.
- Stage both files → exit 0.
- Stage `brain/decisions.md` only with `MIRROR_OK=1` → exit 0.

### 2. NBN-120 — INBOX rotation helper

#### Files

```
code/lib/rotate_inbox.sh        # new
tests/test_rotate.sh            # new
```

#### Decision (deviation from spec §2.2)

Spec said rotate when >10MB to `INBOX-YYYY-MM.md` monthly. Sprint ships **rotate by year** (`raw/<year>.md` in INBOX dir naming → `INBOX-2026.md`). Rationale: monthly rotation produces 12 files per source per year and clutters the dir; yearly + size-trigger gives clean history. Inline flag.

Trigger conditions (either):

- INBOX file >10MB (the spec threshold), OR
- New entry's year > the year of the INBOX file's first entry.

#### `rotate_inbox.sh` behavior

```
Usage: rotate_inbox.sh <source_dir>
```

1. Validate `<source_dir>/INBOX.md` exists.
2. `flock -x` on `<source_dir>/INBOX.md.lock` (same lock as `write_inbox.sh`).
3. Determine target name: scan first `### YYYY-` line; use that year. Target = `<source_dir>/INBOX-<year>.md`.
4. If target exists, append (with a `\n\n` separator); else `mv`.
5. Recreate empty `INBOX.md` (touch, ensure mode 644).
6. Watermark files left untouched (per spec §2.2).
7. Print: `rotated <source_dir>/INBOX.md → INBOX-<year>.md (size <N>MB)`.

Called manually for now. Optional: add a check in `write_inbox.sh` that triggers rotation when the new entry's year differs from existing first-entry year, gated by env `AUTO_ROTATE=1` (default off in v1.0; document in `ingest.md` per source). Inline flag — leaving auto-trigger off keeps v1.0 deterministic.

#### Test

`tests/test_rotate.sh`:

- Generate INBOX with 5 entries dated 2025 → rotate → `INBOX-2025.md` exists, fresh `INBOX.md` empty.
- Append to existing `INBOX-2025.md` and re-rotate → second rotation appends, doesn't clobber.
- Lock contention: spawn `( flock -x INBOX.md.lock; sleep 1 ) &`, then run rotate → blocks until lock free.

### 3. NBN-121 — launchd plist installer

#### Files

`install.sh` (modify).

#### Behavior

After symlinking skills and the pre-commit hook, walk `code/cron/*.plist` and:

1. For each plist, expand `<HOME>` placeholder to the real `$HOME` (use `sed` into a tempfile under `~/Library/LaunchAgents/<plist_name>`).
2. `launchctl unload` if already loaded (suppress error if not loaded).
3. `launchctl load -w ~/Library/LaunchAgents/<plist_name>`.
4. After loading all, run `launchctl list | grep nanobrain` and print the count + names. If any plist failed to load, print error but don't abort install (other plists may be fine).

Idempotency: re-running `install.sh` does unload-then-load every time, which is what we want.

Uninstall path: ship `install.sh --uninstall-cron` that walks the same list and `launchctl unload` + `rm` each. Document in README.

Plists touched by this installer:

- `com.nanobrain.compact.plist` (existing v0.x)
- `com.nanobrain.evolve.plist` (existing v0.x)
- `com.nanobrain.ingest.gmail.plist` (S04)
- `com.nanobrain.ingest.gcal.plist` (S05)
- `com.nanobrain.ingest.gdrive.plist` (S05)
- `com.nanobrain.ingest.slack.plist` (S06)
- `com.nanobrain.ingest.ramp.plist` (S06)

### 4. NBN-110 — `/brain-restore`

#### Files

```
code/skills/brain-restore/SKILL.md     # new
code/skills/brain-restore/restore.sh   # new
```

#### `SKILL.md` frontmatter

```yaml
---
name: brain-restore
description: Roll back to a prior brain state. Lists last 20 capture commits + pre-evolve tags, prompts to pick, checks out into a new branch (never reset --hard). Safe to run any number of times.
---
```

Body invokes `bash $HOME/brain/code/skills/brain-restore/restore.sh "$@"`.

#### `restore.sh` behavior

Per spec §3.6:

1. TTY check; exit 1 if non-interactive.
2. `cd "${BRAIN_DIR:-$HOME/brain}"`.
3. List candidates:
   - `git log --grep '^capture:' -n 20 --pretty=format:'%h  %ai  %s'`.
   - `git tag --list 'pre-evolve-*'` with `git log -1 --pretty=format:'%h  %ai' <tag>`.
4. Print numbered list (1..N). Prompt: "pick a number, or `q` to abort".
5. On valid pick: `BRANCH="restore/$(date +%s)"`. `git checkout -b "$BRANCH" "$SHA"`.
6. Print:

```
restored to branch restore/1714239012.
inspect, then:
  git checkout main
  git merge restore/1714239012   # to apply
  git branch -D restore/1714239012  # to discard
```

7. Never run `git reset --hard`. Never delete branches. Never push.

#### Edge cases

- Brain dir not a git repo → exit 1 with actionable message.
- Brain dir dirty (uncommitted changes) → refuse with "commit or stash first; restore should start from a clean tree".
- Less than 20 captures → list whatever exists; tags still listed.
- User picks a sha that's already the current HEAD → still create the branch (ergonomic; cheap; user can delete).

## Reference patterns

- `install.sh` (v0.x) for the existing skill-symlink and backup-on-replace pattern.
- `code/hooks/capture.sh` for the `MIRROR_OK` env-bypass idiom (used elsewhere).
- `code/cron/com.nanobrain.compact.plist` for plist shape; the installer's plist-name list comes from `ls code/cron/*.plist`.

## Testing

```bash
cd ~/Documents/nanobrain

# 1. mirror-check unit
bash tests/test_mirror_hook.sh
# Expect: 3/3 pass.

# 2. real-repo wiring
~/Documents/nanobrain/install.sh ~/your-brain
ls -l ~/your-brain/.git/hooks/pre-commit
# Expect: symlink → code/hooks/pre-commit/mirror-check.sh

# 3. live mirror enforcement (in private brain)
cd ~/your-brain
echo "test edit" >> brain/decisions.md
git add brain/decisions.md
git commit -m "test"
# Expect: exit 1, "pre-commit mirror check FAILED".
git checkout brain/decisions.md   # revert

# 4. rotation
bash tests/test_rotate.sh

# 5. plist installer
launchctl list | grep nanobrain
# Expect: 7 entries (2 v0.x + 5 v1.0 sources).

# 6. brain-restore dry run
cd ~/your-brain
bash ~/Documents/nanobrain/code/skills/brain-restore/restore.sh
# Expect: numbered list of capture commits + pre-evolve tags. Pick `q` to abort.
```

## Definition of done

- [ ] `mirror-check.sh` rejects unmirrored brain edits, accepts paired edits, honors `MIRROR_OK=1`.
- [ ] `install.sh` symlinks the hook (with backup-on-replace) and updates pre-commit on re-run.
- [ ] `rotate_inbox.sh` rotates by year, locks correctly, idempotent on re-rotation.
- [ ] `install.sh` loads all 7 plists; `launchctl list | grep nanobrain` shows them.
- [ ] `install.sh --uninstall-cron` cleanly unloads and removes plists.
- [ ] `/brain-restore` lists captures + tags, creates a new branch, never destroys history.
- [ ] All four `tests/test_*.sh` from this sprint green.

## Commit / push

Four commits, public framework only:

```bash
cd ~/Documents/nanobrain

git add code/hooks/pre-commit/mirror-check.sh tests/test_mirror_hook.sh
git commit -m "feat: pre-commit mirror enforcement hook (NBN-119)"

git add code/lib/rotate_inbox.sh tests/test_rotate.sh
git commit -m "feat: yearly INBOX rotation helper (NBN-120)"

git add install.sh
git commit -m "feat: install.sh wires all per-source plists + pre-commit hook (NBN-121)"

git add code/skills/brain-restore/
git commit -m "feat: /brain-restore as thin git wrapper (NBN-110)"

git push
```

After push, on the maintainer's machine:

```bash
~/Documents/nanobrain/install.sh ~/your-brain
```

This is the operational moment everything goes live: hook armed, plists loaded.

## Estimated time

6 hours. ~1h mirror hook + test, ~1h rotation + test, ~2h plist installer (idempotency, uninstall path, error handling), ~1.5h brain-restore (interactive flow, all edge cases), ~30min full integration on real brain.
