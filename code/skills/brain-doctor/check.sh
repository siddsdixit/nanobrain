#!/usr/bin/env bash
# check.sh -- read-only health check.

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"

echo "== nanobrain doctor =="
echo "BRAIN_DIR=$BRAIN_DIR"
echo "NANOBRAIN_DIR=$FRAMEWORK_DIR"
echo

ctx_file="$BRAIN_DIR/brain/_contexts.yaml"
echo "-- contexts --"
if [ -f "$ctx_file" ]; then
  bash "$FRAMEWORK_DIR/code/lib/contexts.sh" validate "$ctx_file" || true
else
  echo "MISSING: $ctx_file (run brain-init)"
fi
echo

echo "-- sources --"
for src in claude gmail gcal gdrive slack; do
  d="$FRAMEWORK_DIR/code/sources/$src"
  if [ -f "$d/ingest.sh" ] && [ -f "$d/requires.yaml" ]; then
    printf '  %-8s ok\n' "$src"
  else
    printf '  %-8s INCOMPLETE\n' "$src"
  fi
done
echo

echo "-- mcp server --"
mcp="$FRAMEWORK_DIR/code/mcp-server/server.sh"
if [ -x "$mcp" ] || [ -f "$mcp" ]; then
  if printf '{"jsonrpc":"2.0","id":1,"method":"tools/list"}\n' | bash "$mcp" >/dev/null 2>&1; then
    echo "  ok"
  else
    echo "  ERROR: tools/list failed"
  fi
else
  echo "  MISSING: $mcp"
fi
echo

echo "-- github sync --"
push_fail="$BRAIN_DIR/data/_logs/push_failed.txt"
if [ -f "$push_fail" ]; then
  echo "  ERROR: last push to GitHub FAILED"
  echo "  $(head -1 "$push_fail") -- $(tail -n +2 "$push_fail" | head -1)"
  echo "  Fix: cd $BRAIN_DIR && git push origin HEAD"
  echo "  Then: rm $push_fail"
else
  remote=$(cd "$BRAIN_DIR" && git remote get-url origin 2>/dev/null || echo "")
  if [ -n "$remote" ]; then
    echo "  ok (remote: $remote)"
  else
    echo "  WARNING: no remote configured -- brain is local-only"
    echo "  Fix: gh repo create <name> --private --source=$BRAIN_DIR --remote=origin --push"
  fi
fi
echo

echo "-- inbox sizes --"
for src in claude gmail gcal gdrive slack; do
  f="$BRAIN_DIR/data/$src/INBOX.md"
  if [ -f "$f" ]; then
    sz=$(wc -c <"$f" | tr -d ' ')
    printf '  %-8s %s bytes\n' "$src" "$sz"
  else
    printf '  %-8s (none)\n' "$src"
  fi
done
raw="$BRAIN_DIR/brain/raw.md"
if [ -f "$raw" ]; then
  echo "  raw.md   $(wc -c <"$raw" | tr -d ' ') bytes"
fi
