#!/usr/bin/env bash
# fetch.sh -- gcal. Calls claude -p with GCal MCP, normalizes to ingest shape.
# Stdout: JSON array. Stderr: progress only.
# Shape: [{"id","calendar_id","organizer","start"(ISO8601),"title","description"}]

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
DATA_DIR="$BRAIN_DIR/data/gcal"
WM="$DATA_DIR/.fetch_watermark"
mkdir -p "$DATA_DIR"

SINCE=7
if [ -f "$WM" ]; then
  last=$(cat "$WM" 2>/dev/null || echo 0)
  now=$(date +%s)
  diff=$(( (now - last) / 86400 + 1 ))
  SINCE=$(( diff < 1 ? 1 : diff > 90 ? 90 : diff ))
fi
while [ "$#" -gt 0 ]; do
  case "$1" in --since) SINCE="$2"; shift 2 ;; *) shift ;; esac
done

command -v claude >/dev/null 2>&1 || { echo "[gcal/fetch] claude not in PATH" >&2; exit 3; }

prompt="Call mcp__claude_ai_Google_Calendar__list_events with max_results 50, covering the last ${SINCE} days through the next 14 days. The full result may be saved to a file (you may see a path like /Users/.../tool-results/...). If so, read that file and extract ONLY the events array, then output ONLY a compact JSON array of the first 50 events with these fields per event: id, summary, start (object with dateTime or date), end, organizer (object with email), description, attendees. Strip everything else. Output ONLY the JSON array, no prose, no markdown."

raw=$(printf '%s' "$prompt" | claude -p 2>/dev/null || true)

json=$(printf '%s' "$raw" | python3 -c "
import sys, re, json
text = sys.stdin.read()
text = re.sub(r'\`\`\`[a-z]*\n?', '', text)
def find_balanced(s):
    n = len(s)
    for i in range(n):
        if s[i] in '{[':
            opener = s[i]; closer = '}' if opener == '{' else ']'
            depth = 0; in_str = False; esc = False
            for j in range(i, n):
                c = s[j]
                if esc: esc = False; continue
                if c == '\\\\' and in_str: esc = True; continue
                if c == '\"': in_str = not in_str; continue
                if in_str: continue
                if c == opener: depth += 1
                elif c == closer:
                    depth -= 1
                    if depth == 0: return s[i:j+1]
    return None
candidate = find_balanced(text)
if candidate:
    try:
        val = json.loads(candidate); print(json.dumps(val))
    except Exception: print('[]')
else:
    print('[]')
" 2>/dev/null || echo "[]")

# Normalize to ingest shape — handles Google Calendar API field names
normalized=$(printf '%s' "$json" | python3 -c "
import sys, json

def safe(v): return v if isinstance(v, str) else ''

def get_dt(item, *keys):
    for k in keys:
        v = item.get(k)
        if isinstance(v, dict):
            return v.get('dateTime') or v.get('date') or ''
        if isinstance(v, str) and v:
            return v
    return ''

def normalize(item):
    if not isinstance(item, dict): return None
    lkeys = {k.lower(): v for k, v in item.items()}
    nid   = safe(lkeys.get('id') or lkeys.get('eventid') or lkeys.get('event_id') or '')
    title = safe(lkeys.get('summary') or lkeys.get('title') or lkeys.get('name') or '')
    start = get_dt(item, 'start', 'startTime', 'start_time')
    org   = ''
    org_v = lkeys.get('organizer')
    if isinstance(org_v, dict):
        org = org_v.get('email') or org_v.get('displayName') or ''
    elif isinstance(org_v, str):
        org = org_v
    cal_id = safe(lkeys.get('calendar_id') or lkeys.get('calendarid') or org)
    desc   = safe(lkeys.get('description') or lkeys.get('body') or '')[:500]
    if not nid and not title: return None
    if not nid: nid = title[:40]
    return {'id': nid, 'calendar_id': cal_id, 'organizer': org,
            'start': start, 'title': title, 'description': desc}

data = json.loads(sys.stdin.read())
if isinstance(data, dict):
    data = (data.get('items') or data.get('events') or data.get('value') or list(data.values()))
if not isinstance(data, list): data = []
out = [r for r in (normalize(i) for i in data) if r]
print(json.dumps(out))
" 2>/dev/null || echo "[]")

printf '%s\n' "$normalized"
date +%s > "$WM"
exit 0
