#!/usr/bin/env bash
# Punto de entrada unico de verificacion del repo.
#
# Existe porque RDD exige una evidencia pasada como argv: sin un script real,
# la unica alternativa es una cadena con operadores de shell, y ahi un `|| true`
# puede fabricar el exit 0 que el recibo dice haber verificado.
set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
cd "$REPO_ROOT"

SUITES=(
  config/claude/statusline.test.sh
  config/claude/hooks/project-integrations-check.test.sh
  config/claude/hooks/protect-codegraph-tracking.test.sh
  config/claude/hooks/quality-gate.test.sh
  config/claude/hooks/validate-safe-ops.test.sh
  config/claude/hooks/lib/test-runner.test.sh
  config/claude/scripts/test-swarmforge-workflow.sh
)

# Las suites no se versionan (ver .gitignore): en un clone limpio no existen.
# Se reporta cada ausencia en vez de saltarla en silencio, porque una etapa que
# no corrio no es una etapa que paso.
MISSING=0
for suite in "${SUITES[@]}"; do
  if [ ! -f "$suite" ]; then
    printf '== %s AUSENTE (etapa omitida)\n' "$suite"
    MISSING=$((MISSING + 1))
    continue
  fi
  printf '== %s\n' "$suite"
  bash "$suite" >/dev/null
done

printf '== manifiestos JSON\n'
jq empty config/claude/settings.json
jq empty config/claude/skills-lock.json

printf '== dependencias de skills\n'
bash config/claude/scripts/check-skill-deps.sh >/dev/null

# La etapa de linting solo corre si el binario esta disponible: en un host sin
# el, callar seria reportar una cobertura que no existe.
# (El comentario no puede abrir con la palabra reservada de la directiva: se
# parsea como tal y rompe el parseo del archivo entero.)
if command -v shellcheck >/dev/null 2>&1; then
  # Los .sh del repo, excluyendo lo que vive dentro de skills de terceros.
  # Sin mapfile: bash 3.2 (el que trae macOS) no lo tiene.
  SCRIPTS=()
  while IFS= read -r script; do
    SCRIPTS+=("$script")
  done < <(git ls-files '*.sh' ':!:config/claude/skills/*' 2>/dev/null)

  # Bajo `set -u`, expandir un array vacio aborta en bash 3.2. Pasa cuando el
  # arbol no es un repo git: ahi la lista no es "cero scripts que pasan", es
  # una etapa que no se pudo armar.
  if [ ${#SCRIPTS[@]} -eq 0 ]; then
    printf '== linting SIN LISTA DE ARCHIVOS (etapa omitida)\n'
    MISSING=$((MISSING + 1))
  else
    printf '== linting\n'
    shellcheck -S warning "${SCRIPTS[@]}"
  fi
else
  printf '== linting NO DISPONIBLE (etapa omitida)\n'
  MISSING=$((MISSING + 1))
fi

if [ "$MISSING" -gt 0 ]; then
  printf 'VERDE PARCIAL — %s suite(s) ausente(s), cobertura incompleta\n' "$MISSING"
else
  printf 'TODO VERDE\n'
fi
