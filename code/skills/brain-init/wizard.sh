#!/usr/bin/env bash
# wizard.sh -- two-question init. Writes _contexts.yaml.

set -eu

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
NANOBRAIN_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../../.." && pwd)}"
WORK_EMAIL=""
PERSONAL_EMAIL=""
NONINTERACTIVE=0
FORCE=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --brain-dir) BRAIN_DIR="$2"; shift 2 ;;
    --work) WORK_EMAIL="$2"; NONINTERACTIVE=1; shift 2 ;;
    --personal) PERSONAL_EMAIL="$2"; NONINTERACTIVE=1; shift 2 ;;
    --force) FORCE=1; shift ;;
    *) echo "[brain-init] unknown arg: $1" >&2; exit 64 ;;
  esac
done

mkdir -p "$BRAIN_DIR/brain"
out="$BRAIN_DIR/brain/_contexts.yaml"

if [ -f "$out" ] && [ "$FORCE" -ne 1 ]; then
  echo "[brain-init] $out exists; refusing to overwrite." >&2
  exit 1
fi

if [ "$NONINTERACTIVE" -eq 0 ]; then
  printf 'work email (blank to skip, solo personal): '
  read -r WORK_EMAIL || WORK_EMAIL=""
  printf 'personal email: '
  read -r PERSONAL_EMAIL || PERSONAL_EMAIL=""
fi

normalize_email() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

validate_email() {
  local label="$1" value="$2"
  [ -n "$value" ] || return 0
  if ! printf '%s' "$value" | grep -Eq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
    echo "[brain-init] invalid $label email: $value" >&2
    exit 64
  fi
}

regex_escape() {
  printf '%s' "$1" | perl -pe 's/([\\.^$|()\[\]{}*+?])/\\$1/g'
}

WORK_EMAIL=$(normalize_email "$WORK_EMAIL")
PERSONAL_EMAIL=$(normalize_email "$PERSONAL_EMAIL")
validate_email "work" "$WORK_EMAIL"
validate_email "personal" "$PERSONAL_EMAIL"

# Extract domains (everything after @).
work_dom=""
[ -n "$WORK_EMAIL" ] && work_dom=$(printf '%s' "$WORK_EMAIL" | awk -F@ 'NF>1{print $NF}')
pers_dom=""
[ -n "$PERSONAL_EMAIL" ] && pers_dom=$(printf '%s' "$PERSONAL_EMAIL" | awk -F@ 'NF>1{print $NF}')
[ -n "$pers_dom" ] || pers_dom="gmail.com"

work_dom_re=$(regex_escape "$work_dom")
pers_dom_re=$(regex_escape "$pers_dom")
work_email_re=$(regex_escape "$WORK_EMAIL")
personal_email_re=$(regex_escape "$PERSONAL_EMAIL")

tmp=$(mktemp "$BRAIN_DIR/brain/.contexts.XXXXXX")
trap 'rm -f "$tmp"' EXIT

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
    printf "    - { match: { from: '@%s$' }, context: work }\n" "$work_dom_re"
  fi
  printf "    - { match: { from: '@%s$' }, context: personal }\n" "$pers_dom_re"
  echo "  gcal:"
  if [ -n "$WORK_EMAIL" ]; then
    printf "    - { match: { calendar_id: '^%s$' }, context: work }\n" "$work_email_re"
  fi
  if [ -n "$PERSONAL_EMAIL" ]; then
    printf "    - { match: { calendar_id: '^%s$' }, context: personal }\n" "$personal_email_re"
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
  echo "  granola:"
  if [ -n "$work_dom" ]; then
    printf "    - { match: { attendee_domain: '%s$' }, context: work }\n" "$work_dom_re"
  fi
  printf "    - { match: { attendee_domain: '%s$' }, context: personal }\n" "$pers_dom_re"
} > "$tmp"

bash "$NANOBRAIN_DIR/code/lib/contexts.sh" validate "$tmp" >/dev/null
mv "$tmp" "$out"
trap - EXIT

echo "[brain-init] wrote $out"
