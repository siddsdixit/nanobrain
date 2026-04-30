#!/usr/bin/env bash
# fetch.sh -- granola source. Reads WorkOS JWT from Granola's local app state.
# No stored API key. Token is refreshed by the running Granola app automatically.
# Outputs JSON array of meeting notes matching ingest.sh shape.
#
# Shape:
# [{"id":"...","title":"...","date":"ISO8601","attendees":["..."],
#   "body":"...","context":"work|personal"}]

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
GRANOLA_STATE="${HOME}/Library/Application Support/Granola/supabase.json"
API="https://api.granola.ai"

# --since DAYS (default: 7, or read from fetch watermark)
SINCE_DAYS=7
if [ -f "$BRAIN_DIR/data/granola/.fetch_watermark" ]; then
  wm=$(cat "$BRAIN_DIR/data/granola/.fetch_watermark" 2>/dev/null || echo 0)
  now=$(date +%s)
  delta=$(( (now - wm) / 86400 + 1 ))
  SINCE_DAYS=$( [ "$delta" -lt 1 ] && echo 1 || ( [ "$delta" -gt 90 ] && echo 90 || echo "$delta" ) )
fi
while [ "$#" -gt 0 ]; do
  case "$1" in --since) SINCE_DAYS="$2"; shift 2 ;; *) shift ;; esac
done

# Resolve work email for context tagging
WORK_EMAIL=""
ctx_yaml="$BRAIN_DIR/brain/_contexts.yaml"
if command -v python3 >/dev/null 2>&1 && [ -f "$ctx_yaml" ]; then
  WORK_EMAIL=$(python3 -c "
import sys
try:
    data=open('$ctx_yaml').read()
    for line in data.splitlines():
        line=line.strip()
        if 'work' in line and '@' in line:
            import re
            m=re.search(r'[\w.+-]+@[\w.-]+',line)
            if m: print(m.group(0)); break
except: pass
" 2>/dev/null || echo "")
fi

# Get token from Granola's local state (set -e safe: fail gracefully)
if [ ! -f "$GRANOLA_STATE" ]; then
  echo "[granola] Granola app not installed or never launched" >&2
  printf '[]'
  exit 0
fi

get_token() {
  python3 -c "
import json,sys
try:
    with open(sys.argv[1]) as f: d=json.load(f)
    wt=json.loads(d.get('workos_tokens','{}'))
    print(wt.get('access_token',''))
except Exception as e:
    print('',end='')
" "$GRANOLA_STATE" 2>/dev/null || echo ""
}

TOKEN=$(get_token)
if [ -z "$TOKEN" ]; then
  echo "[granola] could not read auth token (is Granola running?)" >&2
  printf '[]'
  exit 0
fi

# Fetch docs (Granola returns most-recent-first)
LIMIT=50
raw=$(curl -s \
  "https://api.granola.ai/v2/get-documents" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  --compressed \
  -d "{\"limit\": $LIMIT}" 2>/dev/null) || true

if [ -z "$raw" ]; then
  echo "[granola] empty response from API" >&2
  printf '[]'
  exit 0
fi

# Transform to ingest shape, filter by window
cutoff=$(( $(date +%s) - SINCE_DAYS * 86400 ))
WORK_EMAIL_VAR="$WORK_EMAIL"

python3 -c "
import json, sys, re
from datetime import datetime, timezone

raw=sys.stdin.read()
try:
    d=json.loads(raw)
except Exception:
    print('[]'); sys.exit(0)

docs=d.get('docs',[])
cutoff=int(sys.argv[1])
work_email=sys.argv[2].lower()

def to_epoch(s):
    if not s: return 0
    try:
        s=re.sub(r'\.\d+Z$','Z',s).replace('Z','+00:00')
        return int(datetime.fromisoformat(s).timestamp())
    except: return 0

def attendee_emails(doc):
    people=doc.get('people') or {}
    emails=[]
    for att in (people.get('attendees') or []):
        e=att.get('email','')
        if e: emails.append(e)
    creator=(people.get('creator') or {}).get('email','')
    if creator: emails.append(creator)
    return list(set(emails))

def infer_context(doc, work_email):
    if not work_email: return 'personal'
    for e in attendee_emails(doc):
        if work_email in e.lower(): return 'work'
    creator=((doc.get('people') or {}).get('creator') or {}).get('email','')
    if work_email in creator.lower(): return 'work'
    return 'personal'

def body(doc):
    nm=doc.get('notes_markdown','') or ''
    if nm.strip(): return nm[:2000]
    sm=doc.get('summary','') or ''
    if sm: return sm[:2000]
    # Chapters
    for ch in (doc.get('chapters') or []):
        c=ch.get('content','') or ''
        if c: return c[:2000]
    return ''

out=[]
for doc in docs:
    ts=to_epoch(doc.get('created_at',''))
    if ts < cutoff: continue
    b=body(doc)
    if not b: continue  # skip empty meetings
    out.append({
        'id': doc.get('id',''),
        'title': doc.get('title','') or 'Untitled meeting',
        'date': doc.get('created_at',''),
        'attendees': attendee_emails(doc),
        'body': b,
        'context': infer_context(doc, work_email),
    })

print(json.dumps(out))
" "$cutoff" "$WORK_EMAIL_VAR" <<< "$raw"

# Update watermark
mkdir -p "$BRAIN_DIR/data/granola"
date +%s > "$BRAIN_DIR/data/granola/.fetch_watermark"
