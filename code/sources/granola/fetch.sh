#!/usr/bin/env bash
# fetch.sh -- granola source. Uses official public-api.granola.ai with grn_ API key.
# Key is read from NANOBRAIN_GRANOLA_KEY env var — never stored in the repo.
# Only returns notes that have an AI summary (Granola API requirement).
#
# Output shape:
# [{"id":"...","title":"...","date":"ISO8601","attendees":["..."],
#   "body":"...","context":"work|personal"}]

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
API="https://public-api.granola.ai"

KEY="${NANOBRAIN_GRANOLA_KEY:-}"

# Fallback 1: brain .env file
if [ -z "$KEY" ] && [ -f "$BRAIN_DIR/.env" ]; then
  KEY=$(grep "^NANOBRAIN_GRANOLA_KEY=" "$BRAIN_DIR/.env" 2>/dev/null | cut -d= -f2- | tr -d '[:space:]') || true
fi

# Fallback 2: macOS Keychain
if [ -z "$KEY" ] && command -v security >/dev/null 2>&1; then
  KEY=$(security find-generic-password -s "nanobrain-granola-api-key" -w 2>/dev/null || true)
fi

if [ -z "$KEY" ]; then
  echo "[granola] NANOBRAIN_GRANOLA_KEY not set (env, .env, or Keychain)" >&2
  printf '[]'
  exit 0
fi

# --since DAYS (default: 7 or derived from fetch watermark)
SINCE_DAYS=7
if [ -f "$BRAIN_DIR/data/granola/.fetch_watermark" ]; then
  wm=$(cat "$BRAIN_DIR/data/granola/.fetch_watermark" 2>/dev/null || echo 0)
  now=$(date +%s)
  delta=$(( (now - wm) / 86400 + 1 ))
  if [ "$delta" -lt 1 ]; then SINCE_DAYS=1
  elif [ "$delta" -gt 90 ]; then SINCE_DAYS=90
  else SINCE_DAYS="$delta"
  fi
fi
while [ "$#" -gt 0 ]; do
  case "$1" in --since) SINCE_DAYS="$2"; shift 2 ;; *) shift ;; esac
done

# ISO8601 cutoff for created_after param
CREATED_AFTER=$(date -v-${SINCE_DAYS}d -u "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
  || date -u -d "${SINCE_DAYS} days ago" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
  || date -u "+%Y-%m-%dT%H:%M:%SZ")

# Resolve work email for context tagging
WORK_EMAIL=""
ctx_yaml="$BRAIN_DIR/brain/_contexts.yaml"
if command -v python3 >/dev/null 2>&1 && [ -f "$ctx_yaml" ]; then
  WORK_EMAIL=$(python3 -c "
import re,sys
try:
    for line in open('$ctx_yaml'):
        if 'work' in line and '@' in line:
            m=re.search(r'[\w.+-]+@[\w.-]+',line)
            if m: print(m.group(0)); break
except: pass
" 2>/dev/null || echo "")
fi

# Paginate through all notes since cutoff
fetch_all_notes() {
  local cursor="" has_more="true" page=0 all="[]"
  while [ "$has_more" = "true" ] && [ "$page" -lt 10 ]; do
    local url="$API/v1/notes?created_after=${CREATED_AFTER}&limit=50"
    [ -n "$cursor" ] && url="$url&cursor=$cursor"
    local resp
    resp=$(curl -s "$url" \
      -H "Authorization: Bearer $KEY" 2>/dev/null) || true
    [ -z "$resp" ] && break
    # Merge notes arrays
    all=$(python3 -c "
import json,sys
existing=json.loads(sys.argv[1])
new=json.loads(sys.argv[2])
notes=new.get('notes',[])
existing.extend(notes)
print(json.dumps(existing))
" "$all" "$resp" 2>/dev/null || echo "$all")
    has_more=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(str(d.get('hasMore',False)).lower())" "$resp" 2>/dev/null || echo "false")
    cursor=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d.get('cursor',''))" "$resp" 2>/dev/null || echo "")
    [ -z "$cursor" ] && break
    page=$((page + 1))
  done
  printf '%s' "$all"
}

notes_list=$(fetch_all_notes)
note_count=$(python3 -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$notes_list" 2>/dev/null || echo 0)

if [ "$note_count" -eq 0 ]; then
  printf '[]'
  date +%s > "$BRAIN_DIR/data/granola/.fetch_watermark" 2>/dev/null || true
  exit 0
fi

# Fetch full detail (with summary) for each note in parallel (batched)
WORK_EMAIL_VAR="$WORK_EMAIL"
KEY_VAR="$KEY"

python3 -c "
import json, sys, subprocess, threading

notes=json.loads(sys.argv[1])
key=sys.argv[2]
work_email=sys.argv[3].lower()
api=sys.argv[4]

def fetch_note(note_id):
    try:
        r=subprocess.run([
            'curl','-s',
            f'{api}/v1/notes/{note_id}?include=transcript',
            '-H',f'Authorization: Bearer {key}'
        ], capture_output=True, timeout=30)
        return json.loads(r.stdout)
    except: return {}

def infer_context(note, work_email):
    if not work_email: return 'personal'
    owner_email=(note.get('owner') or {}).get('email','').lower()
    if work_email in owner_email: return 'work'
    for att in (note.get('attendees') or []):
        if work_email in att.get('email','').lower(): return 'work'
    return 'personal'

def body(note):
    sm=note.get('summary_markdown','') or ''
    if sm.strip(): return sm[:3000]
    st=note.get('summary_text','') or ''
    if st.strip(): return st[:3000]
    # Transcript fallback: join first 2000 chars of speaker text
    tr=note.get('transcript') or []
    if tr:
        lines=[s.get('text','') for s in tr[:50] if s.get('text')]
        joined=' '.join(lines)
        if joined.strip(): return joined[:2000]
    # Metadata fallback
    title=note.get('title','')
    atts=[a.get('name') or a.get('email','') for a in (note.get('attendees') or [])]
    if atts: return f'Meeting: {title}\nAttendees: {\", \".join(atts)}'
    return ''

results=[]
lock=threading.Lock()

def process(note):
    nid=note.get('id','')
    if not nid: return
    full=fetch_note(nid)
    if not full: return
    b=body(full)
    if not b: return
    atts=[a.get('name') or a.get('email','') for a in (full.get('attendees') or [])]
    with lock:
        results.append({
            'id': nid,
            'title': full.get('title','') or note.get('title','Untitled'),
            'date': full.get('created_at','') or note.get('created_at',''),
            'attendees': atts,
            'body': b,
            'context': infer_context(full, work_email),
        })

threads=[threading.Thread(target=process, args=(n,)) for n in notes]
for t in threads: t.start()
for t in threads: t.join()

results.sort(key=lambda x: x.get('date',''), reverse=True)
print(json.dumps(results))
" "$notes_list" "$KEY_VAR" "$WORK_EMAIL_VAR" "$API"

mkdir -p "$BRAIN_DIR/data/granola"
date +%s > "$BRAIN_DIR/data/granola/.fetch_watermark"
