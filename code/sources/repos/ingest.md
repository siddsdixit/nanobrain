# Ingest protocol — repos

Triggered by `/brain ingest repos` or daily cron. Runs `ingest.sh`.

## What `ingest.sh` does

1. **Read watermark.** `data/repos/.watermark` holds the last-seen ISO timestamp. Default: 7 days ago.

2. **List repos owned/contributed-to:**
   ```bash
   gh repo list "$(gh api user --jq .login)" --limit 100 --json nameWithOwner,updatedAt,description,visibility,isArchived
   ```

3. **For each repo updated since watermark, append a block to `data/repos/INBOX.md`:**
   ```
   ### YYYY-MM-DD HH:MM — repos: <name> — <visibility>
   
   **Description:** <description or "(none)">
   **Last update:** <updatedAt>
   **Recent commits (since watermark):**
   - <sha7> <date> <author> <commit subject>
   - ...
   **Open branches:** <count, branch names>
   **Open PRs:** <count, titles>
   ```

4. **Local-clone repos:** if a repo has a known local path (`brain/repos.md` lists known paths), also include uncommitted changes status:
   ```
   **Local status:** <path> — <count modified, count untracked, current branch>
   ```

5. **Apply privacy filter** before writing. Regex strip patterns from `README.md`.

6. **Update watermark** to the latest commit time seen.

7. **Single shell-append write** to `data/repos/INBOX.md`. Never overwrite.

## When to rotate

If `INBOX.md` exceeds 10MB:
```bash
mv data/repos/INBOX.md data/repos/INBOX-$(date +%Y-%m).md
touch data/repos/INBOX.md
```

## Failure modes

- `gh` rate-limited → exit 0 silently, retry next run.
- Repo deleted / renamed → log to stderr, skip, continue.
- Local path missing → skip local-status section, still capture remote info.

## Output

One line on success:
```
ingest repos: N repos surveyed, M new commits, watermark advanced to <ts>
```
