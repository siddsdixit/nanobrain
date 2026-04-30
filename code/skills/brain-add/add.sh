#!/usr/bin/env bash
# add.sh -- onboard a new data source.
# Steps: detect -> prompt/configure -> test fetch -> ingest -> distill -> register launchd.
# Usage: bash add.sh <source>   (gmail|gcal|gdrive|slack|granola)

set -eu

src="${1:-}"
[ -n "$src" ] || { echo "usage: add.sh <source>" >&2; exit 64; }

case "$src" in
  gmail|gcal|gdrive|slack|granola) ;;
  *) echo "[brain-add] unsupported source: $src. Valid: gmail gcal gdrive slack granola" >&2; exit 64 ;;
esac

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$BRAIN_DIR/.nanobrain}"
[ -d "$FRAMEWORK_DIR" ] || FRAMEWORK_DIR="$(cd "$(dirname "$0")/../../.." && pwd)"

SRC_DIR="$FRAMEWORK_DIR/code/sources/$src"
LIB_DIR="$FRAMEWORK_DIR/code/lib"
DATA_DIR="$BRAIN_DIR/data/$src"
BRAIN_ENV="$BRAIN_DIR/.env"
mkdir -p "$DATA_DIR"

# Source brain .env so fetch.sh picks up any stored keys.
if [ -f "$BRAIN_ENV" ]; then
  set -a; . "$BRAIN_ENV"; set +a
fi

# ── 1. Detect / configure ──────────────────────────────────────────────────

setup_granola() {
  # Already set in environment (from .env sourced above or shell).
  if [ -n "${NANOBRAIN_GRANOLA_KEY:-}" ]; then
    echo "[brain-add] granola: API key found."
    return 0
  fi
  echo
  echo "Granola requires an API key."
  echo "  1. Open Granola desktop app"
  echo "  2. Settings → API → Create new key"
  echo "  3. Paste the key below (starts with grn_)"
  echo
  printf "Granola API key: "
  read -r key
  key=$(printf '%s' "$key" | tr -d '[:space:]')
  if [ -z "$key" ]; then
    echo "[brain-add] no key entered, skipping granola" >&2; exit 1
  fi
  # Validate quickly.
  http=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://public-api.granola.ai/v1/notes?limit=1" \
    -H "Authorization: Bearer $key" 2>/dev/null || echo "000")
  if [ "$http" != "200" ]; then
    echo "[brain-add] key validation failed (HTTP $http)" >&2; exit 1
  fi
  # Persist to brain .env (mode 600).
  touch "$BRAIN_ENV" && chmod 600 "$BRAIN_ENV"
  # Remove any existing key line, then append.
  grep -v "^NANOBRAIN_GRANOLA_KEY=" "$BRAIN_ENV" > "${BRAIN_ENV}.tmp" 2>/dev/null || true
  printf 'NANOBRAIN_GRANOLA_KEY=%s\n' "$key" >> "${BRAIN_ENV}.tmp"
  mv "${BRAIN_ENV}.tmp" "$BRAIN_ENV"
  export NANOBRAIN_GRANOLA_KEY="$key"
  # Ensure .env is gitignored.
  if ! grep -qx "^\.env$" "$BRAIN_DIR/.gitignore" 2>/dev/null; then
    echo ".env" >> "$BRAIN_DIR/.gitignore"
  fi
  echo "[brain-add] granola: key saved to $BRAIN_ENV"
}

setup_mcp() {
  if bash "$LIB_DIR/detect_mcp.sh" "$src" 2>/dev/null; then
    echo "[brain-add] $src: MCP detected."
    return 0
  fi
  echo
  echo "[brain-add] $src MCP not configured."
  echo
  case "$src" in
    gmail)
      echo "To connect Gmail:"
      echo "  1. Open claude.ai → Settings → Integrations"
      echo "  2. Enable Gmail and authorize access."
      echo "  3. Re-run: brain-add gmail"
      ;;
    gcal)
      echo "To connect Google Calendar:"
      echo "  1. Open claude.ai → Settings → Integrations"
      echo "  2. Enable Google Calendar and authorize access."
      echo "  3. Re-run: brain-add gcal"
      ;;
    gdrive)
      echo "To connect Google Drive:"
      echo "  1. Open claude.ai → Settings → Integrations"
      echo "  2. Enable Google Drive and authorize access."
      echo "  3. Re-run: brain-add gdrive"
      ;;
    slack)
      echo "To connect Slack:"
      echo "  1. Open claude.ai → Settings → Integrations"
      echo "  2. Enable Slack and authorize access."
      echo "  3. Re-run: brain-add slack"
      ;;
  esac
  echo
  exit 1
}

echo "[brain-add] $src: checking availability..."
if [ "$src" = "granola" ]; then
  setup_granola
else
  setup_mcp
fi

# ── 2. Test fetch ──────────────────────────────────────────────────────────

echo "[brain-add] $src: test fetch (7 days)..."
tmp_json=$(mktemp -t "nanobrain-${src}-XXXXXX.json")
trap 'rm -f "$tmp_json"' EXIT

if ! BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
     bash "$SRC_DIR/fetch.sh" --since 7 > "$tmp_json" 2>/dev/null; then
  echo "[brain-add] $src: fetch failed" >&2
  exit 2
fi

n=$(jq 'length' "$tmp_json" 2>/dev/null || echo 0)
echo "[brain-add] $src: fetched $n items."
if [ "$n" -eq 0 ]; then
  echo "[brain-add] $src: no items in last 7 days — trying 30 days..."
  BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
    bash "$SRC_DIR/fetch.sh" --since 30 > "$tmp_json" 2>/dev/null || true
  n=$(jq 'length' "$tmp_json" 2>/dev/null || echo 0)
  echo "[brain-add] $src: fetched $n items (30d window)."
fi

# ── 3. Ingest ─────────────────────────────────────────────────────────────

echo "[brain-add] $src: ingesting..."
case "$src" in
  gmail)   export NANOBRAIN_GMAIL_STUB="$tmp_json" ;;
  gcal)    export NANOBRAIN_GCAL_STUB="$tmp_json" ;;
  gdrive)  export NANOBRAIN_GDRIVE_STUB="$tmp_json" ;;
  slack)   export NANOBRAIN_SLACK_STUB="$tmp_json" ;;
  granola) export NANOBRAIN_GRANOLA_STUB="$tmp_json" ;;
esac
BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
  bash "$SRC_DIR/ingest.sh"

# ── 4. Distill ────────────────────────────────────────────────────────────

echo "[brain-add] $src: distilling..."
BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
  bash "$FRAMEWORK_DIR/code/skills/brain-distill/dispatch.sh" "$src" \
  || echo "[brain-add] $src: distill skipped (non-fatal)"

# ── 5. Register launchd ───────────────────────────────────────────────────

plist_src="$FRAMEWORK_DIR/code/cron/com.nanobrain.ingest.${src}.plist"
plist_dst="$HOME/Library/LaunchAgents/com.nanobrain.ingest.${src}.plist"
if [ -f "$plist_src" ]; then
  mkdir -p "$HOME/Library/LaunchAgents"
  sed "s|__BRAIN_DIR__|$BRAIN_DIR|g; s|__HOME__|$HOME|g" "$plist_src" > "$plist_dst"
  launchctl unload "$plist_dst" 2>/dev/null || true
  if launchctl load "$plist_dst" 2>/dev/null; then
    echo "[brain-add] $src: launchd job registered."
  else
    echo "[brain-add] $src: WARN: launchctl load failed (plist at $plist_dst)" >&2
  fi
else
  echo "[brain-add] $src: no plist template — skipping launchd"
fi

# ── 6. Summary ────────────────────────────────────────────────────────────

echo
echo "[brain-add] DONE: $src"
echo "  fetched:  $n items"
echo "  inbox:    $DATA_DIR/INBOX.md"
[ -f "$plist_dst" ] && echo "  schedule: $plist_dst"

BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$FRAMEWORK_DIR" \
  bash "$FRAMEWORK_DIR/code/lib/log_op.sh" install "brain-add: $src ($n items)" 2>/dev/null || true
exit 0
