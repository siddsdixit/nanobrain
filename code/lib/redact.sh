#!/usr/bin/env bash
# redact.sh -- strip secrets from stdin. Single perl pass for portability.
# Substitutes: OpenAI sk-, GitHub gh[pousr]_, AWS AKIA, Bearer tokens, JWTs,
# and password|token|api[_-]?key|secret assignments.

set -eu

perl -e '
my $count = 0;
while (<STDIN>) {
  $count += s/sk-[A-Za-z0-9]{20,}/[REDACTED]/g;
  $count += s/AKIA[0-9A-Z]{16}/[REDACTED]/g;
  $count += s/gh[pousr]_[A-Za-z0-9]{36,}/[REDACTED]/g;
  $count += s/xox[bpoars]-[A-Za-z0-9-]{10,}/[REDACTED]/g;
  $count += s/eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/[REDACTED]/g;
  $count += s/Bearer\s+[A-Za-z0-9._-]+/Bearer [REDACTED]/g;
  $count += s/(?i)(password|passwd|pwd|token|api[_-]?key|secret)\s*[:=]\s*\S+/$1: [REDACTED]/g;
  print;
}
if ($count > 0) { print STDERR "[redact] $count substitutions\n"; }
'
