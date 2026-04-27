#!/usr/bin/env bash
# Generic agent-CLI wrapper. Captures the conversation that flows through any
# CLI (codex, gemini, aider, etc.) into a temp transcript, then fires
# nanobrain's capture.sh with a Claude-Code-shaped hook payload on exit.
#
# Usage:
#   wrap.sh <cli-binary> [args...]
#
# Aliases pattern (recommended in ~/.zshrc or ~/.bashrc):
#   alias codex='$HOME/nanobrain/code/runtimes/wrap.sh codex'
#   alias gemini='$HOME/nanobrain/code/runtimes/wrap.sh gemini'
#   alias aider='$HOME/nanobrain/code/runtimes/wrap.sh aider'
#
# Env:
#   BRAIN_DIR           Default $HOME/brain
#   NANOBRAIN_RUNTIME   Override the runtime label (defaults to the CLI name)
#   NANOBRAIN_NO_CAPTURE  Set to 1 to skip the capture hook (for testing)

set -uo pipefail

CLI="${1:-}"
if [ -z "$CLI" ]; then
  echo "usage: $0 <cli-binary> [args...]" >&2
  exit 2
fi
shift

if ! command -v "$CLI" >/dev/null 2>&1; then
  echo "wrap.sh: $CLI not found on PATH" >&2
  exit 127
fi

BRAIN_DIR="${BRAIN_DIR:-$HOME/brain}"
RUNTIME="${NANOBRAIN_RUNTIME:-$CLI}"
TRANSCRIPT="$(mktemp -t "nanobrain-${RUNTIME}.XXXXXX")"
SESSION_ID="$(uuidgen 2>/dev/null || printf '%s-%s' "$RUNTIME" "$(date +%s)")"

# Run the underlying CLI, tee its output to the transcript. Pass through
# stdin so interactive prompts work.
set +e
"$CLI" "$@" 2>&1 | tee "$TRANSCRIPT"
EXIT_CODE=${PIPESTATUS[0]}
set -e

# Skip capture if disabled (test mode) or transcript is too small
if [ "${NANOBRAIN_NO_CAPTURE:-0}" = "1" ]; then
  rm -f "$TRANSCRIPT"
  exit "$EXIT_CODE"
fi

TRANSCRIPT_BYTES="$(wc -c < "$TRANSCRIPT" 2>/dev/null || echo 0)"
if [ "${TRANSCRIPT_BYTES:-0}" -lt 500 ]; then
  rm -f "$TRANSCRIPT"
  exit "$EXIT_CODE"
fi

# Fire the capture pipeline. The hook_event_name=SessionEnd makes capture.sh
# treat this as a forced capture (terminal event, not throttled).
HOOK_PAYLOAD="$(printf '{"session_id":"%s","transcript_path":"%s","stop_hook_active":false,"hook_event_name":"SessionEnd","runtime":"%s"}' \
  "$SESSION_ID" "$TRANSCRIPT" "$RUNTIME")"

if [ -x "$BRAIN_DIR/code/hooks/capture.sh" ]; then
  echo "$HOOK_PAYLOAD" | bash "$BRAIN_DIR/code/hooks/capture.sh" >/dev/null 2>&1 || true
fi

# Clean up after capture has read the transcript
rm -f "$TRANSCRIPT"
exit "$EXIT_CODE"
