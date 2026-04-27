#!/usr/bin/env bash
# ingest.sh — Pull Granola meeting index into data/granola/INBOX.md
# Triggered by `/brain ingest granola` or daily cron. Append-only, shell-only.
#
# Source: ~/Library/Application Support/Granola/cache-v6.json
#         .cache.state.documents → keyed by doc id
# Note bodies are not in the local cache. We index title, time, attendees,
# category (work / personal / mixed / unknown), and the granola:// deeplink.

set -euo pipefail

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
INBOX="$BRAIN_DIR/data/granola/INBOX.md"
WATERMARK="$BRAIN_DIR/data/granola/.watermark"
CACHE="$HOME/Library/Application Support/Granola/cache-v6.json"
mkdir -p "$(dirname "$INBOX")"
touch "$INBOX"

command -v jq >/dev/null 2>&1 || { echo "[ingest granola] jq not found" >&2; exit 0; }
[ -f "$CACHE" ] || { echo "[ingest granola] cache not found at $CACHE" >&2; exit 0; }

DEFAULT_SINCE="$(date -v-30d -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '30 days ago' +%Y-%m-%dT%H:%M:%SZ)"
SINCE="$(cat "$WATERMARK" 2>/dev/null || echo "$DEFAULT_SINCE")"

# Comma-separated list of work email domains. Override via env.
WORK_DOMAINS="${WORK_DOMAINS:-example.com}"

echo "[ingest granola] watermark: $SINCE"

NOW="$(date +%Y-%m-%d\ %H:%M)"
COUNT=0
LATEST="$SINCE"

# jq emits one TSV row per meeting:
#   id  created  updated  title  attendees  category  cal_link  cal_summary
#
# .people shape (object): { attendees: [...], creator: {...}, url: "...", conferencing: {...} }
# Some older docs may have .people: null or missing keys → handle defensively.
DOCS_TSV="$(jq -r --arg since "$SINCE" --arg work_domains "$WORK_DOMAINS" '
  def emails_of:
    ((.attendees // []) | map(if type=="object" then (.email // "") else "" end))
    + (if (.creator // null) | type == "object" then [(.creator.email // "")] else [] end)
    | map(select(length > 0));
  def names_of:
    (.attendees // [])
    | map(if type=="object"
            then (.details.person.name.fullName // .name // .email // "?")
            else tostring end)
    | map(select(length > 0));

  ($work_domains | split(",")) as $work
  | .cache.state.documents
  | to_entries[]
  | .value
  | select(.created_at != null and .created_at > $since)
  | select(.was_trashed != true and .deleted_at == null)
  | (.people // {}) as $p
  | ($p | names_of) as $names
  | ($p | emails_of) as $emails
  | ($emails | map(ascii_downcase) | any(. as $e | $work | any(. as $d | $e | endswith("@" + $d)))) as $has_work
  | ($emails | map(ascii_downcase) | any(. as $e | $work | all(. as $d | ($e | endswith("@" + $d)) | not))) as $has_external
  | (if ($emails | length) == 0 and (.google_calendar_event == null) then "unknown"
     elif $has_work and $has_external then "mixed"
     elif $has_work then "work"
     elif $has_external then "personal"
     else "unknown" end) as $category
  | [
      .id,
      (.created_at // ""),
      (.updated_at // ""),
      ((.title // "(untitled)") | gsub("\t"; " ")),
      ($names | join(", ")),
      $category,
      (.google_calendar_event.htmlLink // ""),
      ((.google_calendar_event.summary // "") | gsub("\t"; " "))
    ]
  | @tsv
' "$CACHE" 2>/dev/null || echo "")"

while IFS=$'\t' read -r ID CREATED UPDATED TITLE PEOPLE CATEGORY CAL_LINK CAL_SUMMARY; do
  [ -z "$ID" ] && continue

  [ -z "$PEOPLE" ] && PEOPLE="(none)"
  DATE_SHORT="${CREATED:0:10}"
  DEEPLINK="granola://notes/$ID"

  {
    printf '\n\n### %s — granola: %s\n\n' "$NOW" "$TITLE"
    printf '**Date:** %s\n' "${DATE_SHORT:-unknown}"
    printf '**Category:** %s\n' "$CATEGORY"
    printf '**Attendees:** %s\n' "$PEOPLE"
    printf '**Granola:** %s\n' "$DEEPLINK"
    [ -n "$CAL_LINK" ] && printf '**Calendar:** %s\n' "$CAL_LINK"
    [ -n "$CAL_SUMMARY" ] && [ "$CAL_SUMMARY" != "$TITLE" ] && printf '**Calendar title:** %s\n' "$CAL_SUMMARY"
    printf '**Source-doc-id:** %s\n' "$ID"
  } >> "$INBOX"

  COUNT=$((COUNT + 1))
  [ "$CREATED" \> "$LATEST" ] && LATEST="$CREATED"
done <<< "$DOCS_TSV"

echo "$LATEST" > "$WATERMARK"

echo "[ingest granola] $COUNT meetings appended, watermark advanced to $LATEST"
