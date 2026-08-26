#!/usr/bin/env bash
# check-provider-runtime-parity.sh — auditoría read-only de overlays.
#
# La paridad del harness y la paridad de providers son gates distintos. Este
# script compara semánticamente sólo los overlays JSON versionados; no prueba
# credenciales, endpoints vivos ni inferencia autenticada. `opus` y el ID que
# el mismo overlay declara como DEFAULT_OPUS son selecciones equivalentes.
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
    -h|--help)
      cat <<'EOF'
Uso: check-provider-runtime-parity.sh [--json] [--strict]

Audita los overlays JSON de providers entre config/claude y ~/.claude.
Es de solo lectura. Ignora formato/orden de claves y trata `opus` como
equivalente al DEFAULT_OPUS del mismo overlay. --strict devuelve exit 1 si
falta o difiere semánticamente un overlay.
CLAUDE_RUNTIME_DIR permite auditar un runtime temporal.
EOF
      exit 0
      ;;
    *)
      printf '[provider-parity] argumento desconocido: %s\n' "$arg" >&2
      exit 2
      ;;
  esac
done

normalize_overlay() {
  jq -cS '
    if .env.ANTHROPIC_MODEL == "opus" then
      .env.ANTHROPIC_MODEL = .env.ANTHROPIC_DEFAULT_OPUS_MODEL
    else
      .
    end
  ' "$1"
}

command -v jq >/dev/null 2>&1 || {
  printf '[provider-parity] jq es requerido.\n' >&2
  exit 2
}

OVERLAYS=(
  deepseek.settings.json
  glm.settings.json
  ollama.settings.json
  openrouter.settings.json
)
RESULTS='[]'
FAILURES=0

record() {
  local path="$1" status="$2" detail="$3"
  RESULTS=$(printf '%s\n' "$RESULTS" | jq -c \
    --arg path "$path" --arg status "$status" --arg detail "$detail" \
    '. + [{path: $path, status: $status, detail: $detail}]')
  case "$status" in
    MATCH) [ "$JSON_MODE" = true ] || printf '[provider-parity] MATCH   %s\n' "$path" ;;
    MISSING|DRIFT|ERROR)
      FAILURES=$((FAILURES + 1))
      [ "$JSON_MODE" = true ] || printf '[provider-parity] %-7s %s — %s\n' "$status" "$path" "$detail" >&2
      ;;
  esac
}

for overlay in "${OVERLAYS[@]}"; do
  source="$SOURCE_ROOT/$overlay"
  runtime="$RUNTIME_ROOT/$overlay"
  if [ ! -f "$source" ]; then
    record "$overlay" ERROR "falta en la fuente"
  elif ! jq empty "$source" >/dev/null 2>&1; then
    record "$overlay" ERROR "fuente no es JSON válido"
  elif [ ! -f "$runtime" ]; then
    record "$overlay" MISSING "falta en el runtime"
  elif ! jq empty "$runtime" >/dev/null 2>&1; then
    record "$overlay" ERROR "runtime no es JSON válido"
  elif [ "$(normalize_overlay "$source")" = "$(normalize_overlay "$runtime")" ]; then
    record "$overlay" MATCH "equivalente a la fuente"
  else
    record "$overlay" DRIFT "el contenido difiere de la fuente"
  fi
done

if [ "$JSON_MODE" = true ]; then
  jq -n --arg source "$SOURCE_ROOT" --arg runtime "$RUNTIME_ROOT" \
    --argjson failures "$FAILURES" --argjson results "$RESULTS" \
    '{source: $source, runtime: $runtime, failures: $failures, results: $results, parity: ($failures == 0)}'
else
  if [ "$FAILURES" -eq 0 ]; then
    printf '[provider-parity] PASS: overlays runtime coinciden con la fuente.\n'
  else
    printf '[provider-parity] DRIFT: %s diferencia(s); no se modificó ningún archivo.\n' "$FAILURES" >&2
  fi
fi

if [ "$STRICT" = true ] && [ "$FAILURES" -gt 0 ]; then
  exit 1
fi
exit 0
