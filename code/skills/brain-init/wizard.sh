#!/usr/bin/env bash
# wizard.sh -- two-question init. Writes _contexts.yaml.

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
WORK_EMAIL=""
PERSONAL_EMAIL=""
NONINTERACTIVE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --brain-dir) BRAIN_DIR="$2"; shift 2 ;;
    --work) WORK_EMAIL="$2"; NONINTERACTIVE=1; shift 2 ;;
    --personal) PERSONAL_EMAIL="$2"; NONINTERACTIVE=1; shift 2 ;;
    *) echo "[brain-init] unknown arg: $1" >&2; exit 64 ;;
  esac
done

mkdir -p "$BRAIN_DIR/brain"
out="$BRAIN_DIR/brain/_contexts.yaml"

if [ -f "$out" ]; then
  echo "[brain-init] $out exists; refusing to overwrite." >&2
  exit 1
fi

if [ "$NONINTERACTIVE" -eq 0 ]; then
  printf 'work email (blank to skip, solo personal): '
  read -r WORK_EMAIL || WORK_EMAIL=""
  printf 'personal email: '
  read -r PERSONAL_EMAIL || PERSONAL_EMAIL=""
fi

# Extract domains (everything after @).
work_dom=""
[ -n "$WORK_EMAIL" ] && work_dom=$(printf '%s' "$WORK_EMAIL" | awk -F@ 'NF>1{print $NF}')
pers_dom=""
[ -n "$PERSONAL_EMAIL" ] && pers_dom=$(printf '%s' "$PERSONAL_EMAIL" | awk -F@ 'NF>1{print $NF}')
[ -n "$pers_dom" ] || pers_dom="gmail.com"

{
  echo "version: 1"
  echo "defaults:"
  echo "  context: personal"
  echo "contexts:"
  if [ -n "$work_dom" ]; then
    echo "  work: {}"
  fi
  echo "  personal: {}"
  echo "resolvers:"
  echo "  gmail:"
  if [ -n "$work_dom" ]; then
    printf '    - { match: { from: "@%s$" }, context: work }\n' "$work_dom"
  fi
  printf '    - { match: { from: "@%s$" }, context: personal }\n' "$pers_dom"
  echo "  gcal:"
  if [ -n "$WORK_EMAIL" ]; then
    printf '    - { match: { calendar_id: "^%s$" }, context: work }\n' "$WORK_EMAIL"
  fi
  if [ -n "$PERSONAL_EMAIL" ]; then
    printf '    - { match: { calendar_id: "^%s$" }, context: personal }\n' "$PERSONAL_EMAIL"
  fi
  echo "  gdrive:"
  if [ -n "$work_dom" ]; then
    echo "    - { match: { path_glob: \"**/work/**\" }, context: work }"
  fi
  echo "    - { match: { path_glob: \"**\" }, context: personal }"
  echo "  slack: []"
  echo "  claude:"
  if [ -n "$work_dom" ]; then
    echo "    - { match: { path_glob: \"**/work/**\" }, context: work }"
  fi
  echo "    - { match: { path_glob: \"**\" }, context: personal }"
} > "$out"

echo "[brain-init] wrote $out"
