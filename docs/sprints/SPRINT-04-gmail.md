# SPRINT-04 — Gmail source (end-to-end first source)

## Goal

Ship the first new v1.0 source end to end. Gmail is the highest-signal, highest-risk source (most secrets, biggest volume, two-pass bootstrap), so doing it first proves the foundations from S01/S02 hold and pins the per-source template every later sprint copies. After this sprint a real user with Gmail MCP configured can run `/brain-ingest gmail --bootstrap` and see tagged messages flow into `data/gmail/INBOX.md`.

## Stories

- **NBN-111** — gmail source (single, large; end-to-end)

## Pre-conditions

- SPRINT-01 merged (`resolve_context.sh`, `write_inbox.sh`, extended `redact.sh`).
- SPRINT-02 merged (`/brain-ingest` dispatcher will hand off to `code/sources/gmail/ingest.sh`).
- `mcp__claude_ai_Gmail__*` MCP server configured in `~/.claude/.mcp.json` on the dev machine (verify via `/brain-doctor`). If absent, sprint can still ship by mocking with `tests/mocks/mcp_gmail.sh`.

## Detailed steps

All paths in **public framework** (`~/Documents/nanobrain/`). No private-corpus changes this sprint.

### 1. Create the source directory

```
~/Documents/nanobrain/code/sources/gmail/
  ingest.sh
  ingest.md
  distill.md
  requires.yaml
  context_resolver.sh
  test_resolver.sh
~/Documents/nanobrain/code/cron/com.nanobrain.ingest.gmail.plist
~/Documents/nanobrain/tests/mocks/mcp_gmail.sh
~/Documents/nanobrain/tests/integration/gmail.sh
```

Copy `code/sources/repos/ingest.sh` as the starting skeleton (style, `set -euo pipefail`, watermark-mv pattern).

### 2. `requires.yaml`

```yaml
source: gmail
mcp: claude_ai_Gmail
binaries: [yq, jq]
windows:
  bootstrap_work_days: 9
  bootstrap_personal_days: 1095   # ~3 years; spec §5.1 said 2y, lifted to 3y to capture longer-cycle relationships. Inline-flag.
cadence:
  cron_expr: "0 9,13,17 * * 1-5"  # weekdays 09/13/17 local; matches plist
  spec_note: "Spec §5.1 says every 4h 09:00-19:00 weekdays; three runs cover the window with margin."
```

Inline flag: spec said 2y personal window, sprint ships 3y. Keep editable in `requires.yaml`; install.sh can later thread to `_contexts.yaml` if user wants per-context overrides. Not building per-context windows in v1.0.

### 3. `context_resolver.sh`

Thin wrapper, ~12 lines. Reads sender domain (extract via `awk -F@ '{print tolower($2)}'`), recipient account, calls `code/lib/resolve_context.sh gmail "<domain>" "<account>"`. Output passes through unchanged (tab-separated tuple).

```bash
#!/usr/bin/env bash
# Usage: context_resolver.sh <sender_email> <recipient_email>
set -euo pipefail
SENDER="${1:-}"
RECIP="${2:-}"
DOMAIN="$(printf '%s' "$SENDER" | awk -F@ 'NF>1{print tolower($2)}')"
exec bash "${BRAIN_FRAMEWORK:-$HOME/.nanobrain}/code/lib/resolve_context.sh" gmail "$DOMAIN" "$RECIP"
```

Use `BRAIN_FRAMEWORK` env (set by install.sh symlinks) so the framework path is discoverable regardless of where the source script is symlinked from.

### 4. `test_resolver.sh`

Table-driven, fixture `_contexts.yaml` from `examples/_contexts.example.yaml`. Cases:

- `vc@firm.com` recipient `founder@side-proj-a.com` → `side-proj-a\tconfidential\tmine`.
- `cfo@bigco.com` recipient `sid@gmail.com` → `work\tconfidential\temployer:bigco`.
- `friend@gmail.com` recipient `sid@gmail.com` → `personal\tprivate\tunset`.
- `noreply@github.com` → still classified, but distill.md drops it. Resolver returns `personal\tprivate\tunset`. (The `noreply` filter lives in `ingest.sh` pre-filter, not the resolver.)

### 5. `ingest.sh` — the meat

**Two-pass bootstrap design:**

- **Pass 1 (foreground):** if `--bootstrap` and no `.watermark` exists, query last 9 days of Gmail across all labels, append everything that survives the pre-filter. Write `.watermark = now()` (ISO 8601 UTC). User sees this finish in the foreground.
- **Pass 2 (background):** if `--bootstrap`, fork `( pass2 ) &` and `disown`. Pass 2 queries last 1095 days (window from `requires.yaml`), throttled in chunks of 200 messages, with `sleep 30` between chunks to avoid MCP rate limits. Pass 2 writes to a separate watermark `data/gmail/.watermark.pass2` so its progress doesn't fight Pass 1. On completion, Pass 2 deletes its own watermark file (signal: bootstrap drained).
- **Incremental (no `--bootstrap`):** read `.watermark`, query messages with `internalDate > .watermark`, append, advance watermark.

**Per-message processing loop:**

1. Fetch metadata (`mcp__claude_ai_Gmail__list_messages` then `get_message` with `format=METADATA`).
2. **Pre-filter (drop early, never reaches resolver/INBOX):**
   - sender matches `noreply|notifications|automated|newsletter` (case-insensitive)
   - sender domain in hardcoded set: `github.com, atlassian.com, slack.com, dropbox.com, calendly.com, eventbrite.com, mailchimp.com, sendgrid.net`
   - subject starts with `[NEWSLETTER]` or contains `unsubscribe` AND no human-author signal in From header
3. If filtered, skip silently, advance per-message cursor only (not watermark — watermark advances at run end).
4. Otherwise, fetch full message (`format=FULL`), extract body (prefer `text/plain` MIME part; fall back to stripping HTML via `awk` regex; cap 500 chars).
5. Call `context_resolver.sh "$FROM" "$TO"` → `CONTEXT, SENSITIVITY, OWNERSHIP`.
6. Call `code/lib/write_inbox.sh` with env: `INBOX, SOURCE=gmail, SUBJECT, CONTEXT, SENSITIVITY, OWNERSHIP, SOURCE_ID=<Message-ID>, BODY=<piped on stdin>`.
7. Increment counters: `appended_count`, `filtered_count`, `redacted_count` (read from `write_inbox.sh` stderr).

**Two-pass bootstrap UX (Pass 1 stdout, foreground):**

```
ingest gmail: bootstrap pass 1 (9d work window)
  fetched 312 messages, filtered 218 (noreply/newsletter), appended 94
  watermark advanced to 2026-04-27T18:42:00Z
  pass 2 (1095d, all contexts) running in background; tail data/gmail/.pass2.log to monitor
```

Pass 2 logs to `data/gmail/.pass2.log` (line-per-chunk: `chunk N: appended X, throttle 30s`). Lock file `data/gmail/.pass2.lock` prevents multiple concurrent Pass 2 runs.

**Exit codes** (spec §3.3): 0 success / no new, 2 lock held, 3 MCP missing, 4 auth expired (detect via MCP error code or "invalid_grant" string match).

### 6. `ingest.md`

Human-readable spec for the source. ~60 lines. Sections:

- What this source pulls (Gmail messages, both directions)
- Bootstrap windows and cadence
- Pre-filter rules (the noreply/newsletter list above; document so users can edit)
- Pass 1 vs Pass 2 design rationale
- Privacy: redact runs in `write_inbox.sh`; Gmail-specific redaction (signature blocks, image alt text) NOT applied in v1.0 — body cap of 500 chars makes this low-risk

### 7. `distill.md`

System prompt for `claude -p`. ~80 lines. Routing rules:

- Investor or board correspondence → `brain/decisions.md` (decision-grade) + `brain/interactions.md` (always)
- Customer escalations or contracts → `brain/decisions.md`
- Recruiter outreach → `brain/people/<slug>.md` (create if missing) + `brain/interactions.md`
- Personal correspondence with named contact → `brain/people/<slug>.md` + `brain/interactions.md`
- Receipts, calendar invites, automated mail that survived pre-filter → drop (no route, INBOX-only)

Output format: each routed entry delimited by `>>>` line, then `target_path: brain/<file>.md`, then the markdown block (with frontmatter inheriting `context`, `sensitivity`, `ownership` from the INBOX entry).

Reference: copy structure of `code/sources/granola/distill.md`, swap rules.

### 8. launchd plist `com.nanobrain.ingest.gmail.plist`

Standard structure (clone `code/cron/com.nanobrain.compact.plist`):

- Label: `com.nanobrain.ingest.gmail`
- ProgramArguments: `/bin/bash`, `<HOME>/.nanobrain/code/skills/brain-ingest/dispatch.sh`, `gmail`
- StartCalendarInterval: array of 5 dicts, one per (Hour=9/13/17, Weekday=1/2/3/4/5). Decision: ship 3-per-day on weekdays. Spec said every 4h 09-19; three runs cover the window with margin and reduce MCP load.
- StandardOutPath / StandardErrorPath: `<HOME>/Library/Logs/nanobrain/ingest.gmail.log`
- RunAtLoad: false (don't run at boot; let user decide)

Install path expansion handled by `install.sh` (S08).

### 9. Mock MCP for testing (`tests/mocks/mcp_gmail.sh`)

Tiny shell script that, given the same arg signature as the MCP, returns canned JSON from `tests/integration/fixtures/gmail/messages_*.json`. Three fixtures: an investor email, a noreply newsletter, a personal note. Used by integration test.

### 10. Integration test (`tests/integration/gmail.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail
F=/tmp/sb-gmail-test
rm -rf "$F" && mkdir -p "$F/brain" "$F/data/gmail"
cp examples/_contexts.example.yaml "$F/brain/_contexts.yaml"
export BRAIN_DIR=$F MCP_GMAIL_MOCK=1 BRAIN_FRAMEWORK="$PWD"

# bootstrap (mock returns 3 messages)
bash code/sources/gmail/ingest.sh --bootstrap

# assertions
[ "$(grep -c '^### ' "$F/data/gmail/INBOX.md")" = "2" ] || { echo "expected 2 entries (1 filtered)"; exit 1; }
grep -q '^context: side-proj-a' "$F/data/gmail/INBOX.md" || { echo "missing side-proj-a tag"; exit 1; }
grep -q '^context: personal' "$F/data/gmail/INBOX.md" || { echo "missing personal tag"; exit 1; }
! grep -q 'newsletter' "$F/data/gmail/INBOX.md" || { echo "newsletter leaked"; exit 1; }
[ -f "$F/data/gmail/.watermark" ] || { echo "watermark not written"; exit 1; }
echo "OK"
```

## Reference patterns

- `code/sources/granola/ingest.sh` — closest analog (richer-than-repos source, body extraction, distill routing).
- `code/sources/repos/ingest.sh` — watermark-mv idempotency, exit-0-on-tool-missing.
- `code/cron/com.nanobrain.compact.plist` — plist boilerplate.
- For background fork pattern: `( cmd ) & disown` and `flock -n` on a lockfile.

## Testing

```bash
cd ~/Documents/nanobrain

# 1. resolver unit tests
bash code/sources/gmail/test_resolver.sh
# Expect: all 4 cases pass.

# 2. integration with mocked MCP
bash tests/integration/gmail.sh
# Expect: OK.

# 3. dispatcher hand-off
BRAIN_DIR=/tmp/sb-gmail-test bash code/skills/brain-ingest/dispatch.sh gmail
# Expect: exit 0, "ingest gmail: 0 appended" (watermark already advanced).

# 4. real-MCP smoke (only on a machine with Gmail MCP configured)
BRAIN_DIR=$HOME/your-brain bash code/skills/brain-ingest/dispatch.sh gmail --bootstrap
# Expect: 9-day window pulled, Pass 2 forked into background, INBOX populated.
tail data/gmail/.pass2.log
# Expect: chunked progress.

# 5. exit code 4 on auth expired (manual: revoke MCP token, retry)
```

## Definition of done

- [ ] `code/sources/gmail/{ingest.sh, ingest.md, distill.md, requires.yaml, context_resolver.sh, test_resolver.sh}` all present.
- [ ] `chmod +x` on `ingest.sh`, `context_resolver.sh`, `test_resolver.sh`.
- [ ] Resolver test passes all 4 cases.
- [ ] Integration test (`tests/integration/gmail.sh`) green.
- [ ] Pre-filter drops noreply/newsletter before resolver/INBOX (asserted by integration test).
- [ ] Two-pass bootstrap: Pass 1 foreground, Pass 2 backgrounded with separate watermark and log.
- [ ] `redact.sh` runs (verified by injecting `sk-test123abc456def789` in mock fixture; INBOX shows `[REDACTED]`).
- [ ] launchd plist syntactically valid (`plutil -lint code/cron/com.nanobrain.ingest.gmail.plist`).
- [ ] Real-MCP smoke ran once on the maintainer's machine; confirmed INBOX entries with correct multi-axis tags.

## Commit / push

Single commit, public framework only:

```bash
cd ~/Documents/nanobrain
git add code/sources/gmail code/cron/com.nanobrain.ingest.gmail.plist tests/mocks/mcp_gmail.sh tests/integration/gmail.sh
git commit -m "feat: gmail source with two-pass bootstrap + multi-axis tagging (NBN-111)"
git push
```

No private-corpus changes this sprint. The plist won't load until S08 wires `install.sh`.

## Estimated time

6 hours. ~2h ingest.sh including pre-filter and two-pass logic, ~1h distill.md routing rules, ~1h resolver + test, ~1h mock + integration test, ~30min plist + ingest.md, ~30min real-MCP smoke and tuning.
