---
name: brain-redact
description: Scrub a leaked secret from the brain corpus AND from git history. Rewrites history, force-pushes, and logs the redaction. Last-resort fix when a secret slipped past capture.sh's redact.sh filter.
---

# /brain-redact

When a secret accidentally lands in `brain/raw.md` or any tracked file, the normal "no file deletion" rule (S4) leaves you stuck. This skill is the documented escape hatch.

## When to use

- A `sk-...` / `ghp_...` / password / bearer token shows up in `brain/raw.md` or any committed file.
- You ran `grep -r 'sk-' brain/` and found a hit.
- You're rotating a secret AND need the old value out of history before the rotation grace period ends.

## When NOT to use

- For plain content you want to remove. Use `git revert` or move the entry to `brain/archive/` per S4.
- On a brain repo that other people clone. History rewrite breaks their clones; coordinate first.

## Steps

### 1. Identify the pattern

Be precise. The redact pattern must match the secret AND nothing else important.

```bash
# Find every match across history (not just current state)
git -C $HOME/brain log -p --all -S '<exact-secret-prefix>' | head -30
```

If the matches look correct, proceed. If they include unrelated content, narrow the regex first.

### 2. Run the redact

```bash
bash $HOME/brain/code/skills/brain-redact/redact.sh '<regex-pattern>'
```

The script:
1. Verifies `git filter-repo` is installed (or falls back to `git filter-branch`).
2. Snapshots the current HEAD into `$STATE_DIR/redact-backup-<timestamp>` for emergency rollback.
3. Rewrites every commit, replacing the pattern with `<<REDACTED:secret>>`.
4. Force-pushes to origin.
5. Appends a one-line entry to `$XDG_STATE_HOME/nanobrain/redactions.log` (date + commit count + which files, never the secret itself).

### 3. Rotate the underlying secret

History rewrite removes the secret from the repo, but anyone who cloned before the rewrite still has it. Always rotate the underlying credential at the source (Anthropic dashboard, AWS IAM, GitHub PAT page, etc.).

### 4. Notify collaborators

If anyone else clones your brain repo, tell them to re-clone or run:

```bash
git fetch origin
git reset --hard origin/main
```

Otherwise their local history retains the secret.

## Hard rules

- **Never log the secret value.** The redaction log records WHEN and WHAT FILES, never the secret itself.
- **Always backup before rewrite.** The backup directory holds the pre-rewrite HEAD for 30 days.
- **Always rotate the secret externally.** Repo redaction is not credential rotation.
- **Refuse to run on `main` if uncommitted changes exist.** Stash or commit first.

## Why this is a separate skill

The mirror rule (S2a) says every brain write also lands in raw.md. That makes raw.md the firehose. But raw.md is shell-append-only and compaction-protected (S3a) — there's no normal edit path. Without `/brain-redact`, a leaked secret would be permanent.

## Linked

- `code/hooks/redact.sh` — the inline filter that runs on every capture (defense in depth)
- `code/SAFETY.md` — invariants S2, S2a, S3a, S4, S5
- ADR-0011 (mirror rule), ADR-0012 (compaction-protected files)
