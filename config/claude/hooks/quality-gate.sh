#!/bin/bash
# quality-gate.sh — PreToolUse hook for git commit.
#
# El gauntlet de Uncle Bob, en la parte que se puede hacer cumplir por commit:
# lint, tests, cobertura por metrica (line/branch/function) y complejidad
# ciclomatica. Mutation testing NO va aca — es caro y su lugar es CI.
#
# Bloquea (exit 2) si: no hay test runner, falla el lint, fallan los tests, la
# cobertura esta bajo el piso, o hay funciones sobre el techo de complejidad.
#
# Kill switch por repo: `touch .claude-relaxed` degrada todos los bloqueos a
# aviso. Existe porque la alternativa a un escape explicito no es cumplimiento,
# es --no-verify.
#
# Lo que NO puede medir lo dice en voz alta en vez de callarlo: un gate que
# finge medir compra confianza falsa, que es peor que no tener gate.

# Read hook input (JSON on stdin)
# jq es obligatorio: sin el, este hook no puede ejecutar el gate de commit.
# Fallar cerrado evita que un commit escape sin la verificación requerida.
if ! command -v jq >/dev/null 2>&1; then
  echo "[quality-gate] jq is not installed: commit blocked; install it with: brew install jq" >&2
  exit 2
fi

input=$(cat)

# Extract tool_name and command
TOOL_NAME=$(echo "$input" | jq -r '.tool_name // ""')
COMMAND=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only act on Bash
[ "$TOOL_NAME" != "Bash" ] && exit 0

# Only act on git commit.
# El patron anterior ('git commit ' literal) exigia el espacio final y no veia
# 'git -C /ruta commit -m x', asi que el gate se saltaba entero.
#
# Se matchea sobre el comando SIN strings quoted, igual que validate-safe-ops.
# Sin eso, cualquier comando que mencione 'git commit' adentro de un string lo
# disparaba: `echo "git commit"`, un heredoc de documentacion, o un printf que
# arma el input de este mismo hook para testearlo. El resultado era un bloqueo
# de commit sobre un comando que no commitea nada.
# El mensaje real de un commit tambien queda fuera, que es lo que se busca:
# `git commit -m "fix: git commit docs"` colapsa a `git commit -m ` y sigue
# matcheando por el binario, no por el texto del mensaje.
NO_QUOTES=$(echo "$COMMAND" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

echo "$NO_QUOTES" | grep -qE '\bgit\b([[:space:]]+-{1,2}[^[:space:]]+([[:space:]]+[^[:space:]-][^[:space:]]*)?)*[[:space:]]+commit\b' || exit 0

# --amend NO se exceptua: seria un bypass de una sola flag para cualquier commit
# que el gate acabara de bloquear. La excepcion de merge se resuelve mas abajo,
# donde ya se sabe a que repo apunta el comando.

# Detect project root and test runner.
#
# El repo a evaluar es al que apunta EL COMANDO, no el cwd de este hook. Con
# worktrees no son el mismo: `cd /otro/worktree && git commit` se evaluaba con
# el estado del worktree de la sesion — mal repo, mal test runner, y el kill
# switch `.claude-relaxed` leido del lado equivocado. Corta en ambos sentidos:
# bloquea commits validos y deja pasar los que deberia frenar.
#
# Se resuelve del comando en el mismo orden en que bash lo aplicaria: primero
# un `cd <path>` inicial, despues `git -C <path>`, que gana porque git lo
# aplica sobre el cwd ya cambiado.
TARGET_DIR=$(echo "$input" | jq -r '.cwd // ""')
[ -n "$TARGET_DIR" ] || TARGET_DIR="$PWD"

CD_PATH=$(echo "$COMMAND" | sed -nE "s/^[[:space:]]*cd[[:space:]]+('([^']*)'|\"([^\"]*)\"|([^[:space:]&;|]+)).*/\2\3\4/p")
[ -n "$CD_PATH" ] && case "$CD_PATH" in
  /*) TARGET_DIR="$CD_PATH" ;;
  ~*) TARGET_DIR="${CD_PATH/#\~/$HOME}" ;;
  *) TARGET_DIR="$TARGET_DIR/$CD_PATH" ;;
esac

# El sed de BSD (macOS) no entiende \b, asi que el limite de palabra se escribe
# a mano. Sin eso el patron no matcheaba nunca y `git -C` caia al cwd.
GIT_C_PATH=$(echo "$COMMAND" | sed -nE "s/.*(^|[^[:alnum:]_])git[[:space:]]+-C[[:space:]]+('([^']*)'|\"([^\"]*)\"|([^[:space:]&;|]+)).*/\3\4\5/p")
[ -n "$GIT_C_PATH" ] && case "$GIT_C_PATH" in
  /*) TARGET_DIR="$GIT_C_PATH" ;;
  ~*) TARGET_DIR="${GIT_C_PATH/#\~/$HOME}" ;;
  *) TARGET_DIR="$TARGET_DIR/$GIT_C_PATH" ;;
esac

ROOT=$(git -C "$TARGET_DIR" rev-parse --show-toplevel 2>/dev/null || echo "$TARGET_DIR")
cd "$ROOT" 2>/dev/null || exit 0

# Merge commit en curso: git mantiene MERGE_HEAD entre el merge y el commit que
# lo cierra. Es la unica señal confiable, y hay que leerla del repo — por eso
# esta aca y no junto al resto del parseo del comando.
#
# Antes se miraba el texto: `grep -qE '(--merge|-m\s+"merge)'`. Fallaba en los
# dos sentidos. `git commit` no tiene flag `--merge`, y un merge real se cierra
# con `git commit` sin `-m`, asi que el caso a eximir nunca matcheaba; mientras
# tanto cualquier `git commit -m "merge ..."` saltaba el gate entero, que es el
# bypass de una palabra que el comentario de arriba dice no querer.
if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
  echo "[quality-gate] merge in progress (MERGE_HEAD): the merge commit does not go through the gate." >&2
  exit 0
fi

# Kill switch por repo. Mismo patron que RDD y por la misma razon: un guardarrail
# que nadie puede desactivar termina esquivado por caminos peores (--no-verify,
# escrituras por Bash, o directamente no commitear). Un scratch repo o un spike
# no tiene por que pelearse con los pisos de cobertura.
RELAX_FILE=".claude-relaxed"
RELAXED=false
[ -f "$ROOT/$RELAX_FILE" ] && RELAXED=true

# El modo de permisos NO relaja este gate, a proposito.
#
# Antes si lo hacia, cuando un modo permisivo era algo que se elegia a mano para
# una sesion puntual. Con un `defaultMode` fijo, degradar por modo dejaria el
# gauntlet inerte de forma permanente en vez de puntual.
#
# La distincion que importa: un modo de permisos gobierna PROMPTS — preguntas
# sobre si tenes derecho a hacer algo. Un gate de calidad no pregunta eso; dice
# que el codigo todavia no esta listo. Son cosas distintas y no deberian
# compartir interruptor. Los `ask` de validate-safe-ops si dependen del modo,
# porque esos si son prompts.
#
# Para relajar este gate esta `.claude-relaxed`, que es una decision explicita
# por repo y no un efecto lateral del modo de permisos.

# Pisos. Los mismos que declara CLAUDE.md; viven aca para que el numero que
# bloquea y el numero que esta escrito no puedan divergir en silencio.
MIN_LINE=80
MIN_BRANCH=70
MIN_FUNC=90
MAX_COMPLEXITY=10

# Function to block commit with message.
# El segundo argumento es la salida real del comando que fallo. Sin ella el
# agente recibia "lint failed, run X" y tenia que volver a correrlo para ver
# QUE fallo: un turno entero perdido por cada bloqueo. Se recortan las ultimas
# 40 lineas porque el error util de un runner vive al final, no al principio.
block() {
  local msg="$1" output="${2:-}"

  # Un solo punto de degradacion. Antes lint y tests llamaban a exit 2 directo
  # y se saltaban el chequeo de RELAXED que si hacian coverage y complejidad:
  # el kill switch relajaba la mitad del gate y la otra mitad seguia frenando,
  # sin que nada lo dijera.
  if [ "$RELAXED" = true ]; then
    echo "[quality-gate] WARNING (not blocking, $RELAX_FILE): $msg" >&2
    [ -n "$output" ] && echo "$output" | tail -20 >&2
    return 0
  fi

  echo "[quality-gate] COMMIT BLOCKED: $msg" >&2
  if [ -n "$output" ]; then
    echo "[quality-gate] --- command output (last 40 lines) ---" >&2
    echo "$output" | tail -40 >&2
    echo "[quality-gate] --- end of output ---" >&2
  fi
  echo "[quality-gate] Fix the issue and retry. Do NOT use --no-verify." >&2
  exit 2
}

RDD="$HOME/.claude/scripts/rdd.sh"

# Auto-encendido de RDD por zona de riesgo.
#
# POR QUE: RDD funcionaba, pero encenderlo dependia de que el usuario se
# acordara de correr `rdd on` en el repo correcto. Un guardarrail que hay que
# recordar activar no se activa nunca — el resto del flujo (freeze/receipt) ya
# no depende de la memoria de nadie porque el bloqueo del gate lo fuerza.
#
# Se mira el PATH, no el contenido: es predecible y explicable. Un falso
# positivo cuesta dos comandos que igual corre el agente; un falso negativo
# deja pasar sin recibo justo el commit que mas lo necesitaba.
if [ -x "$RDD" ] && [ ! -f "$ROOT/.claude-rdd/enabled" ] && [ "$RELAXED" = false ]; then
  RISKY=$(git diff --cached --name-only 2>/dev/null |
    grep -iE '(auth|login|session|token|jwt|oauth|passwd|password|credential)|(pay|billing|checkout|stripe|invoice|refund|charge)|(migration|migrate|schema|seed)|(crypt|secret|signing|sanitiz)' |
    grep -vE '\.(md|txt|rst|adoc|lock|svg|png|jpe?g)$' || true)

  if [ -n "$RISKY" ]; then
    bash "$RDD" on >/dev/null 2>&1 || true
    {
      echo "[quality-gate] RDD TURNED ON AUTOMATICALLY in this repo."
      echo "[quality-gate] The diff touches a risk zone:"
      printf '%s\n' "$RISKY" | sed 's/^/[quality-gate]   - /'
      echo "[quality-gate] From now on this repo requires a receipt to commit."
      echo "[quality-gate] Turn it off with 'rdd off' if this was a false positive."
    } >&2
  fi
fi

# RDD — Receipt Driven Development.
# Si el repo lo tiene encendido, un commit necesita un recibo atado al hash de
# los bytes staged. La opinion del agente ("esto funciona") no autoriza nada;
# el recibo si, porque deja de valer solo apenas el contenido cambia.
# Apagado (default): no bloquea nada, ni siquiera avisa.
if [ -x "$RDD" ] && [ -f "$ROOT/.claude-rdd/enabled" ]; then
  bash "$RDD" verify
  RDD_RC=$?
  RDD_MSG=""
  case $RDD_RC in
    1) RDD_MSG="RDD is on and there is no receipt.
[quality-gate]   1) rdd freeze          freezes the staged bytes
[quality-gate]   2) review those bytes
[quality-gate]   3) rdd receipt '<test cmd>'
[quality-gate] Turn it off with 'rdd off' if this repo does not need it." ;;
    2) RDD_MSG="the receipt is for OTHER bytes. The code changed after the review.
[quality-gate] Freeze again and review once more. 'rdd status' shows the detail." ;;
  esac
  # Via block() y no exit 2 directo, para que el kill switch y el modo autonomo
  # lo degraden igual que al resto del gate.
  [ -n "$RDD_MSG" ] && block "$RDD_MSG"
fi


# Detect test runner and lint.
#
# Primero se prueba en la raiz del repo (comportamiento historico, intacto
# para proyectos de un solo paquete: dir="." no antepone ningun "cd", los
# comandos y mensajes quedan byte-a-byte iguales a como eran antes).
#
# Si la raiz no tiene marcador de proyecto es probable que sea un monorepo
# (ej. backend/ con pyproject.toml + landing/ con package.json, cada uno con
# su propio runner). Se buscan subdirectorios de primer nivel que el commit
# este tocando (STAGED_DIRS) y que ademas tengan marcador de proyecto, para no
# correr la suite de un paquete que el commit ni toco.
# QUIEN DECIDE COMO SE CORREN LOS TESTS: lib/test-runner.sh, no este archivo.
#
# La lib centraliza la precedencia: primero respeta un runner explicito del repo
# (por ejemplo `test.sh` en un dotfiles), luego Make/Just y finalmente los
# manifiestos detectables por convencion. Esta funcion no debe duplicar esa
# decision ni imponer una herramienta de build que el proyecto no necesita.
QG_LIB="$(dirname "${BASH_SOURCE[0]}")/lib/test-runner.sh"
# shellcheck source=lib/test-runner.sh
[ -f "$QG_LIB" ] && . "$QG_LIB"

detect_project_at() {
  # Setea HAS_TESTS/TEST_CMD/LINT_CMD/COVERAGE_CMD/COVERAGE_KIND para el
  # directorio $1 (relativo a ROOT, "." para la raiz). No cambia el cwd del
  # script: los comandos generados llevan su propio "cd" cuando dir != ".".
  local dir="$1" prefix=""
  [ "$dir" != "." ] && prefix="cd \"$dir\" && "

  HAS_TESTS=false
  TEST_CMD=""
  LINT_CMD=""
  COVERAGE_CMD=""
  COVERAGE_KIND=""
  COVERAGE_EXTRA=false

  # La lib manda para TEST_CMD. Los bloques por manifiesto de mas abajo siguen
  # corriendo, pero ya solo para COVERAGE_CMD y LINT_CMD, que la lib no cubre.
  #
  # DECLARED bloquea el reemplazo por COVERAGE_CMD. Sin esto, un repo con
  # `test.sh` propio y un `package.json` con vitest terminaba corriendo
  # `npm test -- --coverage` en vez del runner que el repo escribio: el gate
  # decia respetar la decision del proyecto y ejecutaba otra cosa. Se pierde la
  # medicion de cobertura, y eso se reporta como NO MEDIDO mas abajo — que es la
  # respuesta honesta, no correr un comando que el repo no eligio.
  local declared=false
  if declare -f detect_test_cmd >/dev/null 2>&1; then
    local lib_root="$dir"
    [ "$dir" = "." ] && lib_root="$PWD"
    if detect_test_cmd "$lib_root" && [ -n "$TEST_CMD" ]; then
      HAS_TESTS=true
      [ "${TEST_CMD_SOURCE:-}" = declared ] && declared=true
    else
      TEST_CMD=""
    fi
  fi

  if [ -f "$dir/package.json" ]; then
    # JS/TS project.
    # HAS_TESTS se marca junto con TEST_CMD: antes se marcaba true y el TEST_CMD
    # quedaba vacio si el runner no era vitest/jest (ej. "test": "node --test"),
    # asi que el gate no corria nada y dejaba pasar el commit como si fuera verde.
    if jq -e '.scripts.test' "$dir/package.json" >/dev/null 2>&1; then
      if [ "$HAS_TESTS" = false ]; then
        HAS_TESTS=true
        TEST_CMD="${prefix}npm test"
      fi
      # --coverage.reporter=text fuerza la tabla de istanbul aunque el proyecto
      # tenga configurado otro reporter (lcov/html no traen porcentajes al stdout,
      # y sin ellos el parseo de abajo no ve nada y el piso no se aplica).
      if jq -r '.scripts.test' "$dir/package.json" | grep -qE 'vitest|jest'; then
        COVERAGE_CMD="${prefix}npm test -- --coverage --coverage.reporter=text"
        COVERAGE_KIND="istanbul"
      fi
    fi
    if jq -e '.scripts.lint' "$dir/package.json" >/dev/null 2>&1; then
      LINT_CMD="${prefix}npm run lint"
    elif command -v eslint >/dev/null 2>&1 && { [ -f "$dir/.eslintrc.js" ] || [ -f "$dir/.eslintrc.json" ] || [ -f "$dir/.eslintrc.yml" ] || [ -f "$dir/eslint.config.js" ] || [ -f "$dir/eslint.config.mjs" ]; }; then
      LINT_CMD="${prefix}npx eslint . --max-warnings=0"
    fi
  elif [ -f "$dir/pyproject.toml" ] || [ -f "$dir/setup.cfg" ] || [ -f "$dir/pytest.ini" ]; then
    # Python project
    if command -v uv >/dev/null 2>&1 && [ -f "$dir/pyproject.toml" ]; then
      if [ "$HAS_TESTS" = false ]; then
        HAS_TESTS=true
        TEST_CMD="${prefix}uv run pytest"
      fi
      # --cov-branch: sin el, pytest-cov no reporta branch coverage y el piso de
      # 70% declarado en CLAUDE.md no se puede evaluar.
      COVERAGE_CMD="${prefix}uv run pytest --cov --cov-branch --cov-report=term-missing"
      COVERAGE_KIND="pycov"
    fi
  elif [ -f "$dir/go.mod" ]; then
    # Go project
    if [ "$HAS_TESTS" = false ]; then
      HAS_TESTS=true
      TEST_CMD="${prefix}go test ./..."
    fi
    COVERAGE_CMD="${prefix}go test -cover ./..."
    COVERAGE_KIND="gocov"
    if command -v golangci-lint >/dev/null 2>&1; then
      LINT_CMD="${prefix}golangci-lint run"
    fi
  fi

  # Un runner declarado NO se reemplaza por la variante con flag de cobertura,
  # pero tampoco cancela la medicion: se corren los dos. Un solo punto de
  # decision y despues de los bloques por manifiesto, porque cada uno arma su
  # COVERAGE_CMD sin saber de los otros y repetir la condicion es como se
  # desincronizan.
  COVERAGE_EXTRA=false
  [ "$declared" = true ] && [ -n "$COVERAGE_CMD" ] && COVERAGE_EXTRA=true
}

STAGED_FILES_FOR_DETECT=$(git diff --cached --name-only 2>/dev/null)
STAGED_DIRS_FOR_DETECT=$(printf '%s\n' "$STAGED_FILES_FOR_DETECT" | awk -F/ '{print $1}' | sort -u)

# Documentacion y config estatica no requieren tests per
# rules/common/testing.md ("What does NOT require tests").
#
# Whitelist CERRADA: si TODOS los archivos staged caen en la lista, no hay
# codigo que probar y el gate de tests no aplica. Lo que NO esta en la lista
# sigue pasando por el gate — una extension desconocida no abre un hueco
# silencioso, al reves: bloquea como siempre.
#
# NO se listan .sh ni .py aunque vivan en .github/scripts (los scripts
# requieren tests), ni Dockerfile/Makefile (afectan comportamiento).
is_docs_or_config() {
  local f="$1"
  local base="${f##*/}"

  # PRIMERO la lista negra, porque las reglas de abajo la taparian: un
  # package.json matchea *.json y un Cargo.lock matchea *.lock.
  #
  # Manifiestos y lockfiles NO son config estatica: son el arbol de
  # dependencias, o sea el comportamiento. Un bump de version no toca una
  # linea de codigo propio y rompe la build igual — es exactamente el commit
  # donde la suite tiene que correr, no el que hay que eximir.
  case "$base" in
    package.json | package-lock.json | npm-shrinkwrap.json) return 1 ;;
    bun.lock | bun.lockb | pnpm-lock.yaml | yarn.lock) return 1 ;;
    pyproject.toml | poetry.lock | uv.lock | requirements.txt | Pipfile | Pipfile.lock) return 1 ;;
    Cargo.toml | Cargo.lock | go.mod | go.sum) return 1 ;;
    composer.json | composer.lock | Gemfile | Gemfile.lock) return 1 ;;
    # tsconfig cambia como compila el proyecto; jest/vitest/eslint definen que
    # y como se verifica. Eximirlos deja que se relaje el propio gate sin que
    # nada lo note.
    tsconfig*.json | jest.config.* | vitest.config.* | .eslintrc*) return 1 ;;
  esac

  # Se compara el basename, no la ruta: sin esto `sub/.gitignore` y
  # `pkg/LICENSE` no matcheaban y un commit de solo-docs quedaba bloqueado por
  # vivir en un subdirectorio.
  case "$base" in
    # Documentacion
    *.md | *.txt | *.rst | *.adoc) return 0 ;;
    # Config estatica, CI y lockfiles
    *.yml | *.yaml | *.json | *.toml | *.ini | *.cfg | *.conf | *.lock | *.lockb) return 0 ;;
    # Assets y datos
    *.svg | *.png | *.jpg | *.jpeg | *.webp | *.gif | *.ico | *.woff | *.woff2 | *.ttf | *.otf | *.eot | *.pdf | *.csv) return 0 ;;
    # Dotfiles de config
    .gitignore | .gitattributes | .editorconfig | .dockerignore | .prettierrc | .prettierignore | .nvmrc | .tool-versions | .python-version | .env.example | .env.sample) return 0 ;;
    # Archivos de convencion sin extension
    LICENSE | LICENSE.* | CODEOWNERS | NOTICE | AUTHORS | CONTRIBUTING | CHANGELOG) return 0 ;;
  esac
  return 1
}

if [ -n "$STAGED_FILES_FOR_DETECT" ]; then
  ALL_NON_CODE=true
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    is_docs_or_config "$f" || { ALL_NON_CODE=false; break; }
  done <<< "$STAGED_FILES_FOR_DETECT"
  if [ "$ALL_NON_CODE" = true ]; then
    echo "[quality-gate] Commit with no code (docs/config/assets) — no test gate." >&2
    exit 0
  fi
fi

detect_project_at "."
PROJECT_DIRS=(".")
if [ "$HAS_TESTS" = false ] && [ -z "$LINT_CMD" ]; then
  MONO_DIRS=()
  while IFS= read -r d; do
    [ -z "$d" ] && continue
    [ -d "$d" ] || continue
    if [ -f "$d/package.json" ] || [ -f "$d/pyproject.toml" ] || [ -f "$d/setup.cfg" ] || [ -f "$d/pytest.ini" ] || [ -f "$d/go.mod" ]; then
      MONO_DIRS+=("$d")
    fi
  done <<< "$STAGED_DIRS_FOR_DETECT"
  [ "${#MONO_DIRS[@]}" -gt 0 ] && PROJECT_DIRS=("${MONO_DIRS[@]}")
fi

# run_with_timeout (lib/test-runner.sh) bounds every eval'd command below:
# a stock macOS host has neither timeout nor gtimeout, and Claude Code's
# own docs confirm a timed-out command hook is fail-open (does not block
# the tool call) -- without an internal bound, a hanging lint/test/coverage
# command was relying entirely on the outer harness timeout to ever stop
# it, which meant the commit could go through unchecked instead of blocked.
QG_LINT_TIMEOUT_SECONDS="${QG_LINT_TIMEOUT_SECONDS:-20}"
QG_TEST_TIMEOUT_SECONDS="${QG_TEST_TIMEOUT_SECONDS:-90}"
QG_COVERAGE_TIMEOUT_SECONDS="${QG_COVERAGE_TIMEOUT_SECONDS:-30}"

# These three per-stage ceilings (140s) already sit under settings.json's
# 150s outer PreToolUse timeout for ONE project. A monorepo commit can walk
# several PROJECT_DIRS in the same run, and each used to get its own full
# 140s -- two projects could already run past the outer timeout, handing
# control back to the exact fail-open harness behavior run_with_timeout
# exists to avoid. QG_TOTAL_TIMEOUT_SECONDS is a budget shared across every
# PROJECT_DIR in this run: each stage gets min(its own ceiling, whatever is
# left of the shared budget), and $SECONDS (seconds since this script
# started) is what measures how much has been spent so far.
QG_TOTAL_TIMEOUT_SECONDS="${QG_TOTAL_TIMEOUT_SECONDS:-140}"

budget_remaining() {
  local left=$((QG_TOTAL_TIMEOUT_SECONDS - SECONDS))
  [ "$left" -lt 0 ] && left=0
  printf '%s' "$left"
}

cap_to_budget() {
  local ceiling="$1" left
  left=$(budget_remaining)
  if [ "$left" -lt "$ceiling" ]; then printf '%s' "$left"; else printf '%s' "$ceiling"; fi
}

for PROJECT_DIR in "${PROJECT_DIRS[@]}"; do
  detect_project_at "$PROJECT_DIR"
  LABEL="$PROJECT_DIR"
  [ "$LABEL" = "." ] && LABEL="raiz"

  # Sin test runner NO se pasa.
  #
  # Antes esto avisaba y salia 0, con lo cual el gate castigaba tener tests rotos
  # y premiaba no tener tests: exactamente al reves de lo que la regla pide. El
  # stderr decia "ALL code requires tests. No exceptions" y a la linea siguiente
  # dejaba commitear igual, o sea era un cartel, no una puerta.
  if [ "$HAS_TESTS" = false ]; then
    if [ "$RELAXED" = true ]; then
      echo "[quality-gate] [$LABEL] no test runner; $RELAX_FILE present, letting it through." >&2
      continue
    fi
    block "[$LABEL] there is no test runner in this project and ALL code requires tests (rules/common/testing.md).
[quality-gate] Configure one BEFORE writing production code. If this repo is a scratch
[quality-gate] or a spike, create the kill switch: touch $RELAX_FILE"
  fi

  # 1. Lint (if available)
  if [ -n "$LINT_CMD" ]; then
    if [ "$(budget_remaining)" -eq 0 ]; then
      block "[$LABEL] the shared ${QG_TOTAL_TIMEOUT_SECONDS}s quality-gate budget ran out before lint could run (a monorepo commit walks several PROJECT_DIRS sharing one budget, so their sum never outlives the outer hook timeout). Increase QG_TOTAL_TIMEOUT_SECONDS or check fewer projects per commit."
    fi
    LINT_BOUND=$(cap_to_budget "$QG_LINT_TIMEOUT_SECONDS")
    # eval y no $LINT_CMD a secas: sin eval, el "cd dir &&" de los proyectos de
    # subdirectorio llega como argumentos literales en vez de ejecutarse.
    LINT_OUTPUT=$(run_with_timeout "$LINT_BOUND" "$LINT_CMD")
    LINT_RC=$?
    if [ "$LINT_RC" = 124 ]; then
      block "[$LABEL] lint did not finish in ${LINT_BOUND}s. It could NOT be verified. Run: $LINT_CMD" "$LINT_OUTPUT"
    elif [ "$LINT_RC" != 0 ]; then
      block "[$LABEL] lint failed. Run: $LINT_CMD" "$LINT_OUTPUT"
    fi
  fi

  # 2. Tests + coverage, UNA sola corrida.
  # Antes corria TEST_CMD y despues COVERAGE_CMD, que re-ejecuta la misma suite
  # entera: dos corridas completas en cada intento de commit.
  # COVERAGE_CMD es TEST_CMD con un flag, asi que si existe reemplaza a TEST_CMD
  # y de la misma salida se saca el porcentaje.
  #
  # Excepcion: si el repo declaro su runner (test.sh, target de make/just) ese
  # es el que dictamina si los tests pasan — no se cambia por una variante
  # nuestra. La cobertura se mide igual, en una segunda corrida, porque dejar de
  # medirla para respetar al runner seria pagar el respeto con una metrica menos.
  RUN_CMD="${COVERAGE_CMD:-$TEST_CMD}"
  [ "${COVERAGE_EXTRA:-false}" = true ] && RUN_CMD="$TEST_CMD"
  TEST_OUTPUT=""
  if [ -n "$RUN_CMD" ]; then
    if [ "$(budget_remaining)" -eq 0 ]; then
      block "[$LABEL] the shared ${QG_TOTAL_TIMEOUT_SECONDS}s quality-gate budget ran out before tests could run (a monorepo commit walks several PROJECT_DIRS sharing one budget, so their sum never outlives the outer hook timeout). Increase QG_TOTAL_TIMEOUT_SECONDS or check fewer projects per commit."
    fi
    TEST_BOUND=$(cap_to_budget "$QG_TEST_TIMEOUT_SECONDS")
    TEST_OUTPUT=$(run_with_timeout "$TEST_BOUND" "$RUN_CMD")
    TEST_RC=$?
    if [ "$TEST_RC" = 124 ]; then
      block "[$LABEL] tests did not finish in ${TEST_BOUND}s. It could NOT be verified. Run: $RUN_CMD" "$TEST_OUTPUT"
    elif [ "$TEST_RC" != 0 ]; then
      block "[$LABEL] tests failed. Run: $RUN_CMD" "$TEST_OUTPUT"
    fi
  fi

  # La segunda corrida es solo para leer los porcentajes. Si falla (o se
  # cuelga) no vuelve a dictaminar sobre los tests (de eso ya se encargo el
  # runner declarado), pero tampoco se calla: sin salida no hay metrica, y eso
  # se reporta como NO MEDIDO.
  if [ "${COVERAGE_EXTRA:-false}" = true ]; then
    if [ "$(budget_remaining)" -eq 0 ]; then
      block "[$LABEL] the shared ${QG_TOTAL_TIMEOUT_SECONDS}s quality-gate budget ran out before coverage could run (a monorepo commit walks several PROJECT_DIRS sharing one budget, so their sum never outlives the outer hook timeout). Increase QG_TOTAL_TIMEOUT_SECONDS or check fewer projects per commit."
    fi
    COVERAGE_BOUND=$(cap_to_budget "$QG_COVERAGE_TIMEOUT_SECONDS")
    COV_RUN_OUTPUT=$(run_with_timeout "$COVERAGE_BOUND" "$COVERAGE_CMD")
    COV_RC=$?
    # Un fallo comun del comando de cobertura no dictamina sobre los tests (ya
    # lo hizo el runner declarado): se degrada a NO MEDIDO. Un timeout es
    # distinto -- significa que el proceso siguio vivo mas alla del bound
    # interno, exactamente el escenario fail-open que run_with_timeout existe
    # para cerrar en lint/test. Tragarlo aqui con el mismo `|| true` reabria
    # esa brecha solo para la cobertura.
    if [ "$COV_RC" = 124 ]; then
      block "[$LABEL] coverage did not finish in ${COVERAGE_BOUND}s. It could NOT be verified. Run: $COVERAGE_CMD" "$COV_RUN_OUTPUT"
    fi
    if [ -n "$COV_RUN_OUTPUT" ]; then
      TEST_OUTPUT="$COV_RUN_OUTPUT"
    else
      echo "[quality-gate] [$LABEL] coverage command produced no output: $COVERAGE_CMD" >&2
    fi
  fi

  # 3. Coverage — bloqueante, por metrica.
  #
  # La version anterior hacia `grep -oE '[0-9]+%' | head -1`: agarraba el PRIMER
  # porcentaje del output, que con suerte era line coverage y podia ser cualquier
  # otro numero. Branch y function no se miraban nunca, asi que dos de los tres
  # pisos declarados en CLAUDE.md no existian.
  #
  # Cuando una metrica no se puede medir se dice, en vez de darla por buena: un
  # gate que finge medir es peor que no tener gate, porque compra confianza falsa.
  if [ -n "$COVERAGE_CMD" ]; then
    COVERAGE_OUTPUT="$TEST_OUTPUT"
    COV_LINE=""; COV_BRANCH=""; COV_FUNC=""

    case "${COVERAGE_KIND:-}" in
      istanbul)
        # Tabla de istanbul (vitest/jest):
        #   File      | % Stmts | % Branch | % Funcs | % Lines |
        #   All files |   85.71 |    72.22 |   90.00 |   85.71 |
        ALL_FILES=$(echo "$COVERAGE_OUTPUT" | grep -E '^[[:space:]]*All files' | head -1)
        if [ -n "$ALL_FILES" ]; then
          COV_BRANCH=$(echo "$ALL_FILES" | awk -F'|' '{gsub(/ /,"",$3); print $3}')
          COV_FUNC=$(echo "$ALL_FILES" | awk -F'|' '{gsub(/ /,"",$4); print $4}')
          COV_LINE=$(echo "$ALL_FILES" | awk -F'|' '{gsub(/ /,"",$5); print $5}')
        fi
        ;;
      pycov)
        # pytest-cov: la fila TOTAL trae line coverage. Branch solo aparece con
        # --cov-branch, que se agrega al comando mas arriba.
        COV_LINE=$(echo "$COVERAGE_OUTPUT" | grep -E '^TOTAL' | grep -oE '[0-9]+(\.[0-9]+)?%' | tail -1 | tr -d '%')
        ;;
      gocov)
        # go test -cover: "coverage: 87.5% of statements", una linea por paquete.
        # Se toma la menor: el paquete peor cubierto es el que manda.
        COV_LINE=$(echo "$COVERAGE_OUTPUT" | grep -oE 'coverage: [0-9]+(\.[0-9]+)?%' |
          grep -oE '[0-9]+(\.[0-9]+)?' | sort -n | head -1)
        ;;
    esac

    below() { [ -n "$1" ] && awk -v p="$1" -v m="$2" 'BEGIN { exit !(p < m) }'; }

    COV_FAIL=""
    below "$COV_LINE" "$MIN_LINE" && COV_FAIL="${COV_FAIL}  line ${COV_LINE}% < ${MIN_LINE}%"$'\n'
    below "$COV_BRANCH" "$MIN_BRANCH" && COV_FAIL="${COV_FAIL}  branch ${COV_BRANCH}% < ${MIN_BRANCH}%"$'\n'
    below "$COV_FUNC" "$MIN_FUNC" && COV_FAIL="${COV_FAIL}  function ${COV_FUNC}% < ${MIN_FUNC}%"$'\n'

    if [ -n "$COV_FAIL" ]; then
      if [ "$RELAXED" = true ]; then
        printf '[quality-gate] [%s] coverage below the floor (%s present, not blocking):\n%s' "$LABEL" "$RELAX_FILE" "$COV_FAIL" >&2
      else
        block "[$LABEL] coverage below the floor:
${COV_FAIL}[quality-gate] Add tests. Kill switch for this repo: touch $RELAX_FILE"
      fi
    fi

    # Metricas que el runner no reporto. Se avisa para que no se lean como verdes.
    UNMEASURED=""
    [ -z "$COV_LINE" ] && UNMEASURED="$UNMEASURED line"
    [ -z "$COV_BRANCH" ] && UNMEASURED="$UNMEASURED branch"
    [ -z "$COV_FUNC" ] && UNMEASURED="$UNMEASURED function"
    [ -n "$UNMEASURED" ] &&
      echo "[quality-gate] [$LABEL] NOT MEASURED (the runner does not report it):$UNMEASURED — do not count it as green." >&2

  fi

  # 4. Complejidad ciclomatica.
  #
  # CLAUDE.md declara un techo de 10 por funcion y hasta ahora NADA lo medía: era
  # la unica de las cuatro metricas sin ningun mecanismo detras. Se usa la
  # herramienta del lenguaje si esta instalada; si no esta, se dice, en vez de
  # dejar pasar el commit como si el techo se hubiera verificado.
  COMPLEXITY_OUTPUT=""
  COMPLEXITY_OVER=""
  if [ -f "$PROJECT_DIR/go.mod" ] && command -v gocyclo >/dev/null 2>&1; then
    COMPLEXITY_OUTPUT=$(cd "$PROJECT_DIR" && gocyclo -over "$MAX_COMPLEXITY" . 2>/dev/null || true)
    [ -n "$COMPLEXITY_OUTPUT" ] && COMPLEXITY_OVER=yes
  elif { [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/setup.cfg" ]; } && command -v radon >/dev/null 2>&1; then
    # radon cc -n C marca bloques con complejidad >= 11, que es justo el techo + 1.
    COMPLEXITY_OUTPUT=$(cd "$PROJECT_DIR" && radon cc -n C -s . 2>/dev/null || true)
    [ -n "$COMPLEXITY_OUTPUT" ] && COMPLEXITY_OVER=yes
  elif [ -f "$PROJECT_DIR/package.json" ] && [ -n "$LINT_CMD" ]; then
    # En JS/TS la regla `complexity` de eslint es el camino: si el proyecto ya la
    # tiene configurada, el lint de arriba ya fallo por ella y no hay nada que
    # duplicar aca. Si no la tiene, se avisa una vez.
    if ! (cd "$PROJECT_DIR" && rg -q 'complexity' .eslintrc* eslint.config.* 2>/dev/null); then
      echo "[quality-gate] [$LABEL] NOT MEASURED: cyclomatic complexity. Add the eslint rule:" >&2
      echo "[quality-gate]   'complexity': ['error', { max: $MAX_COMPLEXITY }]" >&2
    fi
  fi

  if [ -n "$COMPLEXITY_OVER" ]; then
    if [ "$RELAXED" = true ]; then
      echo "[quality-gate] [$LABEL] complexity over $MAX_COMPLEXITY ($RELAX_FILE present, not blocking)." >&2
    else
      block "[$LABEL] there are functions with cyclomatic complexity > $MAX_COMPLEXITY. Extract methods." "$COMPLEXITY_OUTPUT"
    fi
  fi
done

# 5. Scope creep detection
# Warn if a single commit touches files in 4+ unrelated top-level directories.
STAGED_DIRS=$(git diff --cached --name-only 2>/dev/null | awk -F/ '{print $1}' | sort -u)
DIR_COUNT=$(echo "$STAGED_DIRS" | grep -c . 2>/dev/null || echo "0")
if [ "$DIR_COUNT" -gt 3 ] 2>/dev/null; then
  echo "[quality-gate] WARNING: commit touches ${DIR_COUNT} top-level directories: $(echo "$STAGED_DIRS" | tr '\n' ' ')" >&2
  echo "[quality-gate] Consider splitting into smaller, scoped commits (see rules/common/git-workflow.md)." >&2
fi

# All good
exit 0
