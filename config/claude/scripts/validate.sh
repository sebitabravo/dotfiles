#!/usr/bin/env bash
# Valida esta configuracion: manifiestos JSON, dependencias de skills y linting
# de los scripts. Si ademas hay suites locales presentes, las corre.
#
# Este repo se clona para copiar la configuracion, no para desarrollarla: las
# suites `*.test.sh` no se versionan (ver .gitignore), asi que en un clone las
# etapas de suite simplemente no estan. Eso no es cobertura faltante, es una
# etapa que no aplica — pero se nombra igual, porque una etapa que no corrio
# nunca se reporta como una que paso.
#
# Se pasa como argv al recibo de RDD: sin un script real la alternativa es una
# cadena con operadores de shell, y ahi un `|| true` fabrica el exit 0 que el
# recibo dice haber verificado.
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

SKIPPED=0
for suite in "${SUITES[@]}"; do
  if [ ! -f "$suite" ]; then
    printf '== %s no presente (suite local)\n' "$suite"
    SKIPPED=$((SKIPPED + 1))
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
    printf '== linting sin lista de archivos (fuera de un repo git)\n'
    SKIPPED=$((SKIPPED + 1))
  else
    printf '== linting\n'
    shellcheck -S warning "${SCRIPTS[@]}"
  fi
else
  printf '== linting no disponible (shellcheck ausente)\n'
  SKIPPED=$((SKIPPED + 1))
fi

if [ "$SKIPPED" -gt 0 ]; then
  printf 'CONFIG VALIDA — %s etapa(s) omitida(s), ninguna fallo\n' "$SKIPPED"
else
  printf 'TODO VERDE\n'
fi
