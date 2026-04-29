---
name: brain-log
description: Append a chronological line to brain/log.md for one operation.
---

# brain-log

Append-only operation log. Greppable. Format: `## [YYYY-MM-DD HH:MM] <op> | <title>`.

Other skills call this to record what they did, when. The log is the audit trail; brain/index.md is the catalog. Both are auto-generated artifacts (never hand-edit log.md beyond the header).

## Usage

```
log.sh <op> "<title>"
```

- `<op>`: short verb (capture, save, distill, ingest, compact, scrub, spawn, evolve, checkpoint, index).
- `<title>`: free text, single line.

Examples:

```
log.sh save "Decided to pause Idaho-craig for Q3"
log.sh distill "gmail: 4 INBOX -> 3 brain files"
log.sh capture "Stop hook: 4 entries from claude session"
```

## Greppable

```
grep "^## \[" $BRAIN_DIR/brain/log.md | tail -10
grep "save"   $BRAIN_DIR/brain/log.md
```

## Header

On first call, the file is created with a small header explaining the format.
