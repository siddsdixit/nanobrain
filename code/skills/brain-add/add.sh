#!/usr/bin/env bash
# add.sh -- onboard a new data source after its MCP is connected.
# Steps: detect MCP -> test fetch -> ingest -> distill -> register launchd plist.
# Usage: bash add.sh <source>   (gmail|gcal|gdrive|slack)

set -eu

src="${1:-}"
[ -n "$src" ] || { echo "usage: add.sh <source>" >&2; exit 64; }

case "$src" in
  gmail|gcal|gdrive|slack) ;;
  *) echo "[brain-add] unsupported source: $src" >&2; exit 64 ;;
esac

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$BRAIN_DIR/.nanobrain}"
[ -d "$FRAMEWORK_DIR" ] || FRAMEWORK_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

SRC_DIR="$FRAMEWORK_DIR/code/sources/$src"
LIB_DIR="$FRAMEWORK_DIR/code/lib"
DATA_DIR="$BRAIN_DIR/data/$src"
mkdir -p "$DATA_DIR"

echo "[brain-add] $src: detecting MCP..."
if ! bash "$LIB_DIR/detect_mcp.sh" "$src"; then
  cat >&2 <<EOF
[brain-add] $src MCP not configured.

To connect $src:
  1. Open Claude (claude.ai) in your browser.
  2. Settings -> Connectors -> enable the $src connector.
  3. Authorize access.
  4. Re-run: bash $0 $src

(Or, for a self-hosted MCP server, add it under "mcpServers" in
 ~/.claude/settings.json.)
EOF
  exit 1
fi
echo "[brain-add] $src: MCP detected."

# 2. Test fetch (7 day sample).
echo "[brain-add] $src: test fetch (7 days)..."
tmp_json=$(mktemp -t "nanobrain-${src}-XXXXXX.json")
trap 'rm -f "$tmp_json"' EXIT
if ! BRAIN_DIR="$BRAIN_DIR" bash "$SRC_DIR/fetch.sh" --since 7 > "$tmp_json"; then
  echo "[brain-add] $src: fetch failed" >&2
  exit 2
fi
n=$(jq 'length' "$tmp_json" 2>/dev/null || echo 0)
echo "[brain-add] $src: fetched $n items."

# 3. Pipe through ingest.sh via the per-source stub env var.
case "$src" in
  gmail)  export NANOBRAIN_GMAIL_STUB="$tmp_json" ;;
  gcal)   export NANOBRAIN_GCAL_STUB="$tmp_json" ;;
  gdrive) export NANOBRAIN_GDRIVE_STUB="$tmp_json" ;;
  slack)  export NANOBRAIN_SLACK_STUB="$tmp_json" ;;
esac
echo "[brain-add] $src: ingesting..."
BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
  bash "$SRC_DIR/ingest.sh"

# 4. Distill.
echo "[brain-add] $src: distilling..."
BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
  bash "$FRAMEWORK_DIR/code/skills/brain-distill/dispatch.sh" "$src" || \
  echo "[brain-add] $src: distill skipped (non-fatal)"

# 5. Register / reload launchd plist.
plist_src="$FRAMEWORK_DIR/code/cron/com.nanobrain.ingest.${src}.plist"
plist_dst="$HOME/Library/LaunchAgents/com.nanobrain.ingest.${src}.plist"
if [ -f "$plist_src" ]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  sed "s|__BRAIN_DIR__|$BRAIN_DIR|g; s|__HOME__|$HOME|g" "$plist_src" > "$plist_dst"
  launchctl unload "$plist_dst" 2>/dev/null || true
  if launchctl load "$plist_dst" 2>/dev/null; then
    echo "[brain-add] $src: launchd job registered."
  else
    echo "[brain-add] $src: WARN: launchctl load failed (job rendered at $plist_dst)" >&2
  fi
else
  echo "[brain-add] $src: no plist template found (skipping launchd)"
fi

# 6. Summary.
echo
echo "[brain-add] DONE: $src"
echo "  fetched:  $n items"
echo "  inbox:    $DATA_DIR/INBOX.md"
echo "  schedule: $plist_dst"
LOG_SH="$FRAMEWORK_DIR/code/lib/log_op.sh"
[ -f "$LOG_SH" ] && BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
  bash "$LOG_SH" install "brain-add: $src ($n items)" 2>/dev/null || true
exit 0
