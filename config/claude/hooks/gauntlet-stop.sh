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

# El modo de permisos NO relaja este hook, cualquiera sea.
# Un modo de permisos responde "tenes derecho a hacer esto"; este hook responde
# "esto todavia no esta terminado". Son preguntas distintas y no deberian
# compartir interruptor, asi que degradar por modo lo dejaria inerte sin que eso
# signifique nada sobre el codigo. El escape es `.claude-relaxed`, una decision
# explicita por repo.

PROJECT_DIR="$PWD"
if command -v jq >/dev/null 2>&1; then
  CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
  [ -n "$CWD" ] && PROJECT_DIR="$CWD"
fi
ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
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
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  base=$(basename "$f")
  dir=$(dirname "$f")
  stem="${base%.*}"

  found=false
  # Convenciones por ecosistema: junto al archivo, en un __tests__/ hermano, o
  # en un tests/ al lado del directorio padre, o en el tests/ de la raiz
  # (convencion Astro/Vite/Vitest).
  for d in "$dir" "$dir/__tests__" "$dir/tests" "$(dirname "$dir")/tests" "$(dirname "$dir")/__tests__" "$ROOT/tests" "$ROOT/__tests__"; do
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
  # Los DOS flags son necesarios y no son aditivos por defecto: --cached mira el
  # indice (tests ya versionados) y --others el working tree (tests nuevos sin
  # commitear). Con --others solo, un test ya trackeado se reporta inexistente.
  if [ "$found" = false ]; then
    if git ls-files --cached --others --exclude-standard "*${stem}*" 2>/dev/null |
      grep -qE '(\.(test|spec)\.|_test\.|(^|/)test_)'; then
      found=true
    fi
  fi

  # Ultimo recurso por contenido: un modulo puede estar cubierto por un test
  # que importa la facade del directorio (src/lib/data) sin nombrar al archivo
  # individual. La suite ya corrio verde arriba; este grep solo evita el falso
  # "missing" para archivos cubiertos via import.
  if [ "$found" = false ] && [ -d "$ROOT/tests" ]; then
    rel="${dir#./}"
    if grep -rlE "['\"][^'\"]*${rel}/${stem}['\"]|['\"][^'\"]*${rel}['\"]" "$ROOT/tests" 2>/dev/null | grep -q .; then
      found=true
    fi
  fi

  [ "$found" = false ] && MISSING="${MISSING}  - $f"$'\n'
done <<<"$SRC"

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
  # shellcheck disable=SC1091
  if [ -r "$HOME/.claude/hooks/lib/test-runner.sh" ]; then
    . "$HOME/.claude/hooks/lib/test-runner.sh"
    detect_test_cmd "$ROOT" || true
  fi

  if [ -n "$TEST_CMD" ]; then
    # run_with_timeout (lib/test-runner.sh) bounds this even without
    # coreutils: a stock macOS host has neither timeout nor gtimeout, and
    # without an internal bound the suite ran fully unbounded, relying only
    # on the OUTER Stop-hook harness timeout to ever cut it off -- silently,
    # before this hook could report anything.
    GAUNTLET_TEST_TIMEOUT_SECONDS="${GAUNTLET_TEST_TIMEOUT_SECONDS:-90}"
    TEST_OUT=$(run_with_timeout "$GAUNTLET_TEST_TIMEOUT_SECONDS" "$TEST_CMD")
    TEST_RC=$?

    # Un timeout BLOQUEA. Antes solo imprimia y seguia, y como abajo se sale 0
    # cuando no falta ningun test, el turno se cerraba igual: "no se pudo
    # verificar" terminaba teniendo el mismo efecto practico que "verde", que es
    # justo lo que el comentario de arriba dice no querer.
    if [ "$TEST_RC" = 124 ]; then
      {
        echo "GAUNTLET: the suite did not finish in ${GAUNTLET_TEST_TIMEOUT_SECONDS}s. It could NOT be verified."
        echo ""
        echo "Do not close the turn calling it green. Either:"
        echo "  1. run the suite yourself and wait for it, or"
        echo "  2. narrow the run to the affected scope, or"
        echo "  3. fix what is hanging it (a test with no timeout, a real service, a busy port)."
        echo ""
        echo "Escape for this repo, if it is genuinely a slow suite: touch .claude-relaxed"
      } >&2
      exit 2
    elif [ "$TEST_RC" != 0 ]; then
      {
        echo "GAUNTLET: the suite is RED. Do not close the turn."
        echo ""
        echo "$TEST_OUT" | tail -30
        echo ""
        echo "DIAGNOSIS ORDER (rules/common/testing.md) — do not skip it:"
        echo "  1. The new code is wrong -> fix it. Do NOT touch the test."
        echo "  2. You broke a contract other code relied on -> adapt your implementation."
        echo "  3. The test is flaky (order, clock, stale mock) -> fix the flakiness,"
        echo "     NOT what it verifies."
        echo "  4. Only here: the test is wrong -> STOP and ask for authorization"
        echo "     stating which test, why, and what stays covered afterwards."
        echo ""
        echo "Never jump to 4 because it is the shortest path to green."
      } >&2
      exit 2
    fi
  fi
fi

[ -z "$MISSING" ] && exit 0

{
  echo "GAUNTLET: there is production code with no test."
  echo ""
  printf '%s' "$MISSING"
  echo ""
  echo "rules/common/testing.md: ALL code requires tests. No exceptions."
  echo "Write the test before closing the turn."
  echo ""
  echo "If it genuinely does not apply (spike, scratch, throwaway prototype),"
  echo "say so explicitly to the user and ask them to run: touch .claude-relaxed"
} >&2

exit 2
