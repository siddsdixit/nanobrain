---
name: brain-redact
description: Scan brain for leaked secrets, or scrub a regex from git history.
---

# /brain-redact

## Modes

- `--scan` (default): grep `brain/` for secret patterns. Prints matches with file:line. Exit 0 if clean, 1 if matches found.
- `--scrub <regex>`: rewrite git history with `git filter-branch`. Dry-run unless `--force-push` is also passed. Refuses dirty working tree.

## Patterns

Same as `code/lib/redact.sh`: OpenAI sk-, AWS AKIA, GitHub gh[pousr]_, JWTs, Bearer tokens, password|token|api_key|secret assignments.

## Usage

```
redact.sh --scan
redact.sh --scrub 'sk-[A-Za-z0-9]{20,}'              # dry run
redact.sh --scrub 'sk-[A-Za-z0-9]{20,}' --force-push # actually rewrite + push
```

## Honors

- `BRAIN_DIR` env (default `$HOME/brain`).
