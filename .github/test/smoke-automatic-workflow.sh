#!/usr/bin/env bash
# smoke-automatic-workflow.sh — verifica el contrato del oneshot sin inferencia.
#
# Ejecuta los hooks versionados como lo haría Claude Code alrededor de una
# sesión descartable: UserPromptSubmit, TaskCreated/TaskCompleted y Stop. No
# llama a un provider ni toca ~/.claude; el estado vive en un HOME temporal.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
CLAUDE_DIR="$REPO_ROOT/config/claude"

AUTOMATIC="$CLAUDE_DIR/hooks/automatic-workflow.sh"
STOP="$CLAUDE_DIR/hooks/automatic-workflow-stop.sh"
TASK_CONTRACT="$CLAUDE_DIR/hooks/task-contract.sh"
STATE_LIB="$CLAUDE_DIR/hooks/lib/automatic-workflow-state.sh"
VALIDATOR="$CLAUDE_DIR/scripts/validate-task-roadmap.py"
RUNNER="$CLAUDE_DIR/hooks/lib/test-runner.sh"

command -v jq >/dev/null 2>&1 || {
  printf '[workflow-smoke] jq es requerido.\n' >&2
  exit 2
}
command -v git >/dev/null 2>&1 || {
  printf '[workflow-smoke] git es requerido.\n' >&2
  exit 2
}
command -v python3 >/dev/null 2>&1 || {
  printf '[workflow-smoke] python3 es requerido.\n' >&2
  exit 2
}

TMP=$(mktemp -d "${TMPDIR:-/tmp}/automatic-workflow-smoke.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

PROJECT="$TMP/project"
STATE="$TMP/state"
TRUST_FILE="$TMP/trusted-repositories"
mkdir -p "$PROJECT/.claude/task-receipts" "$PROJECT/src"
git -C "$PROJECT" init -q

# The production Stop hook never executes a repository-owned test command
# without an explicit trust decision outside the repository. The disposable
# fixture is intentionally trusted here so this smoke test exercises the
# convergent PASS path instead of testing the security BLOCKED path again.
printf '%s\n' "$PROJECT" >"$TRUST_FILE"

cat >"$PROJECT/test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ -s src/one.txt ]
[ -s src/two.txt ]
EOF
chmod +x "$PROJECT/test.sh"

cat >"$PROJECT/TASK-ROADMAP.md" <<'EOF'
# Automatic task roadmap

- [ ] T001 [depends_on: none] [paths: src/one.txt] Create the first artifact
- [ ] T002 [depends_on: T001] [paths: src/two.txt] Create the second artifact
EOF

git -C "$PROJECT" add test.sh TASK-ROADMAP.md
git -C "$PROJECT" -c user.name=workflow-smoke -c user.email=workflow-smoke@example.com commit -qm baseline

# shellcheck source=/dev/null
. "$STATE_LIB"
export CLAUDE_AUTOMATION_STATE_DIR="$STATE"
export CLAUDE_AUTOMATION_VALIDATOR="$VALIDATOR"
export CLAUDE_AUTOMATION_TEST_RUNNER="$RUNNER"
export CLAUDE_AUTOMATION_PYTHON=python3
export CLAUDE_REPOSITORY_TRUST_FILE="$TRUST_FILE"

prompt_payload() {
  jq -nc --arg cwd "$PROJECT" --arg session "$1" --arg prompt "$2" \
    '{hook_event_name:"UserPromptSubmit",cwd:$cwd,session_id:$session,prompt:$prompt}'
}

stop_payload() {
  jq -nc --arg cwd "$PROJECT" --arg session "$1" \
    '{hook_event_name:"Stop",cwd:$cwd,session_id:$session,stop_hook_active:true}'
}

task_payload() {
  jq -nc --arg cwd "$PROJECT" --arg event "$1" --arg id "$2" \
    --arg subject "$3" --arg description "$4" \
    '{hook_event_name:$event,cwd:$cwd,task_id:$id,task_subject:$subject,task_description:$description}'
}

task_description() {
  cat <<EOF
ROADMAP: TASK-ROADMAP.md
DEPENDS_ON: $1
PATHS: $2
ACCEPTANCE: $3
VERIFY: test.sh
RECEIPT: .claude/task-receipts/$4.md
EOF
}

SESSION_ID=workflow-smoke
printf '%s\n' '== UserPromptSubmit activa el oneshot'
prompt_output=$(prompt_payload "$SESSION_ID" 'Implementa los dos artefactos y deja todo pasando' | "$AUTOMATIC")
printf '%s' "$prompt_output" | jq -e \
  '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and
   (.hookSpecificOutput.additionalContext | contains("AUTOMATIC ONESHOT WORKFLOW: ACTIVE"))' \
  >/dev/null
SESSION_STATE=$(automation_state_path "$PROJECT" "$SESSION_ID")
SESSION_RECEIPT=$(automation_receipt_path "$PROJECT" "$SESSION_ID")
ACTIVATION=$(automation_activation_id "$PROJECT" "$SESSION_ID")
[ -s "$SESSION_STATE" ]

printf '%s\n' '== Stop bloquea una sesión incompleta'
cat >"$SESSION_RECEIPT" <<EOF
ROADMAP: TASK-ROADMAP.md
ACTIVATION: $ACTIVATION
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: intentionally incomplete roadmap
EOF
set +e
stop_payload "$SESSION_ID" | "$STOP" >"$TMP/blocked.out" 2>"$TMP/blocked.err"
blocked_rc=$?
set -e
[ "$blocked_rc" -eq 2 ]
grep -Fq 'pendiente' "$TMP/blocked.err"
[ -s "$SESSION_STATE" ]

printf '%s\n' '== un bloqueo explícito conserva el estado sin simular PASS'
cat >"$SESSION_RECEIPT" <<EOF
ROADMAP: TASK-ROADMAP.md
ACTIVATION: $ACTIVATION
STATUS: BLOCKED
ACCEPTANCE: PENDING
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: external dependency unavailable; work must resume later
EOF
stop_payload "$SESSION_ID" | "$STOP" >"$TMP/non-final.out" 2>"$TMP/non-final.err"
grep -Fq 'BLOCKED: se conserva el estado activo' "$TMP/non-final.err"
[ -s "$SESSION_STATE" ]

printf '%s\n' '== Tasks requieren contrato y receipts PASS'
task_payload TaskCreated task-001 '[T001] Create first artifact' \
  "$(task_description none src/one.txt 'src/one.txt existe y no está vacío' task-001)" | "$TASK_CONTRACT"
task_payload TaskCreated task-002 '[T002] Create second artifact' \
  "$(task_description task-001 src/two.txt 'src/two.txt existe y no está vacío' task-002)" | "$TASK_CONTRACT"

printf '%s\n' 'one' >"$PROJECT/src/one.txt"
cat >"$PROJECT/.claude/task-receipts/task-001.md" <<EOF
TASK_ID: task-001
ACTIVATION: $ACTIVATION
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: src/one.txt created
EOF
task_payload TaskCompleted task-001 '[T001] Create first artifact' \
  "$(task_description none src/one.txt 'src/one.txt existe y no está vacío' task-001)" | "$TASK_CONTRACT"

printf '%s\n' 'two' >"$PROJECT/src/two.txt"
cat >"$PROJECT/.claude/task-receipts/task-002.md" <<EOF
TASK_ID: task-002
ACTIVATION: $ACTIVATION
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: src/two.txt created
EOF
task_payload TaskCompleted task-002 '[T002] Create second artifact' \
  "$(task_description task-001 src/two.txt 'src/two.txt existe y no está vacío' task-002)" | "$TASK_CONTRACT"

cat >"$PROJECT/TASK-ROADMAP.md" <<'EOF'
# Automatic task roadmap

- [x] T001 [depends_on: none] [paths: src/one.txt] Create the first artifact
- [x] T002 [depends_on: T001] [paths: src/two.txt] Create the second artifact
EOF
cat >"$SESSION_RECEIPT" <<EOF
ROADMAP: TASK-ROADMAP.md
ACTIVATION: $ACTIVATION
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: test.sh exit 0; task receipts PASS; roadmap validator PASS
EOF

printf '%s\n' '== Stop acepta sólo después de convergencia completa'
stop_payload "$SESSION_ID" | "$STOP" >"$TMP/pass.out" 2>"$TMP/pass.err"
grep -Fq 'PASS' "$TMP/pass.err"
[ ! -e "$SESSION_STATE" ]

printf '[workflow-smoke] PASS: oneshot, bloqueo parcial, contrato de tasks, receipts y Stop convergente.\n'
