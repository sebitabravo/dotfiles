#!/usr/bin/env bash
# shellcheck disable=SC2016 # Fixture strings intentionally preserve literal shell variables.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/convergence-stop.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/convergence-stop-test.XXXXXX")
TRUST_FILE="$TMP/trusted-repositories"
trap 'find "$TMP" -type f -delete; find "$TMP" -depth -type d -empty -delete 2>/dev/null || true' EXIT

mkdir -p "$TMP/bin" "$TMP/home" "$TMP/.claude/convergence" "$TMP/openspec/changes/example-change"
git -C "$TMP" init -q
printf '%s\n' "$TMP" >"$TRUST_FILE"

cat >"$TMP/bin/openspec" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case " $* " in
  *" status --change "*)
    jq -n --arg root "$PWD/openspec/changes/example-change" '{changeRoot:$root,artifacts:{tasks:{status:"done"}}}'
    ;;
  *" instructions apply --change "*)
    if [ "${OPEN_SPEC_STATE:-ready}" = blocked ]; then
      jq -n '{state:"blocked",missingArtifacts:["tasks"],progress:{remaining:1}}'
    else
      jq -n --argjson remaining "${OPEN_SPEC_REMAINING:-0}" '{state:"ready",progress:{remaining:$remaining}}'
    fi
    ;;
  *" validate "*)
    [ "${OPEN_SPEC_VALIDATE:-pass}" = pass ]
    ;;
  *)
    printf '%s\n' '{}'
    ;;
esac
EOF
chmod +x "$TMP/bin/openspec"

cat >"$TMP/test.sh" <<'EOF'
#!/usr/bin/env bash
exit "${VERIFY_RC:-0}"
EOF
chmod +x "$TMP/test.sh"

cat >"$TMP/.claude/convergence/example-change.receipt" <<'EOF'
CHANGE: example-change
STATUS: PASS
ACCEPTANCE: PASS
VERIFY_EXIT: 0
EVIDENCE: test.sh exit 0
EOF
printf '%s\n' 'example-change' >"$TMP/.claude/convergence.active"

run_hook() {
  (cd "$TMP" && printf '%s' "${1:-{}}" | env \
    HOME="$TMP/home" \
    CLAUDE_REPOSITORY_TRUST_FILE="$TRUST_FILE" \
    PATH="$TMP/bin:$PATH" \
    VERIFY_RC="${VERIFY_RC:-0}" \
    OPEN_SPEC_STATE="${OPEN_SPEC_STATE:-ready}" \
    OPEN_SPEC_REMAINING="${OPEN_SPEC_REMAINING:-0}" \
    OPEN_SPEC_VALIDATE="${OPEN_SPEC_VALIDATE:-pass}" \
    "$HOOK")
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

printf '%s\n' '== no active marker is a no-op'
mv "$TMP/.claude/convergence.active" "$TMP/.claude/convergence.active.off"
run_hook
mv "$TMP/.claude/convergence.active.off" "$TMP/.claude/convergence.active"

printf '%s\n' '== pending OpenSpec tasks block'
expect_rc 2 env OPEN_SPEC_REMAINING=2 VERIFY_RC=0 bash -c 'cd "$1" && printf "{}" | env HOME="$1/home" CLAUDE_REPOSITORY_TRUST_FILE="$1/trusted-repositories" PATH="$1/bin:$PATH" OPEN_SPEC_REMAINING="$2" "$3"' sh "$TMP" 2 "$HOOK"

printf '%s\n' '== blocked artifact state blocks'
expect_rc 2 env OPEN_SPEC_STATE=blocked bash -c 'cd "$1" && printf "{}" | env HOME="$1/home" CLAUDE_REPOSITORY_TRUST_FILE="$1/trusted-repositories" PATH="$1/bin:$PATH" OPEN_SPEC_STATE=blocked "$2"' sh "$TMP" "$HOOK"

printf '%s\n' '== failed native verification blocks'
expect_rc 2 env VERIFY_RC=1 bash -c 'cd "$1" && printf "{}" | env HOME="$1/home" CLAUDE_REPOSITORY_TRUST_FILE="$1/trusted-repositories" PATH="$1/bin:$PATH" VERIFY_RC=1 "$2"' sh "$TMP" "$HOOK"

printf '%s\n' '== failed validation blocks'
expect_rc 2 env OPEN_SPEC_VALIDATE=fail bash -c 'cd "$1" && printf "{}" | env HOME="$1/home" CLAUDE_REPOSITORY_TRUST_FILE="$1/trusted-repositories" PATH="$1/bin:$PATH" OPEN_SPEC_VALIDATE=fail "$2"' sh "$TMP" "$HOOK"

printf '%s\n' '== stop_hook_active does not turn a failing gate green'
expect_rc 2 env VERIFY_RC=1 bash -c 'cd "$2" && printf "%s" "$1" | env HOME="$2/home" CLAUDE_REPOSITORY_TRUST_FILE="$2/trusted-repositories" PATH="$2/bin:$PATH" VERIFY_RC=1 "$3"' sh '{"stop_hook_active":true}' "$TMP" "$HOOK"

printf '%s\n' '== complete change passes with fresh native verification'
run_hook

printf '%s\n' '== native runner uses the portable internal timeout helper'
grep -Fq 'run_trusted_test_once "$ROOT" "$SESSION_ID" "$TRANSCRIPT_PATH" "$TEST_TIMEOUT_SECONDS"' "$HOOK" ||
  {
    echo 'convergence stop bypasses the trusted shared runner' >&2
    exit 1
  }
if grep -Fq 'eval "$TIMEOUT_BIN $TEST_CMD"' "$HOOK"; then
  echo 'convergence stop still uses the fail-open timeout wrapper' >&2
  exit 1
fi

printf '%s\n' '== behavioral timeout blocks a hanging runner without timeout/gtimeout'
cat >"$TMP/test.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' 'runner-started' >"$TMP/runner-ran"
sleep 5
exit 0
EOF
chmod +x "$TMP/test.sh"
printf '%s\n' 'example-change' >"$TMP/.claude/convergence.active"
SHORT_DIR="$TMP/short-hook"
mkdir -p "$SHORT_DIR/lib"
sed 's/TEST_TIMEOUT_SECONDS=180/TEST_TIMEOUT_SECONDS=1/' "$HOOK" >"$SHORT_DIR/convergence-stop.sh"
ln -s -- "$ROOT/config/claude/hooks/lib/test-runner.sh" "$SHORT_DIR/lib/test-runner.sh"
chmod +x "$SHORT_DIR/convergence-stop.sh"
PORTABLE_BIN="$TMP/no-timeout-bin"
mkdir -p "$PORTABLE_BIN"
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
PATH="$TMP/bin:$PORTABLE_BIN" HOME="$TMP/home" \
  CLAUDE_REPOSITORY_TRUST_FILE="$TRUST_FILE" \
  "$PYTHON_BIN" - "$SHORT_DIR/convergence-stop.sh" "$TMP" <<'PY'
import os
import subprocess
import sys

try:
    result = subprocess.run(
        [sys.argv[1]],
        cwd=sys.argv[2],
        input=b"{}",
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
[ -s "$TMP/runner-ran" ] || {
  echo 'bounded timeout fixture never executed the native runner' >&2
  exit 1
}
[ "$rc" -eq 2 ] || {
  echo "expected bounded timeout to block with rc=2, got $rc" >&2
  exit 1
}

printf '%s\n' 'PASS: convergence stop gate fixtures'
