#!/usr/bin/env bash
# PreToolUse/Bash: prevent private identifiers and credentials from being sent
# through GitHub issue/PR creation commands.
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "[privacy-review] jq is required; outbound GitHub submission blocked." >&2
  exit 2
fi

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
[ -z "$COMMAND" ] && exit 0

if ! printf '%s' "$COMMAND" | grep -Eiq '(^|[[:space:];|])gh[[:space:]]+(issue|pr)[[:space:]]+create([[:space:];|]|$)'; then
  exit 0
fi

for pattern in \
  '/Users/[A-Za-z0-9._-]+' \
  '/home/[A-Za-z0-9._-]+' \
  'hostname:[^[:space:]]+[.]local' \
  'ghp_[A-Za-z0-9]{36,}' \
  'github_pat_[A-Za-z0-9_]{22,}' \
  'sk-[A-Za-z0-9_-]{20,}' \
  'AKIA[0-9A-Z]{16}' \
  'xox[bprs]-[0-9A-Za-z-]+' \
  '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}'; do
  if printf '%s' "$COMMAND" | grep -Eq -- "$pattern"; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"GitHub issue/PR submission contains a private identifier or credential-shaped value. Replace it with a public-safe placeholder."}}'
    exit 0
  fi
done

exit 0
