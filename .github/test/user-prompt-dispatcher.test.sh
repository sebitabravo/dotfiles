#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
DISPATCHER="$ROOT/config/claude/hooks/user-prompt-dispatcher.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/user-prompt-dispatcher-test.XXXXXX")
HOOKS="$TMP/hooks"
LOG="$TMP/invocations"
trap 'rm -rf -- "$TMP"' EXIT
mkdir -p "$HOOKS"

cat >"$HOOKS/secret-detect.sh" <<'EOF'
#!/usr/bin/env bash
input=$(cat)
printf '%s\n' secret-detect >>"$DISPATCH_LOG"
case "$input" in
  *sk-secret-fixture*) printf '%s\n' 'secret blocked' >&2; exit 2 ;;
esac
EOF
cat >"$HOOKS/automatic-workflow.sh" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' automatic-workflow >>"$DISPATCH_LOG"
printf '%s' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"automatic context"}}'
EOF
cat >"$HOOKS/activate-convergence-on-apply.sh" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' activate-convergence >>"$DISPATCH_LOG"
EOF
cat >"$HOOKS/project-integrations-check.sh" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' project-integrations >>"$DISPATCH_LOG"
printf '%s' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"project context"}}'
EOF
chmod +x "$HOOKS"/*.sh

printf '%s\n' '== settings graph has one sequential UserPromptSubmit dispatcher'
jq -e '
  (.hooks.UserPromptSubmit | length == 1) and
  (.hooks.UserPromptSubmit[0].hooks | length == 1) and
  (.hooks.UserPromptSubmit[0].hooks[0].command | endswith("user-prompt-dispatcher.sh")) and
  ([.hooks.UserPromptSubmit[]?.hooks[]?.command | select(test("secret-detect|automatic-workflow|activate-convergence|project-integrations|herdr-agent-state"))] | length == 0)
' "$ROOT/config/claude/settings.json" >/dev/null

printf '%s\n' '== a secret prompt stops before any side-effect consumer'
set +e
jq -nc --arg prompt 'use sk-secret-fixture now' '{hook_event_name:"UserPromptSubmit",prompt:$prompt}' |
  DISPATCH_LOG="$LOG" CLAUDE_PROMPT_DISPATCHER_HOOK_DIR="$HOOKS" "$DISPATCHER" >/dev/null 2>"$TMP/secret.err"
rc=$?
set -e
[ "$rc" -eq 2 ]
grep -Fq 'secret blocked' "$TMP/secret.err"
[ "$(cat "$LOG")" = secret-detect ]

printf '%s\n' '== a clean prompt reaches consumers in declared sequence'
: >"$LOG"
jq -nc --arg prompt 'implement the fixture change' '{hook_event_name:"UserPromptSubmit",prompt:$prompt}' |
  DISPATCH_LOG="$LOG" CLAUDE_PROMPT_DISPATCHER_HOOK_DIR="$HOOKS" "$DISPATCHER" >"$TMP/clean.out"
[ "$(cat "$LOG")" = $'secret-detect\nautomatic-workflow\nactivate-convergence\nproject-integrations' ]
jq -e '.hookSpecificOutput.additionalContext | contains("automatic context") and contains("project context")' "$TMP/clean.out" >/dev/null

printf '%s\n' '== an optional CodeGraph failure is diagnostic, not a prompt block'
OPTIONAL_BIN="$TMP/optional-bin"
mkdir -p "$OPTIONAL_BIN"
cat >"$OPTIONAL_BIN/codegraph" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' 'simulated CodeGraph outage' >&2
exit 17
EOF
chmod +x "$OPTIONAL_BIN/codegraph"
: >"$LOG"
set +e
jq -nc --arg prompt 'implement the fixture change' '{hook_event_name:"UserPromptSubmit",prompt:$prompt}' |
  PATH="$OPTIONAL_BIN:$PATH" DISPATCH_LOG="$LOG" CLAUDE_PROMPT_DISPATCHER_HOOK_DIR="$HOOKS" \
    "$DISPATCHER" >"$TMP/optional.out" 2>"$TMP/optional.err"
optional_rc=$?
set -e
[ "$optional_rc" -eq 0 ] || fail "optional CodeGraph failure blocked prompt (rc=$optional_rc)"
[ "$(cat "$LOG")" = $'secret-detect\nautomatic-workflow\nactivate-convergence\nproject-integrations' ]
grep -Fq 'optional codegraph failed (rc=17); continuing without its context' "$TMP/optional.err"
jq -e '.hookSpecificOutput.additionalContext | contains("automatic context") and contains("project context")' "$TMP/optional.out" >/dev/null

printf '%s\n' 'PASS: UserPromptSubmit secret barrier is sequential and side-effect safe'
