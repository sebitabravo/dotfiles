#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/automatic-workflow.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/automatic-workflow-test.XXXXXX")
PROJECT="$TMP/project"
STATE="$TMP/state"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$PROJECT"
git -C "$PROJECT" init -q

payload() {
  jq -nc --arg cwd "$PROJECT" --arg session "$1" --arg prompt "$2" \
    '{hook_event_name:"UserPromptSubmit",cwd:$cwd,session_id:$session,prompt:$prompt}'
}

echo '== conversational prompt is a no-op'
conversation=$(payload session-conversation '¿Cómo funciona este hook?' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$conversation" ]
[ ! -e "$STATE/session-conversation.json" ]

echo '== actionable oneshot injects context and creates isolated state'
oneshot=$(payload session-one 'Implementa una validación para el formulario' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
printf '%s' "$oneshot" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit" and (.hookSpecificOutput.additionalContext | contains("AUTOMATIC ONESHOT WORKFLOW: ACTIVE"))' >/dev/null
[ -s "$STATE/session-one.json" ]
receipt=$(printf '%s' "$oneshot" | jq -r '.hookSpecificOutput.additionalContext' | sed -n 's/^Receipt obligatorio de esta sesión: //p')
[ -n "$receipt" ]

echo '== outcome intent activates without an imperative verb'
outcome=$(payload session-outcome 'Quiero que el flujo funcione y pase los tests' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
printf '%s' "$outcome" | jq -e '.hookSpecificOutput.additionalContext | contains("AUTOMATIC ONESHOT WORKFLOW: ACTIVE")' >/dev/null
[ -s "$STATE/session-outcome.json" ]

echo '== informational intent remains a no-op'
informational=$(payload session-informational 'Quiero entender cómo funciona este hook' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$informational" ]
[ ! -e "$STATE/session-informational.json" ]

echo '== a non-actionable follow-up remains inside the active workflow'
follow_up=$(payload session-one 'El error aparece cuando guardo' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
printf '%s' "$follow_up" | jq -e '.hookSpecificOutput.additionalContext | contains("seguimiento de una tarea ya activa")' >/dev/null

echo '== slash commands do not create generic duplicate state'
slash=$(payload session-slash '/opsx:apply example-change' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$slash" ]
[ ! -e "$STATE/session-slash.json" ]

echo '== missing session identity cannot activate an unenforceable task'
missing=$(jq -nc --arg cwd "$PROJECT" '{hook_event_name:"UserPromptSubmit",cwd:$cwd,prompt:"Implementa algo"}' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$missing" ]

echo 'PASS: automatic workflow distingue conversación, oneshot y seguimiento'
