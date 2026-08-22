#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/quality-gate.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/quality-gate-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# quality-gate.sh sources "$HOME/.claude/hooks/lib/test-runner.sh" -- give it
# a real copy of THIS repo's source so the test is self-contained and does not
# depend on whatever happens to be deployed at ~/.claude on the dev machine.
# No ~/.claude/scripts/rdd.sh is provided on purpose: RDD is off by default
# ([ -x "$RDD" ] fails cleanly), keeping these fixtures focused on the
# lint/test/coverage timeout behavior this test exists to cover.
FAKE_HOME="$TMP/home"
mkdir -p "$FAKE_HOME/.claude/hooks/lib"
cp "$ROOT/config/claude/hooks/lib/test-runner.sh" "$FAKE_HOME/.claude/hooks/lib/test-runner.sh"

new_repo() {
  local dir="$1"
  mkdir -p "$dir/src"
  git -C "$dir" init -q 2>/dev/null || { git init -q "$dir"; }
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  printf 'module.exports = () => 1;\n' >"$dir/src/foo.js"
}

run_hook() {
  local dir="$1"
  jq -nc --arg cwd "$dir" '{tool_name:"Bash",tool_input:{command:"git commit -m x"},cwd:$cwd}' |
    (cd "$dir" && HOME="$FAKE_HOME" bash "$HOOK")
}

printf '%s\n' '== declared test.sh runner, passing: commit proceeds (exit 0)'
PASSING="$TMP/passing"
new_repo "$PASSING"
cat >"$PASSING/test.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$PASSING/test.sh"
git -C "$PASSING" add -A
out=$(run_hook "$PASSING" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 0 ]

printf '%s\n' '== declared test.sh runner, failing: commit blocked (exit 2), reports failure'
FAILING="$TMP/failing"
new_repo "$FAILING"
cat >"$FAILING/test.sh" <<'EOF'
#!/usr/bin/env bash
echo "1 test failed"
exit 1
EOF
chmod +x "$FAILING/test.sh"
git -C "$FAILING" add -A
out=$(run_hook "$FAILING" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'tests failed'
printf '%s' "$out" | grep -Fq '1 test failed'

printf '%s\n' '== declared test.sh runner that hangs: blocked within the configured bound, not left to the outer harness'
HANGING="$TMP/hanging"
new_repo "$HANGING"
HANG_MARKER="$TMP/hang-marker"
cat >"$HANGING/test.sh" <<EOF
#!/usr/bin/env bash
echo \$\$ > "$HANG_MARKER"
sleep 30
EOF
chmod +x "$HANGING/test.sh"
git -C "$HANGING" add -A
start=$(date +%s)
out=$(QG_TEST_TIMEOUT_SECONDS=1 run_hook "$HANGING" 2>&1) && rc=0 || rc=$?
end=$(date +%s)
elapsed=$((end - start))
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'did not finish in 1s'
[ "$elapsed" -lt 10 ]
if [ -f "$HANG_MARKER" ]; then
  hang_pid=$(cat "$HANG_MARKER")
  sleep 0.5
  ! kill -0 "$hang_pid" 2>/dev/null
fi

printf '%s\n' '== .claude-relaxed downgrades a hung suite to a warning instead of blocking'
RELAXED_HANGING="$TMP/relaxed-hanging"
new_repo "$RELAXED_HANGING"
touch "$RELAXED_HANGING/.claude-relaxed"
cat >"$RELAXED_HANGING/test.sh" <<'EOF'
#!/usr/bin/env bash
sleep 30
EOF
chmod +x "$RELAXED_HANGING/test.sh"
git -C "$RELAXED_HANGING" add -A
start=$(date +%s)
out=$(QG_TEST_TIMEOUT_SECONDS=1 run_hook "$RELAXED_HANGING" 2>&1) && rc=0 || rc=$?
end=$(date +%s)
elapsed=$((end - start))
[ "$rc" -eq 0 ]
[ "$elapsed" -lt 10 ]
printf '%s' "$out" | grep -Fq 'WARNING'

printf '%s\n' 'PASS: quality-gate.sh enforces a real, portable timeout on lint/test/coverage'
