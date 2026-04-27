# Distill protocol — repos

Triggered by `/brain distill repos` or weekly cron. Reads new entries from `data/repos/INBOX.md` and routes signal.

## Steps

1. **Read distill watermark.** `data/repos/.distill-watermark`.

2. **Tail new entries only.** Use awk or grep to extract blocks newer than watermark. Never `cat` the whole file.

3. **For each new repo block, route signal:**

   ### `brain/repos.md` updates
   - If repo is NEW (not in current `repos.md`): add a row to the right bucket. Pick bucket from repo name or description (active / paused / archived).
   - If repo is EXISTING: update its `last activity` date.
   - If repo hasn't been touched in 60+ days: flag as `stale, verify` in the row.

   ### `brain/projects.md` updates
   - If repo maps to an active project (cross-reference `brain/projects.md`): append a status note under that project section. Format: `_2026-04-26: pushed N commits to <branch> — <one-line summary of latest commit subject>_`
   - Cap status notes at 3 per project per distill run; collapse older ones.

   ### `brain/raw.md` mirror
   - Always append to `brain/raw.md` via shell:
     ```bash
     printf '\n\n### %s — repos — %s\n\n%s\n' "$(date +%Y-%m-%d\ %H:%M)" "<repo>" "<one-line summary>" >> $HOME/brain/brain/raw.md
     ```

4. **Update distill watermark.** Latest entry's timestamp.

5. **Commit:**
   ```bash
   cd $HOME/brain
   git add brain/ data/repos/.distill-watermark
   git -c user.email=you@example.com -c user.name="Your Name" \
     commit -m "distill repos: $(date +%Y-%m-%d) — N repos updated"
   git push
   ```

## Hard rules

- **Never `cat` the INBOX.** Always tail or awk-from-watermark.
- **Don't capture commit diffs or file contents.** Just metadata + commit subjects.
- **Don't capture private/sensitive repo descriptions.** If repo is `private` AND has no description, skip the description field.
- **Match the user's voice.** No em dashes. Short sentences.
- **Be conservative on `projects.md` updates.** Only cross-reference if the repo→project mapping is clear from `brain/repos.md`.

## Source-specific extraction

- Branch names matching `feat/`, `fix/`, `chore/` → status update for matching project
- Commit subjects matching `^(feat|fix|chore|docs|refactor|test):` → use the type as a project status hint
- `Signed-off-by:` or `Co-authored-by:` lines → potential new collaborator (flag for `brain/people.md` review)
- `BREAKING CHANGE:` in commit body → important enough to write to `brain/decisions.md`
