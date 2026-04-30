#!/usr/bin/env bash
# fetch.sh -- gmail. Calls claude -p with Gmail MCP, normalizes to ingest shape.
# Stdout: JSON array. Stderr: progress only.
# Shape: [{"id","from","to","date"(ISO8601),"subject","body"}]

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
DATA_DIR="$BRAIN_DIR/data/gmail"
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

command -v claude >/dev/null 2>&1 || { echo "[gmail/fetch] claude not in PATH" >&2; exit 3; }

prompt="Call mcp__claude_ai_Gmail__search_threads with query 'newer_than:${SINCE}d' and max_results 50. Return the raw JSON tool result verbatim. Output ONLY the JSON (object or array), no prose, no markdown fences."

raw=$(printf '%s' "$prompt" | claude -p 2>/dev/null || true)

# Extract JSON from raw output using balanced-bracket scan (handles nested objects)
json=$(printf '%s' "$raw" | python3 -c "
import sys, re, json
text = sys.stdin.read()
text = re.sub(r'\`\`\`[a-z]*\n?', '', text)
# Find balanced JSON: scan for { or [ then track depth through strings/escapes
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
        val = json.loads(candidate)
        print(json.dumps(val))
    except Exception: print('[]')
else:
    print('[]')
" 2>/dev/null || echo "[]")

# Normalize to ingest shape — handles various MCP field name conventions
normalized=$(printf '%s' "$json" | python3 -c "
import sys, json, re

def safe(v): return v if isinstance(v, str) else ''

def normalize(item):
    if not isinstance(item, dict): return None
    # Threads have a 'messages' array — flatten by taking the first message
    # and merging the thread id back in.
    msgs = item.get('messages')
    if isinstance(msgs, list) and msgs:
        thread_id = item.get('id') or ''
        first = dict(msgs[0]) if isinstance(msgs[0], dict) else {}
        # Prefer thread id, fall back to message id
        if thread_id and 'id' not in first:
            first['id'] = thread_id
        elif thread_id:
            first['threadId'] = thread_id
        item = first
    keys = {k.lower(): v for k, v in item.items()}

    # id
    nid = safe(keys.get('id') or keys.get('threadid') or keys.get('thread_id') or keys.get('messageid') or '')

    # from
    frm = safe(keys.get('from') or keys.get('sender') or keys.get('from_address') or '')
    if not frm:
        payload = keys.get('payload') or {}
        if isinstance(payload, dict):
            for h in (payload.get('headers') or []):
                if isinstance(h, dict) and h.get('name','').lower() == 'from':
                    frm = h.get('value','')

    # to
    to = safe(keys.get('to') or keys.get('recipient') or keys.get('to_address') or '')
    if not to:
        rcpts = keys.get('torecipients') or keys.get('to_recipients')
        if isinstance(rcpts, list):
            to = ', '.join(str(r) for r in rcpts if r)

    # date
    date = safe(keys.get('date') or keys.get('internaldate') or keys.get('timestamp') or keys.get('received_at') or '')
    # Convert epoch ms to ISO if needed
    if re.match(r'^\d{13}$', date.strip()):
        import datetime
        date = datetime.datetime.utcfromtimestamp(int(date)/1000).strftime('%Y-%m-%dT%H:%M:%SZ')

    # subject
    subj = safe(keys.get('subject') or '')
    if not subj:
        payload = keys.get('payload') or {}
        if isinstance(payload, dict):
            for h in (payload.get('headers') or []):
                if isinstance(h, dict) and h.get('name','').lower() == 'subject':
                    subj = h.get('value','')

    # body / snippet
    body = safe(keys.get('body') or keys.get('snippet') or keys.get('text') or keys.get('content') or '')[:500]

    if not nid and not subj: return None
    if not nid: nid = subj[:40]
    return {'id': nid, 'from': frm, 'to': to, 'date': date, 'subject': subj, 'body': body}

data = json.loads(sys.stdin.read())
# Unwrap common envelope shapes
if isinstance(data, dict):
    data = data.get('threads') or data.get('messages') or data.get('items') or list(data.values())
if not isinstance(data, list): data = []

out = [r for r in (normalize(i) for i in data) if r]
print(json.dumps(out))
" 2>/dev/null || echo "[]")

printf '%s\n' "$normalized"
date +%s > "$WM"
exit 0
