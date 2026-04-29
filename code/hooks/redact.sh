#!/usr/bin/env bash
# redact.sh -- thin wrapper to code/lib/redact.sh.
set -eu
FRAMEWORK_DIR="${NANOBRAIN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
exec bash "$FRAMEWORK_DIR/code/lib/redact.sh"
