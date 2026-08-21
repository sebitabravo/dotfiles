#!/bin/bash
# TaskCreated/TaskCompleted gate — contrato minimo para la task list nativa.
#
# El hook valida estructura y evidencia declarada, pero no ejecuta VERIFY:
# ejecutar texto proveniente de una descripcion como shell seria una inyeccion.
# La corrida del comando y el receipt son responsabilidad del agente/proyecto;
# un receipt sin aceptación y verificación PASS no puede cerrar la tarea.
set -euo pipefail

INPUT=$(cat 2>/dev/null || true)
[ -n "$INPUT" ] || exit 0

EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // empty' 2>/dev/null || true)
case "$EVENT" in
  TaskCreated|TaskCompleted) ;;
  *) exit 0 ;;
esac

fail() {
  printf '[task-contract] %s\n' "$1" >&2
  exit 2
}

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
TASK_ID=$(printf '%s' "$INPUT" | jq -r '.task_id // empty' 2>/dev/null || true)
TASK_SUBJECT=$(printf '%s' "$INPUT" | jq -r '.task_subject // empty' 2>/dev/null || true)
TASK_DESCRIPTION=$(printf '%s' "$INPUT" | jq -r '.task_description // empty' 2>/dev/null || true)

[ -n "$CWD" ] && [ -d "$CWD" ] || fail 'cwd ausente o inexistente'
[ -n "$TASK_ID" ] || fail 'task_id ausente'
[ -n "$TASK_SUBJECT" ] || fail 'task_subject ausente'
[ -n "$TASK_DESCRIPTION" ] || fail 'task_description obligatorio'
[ "${#TASK_SUBJECT}" -le 160 ] || fail 'task_subject supera 160 caracteres'

marker_value() {
  printf '%s\n' "$TASK_DESCRIPTION" | awk -v marker="$1" '
    index($0, marker) == 1 {
      value = substr($0, length(marker) + 1)
      sub(/^[[:space:]]+/, "", value)
      print value
      exit
    }
  '
}

ROADMAP=$(marker_value 'ROADMAP:')
DEPENDS_ON=$(marker_value 'DEPENDS_ON:')
PATHS=$(marker_value 'PATHS:')
ACCEPTANCE=$(marker_value 'ACCEPTANCE:')
VERIFY=$(marker_value 'VERIFY:')
RECEIPT=$(marker_value 'RECEIPT:')

[ -n "$ROADMAP" ] || fail 'falta ROADMAP: <ruta relativa>'
[ -n "$DEPENDS_ON" ] || fail 'falta DEPENDS_ON: <task-id,...|none>'
[ -n "$PATHS" ] || fail 'falta PATHS: <rutas afectadas>'
[ -n "$ACCEPTANCE" ] || fail 'falta ACCEPTANCE: <criterio observable>'
[ -n "$VERIFY" ] || fail 'falta VERIFY: <comando o gate>'
[ -n "$RECEIPT" ] || fail 'falta RECEIPT: <ruta del receipt>'

assert_safe_relative_path() {
  case "$1" in
    ''|/*|..|../*|*/../*|*/..|./*|*/./*|*/.)
      fail "$2 debe ser una ruta relativa sin . o ..: $1"
      ;;
  esac
}

assert_safe_paths() {
  local raw="$1" item normalized
  normalized=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')
  case "$normalized" in
    ''|none|-|n/a|na)
      fail 'PATHS debe declarar al menos una ruta afectada; none no prueba ownership'
      ;;
  esac

  while IFS= read -r item; do
    item=$(printf '%s' "$item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    [ -n "$item" ] || fail 'PATHS contiene una ruta vacía'
    case "$item" in
      /*|\\*|../*|*/../*|*/..|.|./*|*/./*)
        fail "PATHS contiene una ruta insegura: $item"
        ;;
    esac
  done < <(printf '%s\n' "$raw" | tr ',;' '\n')
}

assert_safe_relative_path "$ROADMAP" ROADMAP
assert_safe_paths "$PATHS"

if [ ! -f "$CWD/$ROADMAP" ]; then
  fail "ROADMAP no existe: $CWD/$ROADMAP"
fi

receipt_path=''
case "$RECEIPT" in
  '')
    fail 'RECEIPT no puede estar vacio'
    ;;
  /*)
    case "$RECEIPT" in
      /tmp/cavecrew/*)
        case "$RECEIPT" in
          *..*|*/./*) fail 'RECEIPT no puede contener traversal de ruta' ;;
          *) receipt_path="$RECEIPT" ;;
        esac
        ;;
      *) fail 'RECEIPT absoluto solo puede vivir bajo /tmp/cavecrew' ;;
    esac
    ;;
  *)
    assert_safe_relative_path "$RECEIPT" RECEIPT
    receipt_path="$CWD/$RECEIPT"
    ;;
esac

if [ "$EVENT" = TaskCompleted ]; then
  [ -f "$receipt_path" ] || fail "RECEIPT no existe: $receipt_path"
  [ -s "$receipt_path" ] || fail "RECEIPT vacio: $receipt_path"

  receipt_task_id=$(awk -F':[[:space:]]*' '/^[[:space:]]*TASK_ID:/ { print $2; exit }' "$receipt_path")
  [ "$receipt_task_id" = "$TASK_ID" ] || fail "RECEIPT TASK_ID no coincide con $TASK_ID"

  if ! grep -Eq '^[[:space:]]*STATUS:[[:space:]]*PASS[[:space:]]*$' "$receipt_path"; then
    fail 'RECEIPT debe contener STATUS: PASS para cerrar la tarea'
  fi
  if ! grep -Eq '^[[:space:]]*ACCEPTANCE:[[:space:]]*PASS[[:space:]]*$' "$receipt_path"; then
    fail 'RECEIPT debe contener ACCEPTANCE: PASS para cerrar la tarea'
  fi
  if ! grep -Eq '^[[:space:]]*VERIFY_EXIT:[[:space:]]*0[[:space:]]*$' "$receipt_path"; then
    fail 'RECEIPT debe contener VERIFY_EXIT: 0 para cerrar la tarea'
  fi
  if ! grep -Eq '^[[:space:]]*EVIDENCE:[[:space:]]*[^[:space:]].*$' "$receipt_path"; then
    fail 'RECEIPT debe contener EVIDENCE no vacio para cerrar la tarea'
  fi
fi

exit 0
