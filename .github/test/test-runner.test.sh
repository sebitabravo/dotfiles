#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
LIB="$ROOT/config/claude/hooks/lib/test-runner.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/test-runner-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# shellcheck source=/dev/null
source "$LIB"

printf '%s\n' '== declared runner paths are shell-quoted before eval'
SPECIAL_MARKER="$TMP/runner-path-injection-marker"
SPECIAL_ROOT="$TMP/runner path; touch $SPECIAL_MARKER #"
mkdir -p "$SPECIAL_ROOT"
printf '%s\n' '#!/bin/sh' 'printf runner-ok' >"$SPECIAL_ROOT/test.sh"
chmod +x "$SPECIAL_ROOT/test.sh"
TEST_CMD=''
detect_test_cmd "$SPECIAL_ROOT"
out=$(run_with_timeout 5 "$TEST_CMD" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 0 ]
[ "$out" = 'runner-ok' ]
[ ! -e "$SPECIAL_MARKER" ]

printf '%s\n' '== inferred Python venv executable paths are shell-quoted'
VENV_ROOT="$TMP/python package; true #"
mkdir -p "$VENV_ROOT/.venv/bin"
printf '%s\n' '[project]' 'name = "hostile-venv-path"' >"$VENV_ROOT/pyproject.toml"
printf '%s\n' '#!/bin/sh' 'printf venv-runner-ok' >"$VENV_ROOT/.venv/bin/pytest"
chmod +x "$VENV_ROOT/.venv/bin/pytest"
TEST_CMD=''
detect_test_cmd "$TMP"
out=$(run_with_timeout 5 "$TEST_CMD" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 0 ]
[ "$out" = 'venv-runner-ok' ]

printf '%s\n' '== inferred monorepo runner executes every child package and aggregates failures'
MONO_ROOT="$TMP/monorepo"
FAKE_BIN="$TMP/fake-bin"
mkdir -p "$MONO_ROOT/package-a" "$MONO_ROOT/package-b" "$FAKE_BIN"
cat >"$MONO_ROOT/package-a/package.json" <<'EOF'
{"scripts":{"test":"printf package-a-script"}}
EOF
cat >"$MONO_ROOT/package-b/package.json" <<'EOF'
{"scripts":{"test":"printf package-b-script"}}
EOF
cat >"$FAKE_BIN/npm" <<EOF
#!/bin/sh
case "\$PWD" in
  */package-a) printf '%s\n' package-a >>"$MONO_ROOT/invocations"; exit 0 ;;
  */package-b) printf '%s\n' package-b >>"$MONO_ROOT/invocations"; exit 1 ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$FAKE_BIN/npm"
TEST_CMD=''
export PATH="$FAKE_BIN:$PATH"
detect_test_cmd "$MONO_ROOT"
[ "$TEST_CMD_SOURCE" = inferred ]
set +e
run_with_timeout 5 "$TEST_CMD" >/dev/null 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ]
[ "$(cat "$MONO_ROOT/invocations")" = $'package-a\npackage-b' ]

printf '%s\n' '== a declared root aggregator runs once and takes precedence over child manifests'
AGG_ROOT="$TMP/aggregator"
mkdir -p "$AGG_ROOT/package-a"
cat >"$AGG_ROOT/package-a/package.json" <<'EOF'
{"scripts":{"test":"printf child-should-not-run"}}
EOF
cat >"$AGG_ROOT/test.sh" <<EOF
#!/bin/sh
printf '%s\n' root-aggregator >>"$AGG_ROOT/invocations"
EOF
chmod +x "$AGG_ROOT/test.sh"
TEST_CMD=''
detect_test_cmd "$AGG_ROOT"
[ "$TEST_CMD_SOURCE" = declared ]
[ "$TEST_CMD" = "$(shell_quote "$AGG_ROOT/test.sh")" ]
run_with_timeout 5 "$TEST_CMD" >/dev/null
[ "$(cat "$AGG_ROOT/invocations")" = root-aggregator ]

printf '%s\n' '== Stop runner requires user-owned trust and preserves quoting'
TRUST_ROOT="$TMP/trusted repo; echo should-not-run #"
TRUST_MARKER="$TMP/untrusted-runner-marker"
mkdir -p "$TRUST_ROOT"
cat >"$TRUST_ROOT/test.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' executed >>"$TRUST_MARKER"
EOF
chmod +x "$TRUST_ROOT/test.sh"
TRUST_FILE="$TMP/trusted-repositories"
: >"$TRUST_FILE"
export CLAUDE_REPOSITORY_TRUST_FILE="$TRUST_FILE"
set +e
untrusted_out=$(run_trusted_test_once "$TRUST_ROOT" stop-session stop-invocation 5 2>&1)
untrusted_rc=$?
set -e
[ "$untrusted_rc" -eq 126 ]
printf '%s' "$untrusted_out" | grep -Fq 'No repository-declared test command was executed'
[ ! -e "$TRUST_MARKER" ]
printf '%s\n' "$TRUST_ROOT" >"$TRUST_FILE"
run_trusted_test_once "$TRUST_ROOT" stop-session trusted-invocation 5 >/dev/null
[ "$(cat "$TRUST_MARKER")" = executed ]

printf '%s\n' '== concurrent Stop callers share one atomic suite result'
SHARED_ROOT="$TMP/shared suite"
SHARED_COUNT="$TMP/shared-count"
mkdir -p "$SHARED_ROOT"
cat >"$SHARED_ROOT/test.sh" <<EOF
#!/usr/bin/env bash
printf '%s\n' invocation >>"$SHARED_COUNT"
sleep 0.3
EOF
chmod +x "$SHARED_ROOT/test.sh"
printf '%s\n' "$SHARED_ROOT" >>"$TRUST_FILE"
CLAUDE_STOP_RESULT_DIR="$TMP/shared-results" run_trusted_test_once "$SHARED_ROOT" stop-session shared-invocation 5 >"$TMP/shared-a" 2>&1 &
first_pid=$!
CLAUDE_STOP_RESULT_DIR="$TMP/shared-results" run_trusted_test_once "$SHARED_ROOT" stop-session shared-invocation 5 >"$TMP/shared-b" 2>&1 &
second_pid=$!
wait "$first_pid"
wait "$second_pid"
[ "$(wc -l <"$SHARED_COUNT" | tr -d ' ')" -eq 1 ]

printf '%s\n' '== timeout does not wait forever when process inspection is unavailable'
INSPECTOR_BIN="$TMP/inspectors"
mkdir -p "$INSPECTOR_BIN"
cat >"$INSPECTOR_BIN/ps" <<'EOF'
#!/bin/sh
exit 1
EOF
cat >"$INSPECTOR_BIN/pgrep" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod +x "$INSPECTOR_BIN/ps" "$INSPECTOR_BIN/pgrep"
start=$(date +%s)
if PATH="$INSPECTOR_BIN:/usr/bin:/bin" bash -c 'source "$1"; run_with_timeout 1 "sleep 30"' bash "$LIB" >/dev/null 2>&1; then
  rc=0
else
  rc=$?
fi
end=$(date +%s)
elapsed=$((end - start))
[ "$rc" -eq 124 ]
[ "$elapsed" -lt 10 ]

printf '%s\n' '== run_with_timeout kills a grandchild, not just the direct child'
GRANDCHILD_MARKER="$TMP/grandchild-marker"
# The direct child is a shell that forks a grandchild sleep and then waits on
# it: `pkill -P "$pid"` (one generation) kills the direct child's shell but
# leaves the grandchild `sleep` orphaned and alive, which is exactly the
# leaked-process gap _kill_process_tree exists to close.
CMD="bash -c 'sleep 30 & echo \$! > $GRANDCHILD_MARKER; wait'"
out=$(run_with_timeout 1 "$CMD" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 124 ]
[ -f "$GRANDCHILD_MARKER" ]
grandchild_pid=$(cat "$GRANDCHILD_MARKER")
sleep 0.5
if kill -0 "$grandchild_pid" 2>/dev/null; then
  echo 'grandchild survived timeout' >&2
  exit 1
fi

printf '%s\n' '== run_with_timeout kills a descendant that ignores TERM, even after its own parent already died to TERM'
# Regression for a real, deterministic bug (not the earlier load-dependent
# flake): the OLD code re-discovered the process tree via a fresh `pgrep -P`
# walk for the KILL pass. If the intermediate process dies to the FIRST
# (TERM) pass, it orphans its own children (reparented to init/launchd)
# BEFORE the second walk runs -- so a grandchild that ignores TERM becomes
# unreachable from the root PID and the KILL pass never finds it, letting it
# run to completion untouched. The fix discovers the whole tree ONCE and
# signals that same captured list for both TERM and KILL, since kill(2)
# targets a PID directly regardless of its current parent.
TERM_IGNORING_MARKER="$TMP/term-ignoring-marker"
MID_SCRIPT="$TMP/mid.sh"
cat >"$MID_SCRIPT" <<EOF
#!/usr/bin/env bash
( trap '' TERM; sleep 30 ) &
echo \$! >"$TERM_IGNORING_MARKER"
sleep 30 &
wait
EOF
chmod +x "$MID_SCRIPT"
out=$(run_with_timeout 1 "$MID_SCRIPT" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 124 ]
[ -f "$TERM_IGNORING_MARKER" ]
term_ignoring_pid=$(cat "$TERM_IGNORING_MARKER")
# Checked immediately, not after a few seconds: the old code's grandchild
# only died when its OWN sleep finally finished on its own, which would
# still pass a check made long enough after the fact.
if kill -0 "$term_ignoring_pid" 2>/dev/null; then
  echo 'TERM-ignoring descendant survived timeout' >&2
  exit 1
fi

printf '%s\n' '== run_with_timeout still returns the real exit code and output when the command finishes in time'
out=$(run_with_timeout 5 "echo hola; exit 3") && rc=0 || rc=$?
[ "$rc" -eq 3 ]
[ "$out" = "hola" ]

printf '%s\n' 'PASS: run_with_timeout bounds a real command and kills its whole process tree, not one generation'

printf '%s\n' '== run_trusted_test_once cache invalidates when repo content changes mid-session'
# Regression: entry_key only hashed root+session_id+invocation_key+cmd, none
# of which change when a repo gets fixed mid-session (same Stop hook keeps
# firing with the same transcript path). A Claude session that fixes a
# failing suite and reruns the SAME Stop turn got the FIRST cached result
# forever -- a stale RED masking a real fix, or worse, a stale PASS masking
# a real regression reintroduced later in the same session.
STALE_REPO="$TMP/stale-repo"
mkdir -p "$STALE_REPO"
git -C "$STALE_REPO" init -q
git -C "$STALE_REPO" config user.email test@test.test
git -C "$STALE_REPO" config user.name test
printf '%s\n' '#!/bin/sh' 'exit 1' >"$STALE_REPO/test.sh"
chmod +x "$STALE_REPO/test.sh"
git -C "$STALE_REPO" add test.sh
git -C "$STALE_REPO" commit -q -m init

printf '%s\n' "$STALE_REPO" >>"$TRUST_FILE"
STALE_CACHE_ROOT="$TMP/stale-cache-root"

first_out=$(CLAUDE_STOP_RESULT_DIR="$STALE_CACHE_ROOT" run_trusted_test_once "$STALE_REPO" 'session-x' 'transcript-x' 5) && first_rc=0 || first_rc=$?
[ "$first_rc" -eq 1 ] || {
  echo "expected first run to fail, got $first_rc: $first_out" >&2
  exit 1
}

# Fix the suite the way a real session does: edit the file, do not commit.
printf '%s\n' '#!/bin/sh' 'exit 0' >"$STALE_REPO/test.sh"

second_out=$(CLAUDE_STOP_RESULT_DIR="$STALE_CACHE_ROOT" run_trusted_test_once "$STALE_REPO" 'session-x' 'transcript-x' 5) && second_rc=0 || second_rc=$?
[ "$second_rc" -eq 0 ] || {
  echo "expected fixed suite to pass on rerun, got $second_rc: $second_out" >&2
  exit 1
}

printf '%s\n' 'PASS: run_trusted_test_once reruns instead of replaying a stale cached result once repo content changes'

printf '%s\n' '== repository_content_fingerprint is bounded and does not block the Stop-hook budget'
# Regression: the fingerprint's git calls ran with no timeout of their own,
# ahead of the one real timeout (run_with_timeout) that the whole file exists
# to guarantee. A slow/hanging git (huge diff, stuck NFS mount, submodule
# recursion) could stall the Stop hook past its configured budget with no
# bound catching it -- exactly the fail-open gap run_with_timeout's own
# docstring warns about, reintroduced one call up the stack.
HANGING_GIT_ROOT="$TMP/hanging-git-repo"
HANGING_GIT_BIN="$TMP/hanging-git-bin"
mkdir -p "$HANGING_GIT_ROOT" "$HANGING_GIT_BIN"
cat >"$HANGING_GIT_BIN/git" <<'EOF'
#!/bin/sh
sleep 30
EOF
chmod +x "$HANGING_GIT_BIN/git"
start=$(date +%s)
fingerprint_out=$(PATH="$HANGING_GIT_BIN:$PATH" repository_content_fingerprint "$HANGING_GIT_ROOT")
end=$(date +%s)
elapsed=$((end - start))
[ "$elapsed" -lt 20 ] || {
  echo "fingerprint blocked for ${elapsed}s on a hanging git" >&2
  exit 1
}
[ -n "$fingerprint_out" ] || {
  echo 'fingerprint must still return a value that forces a cache miss' >&2
  exit 1
}

printf '%s\n' 'PASS: repository_content_fingerprint stays inside its own timeout instead of blocking on a hanging git'
