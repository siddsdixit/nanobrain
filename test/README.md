# test/

Smoke test for the nanobrain framework. Runs in a tmpdir sandbox. Does NOT touch your real `~/.claude` or your private brain repo.

## Run

```bash
bash test/smoke.sh
```

First run installs the MCP SDK into `code/mcp-server/node_modules` (gitignored). Subsequent runs are fast.

## What it covers

| # | Test | Asserts |
|---|---|---|
| T1 | `install.sh` | symlinks 6 skills, CLAUDE.md, Stop hook in settings.json, idempotent re-run |
| T2 | recursion guard env var | `NANOBRAIN_CAPTURING=1` → exit 0 |
| T3 | recursion guard payload | `stop_hook_active=true` → exit 0 + log skip reason |
| T4 | throttle | sub-threshold delta → "throttle:" log entry |
| T5 | force capture | `FORCE_CAPTURE=1` invokes mock `claude`, logs "run: reason=force/Stop" |
| T6 | MCP server | starts, advertises `brain_search`, responds to `brain_status` |

## What it does NOT cover

- The MCP server tool implementations are stubs that return placeholder data. T6 only verifies wiring + protocol, not query correctness.
- Slash commands (`/brain`, `/brain-save`, etc.) live as markdown read by Claude Code at runtime. They are not script-testable; they need a real Claude session.
- Source plugins (granola, repos): the ingest scripts are platform-specific and not exercised here.
- Cron / launchd: covered by manual install, not in scope for the smoke test.

## Sandbox layout

```
$TMPDIR/nanobrain-smoke.XXXXXX/
├── brain/              ← copy of this repo, treated as the user's private brain
├── .claude/            ← faux ~/.claude where install.sh writes symlinks
├── bin/claude          ← mock claude that consumes stdin and exits 0
└── mock-claude.log     ← records every invocation
```

Cleaned automatically on exit.

## On failure

Logs are preserved in `/tmp/nb-*.log` for diagnosis. Re-running with `bash -x test/smoke.sh` traces every command.
