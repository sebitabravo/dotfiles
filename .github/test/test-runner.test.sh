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

printf '%s\n' '== run_with_timeout still returns the real exit code and output when the command finishes in time'
out=$(run_with_timeout 5 "echo hola; exit 3") && rc=0 || rc=$?
[ "$rc" -eq 3 ]
[ "$out" = "hola" ]

printf '%s\n' 'PASS: run_with_timeout bounds a real command and kills its whole process tree, not one generation'
