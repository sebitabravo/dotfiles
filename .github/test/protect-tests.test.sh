#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/protect-tests.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/protect-tests.XXXXXX")
trap 'rm -rf -- "$TMP"' EXIT

# Existing tests in a non-git project still need the normal hook decision.  A
# failed `git rev-parse` must not terminate gate() under set -e before it emits
# that decision.
PROJECT="$TMP/not-a-git-project"
mkdir -p "$PROJECT/tests"
TEST_FILE="$PROJECT/tests/existing.test.sh"
touch "$TEST_FILE"

payload() {
  jq -nc \
    --arg cwd "$PROJECT" \
    --arg path "$TEST_FILE" \
    --arg mode "$1" \
    '{tool_name:"Edit",permission_mode:$mode,cwd:$cwd,session_id:"protect-tests-regression",tool_input:{file_path:$path}}'
}

output=$(payload default | bash "$HOOK")
printf '%s' "$output" | jq -e \
  '.hookSpecificOutput.permissionDecision == "ask" and
   (.hookSpecificOutput.permissionDecisionReason | contains("TEST PROTECTION"))' \
  >/dev/null

output=$(payload bypassPermissions | bash "$HOOK")
printf '%s' "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null

printf 'protect-tests tests: PASS\n'
