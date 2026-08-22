#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
LIB="$ROOT/config/claude/hooks/lib/test-runner.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/test-runner-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# shellcheck source=/dev/null
source "$LIB"

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
! kill -0 "$grandchild_pid" 2>/dev/null

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
! kill -0 "$term_ignoring_pid" 2>/dev/null

printf '%s\n' '== run_with_timeout still returns the real exit code and output when the command finishes in time'
out=$(run_with_timeout 5 "echo hola; exit 3") && rc=0 || rc=$?
[ "$rc" -eq 3 ]
[ "$out" = "hola" ]

printf '%s\n' 'PASS: run_with_timeout bounds a real command and kills its whole process tree, not one generation'
