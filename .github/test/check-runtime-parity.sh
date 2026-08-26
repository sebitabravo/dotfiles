#!/usr/bin/env bash
# check-runtime-parity.sh — auditoría de solo lectura del gate efectivo.
#
# La fuente config/claude puede estar verde mientras ~/.claude sigue usando una
# versión anterior. Este script compara únicamente los archivos y comandos que
# hacen cumplir convergencia; no intenta sincronizar, borrar ni modificar el
# runtime. El resto de ~/.claude puede contener estado local legítimo.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/../.." && pwd)
SOURCE_ROOT=${CLAUDE_SOURCE_DIR:-$REPO_ROOT/config/claude}
RUNTIME_ROOT=${CLAUDE_RUNTIME_DIR:-$HOME/.claude}
JSON_MODE=false
STRICT=false

for arg in "$@"; do
  case "$arg" in
    --json) JSON_MODE=true ;;
    --strict) STRICT=true ;;
    -h | --help)
      cat <<'EOF'
Uso: check-runtime-parity.sh [--json] [--strict]

Audita los archivos y hooks de convergencia entre config/claude y ~/.claude.
Es de solo lectura. --strict devuelve exit 1 si falta o difiere algo.
CLAUDE_RUNTIME_DIR permite auditar un runtime temporal sin tocar ~/.claude.
EOF
      exit 0
      ;;
    *)
      printf '[parity] argumento desconocido: %s\n' "$arg" >&2
      exit 2
      ;;
  esac
done

command -v jq >/dev/null 2>&1 || {
  printf '[parity] jq es requerido para auditar settings.json.\n' >&2
  exit 2
}

SOURCE_SETTINGS="$SOURCE_ROOT/settings.json"
RUNTIME_SETTINGS="$RUNTIME_ROOT/settings.json"
EXPECTED_AUTOMATIC_USER_PROMPT="$HOME/.claude/hooks/automatic-workflow.sh"
EXPECTED_USER_PROMPT="$HOME/.claude/hooks/activate-convergence-on-apply.sh"
EXPECTED_AUTOMATIC_STOP="$HOME/.claude/hooks/automatic-workflow-stop.sh"
EXPECTED_STOP="$HOME/.claude/hooks/convergence-stop.sh"

RESULTS='[]'
FAILURES=0

record() {
  local kind="$1" path="$2" status="$3" detail="$4"
  RESULTS=$(printf '%s\n' "$RESULTS" | jq -c \
    --arg kind "$kind" --arg path "$path" --arg status "$status" --arg detail "$detail" \
    '. + [{kind: $kind, path: $path, status: $status, detail: $detail}]')
  case "$status" in
    MATCH) [ "$JSON_MODE" = true ] || printf '[parity] MATCH  %s\n' "$path" ;;
    MISSING | DRIFT | ERROR)
      FAILURES=$((FAILURES + 1))
      [ "$JSON_MODE" = true ] || printf '[parity] %-7s %s — %s\n' "$status" "$path" "$detail" >&2
      ;;
  esac
}

check_file() {
  local relative="$1"
  local source="$SOURCE_ROOT/$relative"
  local runtime="$RUNTIME_ROOT/$relative"

  if [ ! -f "$source" ]; then
    record file "$relative" ERROR "falta en la fuente"
  elif [ ! -x "$source" ]; then
    record file "$relative" ERROR "la fuente no es ejecutable"
  elif [ ! -f "$runtime" ]; then
    record file "$relative" MISSING "falta en el runtime"
  elif cmp -s "$source" "$runtime"; then
    if [ -x "$runtime" ]; then
      record file "$relative" MATCH "igual a la fuente"
    else
      record file "$relative" DRIFT "contenido igual, pero runtime no es ejecutable"
    fi
  else
    record file "$relative" DRIFT "el contenido difiere de la fuente"
  fi
}

check_content_file() {
  local relative="$1"
  local source="$SOURCE_ROOT/$relative"
  local runtime="$RUNTIME_ROOT/$relative"

  if [ ! -f "$source" ]; then
    record file "$relative" ERROR "falta en la fuente"
  elif [ ! -f "$runtime" ]; then
    record file "$relative" MISSING "falta en el runtime"
  elif cmp -s "$source" "$runtime"; then
    record file "$relative" MATCH "igual a la fuente"
  else
    record file "$relative" DRIFT "el contenido difiere de la fuente"
  fi
}

check_file hooks/activate-convergence-on-apply.sh
check_file hooks/automatic-workflow.sh
check_file hooks/automatic-workflow-stop.sh
check_file hooks/secret-detect.sh
check_file hooks/convergence-stop.sh
check_file hooks/lib/test-runner.sh
check_file hooks/lib/automatic-workflow-state.sh
check_file hooks/task-contract.sh
check_file hooks/compact-resume.py
check_file scripts/convergence-start.sh
check_content_file scripts/validate-task-roadmap.py
check_content_file skills/automatic-task-orchestrator/SKILL.md

check_hook_command() {
  local section="$1" expected="$2"
  local tilde_expected="~${expected#"$HOME"}"
  local source_count runtime_count

  source_count=$(jq -r --arg section "$section" --arg expected "$expected" --arg tilde "$tilde_expected" \
    '[.hooks[$section][]?.hooks[]?.command | select(. == $expected or . == $tilde)] | length' \
    "$SOURCE_SETTINGS" 2>/dev/null || printf '%s\n' '-1')
  runtime_count=$(jq -r --arg section "$section" --arg expected "$expected" --arg tilde "$tilde_expected" \
    '[.hooks[$section][]?.hooks[]?.command | select(. == $expected or . == $tilde)] | length' \
    "$RUNTIME_SETTINGS" 2>/dev/null || printf '%s\n' '-1')

  if [ "$source_count" = "0" ]; then
    record settings "$section:$expected" ERROR "el hook esperado no está en la fuente"
  elif [ "$source_count" != "1" ]; then
    record settings "$section:$expected" ERROR "la fuente registra $source_count aliases equivalentes del hook"
  elif [ ! -f "$RUNTIME_SETTINGS" ]; then
    record settings "$section:$expected" MISSING "falta runtime settings.json"
  elif [ "$runtime_count" = "0" ]; then
    record settings "$section:$expected" MISSING "el hook no está registrado en runtime settings.json"
  elif [ "$runtime_count" != "1" ]; then
    record settings "$section:$expected" DRIFT "runtime registra $runtime_count aliases equivalentes; debe existir exactamente uno"
  else
    record settings "$section:$expected" MATCH "hook registrado una sola vez"
  fi
}

if [ ! -f "$SOURCE_SETTINGS" ]; then
  record settings settings.json ERROR "falta settings.json en la fuente"
elif ! jq empty "$SOURCE_SETTINGS" >/dev/null 2>&1; then
  record settings settings.json ERROR "settings.json de fuente no es JSON válido"
elif [ -f "$RUNTIME_SETTINGS" ] && ! jq empty "$RUNTIME_SETTINGS" >/dev/null 2>&1; then
  record settings settings.json ERROR "runtime settings.json no es JSON válido"
else
  check_hook_command UserPromptSubmit "$EXPECTED_AUTOMATIC_USER_PROMPT"
  check_hook_command UserPromptSubmit "$EXPECTED_USER_PROMPT"
  check_hook_command Stop "$EXPECTED_AUTOMATIC_STOP"
  check_hook_command Stop "$EXPECTED_STOP"
fi

if [ "$JSON_MODE" = true ]; then
  jq -n --arg source "$SOURCE_ROOT" --arg runtime "$RUNTIME_ROOT" \
    --argjson failures "$FAILURES" --argjson results "$RESULTS" \
    '{source: $source, runtime: $runtime, failures: $failures, results: $results, parity: ($failures == 0)}'
else
  if [ "$FAILURES" -eq 0 ]; then
    printf '[parity] PASS: runtime contiene el gate de convergencia de la fuente.\n'
  else
    printf '[parity] DRIFT: %s diferencia(s); no se modificó ningún archivo.\n' "$FAILURES" >&2
  fi
fi

if [ "$STRICT" = true ] && [ "$FAILURES" -gt 0 ]; then
  exit 1
fi
exit 0
