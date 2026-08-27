#!/usr/bin/env bash
# Severity-based gate for the GGA review: only 🔴 blocking findings fail the check.
# Usage: ai-review-gate.sh <gga_exit_code> <comment-file>
#   gga exit 0            -> PASSED (green)
#   FAILED + 🔴 findings  -> blocking (red)
#   FAILED + 🟡/🟣 only   -> non-blocking (green, nits posted)
#   FAILED, no table      -> infrastructure/ambiguous issue (red, conservative)
set -euo pipefail

code="${1:?usage: ai-review-gate.sh <gga_exit_code> <comment-file>}"
file="${2:?usage: ai-review-gate.sh <gga_exit_code> <comment-file>}"

if [[ "$code" == "0" ]]; then
  echo "review: PASSED"
  exit 0
fi

# Infra guard: if comment has no STATUS line, it's not a valid review (engine failure, not a finding)
if ! grep -q "^STATUS: \(PASSED\|FAILED\)" "$file"; then
  echo "review: infra failure — no STATUS line in comment (not a valid review)" >&2
  exit 1
fi

# GGA failed. Gate by severity, parsing the model's table (| Sev | File:Line | Issue | Rule |).
if grep -qE '^\| 🔴 ' "$file"; then
  echo "review: FAILED (🔴 blocking findings)" >&2
  exit 1
fi
if grep -qE '^\| (🟡|🟣) ' "$file"; then
  echo "review: failed but non-blocking only (🟡/🟣) - check passes" >&2
  exit 0
fi
echo "review: failed with no parseable findings (infra/ambiguous?) — check fails" >&2
exit 1
