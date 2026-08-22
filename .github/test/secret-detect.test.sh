#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
HOOK="$ROOT/config/claude/hooks/secret-detect.sh"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/secret-detect-test.XXXXXX")
trap 'rm -rf "$TMP"' EXIT

printf '%s\n' '== JSON cwd with task- prefix is not a secret'
jq -nc \
  --arg cwd "$TMP/claude-task-oneshot-12345678901234567890/project" \
  --arg prompt 'Implementa la tarea en el repositorio temporal' \
  '{hook_event_name:"UserPromptSubmit",cwd:$cwd,prompt:$prompt}' | "$HOOK"

printf '%s\n' '== JSON prompt with a provider key is blocked'
set +e
jq -nc --arg prompt "Usa sk-abcdefghijklmnopqrstuvwxyz123456" \
  '{hook_event_name:"UserPromptSubmit",prompt:$prompt}' | "$HOOK" >"$TMP/out" 2>"$TMP/err"
rc=$?
set -e
[ "$rc" -eq 2 ]
grep -Fq 'PROMPT BLOCKED: secret detected' "$TMP/err"

printf '%s\n' '== plain text remains supported'
set +e
printf '%s' 'sk-abcdefghijklmnopqrstuvwxyz123456' | "$HOOK" >"$TMP/plain.out" 2>"$TMP/plain.err"
rc=$?
set -e
[ "$rc" -eq 2 ]

printf '%s\n' 'PASS: secret detector scans prompt content without path false positives'

