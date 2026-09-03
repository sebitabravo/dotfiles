#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/protect-codegraph-tracking.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/protect-codegraph-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

git -C "$TMP" init -q
mkdir -p "$TMP/openspec"
touch "$TMP/openspec/change.md"

payload() {
  jq -nc --arg cwd "$TMP" --arg cmd "$1" \
    '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$cwd,tool_input:{command:$cmd}}'
}

is_denied() { grep -q '"permissionDecision":"deny"'; }

printf '%s\n' '== real unquoted git add of an untracked artifact is denied'
OUT=$(payload 'git add openspec' | "$HOOK")
printf '%s' "$OUT" | is_denied

printf '%s\n' '== real unquoted git commit with a staged untracked artifact is denied'
git -C "$TMP" add openspec >/dev/null 2>&1 || true
OUT=$(payload 'git commit -m wip' | "$HOOK")
printf '%s' "$OUT" | is_denied
git -C "$TMP" reset -q >/dev/null 2>&1 || true

printf '%s\n' '== git add/commit named only inside a quoted prompt string is not a real command'
OUT=$(payload 'claude -p "crea notes.txt, luego git add notes.txt y git commit -m wip"' | "$HOOK")
[ -z "$OUT" ]

printf '%s\n' '== git add/commit named inside single-quoted text is not a real command either'
OUT=$(payload "echo 'reminder: run git add and git commit before lunch'" | "$HOOK")
[ -z "$OUT" ]

printf '%s\n' 'PASS: protect-codegraph-tracking distinguishes real git invocations from quoted prompt text'
