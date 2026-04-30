# Contributing

The highest-leverage contribution is a new source plugin. The pattern lives in `code/sources/gmail/` — copy it.

## Local setup

```bash
git clone https://github.com/siddsdixit/nanobrain
cd nanobrain
bash tests/run_all.sh   # ~30 sec on M-series Mac
```

## Adding a source

A source is one directory under `code/sources/<name>/` with:

- `ingest.sh` — pulls raw items into `data/<name>/INBOX.md`. Deterministic, redact-first, atomic.
- `fetch.sh` — pulls live data from the upstream API (called by ingest.sh when no stub env var is set).
- `distill.md` — the prompt the LLM sees during distill. LLM-only, idempotent.
- `README.md` — what the source captures and what fields it emits.
- `requires.yaml` — declares prerequisites (env vars, MCPs, binaries).

Add a matching `tests/test_<name>_ingest.sh` that pipes a fixture JSON through ingest and verifies the INBOX format.

## Style

- Bash 3.2 compatible. No `local` outside functions, no `[[ ]]`, quote everything.
- `set -eu` at the top of every script. `pipefail` only where it is correct.
- One sentence per commit message. Imperative mood. No "this commit ...".
- No em dashes anywhere (project convention).
- Use `code/lib/redact.sh` before any LLM call or persistent write.

## Tests

Every PR runs:

- The full test suite (`tests/run_all.sh`)
- The redact CI job (verifies known token formats are stripped)
- `shellcheck --severity=error` on all shell

Add a new `test_*.sh` for any new code path. Tests use `tests/_lib.sh` helpers — read it once.

## Pull requests

- Small, focused. One feature or one fix per PR.
- Reference an issue if there is one. Otherwise explain the user-visible reason.
- Update CHANGELOG.md under "Unreleased".

## Releasing

Maintainer-only for now. Tag with `v<major>.<minor>.<patch>`, update CHANGELOG, push tag.
