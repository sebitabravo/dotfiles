#!/usr/bin/env bash
# gauntlet-stop.sh — Stop hook. Bloquea el fin de turno si quedo codigo de
# produccion nuevo o modificado SIN su test.
#
# POR QUE EXISTE: quality-gate.sh solo corre en `git commit`. Si el agente
# trabaja y no commitea, no corre ningun gate — el usuario termina mirando
# codigo que no paso por nada. Ese hueco de timing vacia el gauntlet entero
# cuando el flujo es "el agente edita, yo reviso el resultado".
#
# qa-checklist.sh ya detectaba esto pero salia 0: avisaba y dejaba cerrar el
# turno igual. Un aviso que no frena nada se vuelve invisible a los tres dias.
#
# ALCANCE: solo codigo de produccion bajo src/|app/|lib/|internal/|pkg/. Un
# script suelto en la raiz o un archivo de config no dispara esto.
#
# Kill switch: `touch .claude-relaxed` en la raiz del repo.
set -uo pipefail

INPUT=$(cat 2>/dev/null || echo '{}')

# stop_hook_active: Claude Code lo marca cuando el turno ya se reanudo por culpa
# de un Stop hook. Sin este corte, bloquear de nuevo genera un loop infinito
# entre el agente y el hook.
if command -v jq >/dev/null 2>&1; then
  ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
  [ "$ACTIVE" = "true" ] && exit 0
fi

# El modo de permisos NO relaja este hook.
# `defaultMode` es bypassPermissions de forma permanente, asi que degradar por
# modo lo dejaba inerte siempre. Bypass saca los prompts de permiso; no declara
# que el codigo sin tests este terminado. El escape es `.claude-relaxed`, una
# decision explicita por repo.

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" 2>/dev/null || exit 0
[ -f "$ROOT/.claude-relaxed" ] && exit 0

# Archivos de codigo tocados en el working tree, staged, o sin trackear.
CHANGED=$(
  {
    git diff --name-only HEAD 2>/dev/null
    git diff --name-only --cached 2>/dev/null
    git ls-files --others --exclude-standard 2>/dev/null
  } | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|php|java|kt)$' | sort -u
)
[ -z "$CHANGED" ] && exit 0

# Solo codigo de produccion, y nunca los tests mismos.
# El ancla `^` sola no veia monorepos: en un repo con `backend/app/` o
# `packages/api/src/`, el codigo de produccion no matcheaba y el hook se
# saltaba entero — falso verde justo en los repos mas grandes.
# Se permiten hasta 2 segmentos de prefijo (backend/app, packages/api/src).
#
# generated/, __mocks__/|mocks/|fixtures/ y *.d.ts quedan afuera porque
# rules/common/testing.md los excluye explicitamente: "Generated code (ORM
# models, protobuf, OpenAPI stubs)" y "Tests of tests (do not test mocks,
# fixtures, or test helpers)". Un .d.ts puro son solo declaraciones de tipos,
# sin comportamiento en runtime que un test pueda verificar — cae bajo
# "Static config that does not affect behavior". El hook bloqueaba estos tres
# casos sin que la regla que dice implementar los pidiera.
SRC=$(echo "$CHANGED" |
  grep -E '^([^/]+/){0,2}(src|app|lib|internal|pkg)/' |
  grep -vE '(^|/)(tests?|specs?|__tests__|e2e|features|node_modules|vendor|migrations|generated|__mocks__|mocks|fixtures)/|\.(test|spec)\.|_test\.|(^|/)test_|\.d\.ts$' || true)
[ -z "$SRC" ] && exit 0

MISSING=""
for f in $SRC; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  dir=$(dirname "$f")
  stem="${base%.*}"

  found=false
  # Convenciones por ecosistema: junto al archivo, en un __tests__/ hermano, o
  # en un tests/ al lado del directorio padre.
  for d in "$dir" "$dir/__tests__" "$dir/tests" "$(dirname "$dir")/tests" "$(dirname "$dir")/__tests__"; do
    [ -d "$d" ] || continue
    for pat in "${stem}.test" "${stem}.spec" "test_${stem}" "${stem}_test"; do
      if find "$d" -maxdepth 1 -name "${pat}.*" 2>/dev/null | grep -q .; then
        found=true
        break 2
      fi
    done
  done

  # Ultimo recurso: cualquier test en el repo cuyo nombre contenga el stem.
  # Cubre layouts que no siguen ninguna de las convenciones de arriba.
  if [ "$found" = false ]; then
    if git ls-files "*${stem}*" 2>/dev/null |
      grep -qE '(\.(test|spec)\.|_test\.|(^|/)test_)'; then
      found=true
    fi
  fi

  [ "$found" = false ] && MISSING="${MISSING}  - $f"$'\n'
done

# ── La suite existente tiene que estar verde ────────────────────────────────
#
# Tener el archivo de test no prueba nada si la suite esta roja. Y hasta ahora
# NADIE la corria fuera de `git commit`: si el turno terminaba sin commitear,
# el usuario revisaba codigo que no habia pasado por ningun gate.
#
# Corre solo si hay codigo tocado, y con timeout: una suite lenta que frena cada
# turno se termina desactivando entera, y un gate desactivado no protege nada.
# Si no entra en el timeout, se dice — no se asume verde.
if [ -z "${CLAUDE_SKIP_TEST_RUN:-}" ]; then
  TEST_CMD=""
  # shellcheck source=lib/test-runner.sh
  if [ -r "$HOME/.claude/hooks/lib/test-runner.sh" ]; then
    . "$HOME/.claude/hooks/lib/test-runner.sh"
    detect_test_cmd "$ROOT" || true
  fi

  if [ -n "$TEST_CMD" ]; then
    TIMEOUT_BIN=""
    command -v timeout >/dev/null 2>&1 && TIMEOUT_BIN="timeout 90"
    command -v gtimeout >/dev/null 2>&1 && TIMEOUT_BIN="gtimeout 90"

    # eval: el comando puede venir como `cd backend && uv run pytest`, y sin
    # eval el `&&` y el cd llegarian como argumentos literales al runner.
    TEST_OUT=$(eval "$TIMEOUT_BIN $TEST_CMD" 2>&1)
    TEST_RC=$?

    if [ "$TEST_RC" = 124 ]; then
      echo "[gauntlet] la suite no termino en 90s; no se pudo verificar. NO la des por verde." >&2
    elif [ "$TEST_RC" != 0 ]; then
      {
        echo "GAUNTLET: la suite esta ROJA. No cierres el turno."
        echo ""
        echo "$TEST_OUT" | tail -30
        echo ""
        echo "ORDEN DE DIAGNOSTICO (rules/common/testing.md) — no lo saltees:"
        echo "  1. El codigo nuevo esta mal -> arreglalo. NO toques el test."
        echo "  2. Rompiste un contrato que otro codigo usaba -> adapta tu implementacion."
        echo "  3. El test es fragil (orden, reloj, mock viejo) -> arregla la fragilidad,"
        echo "     NO lo que verifica."
        echo "  4. Recien aca: el test esta mal escrito -> PARA y pedi autorizacion"
        echo "     diciendo que test, por que, y que cubre despues."
        echo ""
        echo "Nunca saltes al 4 porque es el camino mas corto al verde."
      } >&2
      exit 2
    fi
  fi
fi

[ -z "$MISSING" ] && exit 0

{
  echo "GAUNTLET: hay codigo de produccion sin test."
  echo ""
  printf '%s' "$MISSING"
  echo ""
  echo "rules/common/testing.md: ALL code requires tests. No exceptions."
  echo "Escribi el test antes de cerrar el turno."
  echo ""
  echo "Si de verdad no corresponde (spike, scratch, prototipo descartable),"
  echo "decilo explicitamente al usuario y pedile que corra: touch .claude-relaxed"
} >&2

exit 2
