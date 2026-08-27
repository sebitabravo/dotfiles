#!/usr/bin/env bash
# Stop hook — no permite cerrar una sesión de oneshot sin convergencia fresca.
#
# El receipt aporta la ruta del roadmap y la evidencia declarada, pero nunca
# se ejecuta como shell. Los únicos comandos que este hook ejecuta son el
# validador versionado del roadmap, OpenSpec validate para su change y el
# runner nativo detectado por test-runner.sh.
set -u

INPUT=$(cat 2>/dev/null || printf '%s' '{}')
if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' '[automatic-workflow] jq is not installed: blocking preventively; install it with: brew install jq' >&2
  exit 2
fi

SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$SESSION_ID" ] && [ -d "$CWD" ] || exit 0

ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$ROOT" ] && [ -d "$ROOT" ] || exit 0
[ -f "$ROOT/.claude-relaxed" ] && exit 0

STATE_LIB="$(dirname "$0")/lib/automatic-workflow-state.sh"
[ -r "$STATE_LIB" ] || exit 0
# shellcheck source=/dev/null
. "$STATE_LIB"

STATE=$(automation_state_path "$ROOT" "$SESSION_ID" 2>/dev/null || true)
[ -s "$STATE" ] || exit 0

fail() {
  printf '[automatic-workflow] %s\n' "$1" >&2
  exit 2
}

# Version-1 states created before activation-bound receipts are legacy state,
# not evidence. Reinitialize them before reading receipts so Stop never gets
# trapped on an empty activation or accepts a historical PASS.
if ! automation_state_is_valid "$ROOT" "$SESSION_ID"; then
  LEGACY_MODE=$(automation_state_mode "$ROOT" "$SESSION_ID" 2>/dev/null || true)
  case "$LEGACY_MODE" in
    oneshot | follow_up | docs_only) ;;
    *) LEGACY_MODE=oneshot ;;
  esac
  automation_activate "$ROOT" "$SESSION_ID" "$LEGACY_MODE" || fail 'no se pudo migrar el state legacy a una activación nueva'
fi

RECEIPT=$(automation_receipt_path "$ROOT" "$SESSION_ID") || fail 'no se pudo resolver el receipt de la sesión'
PROJECT_RECEIPT=$(automation_project_receipt_path "$ROOT" "$SESSION_ID") || fail 'no se pudo resolver el receipt local de la sesión'
EXPECTED_ACTIVATION=$(automation_activation_id "$ROOT" "$SESSION_ID") || fail 'no se pudo leer ACTIVATION del state'
[ -n "$EXPECTED_ACTIVATION" ] || fail 'el state no tiene activation_id; inicia una activación nueva'

# The project-local receipt is the preferred candidate. Its presence is
# authoritative: a malformed or stale local receipt is an actionable error,
# never a reason to fall back silently to an old administrative PASS.
if [ -e "$PROJECT_RECEIPT" ]; then
  RECEIPT="$PROJECT_RECEIPT"
elif [ -e "$RECEIPT" ]; then
  :
fi

[ ! -e "$RECEIPT" ] || [ -s "$RECEIPT" ] ||
  fail "el receipt seleccionado está vacío o es inválido: $RECEIPT"

if [ ! -s "$RECEIPT" ]; then
  # A missing receipt is an actionable workflow blocker, not a reason to trap
  # Claude in an endless Stop-hook retry loop. Record the typed BLOCKED state
  # from the hook-owned runtime path, then let the next user prompt resume it.
  BLOCKED_TMP=$(mktemp "${RECEIPT}.tmp.XXXXXX" 2>/dev/null || true)
  if [ -n "$BLOCKED_TMP" ]; then
    cat >"$BLOCKED_TMP" <<EOF
STATUS: BLOCKED
ACCEPTANCE: PENDING
ACTIVATION: $EXPECTED_ACTIVATION
VERIFY_TYPE: $(automation_state_mode "$ROOT" "$SESSION_ID" | grep -qx docs_only && printf STRUCTURAL || printf EXECUTABLE)
VERIFY_EXIT: 2
EVIDENCE: no se produjo un receipt de convergencia antes de Stop; retomá la sesión para completar el roadmap y la verificación
EOF
    mv -f -- "$BLOCKED_TMP" "$RECEIPT" || rm -f -- "$BLOCKED_TMP"
  fi
  printf '%s\n' '[automatic-workflow] BLOCKED: falta el receipt; se conserva el estado activo sin reintentos infinitos.' >&2
  exit 0
fi

receipt_value() {
  awk -F':[[:space:]]*' -v key="$1" '$1 == key { print substr($0, index($0, ":") + 1); exit }' "$RECEIPT" | sed 's/^[[:space:]]*//'
}

ACTIVATION=$(receipt_value ACTIVATION)
[ "$ACTIVATION" = "$EXPECTED_ACTIVATION" ] ||
  fail "el receipt no está ligado a la activación actual (ACTIVATION esperado: $EXPECTED_ACTIVATION)"

MODE=$(automation_state_mode "$ROOT" "$SESSION_ID")
case "$MODE" in
  docs_only) EXPECTED_VERIFY_TYPE=STRUCTURAL ;;
  oneshot | follow_up) EXPECTED_VERIFY_TYPE=EXECUTABLE ;;
  *) fail "modo de state inválido: $MODE" ;;
esac

grep -Eq "^[[:space:]]*VERIFY_TYPE:[[:space:]]*${EXPECTED_VERIFY_TYPE}[[:space:]]*$" "$RECEIPT" ||
  fail "el receipt debe declarar VERIFY_TYPE: $EXPECTED_VERIFY_TYPE"

STATUS=$(receipt_value STATUS)
case "$STATUS" in
  BLOCKED)
    grep -Eq '^[[:space:]]*ACCEPTANCE:[[:space:]]*PENDING[[:space:]]*$' "$RECEIPT" || fail 'un receipt BLOCKED debe tener ACCEPTANCE: PENDING'
    grep -Eq '^[[:space:]]*VERIFY_EXIT:[[:space:]]*[0-9]+[[:space:]]*$' "$RECEIPT" || fail 'un receipt BLOCKED debe tener VERIFY_EXIT numérico'
    grep -Eq '^[[:space:]]*EVIDENCE:[[:space:]]*[^[:space:]].*$' "$RECEIPT" || fail 'un receipt BLOCKED debe tener EVIDENCE no vacío'
    printf '[automatic-workflow] BLOCKED: se conserva el estado activo; no se declara PASS.\n' >&2
    exit 0
    ;;
  PASS) ;;
  *)
    fail 'el receipt debe tener STATUS: PASS o STATUS: BLOCKED'
    ;;
esac

grep -Eq '^[[:space:]]*ACCEPTANCE:[[:space:]]*PASS[[:space:]]*$' "$RECEIPT" || fail 'el receipt no tiene ACCEPTANCE: PASS'
grep -Eq '^[[:space:]]*VERIFY_EXIT:[[:space:]]*0[[:space:]]*$' "$RECEIPT" || fail 'el receipt no tiene VERIFY_EXIT: 0'
grep -Eq '^[[:space:]]*EVIDENCE:[[:space:]]*[^[:space:]].*$' "$RECEIPT" || fail 'el receipt no tiene EVIDENCE no vacío'

ROADMAP=$(receipt_value ROADMAP)
case "$ROADMAP" in
  '' | /* | .. | ../* | */../* | */.. | ./* | */./* | */.)
    fail "ROADMAP debe ser una ruta relativa segura: $ROADMAP"
    ;;
esac
ROADMAP_PATH="$ROOT/$ROADMAP"
[ -f "$ROADMAP_PATH" ] || fail "el roadmap no existe: $ROADMAP_PATH"

# Una ruta declarada en el receipt no autoriza duplicar la fuente de verdad.
# Sólo se aplica a la ruta directa; OpenSpec tiene su propio layout de tasks.
case "$ROADMAP" in
  openspec/changes/*/tasks.md) ;;
  *)
    DIRECT_ROADMAP_COUNT=0
    DIRECT_ROADMAP_ONE=''
    DIRECT_ROADMAP_TWO=''
    for candidate in \
      "$ROOT/TASK-ROADMAP.md" \
      "$ROOT/task-roadmap.md" \
      "$ROOT/.claude/task-roadmap.md"; do
      [ -f "$candidate" ] || continue
      same_file=false
      [ -n "$DIRECT_ROADMAP_ONE" ] && [ "$candidate" -ef "$DIRECT_ROADMAP_ONE" ] && same_file=true
      [ -n "$DIRECT_ROADMAP_TWO" ] && [ "$candidate" -ef "$DIRECT_ROADMAP_TWO" ] && same_file=true
      if [ "$same_file" = false ]; then
        DIRECT_ROADMAP_COUNT=$((DIRECT_ROADMAP_COUNT + 1))
        if [ "$DIRECT_ROADMAP_COUNT" -eq 1 ]; then
          DIRECT_ROADMAP_ONE="$candidate"
        elif [ "$DIRECT_ROADMAP_COUNT" -eq 2 ]; then
          DIRECT_ROADMAP_TWO="$candidate"
        fi
      fi
    done
    if [ "$DIRECT_ROADMAP_COUNT" -gt 1 ]; then
      fail "se detectaron múltiples roadmaps directos; consolida una sola fuente antes de cerrar"
    fi
    ;;
esac

VALIDATOR="${CLAUDE_AUTOMATION_VALIDATOR:-$HOME/.claude/scripts/validate-task-roadmap.py}"
[ -x "$VALIDATOR" ] || [ -f "$VALIDATOR" ] || fail "no existe el validador de roadmap: $VALIDATOR"
PYTHON_BIN="${CLAUDE_AUTOMATION_PYTHON:-python3}"
command -v "$PYTHON_BIN" >/dev/null 2>&1 || fail "no existe el intérprete del validador: $PYTHON_BIN"

VALIDATOR_ARGS=()
case "$ROADMAP" in
  openspec/changes/*/tasks.md) ;;
  *) VALIDATOR_ARGS+=(--strict --require-paths-for-parallel) ;;
esac
ROADMAP_JSON=$("$PYTHON_BIN" "$VALIDATOR" "$ROADMAP_PATH" --json "${VALIDATOR_ARGS[@]}" 2>/dev/null || true)
if ! printf '%s' "$ROADMAP_JSON" | jq -e '.valid == true and .task_count > 0' >/dev/null 2>&1; then
  printf '%s\n' "$ROADMAP_JSON" | jq -r '.errors[]? // empty' >&2 || true
  fail "el roadmap no es un DAG válido: $ROADMAP"
fi
PENDING=$(printf '%s' "$ROADMAP_JSON" | jq -r '.graph.status_counts.pending // 0')
IN_PROGRESS=$(printf '%s' "$ROADMAP_JSON" | jq -r '.graph.status_counts.in_progress // 0')
[ "$PENDING" = 0 ] || fail "el roadmap todavía tiene $PENDING task(s) pendiente(s)"
[ "$IN_PROGRESS" = 0 ] || fail "el roadmap todavía tiene $IN_PROGRESS task(s) en progreso"

case "$ROADMAP" in
  openspec/changes/*/tasks.md)
    CHANGE=${ROADMAP#openspec/changes/}
    CHANGE=${CHANGE%/tasks.md}
    case "$CHANGE" in
      '' | *[!a-zA-Z0-9._-]* | . | ..) fail "change OpenSpec inválido en ROADMAP: $CHANGE" ;;
    esac
    command -v openspec >/dev/null 2>&1 || fail 'OpenSpec CLI no está en PATH'
    openspec validate "$CHANGE" --type change --json >/dev/null 2>&1 || fail "openspec validate falló para $CHANGE"
    ;;
esac

git -C "$ROOT" diff --check >/dev/null 2>&1 || fail 'git diff --check falló; corrige whitespace antes de cerrar'

if [ "$EXPECTED_VERIFY_TYPE" = EXECUTABLE ]; then
  # TEST_CMD is a public variable populated by the sourced runner helper.
  # shellcheck disable=SC2034
  TEST_CMD=""
  RUNNER="${CLAUDE_AUTOMATION_TEST_RUNNER:-$HOME/.claude/hooks/lib/test-runner.sh}"
  [ -r "$RUNNER" ] || RUNNER="$(dirname "$0")/lib/test-runner.sh"
  [ -r "$RUNNER" ] || fail 'no existe el detector de runner nativo'
  # shellcheck source=/dev/null
  . "$RUNNER"
  declare -f run_trusted_test_once >/dev/null 2>&1 || fail 'el detector de runner no expone la frontera de confianza requerida'

  TEST_TIMEOUT_SECONDS=180
  TEST_OUT=$(cd "$ROOT" && run_trusted_test_once "$ROOT" "$SESSION_ID" "$TRANSCRIPT_PATH" "$TEST_TIMEOUT_SECONDS" 2>&1)
  TEST_RC=$?
  [ "$TEST_RC" = 126 ] && fail "$TEST_OUT"
  [ "$TEST_RC" = 127 ] && fail "$TEST_OUT"
  [ "$TEST_RC" = 125 ] && fail "$TEST_OUT"
  [ "$TEST_RC" = 124 ] && fail "el runner nativo excedió 180s: $(printf '%s' "$TEST_OUT" | tail -5)"
  [ "$TEST_RC" = 0 ] || fail "el runner nativo está RED: $(printf '%s' "$TEST_OUT" | tail -20)"
fi

automation_clear_receipts "$ROOT" "$SESSION_ID" || fail 'no se pudieron limpiar ambos receipts después de PASS; se conserva el state activo'
automation_deactivate "$ROOT" "$SESSION_ID" || fail 'no se pudo desactivar el state después de limpiar receipts'
printf '[automatic-workflow] PASS: roadmap, acceptance, diff check y runner nativo están verdes.\n' >&2
exit 0
