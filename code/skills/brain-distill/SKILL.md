# brain-distill

Reads INBOX entries for a source, calls `claude -p` with the source's `distill.md`, parses the result into typed blocks, and writes:

1. each block to its declared `target_path` (must be one of `brain/decisions.md`, `brain/learnings.md`, `brain/people.md`, `brain/projects.md`)
2. a full mirror copy of the same content to `brain/raw.md`
3. a single git commit covering all writes

For deterministic tests set `NANOBRAIN_DISTILL_STUB` to a file containing pre-formatted distill output (block format described in each source's `distill.md`).

Run: `bash code/skills/brain-distill/dispatch.sh <source>`
