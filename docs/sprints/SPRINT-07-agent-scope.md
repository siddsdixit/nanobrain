# SPRINT-07 — Agent scope enforcement

## Goal

Lock the safety property that distinguishes nanobrain from "a folder of markdown": agents physically cannot read out-of-scope content, even if they try. The `reads:` block in agent definitions is enforced by the brain MCP server at the tool-call boundary, with a leak-prevention test fixture that proves it.

This sprint can run in parallel with S04-S06 (it depends only on S01).

## Stories

- **NBN-116** — agent template extension for `reads:` filters (small)
- **NBN-117** — brain MCP server `read_brain_file` tool (large)
- **NBN-118** — leak-prevention test suite (medium)

## Pre-conditions

- SPRINT-01 merged (multi-axis tag headers exist on entries we're going to filter).
- `code/mcp-server/` already scaffolded (SDK present, npm deps installed). Verify `cd code/mcp-server && npm install && node index.js --help` runs.
- `code/agents/_TEMPLATE.md` exists from v0.x agent foundry.

## Detailed steps

All paths in **public framework** (`~/Documents/nanobrain/`).

### 1. NBN-116 — extend agent template

#### Files to modify

- `code/agents/_TEMPLATE.md` (existing)
- `code/skills/brain-spawn/spawn.sh` (existing)
- `code/skills/brain-spawn/SKILL.md` (existing, prompt update)

#### Template front-matter (new shape)

Replace the existing `_TEMPLATE.md` front-matter with:

```yaml
---
slug: <agent-slug>                          # lowercase, no spaces
role: <one-line description>
model: claude-opus | claude-sonnet | claude-haiku
tools: [Read, Grep, Glob]                   # standard CC tools
reads:
  paths:                                    # explicit allow-list, glob ok
    - brain/projects.md
    - brain/people/<slug>.md
  context_in: []                            # OR-match; empty = all
  sensitivity_max: private                  # public | private | confidential
  ownership_in: []                          # OR-match; empty = all
writes:
  paths: []                                 # default empty; explicit additions only
sensitivity: private                        # the agent's own classification
---
```

Body (below front-matter): keep the existing template body. Add a one-paragraph note: "The brain MCP server enforces `reads:` at the tool-call boundary. An agent declaring `context_in: [side-proj-a]` cannot Read entries from other contexts via the brain MCP, full stop. Direct file Read tools bypass the server but those tools should be removed from `tools:` for any scoped agent."

#### `spawn.sh` updates

- After collecting agent slug and role, prompt for:
  - "context_in (comma-separated, or blank for all): "
  - "sensitivity_max [public/private/confidential, default private]: "
  - "ownership_in (comma-separated, or blank for all): "
- Validate: `sensitivity_max` ∈ allowed set.
- Splice values into the template under `reads:`.
- Validation step before writing the agent file: parse the resulting front-matter with `yq`, confirm `reads:` block has both `paths:` (non-empty) and `sensitivity_max:`. If missing, refuse to write; print actionable error.

#### `SKILL.md` (brain-spawn)

Update the prompt instructions to mention the new fields.

### 2. NBN-117 — brain MCP server `read_brain_file` tool

#### Files

```
code/mcp-server/index.js               # modify
code/mcp-server/lib/scope.js           # new
code/mcp-server/lib/parse_entries.js   # new
tests/mcp/test_scope.sh                # new
```

#### `lib/parse_entries.js`

Pure function. Takes a markdown string. Returns array of entries: each entry is `{ header_line, frontmatter: {context, sensitivity, ownership}, body, raw }`. Entry boundary is `^### ` line. Frontmatter is the lines `context:`, `sensitivity:`, `ownership:`, `source_id:` immediately following the header until the first blank line. Tolerant: missing fields default to `(personal, private, unset)` per spec §6 NBN-122 backward-compat rule.

Test fixture: a 4-entry markdown file mixing v0.x entries (no front-matter) and v1.0 entries.

#### `lib/scope.js`

Exports `filterEntries(entries, scope)` and `pathAllowed(path, scope)`.

```js
// scope: { paths: [...], context_in: [...], sensitivity_max: 'private', ownership_in: [...] }
const SENS_RANK = { public: 0, private: 1, confidential: 2 };

function pathAllowed(path, scope) {
  return scope.paths.some(p => globMatch(p, path));
}

function filterEntries(entries, scope) {
  const ceiling = SENS_RANK[scope.sensitivity_max ?? 'private'];
  return entries.filter(e => {
    const fm = e.frontmatter;
    if (scope.context_in?.length && !scope.context_in.includes(fm.context)) return false;
    if (SENS_RANK[fm.sensitivity] > ceiling) return false;
    if (scope.ownership_in?.length && !scope.ownership_in.includes(fm.ownership)) return false;
    return true;
  });
}
```

Glob match via the `minimatch` npm package (already a transitive dep; add as direct if not).

#### `index.js` — `read_brain_file` tool

Register a new MCP tool:

```js
{
  name: 'read_brain_file',
  description: 'Read a brain file, filtered by the calling agent\'s declared scope.',
  inputSchema: {
    type: 'object',
    properties: {
      agent_slug: { type: 'string' },
      path: { type: 'string' }
    },
    required: ['agent_slug', 'path']
  }
}
```

Handler:

1. Read `code/agents/<agent_slug>.md`. If missing → return `{ error: 'ERR_AGENT_NOT_FOUND' }`.
2. Parse front-matter via `yaml` package. Extract `reads:` block.
3. Call `pathAllowed(path, scope)`. Mismatch → `{ error: 'ERR_SCOPE_PATH', detail: '<path> not in agent.reads.paths' }`.
4. Read file from `${BRAIN_DIR}/<path>`.
5. Parse via `parse_entries`. Filter via `scope.filterEntries`.
6. Return reassembled markdown: original document header (lines before first `### `) + filtered entries joined.

Logging: every call writes one line to `${BRAIN_DIR}/data/_mcp/access.log`: `<ISO_TS> agent=<slug> path=<path> status=<ok|ERR_*> kept=<N>/<total>`. Append-only, mode 600. Useful both for audit and for NBN-118 to assert.

Hardcode refusal: if `path` contains `..` or starts with `/`, return `ERR_SCOPE_PATH` regardless of front-matter (defense in depth against agent-supplied path traversal).

### 3. NBN-118 — leak-prevention test suite

#### Files

```
tests/mcp/fixtures/brain/projects.md       # 4 hand-crafted entries
tests/mcp/fixtures/agents/agent-a.md       # context_in=[side-proj-a], sens=private
tests/mcp/fixtures/agents/agent-b.md       # context_in=[work], sens=confidential
tests/mcp/fixtures/agents/agent-c.md       # context_in=[], sens=public (most restrictive)
tests/mcp/fixtures/agents/agent-d.md       # paths only allow people/<slug>.md (path scope test)
tests/mcp/test_leak.sh                     # the runner
```

#### Fixture `projects.md` (4 entries spanning 2 contexts × 2 sensitivities)

```
### 2026-04-20 — side-proj-a milestone
context: side-proj-a
sensitivity: private
ownership: mine
source_id: t1
body line.

### 2026-04-21 — side-proj-a investor decision
context: side-proj-a
sensitivity: confidential
ownership: mine
source_id: t2
body line.

### 2026-04-22 — work standup outcome
context: work
sensitivity: private
ownership: employer:bigco
source_id: t3
body line.

### 2026-04-23 — work board memo
context: work
sensitivity: confidential
ownership: employer:bigco
source_id: t4
body line.
```

#### `test_leak.sh` cases

Six combinations, each asserts the exact set of entry source_ids returned (via grep `source_id: tN` count from the response).

| Agent | scope | expected |
|---|---|---|
| agent-a | context=[side-proj-a], sens=private | t1 only (t2 confidential filtered) |
| agent-b | context=[work], sens=confidential | t3, t4 |
| agent-c | context=[], sens=public | (none) |
| agent-d | paths=[brain/people/**] | path mismatch on `brain/projects.md` → ERR_SCOPE_PATH |
| path-traversal | request `../../../etc/passwd` | ERR_SCOPE_PATH |
| missing-agent | agent_slug=nope | ERR_AGENT_NOT_FOUND |

Driver: `node code/mcp-server/index.js` invoked over stdin with JSON-RPC requests; `test_leak.sh` posts each case and grep-asserts the response.

For ergonomic CLI assertion, ship a tiny `tests/mcp/_call.sh` helper that wraps the JSON-RPC handshake.

#### CI hook

Add to `tests/run_all.sh`:

```bash
bash tests/mcp/test_leak.sh || { echo "leak test failed"; exit 1; }
```

## Reference patterns

- `code/mcp-server/index.js` for current tool registration shape.
- `tests/test_resolve_context.sh` for table-driven assertion style.
- `code/agents/_TEMPLATE.md` for the front-matter convention to extend.

## Testing

```bash
cd ~/Documents/nanobrain

# unit: parser + scope filter
node code/mcp-server/lib/parse_entries.js < tests/mcp/fixtures/brain/projects.md
# Expect: JSON array of 4 entries.

# leak-prevention suite
bash tests/mcp/test_leak.sh
# Expect: "leak test: 6/6 pass".

# spawn integration: produce a scoped agent
echo -e 'foo-agent\ntest role\n\nside-proj-a\nprivate\n\n' | bash code/skills/brain-spawn/spawn.sh
# Expect: agents/_proposed/foo-agent.md created with the new `reads:` block.

# end-to-end: read filtered content via MCP
BRAIN_DIR=$PWD/tests/mcp/fixtures bash tests/mcp/_call.sh agent-a brain/projects.md
# Expect: response includes only entry t1; access.log has one line.
```

## Definition of done

- [ ] `code/agents/_TEMPLATE.md` carries the new `reads:` block; spawn refuses to write without it.
- [ ] `code/mcp-server/lib/parse_entries.js` round-trips v0.x and v1.0 entries.
- [ ] `code/mcp-server/lib/scope.js` filters by all three axes; sensitivity ceiling is hierarchical.
- [ ] `read_brain_file` tool registered and reachable.
- [ ] Path traversal (`..`, leading `/`) rejected as `ERR_SCOPE_PATH`.
- [ ] `data/_mcp/access.log` written, mode 600.
- [ ] `tests/mcp/test_leak.sh` green for all 6 cases.
- [ ] `tests/run_all.sh` includes the leak suite.
- [ ] `npm install` in `code/mcp-server/` completes clean.

## Commit / push

Three commits, public framework only:

```bash
cd ~/Documents/nanobrain

git add code/agents/_TEMPLATE.md code/skills/brain-spawn/
git commit -m "feat: agent template carries reads: scope filter (NBN-116)"

git add code/mcp-server/index.js code/mcp-server/lib/ code/mcp-server/package.json
git commit -m "feat: read_brain_file MCP tool with scope enforcement (NBN-117)"

git add tests/mcp/
git commit -m "test: leak-prevention fixture proves scope filter (NBN-118)"

git push
```

## Estimated time

6 hours. ~1h template + spawn.sh, ~3h MCP server (parser, scope, tool, logging, path traversal hardening), ~2h fixtures + leak suite + CI wiring.
