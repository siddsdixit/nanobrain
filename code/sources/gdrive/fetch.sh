#!/usr/bin/env bash
# fetch.sh -- gdrive. Calls claude -p with Drive MCP, normalizes to ingest shape.
# Stdout: JSON array. Stderr: progress only.
# Shape: [{"id","folder_path","owner","modified"(ISO8601),"title","snippet"}]

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
DATA_DIR="$BRAIN_DIR/data/gdrive"
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

command -v claude >/dev/null 2>&1 || { echo "[gdrive/fetch] claude not in PATH" >&2; exit 3; }

prompt="Call mcp__claude_ai_Google_Drive__list_recent_files with max_results 50 (files modified in last ${SINCE} days if filter supported). The full result may be saved to a file (path like /Users/.../tool-results/...). If so, read that file and emit ONLY a compact JSON array of the first 50 files with these fields per file: id, name, modifiedTime, owners (array with emailAddress), webViewLink, mimeType. Output ONLY the JSON array, no prose, no markdown."

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

# Normalize to ingest shape — handles Google Drive API field names
normalized=$(printf '%s' "$json" | python3 -c "
import sys, json

def safe(v): return v if isinstance(v, str) else ''

def normalize(item):
    if not isinstance(item, dict): return None
    lkeys = {k.lower(): v for k, v in item.items()}
    nid      = safe(lkeys.get('id') or lkeys.get('fileid') or lkeys.get('file_id') or '')
    title    = safe(lkeys.get('name') or lkeys.get('title') or lkeys.get('filename') or '')
    modified = safe(lkeys.get('modifiedtime') or lkeys.get('modified') or lkeys.get('modifiedat')
                    or lkeys.get('modified_time') or lkeys.get('lastupdated') or '')
    # owner: may be string, dict, or list
    owner_v  = lkeys.get('owners') or lkeys.get('owner') or lkeys.get('lastmodifyinguser')
    owner    = ''
    if isinstance(owner_v, list) and owner_v:
        o = owner_v[0]
        owner = (o.get('emailAddress') or o.get('email') or o.get('displayName') or '') if isinstance(o, dict) else safe(o)
    elif isinstance(owner_v, dict):
        owner = owner_v.get('emailAddress') or owner_v.get('email') or owner_v.get('displayName') or ''
    elif isinstance(owner_v, str):
        owner = owner_v
    # folder_path: parents → use webViewLink or just name
    folder_path = safe(lkeys.get('webviewlink') or lkeys.get('webcontentlink') or lkeys.get('path') or '/')
    snippet  = safe(lkeys.get('snippet') or lkeys.get('description') or lkeys.get('summary') or '')[:500]
    if not nid and not title: return None
    if not nid: nid = title[:40]
    return {'id': nid, 'folder_path': folder_path, 'owner': owner,
            'modified': modified, 'title': title, 'snippet': snippet}

data = json.loads(sys.stdin.read())
if isinstance(data, dict):
    data = (data.get('files') or data.get('items') or data.get('value') or list(data.values()))
if not isinstance(data, list): data = []
out = [r for r in (normalize(i) for i in data) if r]
print(json.dumps(out))
" 2>/dev/null || echo "[]")

printf '%s\n' "$normalized"
date +%s > "$WM"
exit 0
