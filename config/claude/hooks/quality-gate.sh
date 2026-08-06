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
# jq es obligatorio: sin el, este hook no puede leer el input y falla ABIERTO.
# Se avisa fuerte en vez de morir en silencio, porque un hook mudo parece un
# hook que aprueba. Instalar: brew install jq / apt install jq.
if ! command -v jq >/dev/null 2>&1; then
  echo "[quality-gate] jq no esta instalado: el gate de lint/tests NO corre antes del commit. Instalalo con: brew install jq" >&2
  exit 0
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

# Skip merge commits. --amend NO se exceptua: era un bypass de una sola flag
# para cualquier commit que el gate acabara de bloquear.
echo "$COMMAND" | grep -qE '(--merge|-m\s+"merge)' && exit 0

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

# Kill switch por repo. Mismo patron que RDD y por la misma razon: un guardarrail
# que nadie puede desactivar termina esquivado por caminos peores (--no-verify,
# escrituras por Bash, o directamente no commitear). Un scratch repo o un spike
# no tiene por que pelearse con los pisos de cobertura.
RELAX_FILE=".claude-relaxed"
RELAXED=false
[ -f "$ROOT/$RELAX_FILE" ] && RELAXED=true

# El modo de permisos NO relaja este gate, a proposito.
#
# Antes si lo hacia, cuando bypassPermissions era algo que se elegia a mano para
# una sesion puntual. Ahora `defaultMode` es bypassPermissions de forma
# permanente, asi que degradar por modo dejaba el gauntlet inerte para siempre.
#
# La distincion que importa: bypass elimina PROMPTS DE PERMISO — preguntas sobre
# si tenes derecho a hacer algo. Un gate de calidad no pregunta eso; dice que el
# codigo todavia no esta listo. Son cosas distintas y no deberian compartir
# interruptor. Los `ask` de validate-safe-ops si degradan en bypass, porque esos
# si son prompts.
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
    echo "[quality-gate] AVISO (no bloquea, $RELAX_FILE): $msg" >&2
    [ -n "$output" ] && echo "$output" | tail -20 >&2
    return 0
  fi

  echo "[quality-gate] COMMIT BLOCKED: $msg" >&2
  if [ -n "$output" ]; then
    echo "[quality-gate] --- salida del comando (ultimas 40 lineas) ---" >&2
    echo "$output" | tail -40 >&2
    echo "[quality-gate] --- fin de la salida ---" >&2
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
      echo "[quality-gate] RDD ENCENDIDO AUTOMATICAMENTE en este repo."
      echo "[quality-gate] El diff toca zona de riesgo:"
      printf '%s\n' "$RISKY" | sed 's/^/[quality-gate]   - /'
      echo "[quality-gate] Desde ahora este repo exige recibo para commitear."
      echo "[quality-gate] Apagalo con 'rdd off' si fue un falso positivo."
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
    1) RDD_MSG="RDD encendido y no hay recibo.
[quality-gate]   1) rdd freeze          congela los bytes staged
[quality-gate]   2) revisa sobre ellos
[quality-gate]   3) rdd receipt '<cmd de tests>'
[quality-gate] Apagalo con 'rdd off' si este repo no lo necesita." ;;
    2) RDD_MSG="el recibo es de OTROS bytes. El codigo cambio despues del review.
[quality-gate] Volve a congelar y revisa de nuevo. 'rdd status' muestra el detalle." ;;
  esac
  # Via block() y no exit 2 directo, para que el kill switch y el modo autonomo
  # lo degraden igual que al resto del gate.
  [ -n "$RDD_MSG" ] && block "$RDD_MSG"
fi


# Detect test runner and lint
HAS_TESTS=false
TEST_CMD=""
LINT_CMD=""
COVERAGE_CMD=""
COVERAGE_KIND=""

if [ -f "package.json" ]; then
  # JS/TS project.
  # HAS_TESTS se marca junto con TEST_CMD: antes se marcaba true y el TEST_CMD
  # quedaba vacio si el runner no era vitest/jest (ej. "test": "node --test"),
  # asi que el gate no corria nada y dejaba pasar el commit como si fuera verde.
  if jq -e '.scripts.test' package.json >/dev/null 2>&1; then
    HAS_TESTS=true
    TEST_CMD="npm test"
    # --coverage.reporter=text fuerza la tabla de istanbul aunque el proyecto
    # tenga configurado otro reporter (lcov/html no traen porcentajes al stdout,
    # y sin ellos el parseo de abajo no ve nada y el piso no se aplica).
    if jq -r '.scripts.test' package.json | grep -qE 'vitest|jest'; then
      COVERAGE_CMD="npm test -- --coverage --coverage.reporter=text"
      COVERAGE_KIND="istanbul"
    fi
  fi
  if jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
    LINT_CMD="npm run lint"
  elif command -v eslint >/dev/null 2>&1 && { [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; }; then
    LINT_CMD="npx eslint . --max-warnings=0"
  fi
elif [ -f "pyproject.toml" ] || [ -f "setup.cfg" ] || [ -f "pytest.ini" ]; then
  # Python project
  if command -v uv >/dev/null 2>&1 && [ -f "pyproject.toml" ]; then
    HAS_TESTS=true
    TEST_CMD="uv run pytest"
    # --cov-branch: sin el, pytest-cov no reporta branch coverage y el piso de
    # 70% declarado en CLAUDE.md no se puede evaluar.
    COVERAGE_CMD="uv run pytest --cov --cov-branch --cov-report=term-missing"
    COVERAGE_KIND="pycov"
  fi
elif [ -f "go.mod" ]; then
  # Go project
  HAS_TESTS=true
  TEST_CMD="go test ./..."
  COVERAGE_CMD="go test -cover ./..."
  COVERAGE_KIND="gocov"
  if command -v golangci-lint >/dev/null 2>&1; then
    LINT_CMD="golangci-lint run"
  fi
fi

# Sin test runner NO se pasa.
#
# Antes esto avisaba y salia 0, con lo cual el gate castigaba tener tests rotos
# y premiaba no tener tests: exactamente al reves de lo que la regla pide. El
# stderr decia "ALL code requires tests. No exceptions" y a la linea siguiente
# dejaba commitear igual, o sea era un cartel, no una puerta.
if [ "$HAS_TESTS" = false ]; then
  if [ "$RELAXED" = true ]; then
    echo "[quality-gate] sin test runner; $RELAX_FILE presente, se deja pasar." >&2
    exit 0
  fi
  block "no hay test runner en este proyecto y ALL code requires tests (rules/common/testing.md).
[quality-gate] Configura uno ANTES de escribir codigo de produccion. Si este repo es un scratch
[quality-gate] o un spike, creá el kill switch: touch $RELAX_FILE"
fi

# 1. Lint (if available)
if [ -n "$LINT_CMD" ]; then
  LINT_OUTPUT=$($LINT_CMD 2>&1) || block "lint failed. Run: $LINT_CMD" "$LINT_OUTPUT"
fi

# 2. Tests + coverage, UNA sola corrida.
# Antes corria TEST_CMD y despues COVERAGE_CMD, que re-ejecuta la misma suite
# entera: dos corridas completas en cada intento de commit, con timeout de 120s.
# COVERAGE_CMD es TEST_CMD con un flag, asi que si existe reemplaza a TEST_CMD
# y de la misma salida se saca el porcentaje.
RUN_CMD="${COVERAGE_CMD:-$TEST_CMD}"
TEST_OUTPUT=""
if [ -n "$RUN_CMD" ]; then
  # eval y no $RUN_CMD a secas: sin eval, redirecciones y operadores del string
  # llegaban a npm como argumentos literales y la medicion nunca corria.
  TEST_OUTPUT=$(eval "$RUN_CMD" 2>&1) || block "tests failed. Run: $RUN_CMD" "$TEST_OUTPUT"
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
      printf '[quality-gate] cobertura bajo el piso (%s presente, no bloquea):\n%s' "$RELAX_FILE" "$COV_FAIL" >&2
    else
      block "cobertura bajo el piso:
${COV_FAIL}[quality-gate] Agrega tests. Kill switch para este repo: touch $RELAX_FILE"
    fi
  fi

  # Metricas que el runner no reporto. Se avisa para que no se lean como verdes.
  UNMEASURED=""
  [ -z "$COV_LINE" ] && UNMEASURED="$UNMEASURED line"
  [ -z "$COV_BRANCH" ] && UNMEASURED="$UNMEASURED branch"
  [ -z "$COV_FUNC" ] && UNMEASURED="$UNMEASURED function"
  [ -n "$UNMEASURED" ] &&
    echo "[quality-gate] NO MEDIDO (el runner no lo reporta):$UNMEASURED — no lo cuentes como verde." >&2

fi

# 4. Complejidad ciclomatica.
#
# CLAUDE.md declara un techo de 10 por funcion y hasta ahora NADA lo medía: era
# la unica de las cuatro metricas sin ningun mecanismo detras. Se usa la
# herramienta del lenguaje si esta instalada; si no esta, se dice, en vez de
# dejar pasar el commit como si el techo se hubiera verificado.
COMPLEXITY_OUTPUT=""
COMPLEXITY_OVER=""
if [ -f "go.mod" ] && command -v gocyclo >/dev/null 2>&1; then
  COMPLEXITY_OUTPUT=$(gocyclo -over "$MAX_COMPLEXITY" . 2>/dev/null || true)
  [ -n "$COMPLEXITY_OUTPUT" ] && COMPLEXITY_OVER=yes
elif { [ -f "pyproject.toml" ] || [ -f "setup.cfg" ]; } && command -v radon >/dev/null 2>&1; then
  # radon cc -n C marca bloques con complejidad >= 11, que es justo el techo + 1.
  COMPLEXITY_OUTPUT=$(radon cc -n C -s . 2>/dev/null || true)
  [ -n "$COMPLEXITY_OUTPUT" ] && COMPLEXITY_OVER=yes
elif [ -f "package.json" ] && [ -n "$LINT_CMD" ]; then
  # En JS/TS la regla `complexity` de eslint es el camino: si el proyecto ya la
  # tiene configurada, el lint de arriba ya fallo por ella y no hay nada que
  # duplicar aca. Si no la tiene, se avisa una vez.
  if ! rg -q 'complexity' .eslintrc* eslint.config.* 2>/dev/null; then
    echo "[quality-gate] NO MEDIDO: complejidad ciclomatica. Agrega la regla eslint:" >&2
    echo "[quality-gate]   'complexity': ['error', { max: $MAX_COMPLEXITY }]" >&2
  fi
fi

if [ -n "$COMPLEXITY_OVER" ]; then
  if [ "$RELAXED" = true ]; then
    echo "[quality-gate] complejidad sobre $MAX_COMPLEXITY ($RELAX_FILE presente, no bloquea)." >&2
  else
    block "hay funciones con complejidad ciclomatica > $MAX_COMPLEXITY. Extrae metodos." "$COMPLEXITY_OUTPUT"
  fi
fi

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
