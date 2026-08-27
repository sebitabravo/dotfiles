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
legacy_receipt=$(printf '%s' "$oneshot" | jq -r '.hookSpecificOutput.additionalContext' | sed -n 's/^Receipt obligatorio de esta sesión: //p')
local_receipt=$(printf '%s' "$oneshot" | jq -r '.hookSpecificOutput.additionalContext' | sed -n 's/^Receipt local recomendado (no requiere permisos fuera del repositorio): //p')
admin_receipt=$(printf '%s' "$oneshot" | jq -r '.hookSpecificOutput.additionalContext' | sed -n 's/^Si la política permite además un receipt administrativo, también se acepta: //p')
[ -z "$legacy_receipt" ]
[ -n "$local_receipt" ]
[ -n "$admin_receipt" ]
printf '%s' "$oneshot" | jq -e '.hookSpecificOutput.additionalContext | contains("No uses xxd ni el validador privado bajo ~/.claude/scripts") and contains("- [ ] T001 [depends_on: none]")' >/dev/null
activation=$(jq -r '.activation_id' "$STATE/session-one.json")
printf '%s' "$oneshot" | jq -e --arg activation "$activation" '.hookSpecificOutput.additionalContext | contains("ACTIVATION obligatorio para ambos receipts: " + $activation) and contains("VERIFY_TYPE obligatorio para este modo: EXECUTABLE")' >/dev/null

echo '== explicit read-only audit is a no-op even though review is an action word'
read_only=$(payload session-read-only 'Review this repository read-only. Do not modify anything.' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$read_only" ]
[ ! -e "$STATE/session-read-only.json" ]

echo '== read-only suggestions and negated mutation words stay informational'
read_only_suggestion=$(payload session-read-only-suggestion 'Review this read-only; suggestion: fix the typo if you find one.' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$read_only_suggestion" ]
[ ! -e "$STATE/session-read-only-suggestion.json" ]
read_only_negation=$(payload session-read-only-negation 'Audit only. Do not modify, edit, or write anything.' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$read_only_negation" ]
[ ! -e "$STATE/session-read-only-negation.json" ]
read_only_spanish=$(payload session-read-only-spanish 'Solo lectura: no cambies, modifiques ni escribas nada.' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$read_only_spanish" ]
[ ! -e "$STATE/session-read-only-spanish.json" ]

echo '== only an explicit positive read-only follow-on escalates'
read_only_positive=$(payload session-read-only-positive 'Read-only review, then implement the fix' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
printf '%s' "$read_only_positive" | jq -e '.hookSpecificOutput.additionalContext | contains("VERIFY_TYPE obligatorio para este modo: EXECUTABLE")' >/dev/null

echo '== documentation-only activates structural verification without requiring code tests'
docs_only=$(payload session-docs 'Documenta cómo usar este repositorio' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
printf '%s' "$docs_only" | jq -e '.hookSpecificOutput.additionalContext | contains("VERIFY_TYPE obligatorio para este modo: STRUCTURAL") and contains("No exijas ni inventes un runner de código")' >/dev/null
jq -e '.mode == "docs_only"' "$STATE/session-docs.json" >/dev/null

echo '== a docs-only activation escalates a later code mutation without rebinding'
docs_follow_up=$(payload session-docs-follow-up 'Documenta cómo usar este repositorio' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
docs_activation=$(jq -r '.activation_id' "$STATE/session-docs-follow-up.json")
docs_follow_up=$(payload session-docs-follow-up 'Corrige el código roto' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ "$(jq -r '.activation_id' "$STATE/session-docs-follow-up.json")" = "$docs_activation" ]
jq -e '.mode == "follow_up"' "$STATE/session-docs-follow-up.json" >/dev/null
printf '%s' "$docs_follow_up" | jq -e '.hookSpecificOutput.additionalContext | contains("VERIFY_TYPE obligatorio para este modo: EXECUTABLE")' >/dev/null

echo '== mixed documentation and correction remains a mutating workflow'
mixed=$(payload session-mixed 'Documenta cómo usar este repositorio y corrige el enlace roto' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
printf '%s' "$mixed" | jq -e '.hookSpecificOutput.additionalContext | contains("VERIFY_TYPE obligatorio para este modo: EXECUTABLE")' >/dev/null
jq -e '.mode == "oneshot"' "$STATE/session-mixed.json" >/dev/null

echo '== outcome intent activates without an imperative verb'
outcome=$(payload session-outcome 'Quiero que el flujo funcione y pase los tests' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
printf '%s' "$outcome" | jq -e '.hookSpecificOutput.additionalContext | contains("AUTOMATIC ONESHOT WORKFLOW: ACTIVE")' >/dev/null
[ -s "$STATE/session-outcome.json" ]

echo '== informational intent remains a no-op'
informational=$(payload session-informational 'Quiero entender cómo funciona este hook' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$informational" ]
[ ! -e "$STATE/session-informational.json" ]

echo '== an informational question containing the noun test remains a no-op'
test_definition=$(payload session-test-definition '¿Qué es un test?' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
[ -z "$test_definition" ]
[ ! -e "$STATE/session-test-definition.json" ]

echo '== an explicit test action still activates the workflow'
test_action=$(payload session-test-action 'Ejecuta los tests del proyecto' | CLAUDE_AUTOMATION_STATE_DIR="$STATE" "$HOOK")
printf '%s' "$test_action" | jq -e '.hookSpecificOutput.additionalContext | contains("AUTOMATIC ONESHOT WORKFLOW: ACTIVE")' >/dev/null
[ -s "$STATE/session-test-action.json" ]

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
