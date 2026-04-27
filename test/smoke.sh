#!/usr/bin/env bash
# nanobrain smoke test. Builds a sandbox brain, runs install.sh, fires fake
# Stop hooks, exercises capture, redaction, MCP tools (positive + edge cases),
# runtime wrappers (codex/gemini/aider), and validates every config file.
#
# Run:
#   bash test/smoke.sh           # standard run (cleans up after)
#   bash test/smoke.sh --keep    # keep sandbox at $TMPDIR for inspection
#
# No real ~/.claude is touched. Everything happens under a tmpdir.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d -t nanobrain-smoke.XXXXXX)"
FAKE_BRAIN="$TEST_HOME/brain"
FAKE_BIN="$TEST_HOME/bin"
KEEP_SANDBOX=0
PASS=0
FAIL=0
RESULTS=()

for arg in "$@"; do
  case "$arg" in
    --keep) KEEP_SANDBOX=1 ;;
  esac
done

cleanup() {
  if [ "$KEEP_SANDBOX" = "1" ]; then
    echo ""
    echo "→ sandbox kept at: $TEST_HOME"
  else
    rm -rf "$TEST_HOME"
  fi
}
trap cleanup EXIT

ok()   { PASS=$((PASS+1)); RESULTS+=("  ✅ $*"); }
fail() { FAIL=$((FAIL+1)); RESULTS+=("  ❌ $*"); }

echo "→ Sandbox: $TEST_HOME"
echo "→ Repo:    $REPO_DIR"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Setup: copy framework into sandbox, mock claude
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$FAKE_BIN" "$FAKE_BRAIN" "$TEST_HOME/.claude"

rsync -a --exclude='.git' --exclude='.cache' --exclude='node_modules' \
  "$REPO_DIR/" "$FAKE_BRAIN/"

# Seed the brain with the example synthetic data
cp -R "$FAKE_BRAIN/examples/starter-brain/." "$FAKE_BRAIN/brain/"

# Mock claude CLI: records invocation count + every stdin payload
cat > "$FAKE_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "$(date +%s)" >> "${MOCK_CLAUDE_LOG:-/dev/null}"
cat > "${MOCK_CLAUDE_STDIN:-/dev/null}"
exit 0
EOF
chmod +x "$FAKE_BIN/claude"

# Mock codex / gemini / aider: each prints a fake conversation > 500 bytes
for cli in codex gemini aider; do
  cat > "$FAKE_BIN/$cli" <<EOF
#!/usr/bin/env bash
echo "[mock-$cli] starting session"
echo "user: this is a test"
echo "assistant: hello, this is mock $cli running in the smoke test"
$(yes "more conversation content for $cli to push transcript above 500 bytes." | head -20)
echo "[mock-$cli] session ended"
exit 0
EOF
  chmod +x "$FAKE_BIN/$cli"
done

export PATH="$FAKE_BIN:$PATH"
export HOME="$TEST_HOME"
export MOCK_CLAUDE_LOG="$TEST_HOME/mock-claude.log"
export MOCK_CLAUDE_STDIN="$TEST_HOME/mock-claude-stdin.txt"
: > "$MOCK_CLAUDE_LOG"

( cd "$FAKE_BRAIN" && git init -q -b main \
  && git -c user.email=test@test -c user.name=test add -A \
  && git -c user.email=test@test -c user.name=test commit -q -m "init" )

# ─────────────────────────────────────────────────────────────────────────────
# T1: install.sh — full install
# ─────────────────────────────────────────────────────────────────────────────

echo "T1: install.sh full install"

if bash "$FAKE_BRAIN/code/install.sh" >/tmp/nb-install.log 2>&1; then
  ok "install.sh exited 0"
else fail "install.sh failed (see /tmp/nb-install.log)"; fi

for skill in brain brain-save brain-compact brain-evolve brain-checkpoint brain-spawn brain-redact; do
  [ -L "$TEST_HOME/.claude/skills/$skill" ] && ok "skill: $skill" || fail "skill missing: $skill"
done

[ -L "$TEST_HOME/.claude/CLAUDE.md" ] && ok "CLAUDE.md symlinked" || fail "CLAUDE.md missing"

if [ -f "$TEST_HOME/.claude/settings.json" ] && grep -q '"Stop"' "$TEST_HOME/.claude/settings.json"; then
  ok "Stop hook in settings.json"
else fail "Stop hook missing"; fi

bash "$FAKE_BRAIN/code/install.sh" >/dev/null 2>&1 && ok "idempotent" || fail "non-idempotent"

# ─────────────────────────────────────────────────────────────────────────────
# T2: install.sh --dry-run
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T2: install.sh --dry-run"

DRY_HOME="$(mktemp -d)"
HOME="$DRY_HOME" bash "$FAKE_BRAIN/code/install.sh" --dry-run >/tmp/nb-dry.log 2>&1
[ ! -e "$DRY_HOME/.claude" ] && ok "--dry-run no ~/.claude" || fail "--dry-run created ~/.claude"
rm -rf "$DRY_HOME"

# ─────────────────────────────────────────────────────────────────────────────
# T3: install.sh --read-only
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T3: install.sh --read-only"

RO_HOME="$(mktemp -d)"
HOME="$RO_HOME" bash "$FAKE_BRAIN/code/install.sh" --read-only >/tmp/nb-ro.log 2>&1
if [ ! -d "$RO_HOME/.claude/skills" ] && [ ! -L "$RO_HOME/.claude/CLAUDE.md" ]; then
  ok "--read-only skipped ~/.claude"
else fail "--read-only mutated ~/.claude"; fi
rm -rf "$RO_HOME"

# ─────────────────────────────────────────────────────────────────────────────
# T4: capture.sh guards + throttle
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T4: capture.sh guards + throttle"

NANOBRAIN_CAPTURING=1 bash "$FAKE_BRAIN/code/hooks/capture.sh" </dev/null >/tmp/nb-rec.log 2>&1 \
  && ok "guard: NANOBRAIN_CAPTURING=1 → exit 0" \
  || fail "guard exit non-zero"

TRANSCRIPT="$TEST_HOME/fake-transcript.jsonl"
yes '{"role":"assistant","content":"x"}' | head -c 2000 > "$TRANSCRIPT"

PAY_ACTIVE='{"session_id":"smoke-1","transcript_path":"'"$TRANSCRIPT"'","stop_hook_active":true,"hook_event_name":"Stop"}'
echo "$PAY_ACTIVE" | bash "$FAKE_BRAIN/code/hooks/capture.sh" >/tmp/nb-active.log 2>&1 \
  && ok "guard: stop_hook_active=true → exit 0" \
  || fail "stop_hook_active non-zero"

grep -q "skip: stop_hook_active=true" "$FAKE_BRAIN/data/_logs/capture.log" \
  && ok "skip reason logged" || fail "skip reason missing"

PAY_THROTTLE='{"session_id":"smoke-throttle","transcript_path":"'"$TRANSCRIPT"'","stop_hook_active":false,"hook_event_name":"Stop"}'
echo "$PAY_THROTTLE" | bash "$FAKE_BRAIN/code/hooks/capture.sh" >/dev/null 2>&1 || true
echo "tiny" >> "$TRANSCRIPT"
echo "$PAY_THROTTLE" | bash "$FAKE_BRAIN/code/hooks/capture.sh" >/dev/null 2>&1 || true
grep -q "throttle: " "$FAKE_BRAIN/data/_logs/capture.log" \
  && ok "throttle path triggered" || fail "throttle log missing"

# ─────────────────────────────────────────────────────────────────────────────
# T5: FORCE_CAPTURE invokes claude + watermark XDG
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T5: FORCE_CAPTURE + watermark location"

PRE=$(wc -l < "$MOCK_CLAUDE_LOG" 2>/dev/null || echo 0)
PAY_FORCE='{"session_id":"smoke-force","transcript_path":"'"$TRANSCRIPT"'","stop_hook_active":false,"hook_event_name":"Stop"}'
echo "$PAY_FORCE" | FORCE_CAPTURE=1 bash "$FAKE_BRAIN/code/hooks/capture.sh" >/tmp/nb-force.log 2>&1 || true
POST=$(wc -l < "$MOCK_CLAUDE_LOG" 2>/dev/null || echo 0)

[ "$POST" -gt "$PRE" ] && ok "claude invoked ($PRE -> $POST)" || fail "claude not invoked"
grep -q "run: reason=force" "$FAKE_BRAIN/data/_logs/capture.log" \
  && ok "force reason logged" || fail "force reason missing"
[ -f "$TEST_HOME/.local/state/nanobrain/sessions/smoke-force.json" ] \
  && ok "watermark in XDG state" || fail "watermark not in XDG"
[ ! -f "$FAKE_BRAIN/data/_logs/sessions/smoke-force.json" ] \
  && ok "no watermark in brain repo" || fail "watermark leaked into brain repo"

# Lock file in XDG, not brain repo
[ ! -f "$FAKE_BRAIN/.capture.lock" ] \
  && ok "lock not in brain repo" || fail "lock leaked into brain repo"

# ─────────────────────────────────────────────────────────────────────────────
# T6: redact.sh + capture.sh end-to-end secrets filter
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T6: secrets filter"

SECRET_FILE="$TEST_HOME/secret-transcript.jsonl"
{
  yes '{"role":"assistant","content":"normal content"}' | head -c 1500
  echo ''
  echo 'OPENAI=sk-fakeOPENAI1234567890abcdefghijklmnop'
  echo 'ANTHROPIC=sk-ant-fakeANTHROPIC1234567890abcdefgh'
  echo 'GH=ghp_fakeGITHUBTOKEN12345678901234567890'
  echo 'AWS=AKIAIOSFODNN7EXAMPLE'
  echo 'AUTH=Bearer abcdef0123456789abcdef0123456789'
  echo 'JWT=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkw.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c'
  echo 'INLINE=api_key="abcd1234efgh5678ijkl9012"'
  # Build a Slack-shaped string at runtime so GitHub Push Protection's
  # secret scanner doesn't flag the test fixture as a real token.
  echo "SLACK=$(printf 'xoxb-%s-%s-%s' EXAMPLE0000000 EXAMPLE0000000 EXAMPLEEXAMPLEEXAMPLEEXAM)"
} > "$SECRET_FILE"

REDACTED="$(bash "$FAKE_BRAIN/code/hooks/redact.sh" < "$SECRET_FILE")"

assert_no() { echo "$REDACTED" | grep -q "$1" && fail "redact leaked: $2" || ok "redact: $2"; }
assert_no "sk-fakeOPENAI1234567890abcdefghijklmnop"  "openai-key"
assert_no "sk-ant-fakeANTHROPIC"                      "anthropic-key"
assert_no "ghp_fakeGITHUBTOKEN"                       "github-token"
assert_no "AKIAIOSFODNN7EXAMPLE"                      "aws-key"
assert_no "abcdef0123456789abcdef0123456789"          "bearer"
assert_no "abcd1234efgh5678ijkl9012"                  "api_key="
assert_no "xoxb-1234567890123"                        "slack-token"

# End-to-end: capture.sh pipes through redact before claude
PAY_REDACT='{"session_id":"smoke-redact","transcript_path":"'"$SECRET_FILE"'","stop_hook_active":false,"hook_event_name":"Stop"}'
: > "$MOCK_CLAUDE_STDIN"
echo "$PAY_REDACT" | FORCE_CAPTURE=1 bash "$FAKE_BRAIN/code/hooks/capture.sh" >/dev/null 2>&1 || true
grep -q "sk-fakeOPENAI" "$MOCK_CLAUDE_STDIN" \
  && fail "capture.sh leaked secret to claude stdin" \
  || ok "capture.sh redacted secrets end-to-end"

# ─────────────────────────────────────────────────────────────────────────────
# T7: MCP server (positive cases)
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T7: MCP server real implementations"

if [ ! -d "$FAKE_BRAIN/code/mcp-server/node_modules" ]; then
  echo "   installing MCP SDK ..."
  ( cd "$FAKE_BRAIN/code/mcp-server" && npm install --silent --no-audit --no-fund 2>/tmp/nb-npm.log )
fi

[ -d "$FAKE_BRAIN/code/mcp-server/node_modules/@modelcontextprotocol/sdk" ] \
  && ok "MCP SDK installed" || fail "MCP SDK missing"

cp "$REPO_DIR/test/mcp-client.mjs" "$FAKE_BRAIN/code/mcp-server/_smoke-client.mjs"
if BRAIN_DIR="$FAKE_BRAIN" \
   node "$FAKE_BRAIN/code/mcp-server/_smoke-client.mjs" "$FAKE_BRAIN/code/mcp-server/index.js" \
   >/tmp/nb-mcp.log 2>&1; then
  ok "MCP client connected"
  grep -q "TOOLS:.*brain_search" /tmp/nb-mcp.log && ok "brain_search advertised" || fail "brain_search missing"
  grep -q "STATUS:.*indexes" /tmp/nb-mcp.log && ok "brain_status returned indexes" || fail "brain_status no indexes"
  grep -q "SEARCH_HIT_JANE:true" /tmp/nb-mcp.log && ok "brain_search found Jane" || fail "brain_search missed Jane"
  grep -q "LIST_PERSON_HAS_JANE:true" /tmp/nb-mcp.log && ok "brain_list_by_type found jane-doe" || fail "brain_list_by_type missed jane-doe"
  grep -q "ENTITY_JANE_NAME:Jane Doe" /tmp/nb-mcp.log && ok "brain_get_entity parsed frontmatter" || fail "brain_get_entity no frontmatter"
else fail "MCP client failed (see /tmp/nb-mcp.log)"; fi

# ─────────────────────────────────────────────────────────────────────────────
# T8: MCP edge cases
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T8: MCP edge cases"

# Build a 2nd, EMPTY brain to test missing-data behavior
EMPTY_BRAIN="$TEST_HOME/empty-brain"
mkdir -p "$EMPTY_BRAIN/brain/person" "$EMPTY_BRAIN/brain/project" "$EMPTY_BRAIN/brain/decision" "$EMPTY_BRAIN/brain/concept"

cat > "$FAKE_BRAIN/code/mcp-server/_edge-client.mjs" <<'EOF'
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const serverPath = process.argv[2];
const t = new StdioClientTransport({ command: "node", args: [serverPath], env: process.env });
const c = new Client({ name: "edge", version: "0.0.1" }, { capabilities: {} });
const text = (r) => { try { return JSON.parse(r?.content?.[0]?.text ?? "{}"); } catch { return {}; } };

await c.connect(t);

// 1. Empty brain: brain_list_by_type returns count: 0
const empty = text(await c.callTool({ name: "brain_list_by_type", arguments: { type: "person" } }));
console.log(`EMPTY_PERSON_COUNT:${empty.count ?? "MISSING"}`);

// 2. Missing entity: brain_get_entity returns error
const missing = text(await c.callTool({ name: "brain_get_entity", arguments: { type: "person", slug: "does-not-exist" } }));
console.log(`MISSING_ENTITY_ERROR:${missing.error ? "yes" : "no"}`);

// 3. Invalid type: brain_get_entity rejects
const invalid = text(await c.callTool({ name: "brain_get_entity", arguments: { type: "invalid_type", slug: "x" } }));
console.log(`INVALID_TYPE_ERROR:${invalid.error ? "yes" : "no"}`);

// 4. Missing _graph.md: brain_query_graph graceful
const noGraph = text(await c.callTool({ name: "brain_query_graph", arguments: { query: "anything" } }));
console.log(`NO_GRAPH_GRACEFUL:${(noGraph.note || noGraph.matches !== undefined) ? "yes" : "no"}`);

// 5. brain_add_to_inbox writes a file
const written = text(await c.callTool({ name: "brain_add_to_inbox", arguments: { source: "test-source", content: "smoke entry from edge test" } }));
console.log(`INBOX_WRITTEN:${written.success ? "yes" : "no"}`);
console.log(`INBOX_PATH:${written.path ?? "MISSING"}`);

await c.close();
EOF

if BRAIN_DIR="$EMPTY_BRAIN" \
   node "$FAKE_BRAIN/code/mcp-server/_edge-client.mjs" "$FAKE_BRAIN/code/mcp-server/index.js" \
   >/tmp/nb-mcp-edge.log 2>&1; then
  grep -q "EMPTY_PERSON_COUNT:0" /tmp/nb-mcp-edge.log && ok "empty brain → count 0" || fail "empty brain didn't return 0"
  grep -q "MISSING_ENTITY_ERROR:yes" /tmp/nb-mcp-edge.log && ok "missing entity → error" || fail "missing entity didn't error"
  grep -q "INVALID_TYPE_ERROR:yes" /tmp/nb-mcp-edge.log && ok "invalid type → error" || fail "invalid type didn't error"
  grep -q "NO_GRAPH_GRACEFUL:yes" /tmp/nb-mcp-edge.log && ok "no _graph.md → graceful" || fail "no _graph.md crashed"
  grep -q "INBOX_WRITTEN:yes" /tmp/nb-mcp-edge.log && ok "brain_add_to_inbox wrote file" || fail "brain_add_to_inbox failed"

  # Verify the file actually landed on disk
  [ -f "$EMPTY_BRAIN/data/test-source/INBOX.md" ] \
    && ok "inbox file on disk" || fail "inbox file missing on disk"
  grep -q "smoke entry from edge test" "$EMPTY_BRAIN/data/test-source/INBOX.md" \
    && ok "inbox content correct" || fail "inbox content wrong"
else fail "MCP edge client crashed"; fi

# ─────────────────────────────────────────────────────────────────────────────
# T9: runtime wrapper (codex/gemini/aider mocks)
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T9: runtime wrappers"

# Reset mock claude log
: > "$MOCK_CLAUDE_LOG"

# Run wrap.sh with each mock CLI
for cli in codex gemini aider; do
  PRE=$(wc -l < "$MOCK_CLAUDE_LOG" 2>/dev/null || echo 0)

  # Need BRAIN_DIR pointing at sandbox, capture.sh on the right path
  BRAIN_DIR="$FAKE_BRAIN" \
    bash "$FAKE_BRAIN/code/runtimes/wrap.sh" "$cli" --version >/tmp/nb-wrap-$cli.log 2>&1
  WRAP_EXIT=$?

  POST=$(wc -l < "$MOCK_CLAUDE_LOG" 2>/dev/null || echo 0)

  [ "$WRAP_EXIT" -eq 0 ] && ok "wrap $cli → exit 0" || fail "wrap $cli → exit $WRAP_EXIT"
  [ "$POST" -gt "$PRE" ] && ok "wrap $cli fired capture (claude $PRE -> $POST)" || fail "wrap $cli did NOT fire capture"
done

# Wrapper with NANOBRAIN_NO_CAPTURE skips capture
PRE=$(wc -l < "$MOCK_CLAUDE_LOG" 2>/dev/null || echo 0)
BRAIN_DIR="$FAKE_BRAIN" NANOBRAIN_NO_CAPTURE=1 \
  bash "$FAKE_BRAIN/code/runtimes/wrap.sh" codex --version >/dev/null 2>&1 || true
POST=$(wc -l < "$MOCK_CLAUDE_LOG" 2>/dev/null || echo 0)
[ "$POST" -eq "$PRE" ] && ok "NANOBRAIN_NO_CAPTURE=1 skips capture" || fail "NO_CAPTURE flag ignored"

# Wrapper refuses if CLI not found
bash "$FAKE_BRAIN/code/runtimes/wrap.sh" nonexistent-cli-xyz 2>/dev/null
[ "$?" -eq 127 ] && ok "wrap missing CLI → exit 127" || fail "wrap should exit 127 for missing CLI"

# ─────────────────────────────────────────────────────────────────────────────
# T10: config file validity
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T10: config file validity"

# JSON
for f in "$FAKE_BRAIN/claude-config/settings.json" "$FAKE_BRAIN/claude-config/mcp.json" "$FAKE_BRAIN/code/mcp-server/package.json"; do
  jq empty "$f" 2>/dev/null && ok "valid JSON: $(basename "$f")" || fail "INVALID JSON: $(basename "$f")"
done

# plist (XML)
for f in "$FAKE_BRAIN/code/cron/com.nanobrain.compact.plist" "$FAKE_BRAIN/code/cron/com.nanobrain.evolve.plist"; do
  if command -v plutil >/dev/null 2>&1; then
    plutil -lint "$f" >/dev/null 2>&1 && ok "valid plist: $(basename "$f")" || fail "INVALID plist: $(basename "$f")"
  else
    xmllint --noout "$f" 2>/dev/null && ok "valid XML: $(basename "$f")" || fail "INVALID XML: $(basename "$f")"
  fi
done

# Skill SKILL.md frontmatter
for s in "$FAKE_BRAIN/code/skills"/*/SKILL.md; do
  if head -1 "$s" | grep -q '^---$'; then
    ok "frontmatter present: $(basename "$(dirname "$s")")"
  else
    fail "frontmatter MISSING: $(basename "$(dirname "$s")")"
  fi
done

# ─────────────────────────────────────────────────────────────────────────────
# T11: shellcheck (informational; warnings don't fail the suite)
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T11: shellcheck (informational)"

if command -v shellcheck >/dev/null 2>&1; then
  SHELLCHECK_OUT="/tmp/nb-shellcheck.log"
  shellcheck --severity=error \
    "$FAKE_BRAIN/code/hooks/capture.sh" \
    "$FAKE_BRAIN/code/hooks/redact.sh" \
    "$FAKE_BRAIN/code/install.sh" \
    "$FAKE_BRAIN/code/runtimes/wrap.sh" \
    "$FAKE_BRAIN/code/skills/brain-redact/redact.sh" \
    "$FAKE_BRAIN/test/smoke.sh" \
    > "$SHELLCHECK_OUT" 2>&1
  if [ "$?" -eq 0 ]; then
    ok "shellcheck: no errors"
  else
    SC_LINES=$(wc -l < "$SHELLCHECK_OUT")
    fail "shellcheck found $SC_LINES lines of issues (see $SHELLCHECK_OUT)"
  fi
else
  echo "  (shellcheck not installed; skipping. brew install shellcheck)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Report
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "─────────────────────────────────────────"
printf '%s\n' "${RESULTS[@]}"
echo "─────────────────────────────────────────"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "Logs preserved in /tmp/nb-*.log"
  exit 1
fi
exit 0
