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

run_hook_command() {
  local dir="$1" command="$2"
  jq -nc --arg cwd "$dir" --arg command "$command" '{tool_name:"Bash",tool_input:{command:$command},cwd:$cwd}' |
    (cd "$dir" && HOME="$FAKE_HOME" bash "$HOOK")
}

run_hook() {
  run_hook_command "$1" 'git commit -m x'
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

printf '%s\n' '== declared runner + coverage-extra that hangs: blocked, not silently NOT MEASURED'
COV_HANGING="$TMP/coverage-hanging"
new_repo "$COV_HANGING"
cat >"$COV_HANGING/test.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$COV_HANGING/test.sh"
cat >"$COV_HANGING/package.json" <<'EOF'
{"scripts": {"test": "vitest run"}}
EOF
git -C "$COV_HANGING" add -A
NPM_BIN="$TMP/coverage-hanging-bin"
mkdir -p "$NPM_BIN"
cat >"$NPM_BIN/npm" <<'EOF'
#!/usr/bin/env bash
# `npm test` (declared-runner check) exits clean; `npm test -- --coverage...`
# (the coverage-extra measurement run) hangs, simulating a stuck instrumented run.
case "$*" in
  *--coverage*) sleep 30 ;;
  *) exit 0 ;;
esac
EOF
chmod +x "$NPM_BIN/npm"
start=$(date +%s)
out=$(QG_COVERAGE_TIMEOUT_SECONDS=1 PATH="$NPM_BIN:$PATH" run_hook "$COV_HANGING" 2>&1) && rc=0 || rc=$?
end=$(date +%s)
elapsed=$((end - start))
[ "$rc" -eq 2 ]
[ "$elapsed" -lt 15 ]
printf '%s' "$out" | grep -Fq 'coverage did not finish in 1s'
if printf '%s' "$out" | grep -Fq 'NOT MEASURED'; then
  echo 'coverage timeout was incorrectly reported as NOT MEASURED' >&2
  exit 1
fi

printf '%s\n' '== monorepo: a shared budget bounds the WHOLE run, not 90s+30s per project'
MONOREPO="$TMP/monorepo"
new_repo "$MONOREPO"
mkdir -p "$MONOREPO/pkg-a" "$MONOREPO/pkg-b"
# setup.cfg is only there to satisfy the monorepo-dir detector's manifest
# check (package.json/pyproject.toml/setup.cfg/pytest.ini/go.mod). Unlike
# pyproject.toml/pytest.ini, it is not one of the markers lib/test-runner.sh's
# own "manifest one level in" scan recognizes, so it can't get root itself
# mistaken for a Python project (which would swallow PROJECT_DIRS back down
# to a single "."). The declared test.sh runner below is what actually runs.
touch "$MONOREPO/pkg-a/setup.cfg" "$MONOREPO/pkg-b/setup.cfg"
for pkg in pkg-a pkg-b; do
  cat >"$MONOREPO/$pkg/test.sh" <<'EOF'
#!/usr/bin/env bash
sleep 30
EOF
  chmod +x "$MONOREPO/$pkg/test.sh"
done
git -C "$MONOREPO" add pkg-a pkg-b
start=$(date +%s)
# Without a shared budget, each project gets its own 90s TEST ceiling: two
# hanging projects would take up to ~180s (or run past the outer harness
# timeout entirely). QG_TOTAL_TIMEOUT_SECONDS=2 must cap the FIRST project's
# stage down to ~2s (or, if fork/exec overhead already spent it, block before
# even starting) -- the second project never gets a fresh 90s of its own.
# Whichever of the two happens depends on $SECONDS's whole-second rounding
# against setup overhead, so accept either message rather than pin one.
out=$(QG_TOTAL_TIMEOUT_SECONDS=2 run_hook "$MONOREPO" 2>&1) && rc=0 || rc=$?
end=$(date +%s)
elapsed=$((end - start))
[ "$rc" -eq 2 ]
[ "$elapsed" -lt 15 ]
printf '%s' "$out" | grep -Eq '\[pkg-a\] (tests did not finish in [0-9]+s|the shared 2s quality-gate budget ran out)'

printf '%s\n' '== git -C after commit cannot redirect the quality gate to another repository'
SCOPED="$TMP/scoped-commit"
SCRATCH="$TMP/scratch-status"
new_repo "$SCOPED"
new_repo "$SCRATCH"
cat >"$SCOPED/test.sh" <<'EOF'
#!/usr/bin/env bash
echo 'real commit repository must fail its suite'
exit 1
EOF
chmod +x "$SCOPED/test.sh"
touch "$SCRATCH/.claude-relaxed"
git -C "$SCOPED" add -A
out=$(run_hook_command "$SCOPED" "git commit -m wip && git -C '$SCRATCH' status" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'tests failed'
if printf '%s' "$out" | grep -Fq 'WARNING (not blocking, .claude-relaxed)'; then
  echo 'quality gate incorrectly used the relaxed repository' >&2
  exit 1
fi

printf '%s\n' '== multiple commit segments fail closed instead of validating only the first one'
MULTI_RELAXED="$TMP/multi-relaxed"
MULTI_REAL="$TMP/multi-real"
new_repo "$MULTI_RELAXED"
new_repo "$MULTI_REAL"
touch "$MULTI_RELAXED/.claude-relaxed"
cat >"$MULTI_REAL/test.sh" <<'EOF'
#!/usr/bin/env bash
echo 'real commit repository must fail its suite'
exit 1
EOF
chmod +x "$MULTI_REAL/test.sh"
git -C "$MULTI_REAL" add -A
out=$(run_hook_command "$MULTI_REAL" "git -C '$MULTI_RELAXED' commit --allow-empty -m scratch && git -C '$MULTI_REAL' commit -m real" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'contains 2 git commit segments'

printf '%s\n' '== a backgrounded later git -C cannot redirect the commit gate'
AMP_RELAXED="$TMP/amp-relaxed"
AMP_REAL="$TMP/amp-real"
new_repo "$AMP_RELAXED"
new_repo "$AMP_REAL"
touch "$AMP_RELAXED/.claude-relaxed"
cat >"$AMP_REAL/test.sh" <<'EOF'
#!/usr/bin/env bash
echo 'real commit repository must fail its suite'
exit 1
EOF
chmod +x "$AMP_REAL/test.sh"
git -C "$AMP_REAL" add -A
out=$(run_hook_command "$AMP_REAL" "git commit -m real & git -C '$AMP_RELAXED' status" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'tests failed'
if printf '%s' "$out" | grep -Fq 'WARNING (not blocking, .claude-relaxed)'; then
  echo 'quality gate incorrectly used the relaxed repository for a backgrounded command' >&2
  exit 1
fi

printf '%s\n' '== quoted git config values containing shell operators remain one commit segment'
QUOTED_VALUES="$TMP/quoted-values"
new_repo "$QUOTED_VALUES"
cat >"$QUOTED_VALUES/test.sh" <<'EOF'
#!/usr/bin/env bash
echo 'quoted git config value fixture must still run the real failing runner'
exit 1
EOF
chmod +x "$QUOTED_VALUES/test.sh"
git -C "$QUOTED_VALUES" add -A
out=$(run_hook_command "$QUOTED_VALUES" "git -c user.name='A&B' commit -m real" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'tests failed'
out=$(run_hook_command "$QUOTED_VALUES" "git -c user.name='A;B' commit -m real" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'tests failed'
out=$(run_hook_command "$QUOTED_VALUES" 'git -c user.name=$(printf A && printf B) commit -m real' 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'tests failed'

printf '%s\n' '== nested git -C cannot redirect the outer commit target'
NESTED_RELAXED="$TMP/nested-relaxed"
NESTED_REAL="$TMP/nested-real"
new_repo "$NESTED_RELAXED"
new_repo "$NESTED_REAL"
touch "$NESTED_RELAXED/.claude-relaxed"
cat >"$NESTED_REAL/test.sh" <<'EOF'
#!/usr/bin/env bash
echo 'outer commit repository must fail its suite'
exit 1
EOF
chmod +x "$NESTED_REAL/test.sh"
git -C "$NESTED_REAL" add -A
nested_command='git -c user.name=$(git -C '\''PLACEHOLDER'\'' rev-parse --is-inside-work-tree) commit -m real'
nested_command=${nested_command/PLACEHOLDER/$NESTED_RELAXED}
out=$(run_hook_command "$NESTED_REAL" "$nested_command" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'tests failed'
if printf '%s' "$out" | grep -Fq 'WARNING (not blocking, .claude-relaxed)'; then
  echo 'quality gate incorrectly used the nested repository for the outer commit' >&2
  exit 1
fi

printf '%s\n' 'PASS: quality-gate.sh enforces a real, portable timeout on lint/test/coverage'
