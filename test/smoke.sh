#!/usr/bin/env bash
# nanobrain smoke test. Builds a sandbox brain, runs install.sh, fires a fake
# Stop hook, verifies the capture pipeline. Then exercises the MCP server.
#
# Run: bash test/smoke.sh
# No real ~/.claude is touched. Everything happens under a tmpdir.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEST_HOME="$(mktemp -d -t nanobrain-smoke.XXXXXX)"
FAKE_BRAIN="$TEST_HOME/brain"
FAKE_BIN="$TEST_HOME/bin"
PASS=0
FAIL=0
RESULTS=()

cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

ok()   { PASS=$((PASS+1)); RESULTS+=("  ✅ $*"); }
fail() { FAIL=$((FAIL+1)); RESULTS+=("  ❌ $*"); }

echo "→ Sandbox: $TEST_HOME"
echo "→ Repo:    $REPO_DIR"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Setup: copy framework into sandbox, mock claude + jq presence
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$FAKE_BIN" "$FAKE_BRAIN" "$TEST_HOME/.claude"

# Copy framework (excluding .git, .cache)
rsync -a --exclude='.git' --exclude='.cache' --exclude='node_modules' \
  "$REPO_DIR/" "$FAKE_BRAIN/"

# Mock claude binary (stand-in for `claude -p`). Records invocation and exits 0.
cat > "$FAKE_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "$(date +%s)" >> "${MOCK_CLAUDE_LOG:-/dev/null}"
cat > /dev/null   # consume stdin
exit 0
EOF
chmod +x "$FAKE_BIN/claude"

export PATH="$FAKE_BIN:$PATH"
export HOME="$TEST_HOME"
export MOCK_CLAUDE_LOG="$TEST_HOME/mock-claude.log"
: > "$MOCK_CLAUDE_LOG"

# Init the sandbox brain as a git repo
( cd "$FAKE_BRAIN" && git init -q -b main \
  && git -c user.email=test@test -c user.name=test add -A \
  && git -c user.email=test@test -c user.name=test commit -q -m "init" )

# ─────────────────────────────────────────────────────────────────────────────
# T1: install.sh wires symlinks idempotently
# ─────────────────────────────────────────────────────────────────────────────

echo "T1: install.sh"

if bash "$FAKE_BRAIN/code/install.sh" >/tmp/nb-install.log 2>&1; then
  ok "install.sh exited 0"
else
  fail "install.sh exited non-zero (see /tmp/nb-install.log)"
fi

for skill in brain brain-save brain-compact brain-evolve brain-checkpoint brain-spawn; do
  if [ -L "$TEST_HOME/.claude/skills/$skill" ]; then
    ok "skill symlink: $skill"
  else
    fail "skill symlink missing: $skill"
  fi
done

if [ -L "$TEST_HOME/.claude/CLAUDE.md" ]; then
  ok "CLAUDE.md symlinked"
else
  fail "CLAUDE.md not symlinked"
fi

if [ -f "$TEST_HOME/.claude/settings.json" ]; then
  if grep -q '"Stop"' "$TEST_HOME/.claude/settings.json"; then
    ok "Stop hook registered in settings.json"
  else
    fail "Stop hook not in settings.json"
  fi
else
  fail "settings.json not created"
fi

# Idempotency: re-run shouldn't error
if bash "$FAKE_BRAIN/code/install.sh" >/dev/null 2>&1; then
  ok "install.sh is idempotent (second run clean)"
else
  fail "install.sh failed on second run"
fi

# ─────────────────────────────────────────────────────────────────────────────
# T2: capture.sh recursion guard short-circuits
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T2: capture.sh recursion guard"

if NANOBRAIN_CAPTURING=1 bash "$FAKE_BRAIN/code/hooks/capture.sh" </dev/null \
   >/tmp/nb-rec.log 2>&1; then
  ok "exits 0 when NANOBRAIN_CAPTURING=1"
else
  fail "non-zero exit on recursion-guard path"
fi

# ─────────────────────────────────────────────────────────────────────────────
# T3: capture.sh stop_hook_active payload short-circuits cleanly
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T3: capture.sh stop_hook_active guard"

# Build fake transcript so pre-flight passes
TRANSCRIPT="$TEST_HOME/fake-transcript.jsonl"
yes '{"role":"assistant","content":"x"}' | head -c 2000 > "$TRANSCRIPT"

PAYLOAD=$(cat <<JSON
{"session_id":"smoke-1","transcript_path":"$TRANSCRIPT","stop_hook_active":true,"hook_event_name":"Stop"}
JSON
)

if echo "$PAYLOAD" | bash "$FAKE_BRAIN/code/hooks/capture.sh" \
   >/tmp/nb-active.log 2>&1; then
  ok "exits 0 when stop_hook_active=true"
else
  fail "non-zero exit on stop_hook_active path"
fi

if grep -q "skip: stop_hook_active=true" "$FAKE_BRAIN/data/_logs/capture.log" 2>/dev/null; then
  ok "logged skip reason"
else
  fail "skip reason not logged"
fi

# ─────────────────────────────────────────────────────────────────────────────
# T4: capture.sh throttle skips small new-content sessions
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T4: capture.sh throttle"

PAYLOAD=$(cat <<JSON
{"session_id":"smoke-throttle","transcript_path":"$TRANSCRIPT","stop_hook_active":false,"hook_event_name":"Stop"}
JSON
)

# First call seeds the watermark + fires capture (FORCE not set, but no prior watermark)
echo "$PAYLOAD" | bash "$FAKE_BRAIN/code/hooks/capture.sh" >/dev/null 2>&1 || true

# Append a small amount (under MIN_NEW_BYTES default 5000) and call again
echo "tiny" >> "$TRANSCRIPT"
echo "$PAYLOAD" | bash "$FAKE_BRAIN/code/hooks/capture.sh" >/dev/null 2>&1 || true

if grep -q "throttle: " "$FAKE_BRAIN/data/_logs/capture.log"; then
  ok "throttle path triggered for sub-threshold delta"
else
  fail "throttle log entry not found"
fi

# ─────────────────────────────────────────────────────────────────────────────
# T5: capture.sh fires when FORCE_CAPTURE=1 (calls mock claude)
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T5: FORCE_CAPTURE invokes mock claude"

PRE_COUNT=$(wc -l < "$MOCK_CLAUDE_LOG" 2>/dev/null || echo 0)

PAYLOAD=$(cat <<JSON
{"session_id":"smoke-force","transcript_path":"$TRANSCRIPT","stop_hook_active":false,"hook_event_name":"Stop"}
JSON
)

echo "$PAYLOAD" | FORCE_CAPTURE=1 MOCK_CLAUDE_LOG="$MOCK_CLAUDE_LOG" \
  bash "$FAKE_BRAIN/code/hooks/capture.sh" >/tmp/nb-force.log 2>&1 || true

POST_COUNT=$(wc -l < "$MOCK_CLAUDE_LOG" 2>/dev/null || echo 0)

if [ "$POST_COUNT" -gt "$PRE_COUNT" ]; then
  ok "mock claude was invoked (counts: $PRE_COUNT → $POST_COUNT)"
else
  fail "mock claude NOT invoked under FORCE_CAPTURE"
fi

if grep -q "run: reason=force" "$FAKE_BRAIN/data/_logs/capture.log"; then
  ok "force-capture reason logged"
else
  fail "force reason missing from log"
fi

# ─────────────────────────────────────────────────────────────────────────────
# T6: MCP server starts, lists tools, responds to a call
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "T6: MCP server smoke"

if [ ! -d "$FAKE_BRAIN/code/mcp-server/node_modules" ]; then
  echo "   installing MCP SDK ..."
  ( cd "$FAKE_BRAIN/code/mcp-server" && npm install --silent --no-audit --no-fund 2>/tmp/nb-npm.log )
fi

if [ -d "$FAKE_BRAIN/code/mcp-server/node_modules/@modelcontextprotocol/sdk" ]; then
  ok "MCP SDK installed"
else
  fail "MCP SDK install failed (see /tmp/nb-npm.log)"
fi

# Run the MCP smoke client. Copy it next to node_modules so ESM resolution works.
cp "$REPO_DIR/test/mcp-client.mjs" "$FAKE_BRAIN/code/mcp-server/_smoke-client.mjs"
if [ -f "$FAKE_BRAIN/code/mcp-server/_smoke-client.mjs" ]; then
  if BRAIN_DIR="$FAKE_BRAIN" \
     node "$FAKE_BRAIN/code/mcp-server/_smoke-client.mjs" "$FAKE_BRAIN/code/mcp-server/index.js" \
     >/tmp/nb-mcp.log 2>&1; then
    ok "MCP server: tools/list returned"
    if grep -q "brain_search" /tmp/nb-mcp.log; then
      ok "MCP server: brain_search advertised"
    else
      fail "MCP server: brain_search not in tool list"
    fi
    if grep -q "brain_status" /tmp/nb-mcp.log; then
      ok "MCP server: brain_status responded"
    else
      fail "MCP server: brain_status no response"
    fi
  else
    fail "MCP client failed (see /tmp/nb-mcp.log)"
  fi
else
  fail "test/mcp-client.mjs missing"
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
