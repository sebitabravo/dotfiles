#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/automatic-workflow-stop.sh"
STATE_LIB="$ROOT/config/claude/hooks/lib/automatic-workflow-state.sh"
VALIDATOR="$ROOT/config/claude/scripts/validate-task-roadmap.py"
RUNNER="$ROOT/config/claude/hooks/lib/test-runner.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/automatic-workflow-stop-test.XXXXXX")
PROJECT="$TMP/project"
STATE="$TMP/state"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$PROJECT/.claude"
git -C "$PROJECT" init -q
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

activate() {
  automation_activate "$PROJECT" "$1" oneshot
  receipt=$(automation_receipt_path "$PROJECT" "$1")
  cat >"$receipt" <<EOF
ROADMAP: .claude/task-roadmap.md
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_EXIT: 0
EVIDENCE: test.sh exit 0 and roadmap validator PASS
EOF
}

echo '== missing receipt blocks'
automation_activate "$PROJECT" missing oneshot
set +e
payload missing | "$HOOK" >/dev/null 2>"$TMP/missing.err"
rc=$?
set -e
[ "$rc" -eq 2 ]
grep -Fq 'falta el receipt' "$TMP/missing.err"

echo '== explicit blocked receipt preserves active state without a hook error'
automation_activate "$PROJECT" blocked oneshot
receipt=$(automation_receipt_path "$PROJECT" blocked)
cat >"$receipt" <<'EOF'
STATUS: BLOCKED
ACCEPTANCE: PENDING
VERIFY_EXIT: 0
EVIDENCE: external service is unavailable
EOF
set +e
payload blocked | "$HOOK" >/dev/null 2>"$TMP/blocked.err"
rc=$?
set -e
[ "$rc" -eq 0 ]
grep -Fq 'BLOCKED: se conserva el estado activo' "$TMP/blocked.err"
[ -s "$STATE/blocked.json" ]

echo '== green roadmap, receipt, diff check and native runner pass'
activate green
payload green | "$HOOK" >/dev/null
[ ! -e "$STATE/green.json" ]

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

echo 'PASS: automatic workflow stop gate exige evidencia fresca y bloquea estados parciales'
