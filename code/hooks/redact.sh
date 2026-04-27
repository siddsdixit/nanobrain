#!/usr/bin/env bash
# Redact common secret patterns from a stream. Reads stdin, writes redacted
# content to stdout. Used by capture.sh as a defense-in-depth filter before
# any transcript content leaves the user's machine via `claude -p`.
#
# This is a best-effort filter, not a guarantee. New secret formats appear
# constantly. Users should still avoid pasting secrets into chat.
#
# Patterns covered:
#   - OpenAI keys           (sk-...)
#   - Anthropic keys        (sk-ant-...)
#   - GitHub PATs           (ghp_..., gho_..., ghs_..., ghr_...)
#   - AWS access keys       (AKIA..., ASIA...)
#   - Slack tokens          (xox[bopsa]-...)
#   - Generic Bearer tokens (Authorization: Bearer <token>)
#   - JWT tokens            (eyJ...)
#   - Inline assignments    (api_key=..., password=..., secret=...)
#
# Tune patterns by editing this file. Smoke test asserts known secrets are
# redacted; if you change the patterns, update the test cases too.

set -uo pipefail

sed -E \
  -e 's/sk-ant-[A-Za-z0-9_-]{20,}/<<REDACTED:anthropic-key>>/g' \
  -e 's/sk-[A-Za-z0-9_-]{20,}/<<REDACTED:openai-key>>/g' \
  -e 's/(ghp|gho|ghs|ghr)_[A-Za-z0-9]{30,}/<<REDACTED:github-token>>/g' \
  -e 's/(AKIA|ASIA)[0-9A-Z]{16}/<<REDACTED:aws-access-key>>/g' \
  -e 's/xox[bopsa]-[A-Za-z0-9-]{10,}/<<REDACTED:slack-token>>/g' \
  -e 's/(Bearer |bearer )[A-Za-z0-9._~+/-]{20,}=*/\1<<REDACTED>>/g' \
  -e 's/eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}/<<REDACTED:jwt>>/g' \
  -e 's/(api[_-]?key[[:space:]]*[:=][[:space:]]*"?)[A-Za-z0-9_-]{16,}/\1<<REDACTED>>/gI' \
  -e 's/(password[[:space:]]*[:=][[:space:]]*"?)[^[:space:]"]{6,}/\1<<REDACTED>>/gI' \
  -e 's/(client[_-]?secret[[:space:]]*[:=][[:space:]]*"?)[A-Za-z0-9_-]{12,}/\1<<REDACTED>>/gI'
