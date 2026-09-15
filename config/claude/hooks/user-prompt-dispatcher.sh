#!/usr/bin/env bash
# UserPromptSubmit dispatcher. Claude runs matching hooks in parallel; JSON
# array order is not a dependency graph. Secret detection therefore runs first
# here, and no prompt consumer is called when it blocks.
set -u

INPUT=$(cat 2>/dev/null || printf '%s' '{}')
HOOK_DIR="${CLAUDE_PROMPT_DISPATCHER_HOOK_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)}"
SECRET_HOOK="$HOOK_DIR/secret-detect.sh"
[ -r "$SECRET_HOOK" ] || {
  printf '[user-prompt-dispatcher] BLOCKED: missing secret detector: %s\n' "$SECRET_HOOK" >&2
  exit 2
}

# This is the security barrier. Its stderr is intentionally preserved so the
# user receives the actionable detector message, but no side-effecting hook is
# reached on a non-zero result.
printf '%s' "$INPUT" | "$SECRET_HOOK"
SECRET_RC=$?
[ "$SECRET_RC" -eq 0 ] || exit "$SECRET_RC"

# CodeGraph enriches context but is not a safety barrier. A stale index,
# unavailable daemon, or provider-side hiccup must not turn an optional
# integration into a hard prompt block.
command -v codegraph >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

OUTPUT=$(printf '%s' "$INPUT" | codegraph prompt-hook 2>/dev/null) || exit 0
[ -n "$OUTPUT" ] || exit 0
printf '%s' "$OUTPUT" |
  jq -e 'type == "object" and (.hookSpecificOutput | type == "object")' >/dev/null 2>&1 || exit 0
printf '%s\n' "$OUTPUT"
exit 0
