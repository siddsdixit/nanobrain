# SPRINT-01 — Foundations

## Goal

Lay the four shared libraries every v1.0 source will call: a YAML schema + validator for `brain/_contexts.yaml`, an extended `redact.sh`, a deterministic context resolver, and a single `write_inbox.sh` helper. By end of day, no source code exists yet but every primitive a source will need is in place and unit-tested.

## Stories

- **NBN-101** — `_contexts.yaml` schema + `validate_contexts.sh`
- **NBN-102** — extend `redact.sh` to handle multi-axis entry headers
- **NBN-103** — `code/lib/resolve_context.sh` (shared resolver)
- **NBN-104** — `code/lib/write_inbox.sh` (shared INBOX append helper)

## Pre-conditions

- `~/Documents/nanobrain/` cloned, branch `main` clean.
- `yq` installed (`brew install yq`); `jq` already required by v0.x.

## Detailed steps

All paths are in the **public framework** repo (`~/Documents/nanobrain/`) unless noted.

### 1. NBN-101 — schema + validator

**Files to create:**

- `~/Documents/nanobrain/examples/_contexts.example.yaml`
- `~/Documents/nanobrain/code/lib/validate_contexts.sh`
- `~/Documents/nanobrain/tests/test_validate_contexts.sh`

**Schema** — paste verbatim into `_contexts.example.yaml`:

```yaml
version: 1
contexts:
  personal:
    sensitivity_default: private
    description: Default catch-all for solo content.
  work:
    sensitivity_default: confidential
    ownership: employer:bigco
    description: Day-job content. Maps to bigco.com domain.
  side-proj-a:
    sensitivity_default: confidential
    ownership: mine
    description: Personal venture; investor and customer correspondence.

resolvers:
  gmail:
    - match: { domain: "bigco\\.com$" }
      context: work
    - match: { account: "founder@side-proj-a.com" }
      context: side-proj-a
  gcal:
    - match: { calendar_id: "sid@bigco.com" }
      context: work
  gdrive:
    folder_overrides:
      - match: { path_glob: "/BigCo/**" }
        context: work
      - match: { path_glob: "/Personal/sideproj-a/**" }
        context: side-proj-a
  slack:
    workspace:
      - match: { team_id: "T_BIGCO" }
        context: work
    channel_overrides:
      - match: { team_id: "T_BIGCO", channel_name: "^random$" }
        context: personal
  ramp:
    - match: { account: "bigco-ramp" }
      context: work
  repos:
    - match: { owner: "siddsdixit" }
      context: personal
    - match: { owner: "bigco" }
      context: work

defaults:
  context: personal
  sensitivity: private
  ownership: unset
```

**Validator** (`code/lib/validate_contexts.sh`) — required behavior:

1. Take a path argument (default `$BRAIN_DIR/brain/_contexts.yaml`).
2. Confirm file exists and ends with newline.
3. Use `yq` to assert `version` is integer and equals 1.
4. Collect every `context: <name>` referenced under `resolvers.*` (recursively). For each, confirm it appears as a top-level key under `contexts:`. Unknown reference → exit 1 with line number from `yq --line-numbers`.
5. For each `contexts.<name>.sensitivity_default`, assert value ∈ {public, private, confidential}.
6. For each `contexts.<name>.ownership` (when present), assert it matches `^(mine|employer:.+|client:.+)$`.
7. Detect duplicate keys via `yq -e '.contexts | keys | length' == ... | unique | length`.
8. On success: print `OK: N contexts, M resolvers` (count distinct resolver entries) and exit 0.

**Test harness** (`tests/test_validate_contexts.sh`):

- Case A: valid example file → exit 0, prints OK.
- Case B: drop a referenced context, expect exit 1.
- Case C: invalid sensitivity value, expect exit 1.
- Case D: malformed YAML, expect exit 1.

### 2. NBN-102 — extend `redact.sh`

**Files to modify:** `~/Documents/nanobrain/code/hooks/redact.sh` (existing v0.x file).

**Verify** the current regex covers `password|passwd|pwd|token|api[_-]?key|secret|sk-[A-Za-z0-9]{20,}|Bearer\s+[A-Za-z0-9._-]+`. Add if missing: AWS access keys (`AKIA[0-9A-Z]{16}`), GitHub tokens (`gh[pousr]_[A-Za-z0-9]{36,}`), JWTs (`eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+`).

**Header preservation behavior** (new): redact must operate **per line** so that the structured header lines (`context:`, `sensitivity:`, `ownership:`, `source_id:`) pass through untouched as long as they don't contain a secret. Implement: read stdin line by line, run regex sub, count substitutions, write to stdout. Print `[redact] N substitutions` to stderr when N > 0.

**Files to create:** `~/Documents/nanobrain/tests/test_redact.sh` with cases:

- `sk-abc1234567890123456789012` → `[REDACTED]`, count 1.
- header `context: work` passes through unchanged.
- multiline body with secret in line 5 — only line 5 changes.

### 3. NBN-103 — `resolve_context.sh`

**Files to create:**

- `~/Documents/nanobrain/code/lib/resolve_context.sh`
- `~/Documents/nanobrain/tests/test_resolve_context.sh`

**Contract** (per ARCHITECTURE-v1.0 §1 and SPEC §4):

- Args: `$1=source` (gmail|gcal|gdrive|slack|ramp|repos), `$2=key`, `$3=key2` (optional).
- Reads `${BRAIN_DIR:-$HOME/brain}/brain/_contexts.yaml`. If missing, emit `[resolve_context] _contexts.yaml missing` to stderr **once per process** (use a `_RESOLVE_LOGGED` env flag) and return defaults.
- Cache `_contexts.yaml` content in a process-local variable so multiple invocations in the same ingest run don't re-read.
- Per source, walk the resolver list. **Slack only:** consult `channel_overrides` first (keyed on `team_id` + `channel_name` regex), then `workspace` (keyed on `team_id`). **gdrive only:** consult `folder_overrides` with glob via `case "$path" in $glob)`.
- On match: pull `sensitivity_default` and `ownership` from the named `contexts.<name>` block. If `ownership` absent, use `unset`.
- On no match: print to stderr `[resolver:<source>] no match for <key>` and return defaults from `defaults:` block (or hard-coded `personal\tprivate\tunset` if defaults absent).
- Output: `printf '%s\t%s\t%s\n' "$context" "$sensitivity" "$ownership"`.

**Implementation hint:** since the resolver runs many times per ingest, prefer one `yq -o=json` parse at startup into a JSON blob, then `jq` queries against the blob (in-memory). Avoid invoking `yq` per call.

**Test cases** (`test_resolve_context.sh`) — fixture `_contexts.yaml` is the example from NBN-101:

```bash
assert_eq() { [ "$1" = "$2" ] || { echo "FAIL: got '$1' want '$2'"; exit 1; }; }

# gmail domain match
assert_eq "$(BRAIN_DIR=$F bash code/lib/resolve_context.sh gmail bigco.com)" \
  "work	confidential	employer:bigco"

# slack channel override
assert_eq "$(BRAIN_DIR=$F bash code/lib/resolve_context.sh slack T_BIGCO random)" \
  "personal	private	unset"

# slack workspace fallback
assert_eq "$(BRAIN_DIR=$F bash code/lib/resolve_context.sh slack T_BIGCO eng)" \
  "work	confidential	employer:bigco"

# gdrive glob
assert_eq "$(BRAIN_DIR=$F bash code/lib/resolve_context.sh gdrive /BigCo/Strategy/x.md)" \
  "work	confidential	employer:bigco"

# no match → defaults
assert_eq "$(BRAIN_DIR=$F bash code/lib/resolve_context.sh gmail randomdomain.io)" \
  "personal	private	unset"
```

(Note: tab character literal between fields. Use `printf` or `$'\t'` in tests.)

### 4. NBN-104 — `write_inbox.sh`

**Files to create:**

- `~/Documents/nanobrain/code/lib/write_inbox.sh`
- `~/Documents/nanobrain/tests/test_write_inbox.sh`

**Contract:**

- Args (env-driven for clarity):
  - `INBOX` — full path to `data/<source>/INBOX.md`.
  - `SOURCE` — slug (gmail, gcal, ...).
  - `SUBJECT` — entry title (first line after timestamp).
  - `CONTEXT`, `SENSITIVITY`, `OWNERSHIP` — from resolver.
  - `SOURCE_ID` — stable upstream id.
  - `BODY` — the entry body (stdin if not env).
- Behavior:
  1. `flock -x` on `${INBOX}.lock`.
  2. Pipe body through `code/hooks/redact.sh`.
  3. Truncate body to 500 chars; append `...` if truncated.
  4. Compose entry exactly per SPEC §2.2:
     ```
     ### <YYYY-MM-DD HH:MM> — <source>: <subject>
     context: <ctx>
     sensitivity: <sens>
     ownership: <own>           # OMIT THIS LINE when ownership=unset
     source_id: <id>

     <body>
     ```
  5. Single `>>` append. No partial writes (build full block in a `printf` then redirect).
  6. Release lock.
- Idempotency: caller's responsibility (we don't dedupe by `source_id` here; ingest scripts do via watermark).

**Test cases** (`test_write_inbox.sh`):

- Basic write: result file contains the formatted block, exactly one `### ` line.
- Ownership=unset: the `ownership:` line is absent.
- Body with secret: redact ran (assert `[REDACTED]` in output).
- Two parallel `write_inbox.sh` calls (`&` then `wait`): both blocks present; no interleaved lines (use `grep -c '^### '` == 2).

## Reference patterns

- Existing `code/sources/repos/ingest.sh` is the closest precedent for the style: `set -euo pipefail`, ISO-8601 watermarks, `printf` for all writes, exit-0 on tool-not-found.
- `code/hooks/redact.sh` is already present — extend, don't replace.

## Testing

```bash
cd ~/Documents/nanobrain
bash tests/test_validate_contexts.sh
bash tests/test_redact.sh
bash tests/test_resolve_context.sh
bash tests/test_write_inbox.sh
```

Expected: each prints test names, all pass, exit 0.

Quick smoke:

```bash
BRAIN_DIR=/tmp/sb mkdir -p /tmp/sb/brain /tmp/sb/data/gmail
cp examples/_contexts.example.yaml /tmp/sb/brain/_contexts.yaml
bash code/lib/validate_contexts.sh /tmp/sb/brain/_contexts.yaml
# OK: 3 contexts, 11 resolvers

bash code/lib/resolve_context.sh gmail bigco.com
# work	confidential	employer:bigco
```

## Definition of done

- [ ] `examples/_contexts.example.yaml` committed and validates green.
- [ ] `code/lib/validate_contexts.sh` exits 0/1 per spec; line numbers on errors.
- [ ] `code/hooks/redact.sh` extended, all four new regex classes covered.
- [ ] `code/lib/resolve_context.sh` passes all five test cases including slack channel override and gdrive glob.
- [ ] `code/lib/write_inbox.sh` parallel-safe via flock; ownership=unset omits the line.
- [ ] All four `tests/test_*.sh` files run green via `bash tests/run_all.sh` (or individually if no runner exists yet — create `tests/run_all.sh` as a one-liner that loops `for f in tests/test_*.sh; do bash "$f" || exit 1; done`).
- [ ] `chmod +x` on every new `.sh` file.

## Commit / push

Single commit, public framework only:

```bash
cd ~/Documents/nanobrain
git add examples/_contexts.example.yaml code/lib/ code/hooks/redact.sh tests/
git commit -m "feat: v1.0 foundations (contexts schema, resolver, write_inbox)"
git push
```

No private-corpus changes this sprint.

## Estimated time

6 hours. NBN-103 is the longest piece (in-memory caching design). NBN-104 is mechanical once 103 lands. 101 and 102 are sub-1h each.
