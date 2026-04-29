# nanobrain v1.0 — sprint index

Each sprint is a single engineer day (~6 hours focused). Each is self-contained: an engineer can pick it up cold, do it, and ship without reading other sprints first. Sequential execution recommended; sprints with no shared dependency can parallelize.

**Critical path:** S01 → S02 → S03 → S04. After S04, S05/S06/S07/S08 parallelize.

| Sprint | Title | Stories | Time | Depends on |
|---|---|---|---|---|
| [SPRINT-01](SPRINT-01-foundations.md) | Foundations: contexts schema, redact, resolver, write_inbox | NBN-101, NBN-102, NBN-103, NBN-104 | 6h | none |
| [SPRINT-02](SPRINT-02-skills-shell.md) | Skills shell: doctor, ingest dispatcher, distill dispatcher, distill-all | NBN-105, NBN-107, NBN-108, NBN-109 | 6h | S01 |
| [SPRINT-03](SPRINT-03-init-wizard.md) | `/brain-init` wizard | NBN-106 | 6h | S01, S02 |
| [SPRINT-04](SPRINT-04-gmail.md) | Gmail source (end-to-end first source) | NBN-111 | 6h | S01, S02 |
| [SPRINT-05](SPRINT-05-gcal-gdrive.md) | Calendar + Drive sources | NBN-112, NBN-113 | 6h | S04 |
| [SPRINT-06](SPRINT-06-slack-ramp.md) | Slack + Ramp sources | NBN-114, NBN-115 | 6h | S04 |
| [SPRINT-07](SPRINT-07-agent-scope.md) | Agent scope enforcement (template, MCP server, leak tests) | NBN-116, NBN-117, NBN-118 | 6h | S01 |
| [SPRINT-08](SPRINT-08-housekeeping.md) | Pre-commit mirror, rotation, plist installer, brain-restore | NBN-119, NBN-120, NBN-121, NBN-110 | 6h | S04, S05, S06 |
| [SPRINT-09](SPRINT-09-migration-polish.md) | Migrate existing sources, STOP.md, README, examples, ADR, smoke test | NBN-122, NBN-123, NBN-124, NBN-125, NBN-126, NBN-127 | 6h | all prior |

**Next up:** [SPRINT-01](SPRINT-01-foundations.md).

## Repo split reminder

Most sprints touch the **public framework** at `~/Documents/nanobrain/` (MIT, no personal data). User content sprints touch the **private corpus** at `~/your-brain/`. Each sprint brief calls out which repo per step.
