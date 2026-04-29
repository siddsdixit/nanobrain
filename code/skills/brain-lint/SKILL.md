# brain-lint

Quality report for a brain. No auto-fix.

## Usage

```
bash code/skills/brain-lint/lint.sh [--strict]
```

Reads `BRAIN_DIR` (default `$HOME/brain`).

## Checks

1. **Orphan pages.** Files in `brain/people/` or `brain/projects/` that no other brain
   file links to via `[[Entity]]`.
2. **Broken `[[refs]]`.** `[[Entity]]` references that resolve to neither a brain file
   nor a known per-entity page.
3. **TODO/FIXME markers.** Lines with `TODO`, `FIXME`, `XXX` in brain files (excludes
   `raw.md`, `log.md`, `_graph.md`, `index.md`).
4. **Duplicate entry headers.** The same `### YYYY-MM-DD HH:MM ...` line appearing more
   than once in one file.
5. **Missing context tag.** Entries without a `{context: ...}` block (warn only).

## Exit codes

- `0` always (issues are reported, not raised), unless `--strict`.
- `--strict`: exit `1` if any issue category has at least one finding.

## Output

Sectioned plain text. Empty sections are still printed with `(none)`.

## Logging

When a brain dir exists, appends `## [<ts>] lint | N issues` to `brain/log.md`.
