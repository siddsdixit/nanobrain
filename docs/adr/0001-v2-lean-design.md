# ADR 0001 -- v2 lean design

Date: 2026-04-28
Status: Accepted

## Context

v1.0 shipped 9 sprints worth of axes, skills, and enforcement. Multi-axis tagging (context + sensitivity + ownership), a pre-commit mirror enforcement pass, firehose rotation, two-pass Gmail bootstrap, and six skills (brain-spawn, brain-graph, brain-hash, brain-redact, brain-checkpoint, brain-distill-all) shipped beyond what an MVP needs to capture, distill, and serve signal. Result: 59 .sh files, four overlapping axes, surface area too wide for one user to reason about.

## Decision

v2 collapses to one axis (`context: work | personal`, two values max), single-pass ingest, and the smallest skill set that covers the loop:

- `brain-doctor` (read-only health check)
- `brain-init` (two-question wizard)
- `brain-ingest` (dispatcher)
- `brain-distill` (route INBOX into typed brain files + raw.md mirror, single commit)
- `brain-restore` (non-destructive git wrapper)

Cut explicitly:

- **sensitivity / ownership axes** -- one user, one machine, one git remote, no team-share story yet. Adding axes before there's a user demanding them is YAGNI.
- **pre-commit mirror enforcement** -- adds friction at write time. Distill writes the mirror in the same commit; if it ever drifts, brain-doctor will tell us.
- **firehose rotation** -- INBOX.md will not exceed 100MB on any realistic schedule before v3. Rotation is a cron concern, not core.
- **two-pass Gmail bootstrap** -- the `.marks` flow is a power-user knob. Single-pass with the work=9d / personal=1095d window is good enough.
- **brain-spawn, brain-graph, brain-hash, brain-redact, brain-checkpoint, brain-distill-all** -- each was a one-off script; collectively they doubled the skill surface for marginal lift.

Kept:

- **MCP server** with real bash stdio JSON-RPC and a CLI fallback (`read_brain_file.sh`). Agents need this. Firehose refusal stays in the read path.
- **brain-restore** as a non-destructive git wrapper. Refuses `--hard`, `--force`, `--reset`.
- **"captured at every stage"**: INBOX entries carry timestamp + source + sender + subject + source_id + context. Brain entries carry source_id + context. raw.md is the full mirror. Any line is traceable back to its origin.

## Consequences

- File count target 25-35 .sh (vs v1's 59).
- Schema breaks v1 brains. Migration is out-of-scope; v1 is archived as v0 at release.
- Adding axes back requires a new ADR.
