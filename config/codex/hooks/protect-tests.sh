#!/usr/bin/env bash
# PreToolUse/apply_patch: protect tests and sensitive files from destructive
# patch operations. Existing test edits remain allowed by default so Codex can
# write regression tests; set CODEX_PROTECT_EXISTING_TESTS=1 per project when
# tests require an explicit human gate.
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "[protect-tests] jq is required; patch blocked until it is installed." >&2
  exit 2
fi

INPUT="$(cat)"
PATCH="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
[ -z "$PATCH" ] && exit 0

deny() {
  jq -nc --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

if printf '%s' "$PATCH" | grep -Eiq '^[*][*][*][[:space:]]+Delete File:.*(test|spec|__tests__|__snapshots__|fixtures)[^[:space:]]*'; then
  deny "Deleting a test, snapshot, or fixture is blocked. Review the exact file and remove it manually if intentional."
fi

if printf '%s' "$PATCH" | grep -Eiq '^[*][*][*][[:space:]]+(Update|Delete) File:.*(^|/)([.]env([.]|$)|secrets?/|credentials[.]json|.*[.](pem|key|p12|pfx)$)'; then
  deny "Patching a credential or secret file is blocked. Use a redacted example or an approved secret-management path."
fi

if [ "${CODEX_PROTECT_EXISTING_TESTS:-0}" = "1" ] && printf '%s' "$PATCH" | grep -Eiq '^[*][*][*][[:space:]]+Update File:.*(test|spec|__tests__|__snapshots__|fixtures)'; then
  deny "This project protects existing test files. Add a new regression test or obtain explicit project approval before editing one."
fi

exit 0
