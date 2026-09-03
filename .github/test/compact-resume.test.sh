#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/compact-resume.py"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/compact-resume-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.git" "$TMP/.claude"
cat >"$TMP/.claude/task-roadmap.md" <<'EOF'
# Active roadmap

- [x] T001 Baseline
- [ ] T002 Implement checkpoint restore
- [>] T003 Verify recovery
EOF

payload=$(jq -n --arg cwd "$TMP" '{hook_event_name:"SessionStart",session_start_reason:"compact",cwd:$cwd}')
output=$(printf '%s' "$payload" | python3 "$HOOK")

printf '%s' "$output" | jq -e '.hookSpecificOutput.hookEventName == "SessionStart"' >/dev/null
printf '%s' "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("active roadmap: .claude/task-roadmap.md")' >/dev/null
printf '%s' "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("- [ ] T002 Implement checkpoint restore")' >/dev/null

empty=$(printf '%s' '{"hook_event_name":"SessionStart","session_start_reason":"startup"}' | python3 "$HOOK")
[ -z "$empty" ] || {
  printf 'expected no output for non-compact session\n' >&2
  exit 1
}

printf '%s\n' 'PASS: compact resume roadmap fixture'
