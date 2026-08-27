#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fixture strings intentionally preserve literal shell variables.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/automatic-workflow-stop.sh"
STATE_LIB="$ROOT/config/claude/hooks/lib/automatic-workflow-state.sh"
VALIDATOR="$ROOT/config/claude/scripts/validate-task-roadmap.py"
RUNNER="$ROOT/config/claude/hooks/lib/test-runner.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/automatic-workflow-stop-test.XXXXXX")
PROJECT="$TMP/project"
STATE="$TMP/state"
TRUST_FILE="$TMP/trusted-repositories"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$PROJECT/.claude"
git -C "$PROJECT" init -q
PROJECT=$(git -C "$PROJECT" rev-parse --show-toplevel)
printf '%s\n' "$PROJECT" >"$TRUST_FILE"
cat >"$PROJECT/test.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$PROJECT/test.sh"
cat >"$PROJECT/.claude/task-roadmap.md" <<'EOF'
# Automatic task roadmap

- [x] T001 [depends_on: none] Validate the automatic workflow
EOF
git -C "$PROJECT" add test.sh .claude/task-roadmap.md
git -C "$PROJECT" -c user.name=test -c user.email=test@example.com commit -qm baseline

payload() {
  jq -nc --arg cwd "$PROJECT" --arg session "$1" \
    '{hook_event_name:"Stop",cwd:$cwd,session_id:$session,stop_hook_active:true}'
}

# shellcheck source=/dev/null
. "$STATE_LIB"
export CLAUDE_AUTOMATION_STATE_DIR="$STATE"
export CLAUDE_AUTOMATION_VALIDATOR="$VALIDATOR"
export CLAUDE_AUTOMATION_TEST_RUNNER="$RUNNER"
export CLAUDE_REPOSITORY_TRUST_FILE="$TRUST_FILE"

echo '== missing jq fails closed with an actionable diagnostic'
NO_JQ_BIN="$TMP/no-jq-bin"
mkdir -p "$NO_JQ_BIN"
for command_name in bash cat env; do
  ln -s -- "$(command -v "$command_name")" "$NO_JQ_BIN/$command_name"
done
set +e
out=$(printf '%s' '{}' | PATH="$NO_JQ_BIN" "$HOOK" 2>&1)
rc=$?
set -e
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'jq is not installed: blocking preventively'
printf '%s' "$out" | grep -Fq 'brew install jq'

activate() {
  automation_activate "$PROJECT" "$1" oneshot
  receipt=$(automation_receipt_path "$PROJECT" "$1")
  activation=$(automation_activation_id "$PROJECT" "$1")
  cat >"$receipt" <<EOF
ROADMAP: .claude/task-roadmap.md
ACTIVATION: $activation
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: test.sh exit 0 and roadmap validator PASS
EOF
}

echo '== missing receipt becomes an explicit BLOCKED state without a retry loop'
automation_activate "$PROJECT" missing oneshot
set +e
payload missing | "$HOOK" >/dev/null 2>"$TMP/missing.err"
rc=$?
set -e
[ "$rc" -eq 0 ]
grep -Fq 'BLOCKED: falta el receipt' "$TMP/missing.err"
receipt=$(automation_receipt_path "$PROJECT" missing)
grep -Eq '^STATUS:[[:space:]]*BLOCKED$' "$receipt"
grep -Eq '^ACCEPTANCE:[[:space:]]*PENDING$' "$receipt"
grep -Eq "^ACTIVATION:[[:space:]]*$(automation_activation_id "$PROJECT" missing)$" "$receipt"
[ -s "$STATE/missing.json" ]

echo '== legacy v1 state without activation is reinitialized and stale PASS is discarded'
legacy_state=$(automation_state_path "$PROJECT" legacy-state)
legacy_receipt=$(automation_receipt_path "$PROJECT" legacy-state)
legacy_project_receipt=$(automation_project_receipt_path "$PROJECT" legacy-state)
cat >"$legacy_state" <<EOF
{"version":1,"root":"$PROJECT","session_id":"legacy-state","mode":"oneshot"}
EOF
cat >"$legacy_receipt" <<'EOF'
ROADMAP: .claude/task-roadmap.md
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_EXIT: 0
EVIDENCE: historical PASS must not be reused
EOF
cat >"$legacy_project_receipt" <<'EOF'
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_EXIT: 0
EVIDENCE: legacy project PASS must not be reused
EOF
set +e
payload legacy-state | "$HOOK" >/dev/null 2>"$TMP/legacy-state.err"
rc=$?
set -e
[ "$rc" -eq 0 ]
legacy_activation=$(jq -r '.activation_id' "$legacy_state")
[ -n "$legacy_activation" ]
grep -Eq '^STATUS:[[:space:]]*BLOCKED$' "$legacy_receipt"
grep -Eq "^ACTIVATION:[[:space:]]*$legacy_activation$" "$legacy_receipt"
[ ! -e "$legacy_project_receipt" ]

echo '== project-local receipt is accepted and cleaned after PASS'
automation_activate "$PROJECT" project-local oneshot
receipt=$(automation_receipt_path "$PROJECT" project-local)
project_receipt=$(automation_project_receipt_path "$PROJECT" project-local)
rm -f -- "$receipt"
activation=$(automation_activation_id "$PROJECT" project-local)
cat >"$project_receipt" <<'EOF'
ROADMAP: .claude/task-roadmap.md
ACTIVATION: PLACEHOLDER
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: test.sh exit 0 and roadmap validator PASS
EOF
sed -i.bak "s/ACTIVATION: PLACEHOLDER/ACTIVATION: $activation/" "$project_receipt"
rm -f -- "$project_receipt.bak"
payload project-local | "$HOOK" >/dev/null
[ ! -e "$STATE/project-local.json" ]
[ ! -e "$project_receipt" ]

echo '== PASS cleanup failure preserves active state and cannot emit PASS'
automation_activate "$PROJECT" cleanup-failure oneshot
receipt=$(automation_receipt_path "$PROJECT" cleanup-failure)
project_receipt=$(automation_project_receipt_path "$PROJECT" cleanup-failure)
mkdir "$receipt"
cat >"$project_receipt" <<EOF
ROADMAP: .claude/task-roadmap.md
ACTIVATION: $(automation_activation_id "$PROJECT" cleanup-failure)
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: cleanup must happen before state deactivation
EOF
set +e
payload cleanup-failure | "$HOOK" >/dev/null 2>"$TMP/cleanup-failure.err"
rc=$?
set -e
[ "$rc" -eq 2 ]
grep -Fq 'se conserva el state activo' "$TMP/cleanup-failure.err"
[ -s "$STATE/cleanup-failure.json" ]
rmdir "$receipt"
[ ! -e "$receipt" ]

echo '== explicit blocked receipt preserves active state without a hook error'
automation_activate "$PROJECT" blocked oneshot
receipt=$(automation_receipt_path "$PROJECT" blocked)
cat >"$receipt" <<'EOF'
STATUS: BLOCKED
ACCEPTANCE: PENDING
ACTIVATION: PLACEHOLDER
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: external service is unavailable
EOF
sed -i.bak "s/ACTIVATION: PLACEHOLDER/ACTIVATION: $(automation_activation_id "$PROJECT" blocked)/" "$receipt"
rm -f -- "$receipt.bak"
set +e
payload blocked | "$HOOK" >/dev/null 2>"$TMP/blocked.err"
rc=$?
set -e
[ "$rc" -eq 0 ]
grep -Fq 'BLOCKED: se conserva el estado activo' "$TMP/blocked.err"
[ -s "$STATE/blocked.json" ]

echo '== missing administrative BLOCKED does not mask a later local PASS in the same activation'
automation_activate "$PROJECT" missing-then-local oneshot
payload missing-then-local | "$HOOK" >/dev/null
receipt=$(automation_receipt_path "$PROJECT" missing-then-local)
project_receipt=$(automation_project_receipt_path "$PROJECT" missing-then-local)
activation=$(automation_activation_id "$PROJECT" missing-then-local)
cat >"$project_receipt" <<EOF
ROADMAP: .claude/task-roadmap.md
ACTIVATION: $activation
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: local receipt supersedes hook-created BLOCKED for the same activation
EOF
payload missing-then-local | "$HOOK" >/dev/null
[ ! -e "$STATE/missing-then-local.json" ]
[ ! -e "$receipt" ]
[ ! -e "$project_receipt" ]

echo '== a prior administrative PASS is removed before a new activation in the same session'
automation_activate "$PROJECT" reused-session oneshot
old_activation=$(automation_activation_id "$PROJECT" reused-session)
receipt=$(automation_receipt_path "$PROJECT" reused-session)
cat >"$receipt" <<EOF
ROADMAP: .claude/task-roadmap.md
ACTIVATION: $old_activation
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: old activation
EOF
automation_deactivate "$PROJECT" reused-session
automation_activate "$PROJECT" reused-session oneshot
new_activation=$(automation_activation_id "$PROJECT" reused-session)
[ "$old_activation" != "$new_activation" ]
[ ! -e "$receipt" ]

echo '== receipts without or with the wrong activation are rejected without fallback'
automation_activate "$PROJECT" invalid-receipt oneshot
receipt=$(automation_receipt_path "$PROJECT" invalid-receipt)
project_receipt=$(automation_project_receipt_path "$PROJECT" invalid-receipt)
cat >"$receipt" <<'EOF'
ROADMAP: .claude/task-roadmap.md
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: missing activation must fail
EOF
cat >"$project_receipt" <<EOF
ROADMAP: .claude/task-roadmap.md
ACTIVATION: wrong-activation
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: EXECUTABLE
VERIFY_EXIT: 0
EVIDENCE: stale local receipt must fail
EOF
set +e
payload invalid-receipt | "$HOOK" >/dev/null 2>"$TMP/invalid-receipt.err"
rc=$?
set -e
[ "$rc" -eq 2 ]
grep -Fq 'ACTIVATION esperado' "$TMP/invalid-receipt.err"
[ -s "$STATE/invalid-receipt.json" ]

echo '== documentation-only PASS uses structural readback when no code runner exists'
mv "$PROJECT/test.sh" "$PROJECT/test.sh.saved"
automation_activate "$PROJECT" docs-no-runner docs_only
receipt=$(automation_receipt_path "$PROJECT" docs-no-runner)
activation=$(automation_activation_id "$PROJECT" docs-no-runner)
cat >"$receipt" <<EOF
ROADMAP: .claude/task-roadmap.md
ACTIVATION: $activation
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_TYPE: STRUCTURAL
VERIFY_EXIT: 0
EVIDENCE: structural readback and git diff --check
EOF
payload docs-no-runner | "$HOOK" >/dev/null
[ ! -e "$STATE/docs-no-runner.json" ]
[ ! -e "$receipt" ]
mv "$PROJECT/test.sh.saved" "$PROJECT/test.sh"

echo '== green roadmap, receipt, diff check and native runner pass'
activate green
payload green | "$HOOK" >/dev/null
[ ! -e "$STATE/green.json" ]
[ ! -e "$(automation_receipt_path "$PROJECT" green)" ]
[ ! -e "$(automation_project_receipt_path "$PROJECT" green)" ]

echo '== duplicate direct roadmaps block the gate'
cp "$PROJECT/.claude/task-roadmap.md" "$PROJECT/TASK-ROADMAP.md"
activate duplicate-roadmaps
set +e
payload duplicate-roadmaps | "$HOOK" >/dev/null 2>"$TMP/duplicate.err"
rc=$?
set -e
[ "$rc" -eq 2 ]
grep -Fq 'múltiples roadmaps directos' "$TMP/duplicate.err"
rm -f "$PROJECT/TASK-ROADMAP.md"

echo '== a red runner blocks even when stop_hook_active and skip flag are present'
cat >"$PROJECT/test.sh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$PROJECT/test.sh"
activate red
set +e
CLAUDE_SKIP_TEST_RUN=true payload red | "$HOOK" >/dev/null 2>"$TMP/red.err"
rc=$?
set -e
[ "$rc" -eq 2 ]
grep -Fq 'runner nativo está RED' "$TMP/red.err"
[ -s "$STATE/red.json" ]

echo '== pending tasks block before the runner can be accepted'
cat >"$PROJECT/.claude/task-roadmap.md" <<'EOF'
# Automatic task roadmap

- [ ] T001 [depends_on: none] Pending work
EOF
activate pending
set +e
payload pending | "$HOOK" >/dev/null 2>"$TMP/pending.err"
rc=$?
set -e
[ "$rc" -eq 2 ]
grep -Fq 'pendiente' "$TMP/pending.err"

echo '== parallel frontier without ownership blocks even with green runner'
cat >"$PROJECT/test.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$PROJECT/test.sh"
cat >"$PROJECT/.claude/task-roadmap.md" <<'EOF'
# Automatic task roadmap

- [x] T001 [depends_on: none] Baseline
- [x] T002 [depends_on: T001] First parallel task
- [x] T003 [depends_on: T001] Second parallel task
EOF
activate unsafe-parallel
set +e
payload unsafe-parallel | "$HOOK" >/dev/null 2>"$TMP/unsafe.err"
rc=$?
set -e
[ "$rc" -eq 2 ]
grep -Fq 'parallel frontier lacks' "$TMP/unsafe.err"
[ -s "$STATE/unsafe-parallel.json" ]

echo '== native runner uses the portable internal timeout helper'
grep -Fq 'run_trusted_test_once "$ROOT" "$SESSION_ID" "$TRANSCRIPT_PATH" "$TEST_TIMEOUT_SECONDS"' "$HOOK" ||
  {
    echo 'automatic workflow stop bypasses the trusted shared runner' >&2
    exit 1
  }
if grep -Fq 'eval "$TIMEOUT_PREFIX $TEST_CMD"' "$HOOK"; then
  echo 'automatic workflow stop still uses the fail-open timeout wrapper' >&2
  exit 1
fi

echo '== behavioral timeout blocks a hanging runner without timeout/gtimeout'
cat >"$PROJECT/test.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' 'runner-started' >"$PROJECT/runner-ran"
sleep 5
exit 0
EOF
chmod +x "$PROJECT/test.sh"
cat >"$PROJECT/.claude/task-roadmap.md" <<'EOF'
# Automatic task roadmap

- [x] T001 [depends_on: none] Bounded runner
EOF
activate bounded-timeout
SHORT_DIR="$TMP/short-hook"
mkdir -p "$SHORT_DIR/lib"
SHORT_HOOK="$SHORT_DIR/automatic-workflow-stop.sh"
sed 's/TEST_TIMEOUT_SECONDS=180/TEST_TIMEOUT_SECONDS=1/' "$HOOK" >"$SHORT_HOOK"
ln -s -- "$STATE_LIB" "$SHORT_DIR/lib/automatic-workflow-state.sh"
chmod +x "$SHORT_HOOK"
PORTABLE_BIN="$TMP/no-timeout-bin"
mkdir -p "$PORTABLE_BIN" "$TMP/home"
PYTHON_BIN="$(python3 -c 'import sys; print(sys.executable)')"
for command_name in awk bash cat dirname git grep jq mktemp pgrep ps python3 rm sed sleep tail tr; do
  if [ "$command_name" = python3 ]; then
    command_path="$PYTHON_BIN"
  else
    command_path=$(command -v "$command_name") || {
      echo "missing test dependency: $command_name" >&2
      exit 1
    }
  fi
  ln -s -- "$command_path" "$PORTABLE_BIN/$command_name"
done
[ ! -e "$PORTABLE_BIN/timeout" ] && [ ! -e "$PORTABLE_BIN/gtimeout" ]
set +e
PATH="$PORTABLE_BIN" HOME="$TMP/home" \
  CLAUDE_AUTOMATION_STATE_DIR="$STATE" \
  CLAUDE_AUTOMATION_VALIDATOR="$VALIDATOR" \
  CLAUDE_AUTOMATION_TEST_RUNNER="$RUNNER" \
  "$PYTHON_BIN" - "$SHORT_HOOK" "$PROJECT" <<'PY'
import json
import os
import subprocess
import sys

try:
    result = subprocess.run(
        [sys.argv[1]],
        cwd=sys.argv[2],
        input=json.dumps({
            "hook_event_name": "Stop",
            "cwd": sys.argv[2],
            "session_id": "bounded-timeout",
            "stop_hook_active": True,
        }).encode(),
        capture_output=True,
        env=os.environ.copy(),
        timeout=4,
    )
except subprocess.TimeoutExpired:
    print("hook exceeded watchdog timeout", file=sys.stderr)
    raise SystemExit(124)
sys.stdout.buffer.write(result.stdout)
sys.stderr.buffer.write(result.stderr)
raise SystemExit(result.returncode)
PY
rc=$?
set -e
[ -s "$PROJECT/runner-ran" ] || {
  echo 'bounded timeout fixture never executed the native runner' >&2
  exit 1
}
[ "$rc" -eq 2 ] || {
  echo "expected bounded timeout to block with rc=2, got $rc" >&2
  exit 1
}

echo 'PASS: automatic workflow stop gate exige evidencia fresca y bloquea estados parciales'
