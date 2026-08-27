#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/gauntlet-stop.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/gauntlet-stop-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

# gauntlet-stop.sh sources "$HOME/.claude/hooks/lib/test-runner.sh" -- give it
# a real copy of THIS repo's source so the test is self-contained and does not
# depend on whatever happens to be deployed at ~/.claude on the dev machine.
FAKE_HOME="$TMP/home"
TRUST_FILE="$TMP/trusted-repositories"
mkdir -p "$FAKE_HOME/.claude/hooks/lib"
cp "$ROOT/config/claude/hooks/lib/test-runner.sh" "$FAKE_HOME/.claude/hooks/lib/test-runner.sh"

new_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  printf '%s\n' 'init' >"$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" commit -q -m init
}

run_hook() {
  local dir="$1"
  printf '%s\n' "$dir" >"$TRUST_FILE"
  (cd "$dir" && HOME="$FAKE_HOME" CLAUDE_REPOSITORY_TRUST_FILE="$TRUST_FILE" bash "$HOOK" </dev/null)
}

printf '%s\n' '== no changed production code: exits 0 immediately'
EMPTY="$TMP/empty"
new_repo "$EMPTY"
out=$(run_hook "$EMPTY" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 0 ]
[ -z "$out" ]

printf '%s\n' '== production file with a matching test and a passing suite: exits 0'
PASSING="$TMP/passing"
new_repo "$PASSING"
mkdir -p "$PASSING/src"
printf 'module.exports = () => 1;\n' >"$PASSING/src/foo.js"
printf '// test\n' >"$PASSING/src/foo.test.js"
cat >"$PASSING/test.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$PASSING/test.sh"
git -C "$PASSING" add src test.sh
out=$(run_hook "$PASSING" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 0 ]

printf '%s\n' '== production file with a matching test but no available runner: exits 2, never infers PASS'
NO_RUNNER="$TMP/no-runner"
new_repo "$NO_RUNNER"
mkdir -p "$NO_RUNNER/src"
printf 'module.exports = () => 1;\n' >"$NO_RUNNER/src/foo.js"
printf '// test\n' >"$NO_RUNNER/src/foo.test.js"
out=$(PATH="/usr/bin:/bin" run_hook "$NO_RUNNER" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'no native test runner was detected'
printf '%s' "$out" | grep -Fq 'could NOT be verified'

printf '%s\n' '== production file with a matching test and a failing suite: exits 2, reports RED'
FAILING="$TMP/failing"
new_repo "$FAILING"
mkdir -p "$FAILING/src"
printf 'module.exports = () => 1;\n' >"$FAILING/src/foo.js"
printf '// test\n' >"$FAILING/src/foo.test.js"
cat >"$FAILING/test.sh" <<'EOF'
#!/usr/bin/env bash
echo "assertion failed: expected 2, got 1"
exit 1
EOF
chmod +x "$FAILING/test.sh"
git -C "$FAILING" add src test.sh
out=$(run_hook "$FAILING" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'GAUNTLET: the suite is RED'
printf '%s' "$out" | grep -Fq 'assertion failed'

printf '%s\n' '== a hanging suite is killed within the configured bound, not 90s, and reports the timeout explicitly'
HANGING="$TMP/hanging"
new_repo "$HANGING"
mkdir -p "$HANGING/src"
printf 'module.exports = () => 1;\n' >"$HANGING/src/foo.js"
printf '// test\n' >"$HANGING/src/foo.test.js"
HANG_MARKER="$TMP/hang-marker"
cat >"$HANGING/test.sh" <<EOF
#!/usr/bin/env bash
echo \$\$ > "$HANG_MARKER"
sleep 30
EOF
chmod +x "$HANGING/test.sh"
git -C "$HANGING" add src test.sh
start=$(date +%s)
out=$(GAUNTLET_TEST_TIMEOUT_SECONDS=1 run_hook "$HANGING" 2>&1) && rc=0 || rc=$?
end=$(date +%s)
elapsed=$((end - start))
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'did not finish in 1s'
# Real bound is ~1s plus polling/kill overhead; well under the 30s the fake
# suite tries to sleep, and nowhere near the old, unenforced 90s target.
[ "$elapsed" -lt 10 ]
# The hung process must actually be killed, not just abandoned: confirm the
# PID gauntlet.test.sh wrote is no longer alive shortly after we got control back.
if [ -f "$HANG_MARKER" ]; then
  hang_pid=$(cat "$HANG_MARKER")
  sleep 0.5
  ! kill -0 "$hang_pid" 2>/dev/null
fi

printf '%s\n' '== production file with NO test anywhere still reports missing coverage (unchanged behavior)'
MISSING_TEST="$TMP/missing-test"
new_repo "$MISSING_TEST"
mkdir -p "$MISSING_TEST/src"
printf 'module.exports = () => 1;\n' >"$MISSING_TEST/src/bar.js"
cat >"$MISSING_TEST/test.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$MISSING_TEST/test.sh"
git -C "$MISSING_TEST" add src test.sh
out=$(run_hook "$MISSING_TEST" 2>&1) && rc=0 || rc=$?
[ "$rc" -eq 2 ]
printf '%s' "$out" | grep -Fq 'GAUNTLET: there is production code with no test'
printf '%s' "$out" | grep -Fq 'src/bar.js'

printf '%s\n' 'PASS: gauntlet-stop.sh fails closed for missing runners, enforces a portable timeout, and gates untested production code'
