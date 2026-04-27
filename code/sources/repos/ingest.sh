#!/usr/bin/env bash
# ingest.sh — Pull GitHub repo activity into data/repos/INBOX.md
# Triggered by `/brain ingest repos` or daily cron. Append-only, shell-only.

set -euo pipefail

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
INBOX="$BRAIN_DIR/data/repos/INBOX.md"
WATERMARK="$BRAIN_DIR/data/repos/.watermark"
mkdir -p "$(dirname "$INBOX")"
touch "$INBOX"

# Default watermark: 7 days ago
DEFAULT_SINCE="$(date -v-7d -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)"
SINCE="$(cat "$WATERMARK" 2>/dev/null || echo "$DEFAULT_SINCE")"

command -v gh >/dev/null 2>&1 || { echo "[ingest repos] gh CLI not found" >&2; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "[ingest repos] jq not found" >&2; exit 0; }

echo "[ingest repos] watermark: $SINCE"

REPOS_JSON="$(gh repo list "$(gh api user --jq .login)" --limit 100 \
  --json nameWithOwner,updatedAt,description,visibility,isArchived 2>/dev/null || echo '[]')"

NOW="$(date +%Y-%m-%d\ %H:%M)"
COUNT=0
LATEST="$SINCE"

# Iterate repos updated since watermark
while IFS=$'\t' read -r NAME UPDATED DESC VIS ARCHIVED; do
  [ -z "$NAME" ] && continue
  [ "$ARCHIVED" = "true" ] && continue
  [ "$UPDATED" \> "$SINCE" ] || continue

  # Apply privacy filter to description
  DESC_CLEAN="$(echo "$DESC" | sed -E 's/(password|token|api[_-]?key|secret|sk-[A-Za-z0-9]+|Bearer [A-Za-z0-9._-]+)/[REDACTED]/gi')"

  # Recent commits via gh API (last 5 since watermark)
  RECENT="$(gh api -X GET "repos/$NAME/commits" -f since="$SINCE" --jq '.[:5] | .[] | "- \(.sha[0:7]) \(.commit.author.date[0:10]) \(.commit.author.name) \(.commit.message | split("\n")[0])"' 2>/dev/null || echo "  (api unavailable)")"

  # Append a single block (shell-only)
  {
    printf '\n\n### %s — repos: %s — %s\n\n' "$NOW" "$NAME" "$VIS"
    printf '**Description:** %s\n' "${DESC_CLEAN:-(none)}"
    printf '**Last update:** %s\n' "$UPDATED"
    printf '**Recent commits (since %s):**\n%s\n' "$SINCE" "${RECENT:-  (none)}"
  } >> "$INBOX"

  COUNT=$((COUNT + 1))
  [ "$UPDATED" \> "$LATEST" ] && LATEST="$UPDATED"
done < <(echo "$REPOS_JSON" | jq -r '.[] | [.nameWithOwner, .updatedAt, (.description // ""), .visibility, (.isArchived | tostring)] | @tsv')

# Update watermark
echo "$LATEST" > "$WATERMARK"

echo "[ingest repos] $COUNT repos appended, watermark advanced to $LATEST"
