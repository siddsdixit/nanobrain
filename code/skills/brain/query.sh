#!/usr/bin/env bash
# query.sh -- support script for the /brain skill.
# The skill body itself is a Claude prompt that reads the corpus; this script
# implements the deterministic sub-commands (status, paths, links).

set -u

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
CORPUS_DIR="$BRAIN_DIR/brain"

cmd="${1:-help}"

case "$cmd" in
  paths)
    cat <<EOF
brain dir:   $BRAIN_DIR
corpus:      $CORPUS_DIR/{self,goals,projects,people,learnings,decisions}.md
firehose:    $CORPUS_DIR/raw.md (never read in full)
sources:     $BRAIN_DIR/data/<source>/INBOX.md
contexts:    $CORPUS_DIR/_contexts.yaml
EOF
    ;;

  status|health)
    [ -d "$BRAIN_DIR" ] || { echo "no brain at $BRAIN_DIR"; exit 1; }
    [ -d "$BRAIN_DIR/.git" ] || { echo "$BRAIN_DIR is not a git repo"; exit 1; }

    echo "=== brain at $BRAIN_DIR ==="
    cd "$BRAIN_DIR"

    echo
    echo "--- last commit ---"
    git log -1 --pretty=format:'%h %ad %s' --date=short 2>/dev/null || echo "no commits yet"

    echo
    echo "--- corpus sizes ---"
    if [ -d "$CORPUS_DIR" ]; then
      wc -l "$CORPUS_DIR"/*.md 2>/dev/null | grep -v total | sort -n
    fi

    echo
    echo "--- sources (INBOX entries) ---"
    if [ -d "$BRAIN_DIR/data" ]; then
      for src in "$BRAIN_DIR/data"/*/; do
        [ -d "$src" ] || continue
        name=$(basename "$src")
        if [ -f "$src/INBOX.md" ]; then
          entries=$(grep -c '^### ' "$src/INBOX.md" 2>/dev/null || echo 0)
          last=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M' "$src/INBOX.md" 2>/dev/null || echo "?")
          printf '  %-12s %4d entries (last touched %s)\n' "$name" "$entries" "$last"
        fi
      done
    fi
    ;;

  links)
    target="${2:-}"
    if [ -z "$target" ]; then
      echo "usage: query.sh links <entity-name>" >&2
      exit 2
    fi
    cd "$CORPUS_DIR" 2>/dev/null || { echo "no corpus at $CORPUS_DIR"; exit 1; }
    echo "=== references to [[$target]] ==="
    grep -n "\[\[$target\]\]" *.md 2>/dev/null | head -50 || echo "no references found"
    ;;

  help|*)
    cat <<EOF
usage: query.sh <subcmd>

  paths           print canonical brain paths
  status|health   last commit, corpus sizes, source freshness
  links <name>    grep [[backlinks]] to <name>

Free-form questions are handled by the /brain Claude skill, not this script.
EOF
    ;;
esac
