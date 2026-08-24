#!/usr/bin/env bash
# convergence-stop.sh — Stop hook para cambios OpenSpec en modo apply.
#
# El contrato de TaskCompleted evita cerrar una tarea sin receipt, pero no
# evita que el agente termine el turno con tareas OpenSpec pendientes. Este
# gate cubre ese hueco: cuando `.claude/convergence.active` existe, el turno
# solo puede terminar si el cambio está completo, OpenSpec valida, la suite
# nativa pasa y existe un receipt final de aceptación.
#
# La activación es deliberada. Un cambio recién creado todavía puede estar en
# la fase de proposal/design y no debe forzar implementación. /opsx:apply (o
# el agente, antes de empezar a aplicar) crea el marcador con el nombre del
# cambio en una sola línea.
#
# No ejecutamos VERIFY desde tasks.md ni desde una descripción LLM: eso sería
# ejecución arbitraria. La suite se detecta con el runner versionado del repo
# (test.sh/Makefile/manifest) y se ejecuta fresca en cada intento de Stop.
#
# `.claude-relaxed` es el escape explícito por repositorio ya usado por los
# demás gates. CLAUDE_SKIP_TEST_RUN no relaja este gate: omitir una prueba no
# es evidencia de convergencia.
set -u

# Consume the hook payload. `stop_hook_active` no es un bypass: si la evidencia
# sigue fallando, el segundo intento también debe quedar bloqueado.
INPUT=$(cat 2>/dev/null || printf '%s' '{}')
CWD=""
if command -v jq >/dev/null 2>&1; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
PROJECT_DIR="${CWD:-$PWD}"

ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" 2>/dev/null || exit 0

[ -f "$ROOT/.claude-relaxed" ] && exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo '[convergence] jq no está en PATH; no se puede interpretar el estado OpenSpec con seguridad.' >&2
  exit 2
fi

MARKER="$ROOT/.claude/convergence.active"
if [ ! -f "$MARKER" ]; then
  # También se puede activar sin crear el marcador cuando el usuario lo
  # solicita explícitamente para una sesión/entorno concreto.
  [ "${CLAUDE_CONVERGENCE_REQUIRED:-false}" = "true" ] || exit 0
fi

CHANGE=""
if [ -f "$MARKER" ]; then
  CHANGE=$(awk 'NF { print $1; exit }' "$MARKER" 2>/dev/null || true)
fi

if [ -z "$CHANGE" ] && [ "${CLAUDE_CONVERGENCE_REQUIRED:-false}" = "true" ]; then
  # Solo auto-seleccionar es seguro cuando existe exactamente un cambio
  # activo. Si hay cero o varios, no inventamos el objetivo.
  LIST_JSON=$(openspec list --json 2>/dev/null || true)
  COUNT=$(printf '%s' "$LIST_JSON" | jq -r '.changes | length' 2>/dev/null || printf '0')
  if [ "$COUNT" = "1" ]; then
    CHANGE=$(printf '%s' "$LIST_JSON" | jq -r '.changes[0].name // .changes[0].id // empty' 2>/dev/null || true)
  fi
fi

if [ -z "$CHANGE" ]; then
  if [ -f "$MARKER" ]; then
    echo '[convergence] marcador activo sin nombre de change; no se puede validar el objetivo.' >&2
    exit 2
  fi
  echo '[convergence] CLAUDE_CONVERGENCE_REQUIRED=true pero no hay un único change OpenSpec activo; no se inventa el objetivo.' >&2
  exit 2
fi

# El nombre viaja a comandos como argumento, nunca se evalúa como shell.
case "$CHANGE" in
  *[!a-zA-Z0-9._-]*|.|..)
    echo "[convergence] nombre de change inválido: $CHANGE" >&2
    exit 2
    ;;
esac

if ! command -v openspec >/dev/null 2>&1; then
  echo '[convergence] OpenSpec CLI no está en PATH; no se puede verificar el change.' >&2
  exit 2
fi

STATUS_JSON=$(openspec status --change "$CHANGE" --json 2>/dev/null || true)
if ! printf '%s' "$STATUS_JSON" | jq -e '.changeRoot and .artifacts' >/dev/null 2>&1; then
  # Un marcador viejo no debe bloquear para siempre después de archivar un
  # change. Se reporta, pero el gate queda inactivo hasta que se seleccione un
  # change válido de nuevo.
  if printf '%s' "$STATUS_JSON" | jq -e '.message == "No active changes." or any(.status[]?; .code == "change_error")' >/dev/null 2>&1; then
    echo "[convergence] marcador stale: el change '$CHANGE' ya no está activo; elimina $MARKER antes del próximo apply." >&2
    exit 0
  fi
  echo "[convergence] no se pudo leer el estado de OpenSpec para '$CHANGE'." >&2
  exit 2
fi

INSTRUCTIONS_JSON=$(openspec instructions apply --change "$CHANGE" --json 2>/dev/null || true)
STATE=$(printf '%s' "$INSTRUCTIONS_JSON" | jq -r '.state // empty' 2>/dev/null || true)
REMAINING=$(printf '%s' "$INSTRUCTIONS_JSON" | jq -r '.progress.remaining // empty' 2>/dev/null || true)

if [ "$STATE" = "blocked" ]; then
  MISSING=$(printf '%s' "$INSTRUCTIONS_JSON" | jq -r '(.missingArtifacts // []) | join(", ")' 2>/dev/null || true)
  echo "[convergence] OpenSpec todavía está bloqueado para '$CHANGE'${MISSING:+; faltan: $MISSING}. No cierres el turno: completa los artifacts requeridos." >&2
  exit 2
fi

case "$REMAINING" in
  ''|*[!0-9]*)
    echo "[convergence] OpenSpec no entregó un progreso verificable para '$CHANGE'." >&2
    exit 2
    ;;
  0) ;;
  *)
    echo "[convergence] '$CHANGE' todavía tiene $REMAINING tarea(s) OpenSpec pendiente(s). Implementa y verifica antes de cerrar." >&2
    exit 2
    ;;
esac

# `validate` recibe el change como item posicional; no existe una opción
# `--change` en OpenSpec 1.9.0.
if ! openspec validate "$CHANGE" --type change --json >/dev/null 2>&1; then
  echo "[convergence] la validación de artifacts OpenSpec falló para '$CHANGE'. Diagnostica y corrige antes de cerrar." >&2
  exit 2
fi

RECEIPT="$ROOT/.claude/convergence/$CHANGE.receipt"
if [ ! -s "$RECEIPT" ]; then
  echo "[convergence] falta el receipt final: $RECEIPT" >&2
  echo '[convergence] Debe contener STATUS: PASS, ACCEPTANCE: PASS, VERIFY_EXIT: 0 y EVIDENCE no vacío.' >&2
  exit 2
fi

receipt_value() {
  awk -F':[[:space:]]*' -v key="$1" '$1 == key { print substr($0, index($0, ":") + 1); exit }' "$RECEIPT" | sed 's/^[[:space:]]*//'
}

[ "$(receipt_value CHANGE)" = "$CHANGE" ] || {
  echo "[convergence] el receipt no contiene CHANGE: $CHANGE." >&2
  exit 2
}
grep -Eq '^[[:space:]]*STATUS:[[:space:]]*PASS[[:space:]]*$' "$RECEIPT" || {
  echo '[convergence] el receipt final no tiene STATUS: PASS.' >&2
  exit 2
}
grep -Eq '^[[:space:]]*ACCEPTANCE:[[:space:]]*PASS[[:space:]]*$' "$RECEIPT" || {
  echo '[convergence] el receipt final no tiene ACCEPTANCE: PASS.' >&2
  exit 2
}
grep -Eq '^[[:space:]]*VERIFY_EXIT:[[:space:]]*0[[:space:]]*$' "$RECEIPT" || {
  echo '[convergence] el receipt final no tiene VERIFY_EXIT: 0.' >&2
  exit 2
}
grep -Eq '^[[:space:]]*EVIDENCE:[[:space:]]*[^[:space:]].*$' "$RECEIPT" || {
  echo '[convergence] el receipt final no tiene EVIDENCE no vacío.' >&2
  exit 2
}

# Asegura una verificación fresca del estado actual; el VERIFY_EXIT del
# receipt por sí solo sería sólo una afirmación histórica.
if ! git diff --check >/dev/null 2>&1; then
  echo '[convergence] git diff --check falló; corrige whitespace antes de cerrar.' >&2
  exit 2
fi

TEST_CMD=""
RUNNER="$HOME/.claude/hooks/lib/test-runner.sh"
[ -r "$RUNNER" ] || RUNNER="$(dirname "$0")/lib/test-runner.sh"
if [ -r "$RUNNER" ]; then
  # shellcheck source=/dev/null
  . "$RUNNER"
  detect_test_cmd "$ROOT" || true
fi

if [ -z "${TEST_CMD:-}" ]; then
  echo '[convergence] no se detectó una suite nativa de verificación; no se acepta convergencia sin un runner del proyecto.' >&2
  exit 2
fi

TIMEOUT_BIN=""
command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN="timeout 180"
command -v gtimeout >/dev/null 2>&1 && TIMEOUT_BIN="gtimeout 180"
[ -z "$TIMEOUT_BIN" ] && echo '[convergence] no hay timeout/gtimeout; se ejecuta la suite sin límite del wrapper.' >&2

TEST_OUT=$(eval "$TIMEOUT_BIN $TEST_CMD" 2>&1)
TEST_RC=$?
if [ "$TEST_RC" = "124" ]; then
  echo '[convergence] la suite nativa no terminó en 180s; no se puede cerrar como PASS.' >&2
  printf '%s\n' "$TEST_OUT" | tail -30 >&2
  exit 2
fi
if [ "$TEST_RC" != "0" ]; then
  echo '[convergence] la suite nativa está RED; el agente debe diagnosticar y aplicar la corrección.' >&2
  printf '%s\n' "$TEST_OUT" | tail -40 >&2
  exit 2
fi

echo "[convergence] PASS: '$CHANGE' tiene artifacts/tareas completos, validación OpenSpec, receipt de aceptación y suite nativa verde." >&2
exit 0
