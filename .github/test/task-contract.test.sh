#!/bin/bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/task-contract.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/task-contract-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude/task-receipts"
printf '# Test roadmap\n' >"$TMP/roadmap.md"

valid_description() {
  cat <<'EOF'
ROADMAP: roadmap.md
DEPENDS_ON: none
PATHS: src/example.txt
ACCEPTANCE: the example file exists
VERIFY: test -f src/example.txt
RECEIPT: .claude/task-receipts/task-001.md
EOF
}

payload() {
  local event=$1
  local description=$2
  jq -n --arg event "$event" --arg cwd "$TMP" --arg id "task-001" \
    --arg subject "[T001] Test task" --arg description "$description" \
    '{hook_event_name:$event,cwd:$cwd,task_id:$id,task_subject:$subject,task_description:$description}'
}

expect_rc() {
  local expected=$1
  shift
  local actual
  set +e
  "$@"
  actual=$?
  set -e
  [ "$actual" -eq "$expected" ] || {
    printf 'expected rc=%s, got rc=%s\n' "$expected" "$actual" >&2
    return 1
  }
}

printf '%s\n' '== TaskCreated valid contract'
payload TaskCreated "$(valid_description)" | "$HOOK"

printf '%s\n' '== TaskCreated rejects missing acceptance'
missing_acceptance=$(valid_description | sed '/^ACCEPTANCE:/d')
expect_rc 2 sh -c 'printf "%s" "$1" | "$2"' sh "$(payload TaskCreated "$missing_acceptance")" "$HOOK"

printf '%s\n' '== TaskCompleted rejects missing receipt'
expect_rc 2 sh -c 'printf "%s" "$1" | "$2"' sh "$(payload TaskCompleted "$(valid_description)")" "$HOOK"

printf '%s\n' '== TaskCompleted rejects non-pass receipt'
cat >"$TMP/.claude/task-receipts/task-001.md" <<'EOF'
TASK_ID: task-001
STATUS: BLOCKED
EOF
expect_rc 2 sh -c 'printf "%s" "$1" | "$2"' sh "$(payload TaskCompleted "$(valid_description)")" "$HOOK"

printf '%s\n' '== TaskCompleted rejects pass without verification evidence'
cat >"$TMP/.claude/task-receipts/task-001.md" <<'EOF'
TASK_ID: task-001
STATUS: PASS
EOF
expect_rc 2 sh -c 'printf "%s" "$1" | "$2"' sh "$(payload TaskCompleted "$(valid_description)")" "$HOOK"

printf '%s\n' '== TaskCompleted rejects absolute receipt traversal'
traversal_description=$(valid_description | sed 's#RECEIPT:.*#RECEIPT: /tmp/cavecrew/../task-001.md#')
expect_rc 2 sh -c 'printf "%s" "$1" | "$2"' sh "$(payload TaskCompleted "$traversal_description")" "$HOOK"

printf '%s\n' '== TaskCreated rejects empty ownership marker'
none_paths=$(valid_description | sed 's#PATHS:.*#PATHS: none#')
expect_rc 2 sh -c 'printf "%s" "$1" | "$2"' sh "$(payload TaskCreated "$none_paths")" "$HOOK"

printf '%s\n' '== TaskCreated rejects ownership traversal'
unsafe_paths=$(valid_description | sed 's#PATHS:.*#PATHS: ../outside.txt#')
expect_rc 2 sh -c 'printf "%s" "$1" | "$2"' sh "$(payload TaskCreated "$unsafe_paths")" "$HOOK"

printf '%s\n' '== TaskCompleted accepts matching pass receipt'
cat >"$TMP/.claude/task-receipts/task-001.md" <<'EOF'
TASK_ID: task-001
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_EXIT: 0
EVIDENCE: fixture verification output
EOF
payload TaskCompleted "$(valid_description)" | "$HOOK"

printf '%s\n' 'PASS: task contract gate fixtures'
