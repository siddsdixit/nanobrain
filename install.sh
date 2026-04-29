#!/usr/bin/env bash
# install.sh -- one command, brain ready.
#
# Does:
#   1. Copy framework into <brain_dir>/.nanobrain
#   2. Run brain-init wizard (writes _contexts.yaml)
#   3. Render and load launchd autosave + ingest plists (unless --skip-cron)
#   4. Wire the Stop hook into ~/.claude/settings.json (unless --skip-hook)
#   5. git init + initial commit
#   6. Optional: gh repo create + push (--gh-repo <name> [--public|--private])
#
# Usage:
#   bash install.sh <brain_dir>
#     [--work EMAIL] [--personal EMAIL]
#     [--skip-cron] [--skip-hook]
#     [--gh-repo <name>] [--public|--private]
#
# Defaults: --private. --skip-cron and --skip-hook are off (we install both).

set -eu

BRAIN_DIR="${1:-}"
[ -n "$BRAIN_DIR" ] || { echo "usage: install.sh <brain_dir> [--work EMAIL] [--personal EMAIL] [--skip-cron] [--skip-hook] [--gh-repo NAME] [--public|--private]" >&2; exit 64; }
shift

WORK=""
PERSONAL=""
SKIP_CRON=0
SKIP_HOOK=0
GH_REPO=""
GH_VIS="--private"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --work)      WORK="$2"; shift 2 ;;
    --personal)  PERSONAL="$2"; shift 2 ;;
    --skip-cron) SKIP_CRON=1; shift ;;
    --skip-hook) SKIP_HOOK=1; shift ;;
    --gh-repo)   GH_REPO="$2"; shift 2 ;;
    --public)    GH_VIS="--public"; shift ;;
    --private)   GH_VIS="--private"; shift ;;
    *) echo "[install] unknown arg: $1" >&2; exit 64 ;;
  esac
done

FRAMEWORK_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. Copy framework. .nanobrain inside the brain dir keeps everything together.
mkdir -p "$BRAIN_DIR/.nanobrain" "$BRAIN_DIR/brain" "$BRAIN_DIR/data"
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete \
    --exclude '.git' --exclude 'tests' --exclude 'examples' \
    "$FRAMEWORK_DIR/" "$BRAIN_DIR/.nanobrain/"
else
  cp -R "$FRAMEWORK_DIR/code" "$BRAIN_DIR/.nanobrain/"
  cp -R "$FRAMEWORK_DIR/docs" "$BRAIN_DIR/.nanobrain/" 2>/dev/null || true
fi
echo "[install] framework copied to $BRAIN_DIR/.nanobrain"

# 2. brain-init (non-interactive if flags; else prompts).
init_args=""
[ -n "$WORK" ]     && init_args="$init_args --work $WORK"
[ -n "$PERSONAL" ] && init_args="$init_args --personal $PERSONAL"
if [ ! -f "$BRAIN_DIR/brain/_contexts.yaml" ]; then
  # shellcheck disable=SC2086
  BRAIN_DIR="$BRAIN_DIR" bash "$FRAMEWORK_DIR/code/skills/brain-init/wizard.sh" --brain-dir "$BRAIN_DIR" $init_args
fi

# 3. cron / autosave plists (load unless --skip-cron).
if [ "$SKIP_CRON" -eq 1 ]; then
  BRAIN_DIR="$BRAIN_DIR" bash "$FRAMEWORK_DIR/code/cron/install.sh" --skip-cron --brain-dir "$BRAIN_DIR"
  echo "[install] cron rendered (not loaded; --skip-cron)"
else
  BRAIN_DIR="$BRAIN_DIR" bash "$FRAMEWORK_DIR/code/cron/install.sh" --brain-dir "$BRAIN_DIR" \
    && echo "[install] launchd jobs registered" \
    || echo "[install] (cron load failed; non-fatal)"
fi

# 4. Wire Claude capture hooks into ~/.claude/settings.json.
# The hook is a sub-50ms file append (no LLM). Distill happens later via the drainer.
# We register on Stop, SessionEnd, and PreCompact so all session-lifecycle moments enqueue.
if [ "$SKIP_HOOK" -eq 1 ]; then
  echo "[install] capture hooks NOT wired (--skip-hook)"
else
  SETTINGS="$HOME/.claude/settings.json"
  HOOK_CMD="BRAIN_DIR=$BRAIN_DIR NANOBRAIN_DIR=$BRAIN_DIR/.nanobrain bash $BRAIN_DIR/.nanobrain/code/hooks/capture.sh"
  mkdir -p "$HOME/.claude"
  if [ ! -f "$SETTINGS" ]; then
    cat > "$SETTINGS" <<JSON
{
  "hooks": {
    "Stop":        [{ "matcher": "", "hooks": [{ "type": "command", "command": "$HOOK_CMD" }] }],
    "SessionEnd":  [{ "matcher": "", "hooks": [{ "type": "command", "command": "$HOOK_CMD" }] }],
    "PreCompact":  [{ "matcher": "", "hooks": [{ "type": "command", "command": "$HOOK_CMD" }] }]
  }
}
JSON
    echo "[install] capture hooks wired (Stop, SessionEnd, PreCompact) in new $SETTINGS"
  else
    if grep -q "$BRAIN_DIR/.nanobrain/code/hooks/capture.sh" "$SETTINGS" 2>/dev/null; then
      echo "[install] capture hooks already present in $SETTINGS"
    else
      cp "$SETTINGS" "$SETTINGS.local-backup-$(date +%s)"
      if command -v jq >/dev/null 2>&1; then
        tmp=$(mktemp)
        jq --arg cmd "$HOOK_CMD" '
          .hooks //= {} |
          .hooks.Stop //= [] |
          .hooks.SessionEnd //= [] |
          .hooks.PreCompact //= [] |
          .hooks.Stop += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}] |
          .hooks.SessionEnd += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}] |
          .hooks.PreCompact += [{"matcher": "", "hooks": [{"type": "command", "command": $cmd}]}]
        ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS" \
          && echo "[install] capture hooks appended to $SETTINGS (Stop, SessionEnd, PreCompact; backup created)" \
          || { echo "[install] WARN: jq edit of settings.json failed; manual edit required" >&2; rm -f "$tmp"; }
      else
        echo "[install] WARN: jq missing; manual edit of $SETTINGS needed:" >&2
        echo "         add capture hooks (Stop, SessionEnd, PreCompact): $HOOK_CMD" >&2
      fi
    fi
  fi
fi

# 5. git init + initial commit.
if [ ! -d "$BRAIN_DIR/.git" ]; then
  ( cd "$BRAIN_DIR" && git init -q ) || true
  cat > "$BRAIN_DIR/.gitignore" <<'GIT'
.DS_Store
.nanobrain/.harvey-logs/
*.log
.cache/
.tmp/
GIT
  ( cd "$BRAIN_DIR" && git add -A && git commit -q -m "init nanobrain brain" ) \
    && echo "[install] git initialized + initial commit"
fi

# Log the bootstrap event itself.
BRAIN_DIR="$BRAIN_DIR" NANOBRAIN_DIR="$BRAIN_DIR/.nanobrain" \
  bash "$BRAIN_DIR/.nanobrain/code/lib/log_op.sh" install "brain bootstrapped at $BRAIN_DIR" 2>/dev/null || true

# 6. Optional: GitHub repo creation + push.
if [ -n "$GH_REPO" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "[install] WARN: gh CLI not installed; skipping GitHub setup" >&2
  else
    cd "$BRAIN_DIR"
    if gh repo view "$GH_REPO" >/dev/null 2>&1; then
      echo "[install] GitHub repo $GH_REPO already exists; setting remote and pushing"
      remote=$(gh repo view "$GH_REPO" --json sshUrl -q .sshUrl 2>/dev/null || echo "")
      if [ -n "$remote" ]; then
        git remote add origin "$remote" 2>/dev/null || git remote set-url origin "$remote"
        git push -u origin HEAD 2>&1 | tail -3 \
          && echo "[install] pushed to $GH_REPO" \
          || echo "[install] WARN: push failed; check remote permissions" >&2
      fi
    else
      gh repo create "$GH_REPO" "$GH_VIS" --source=. --remote=origin --push 2>&1 | tail -3 \
        && echo "[install] created + pushed to $GH_REPO ($GH_VIS)" \
        || echo "[install] WARN: gh repo create failed" >&2
    fi
  fi
fi

echo
echo "[install] done."
echo
echo "Brain at:       $BRAIN_DIR"
echo "Framework at:   $BRAIN_DIR/.nanobrain"
echo "Contexts:       $BRAIN_DIR/brain/_contexts.yaml"
echo
echo "Next steps:"
echo "  1. Open Claude Code in any project."
echo "  2. Have one normal conversation."
echo "  3. End the session. Run: cat $BRAIN_DIR/brain/decisions.md"
echo "     The brain will have captured what you decided."
echo
[ "$SKIP_CRON" -eq 0 ] && echo "  Autosave runs every 30 min (launchd)."
[ "$SKIP_HOOK" -eq 0 ] && echo "  Stop hook fires at end of every Claude turn."
[ -n "$GH_REPO" ]      && echo "  Pushing to GitHub on every commit."
