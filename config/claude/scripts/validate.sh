#!/usr/bin/env bash
# Valida esta configuracion: manifiestos JSON, dependencias de skills y linting
# de los scripts. Si ademas hay suites presentes, las corre.
#
# Todas las suites viven en .github/test/, versionadas y corridas en CI via
# .github/test.sh -- ningun directorio administrado (config/claude/**, etc.)
# tiene sus propias suites, asi que install.sh no necesita excluirlas por
# convencion de nombre al copiar. Las entradas de esta lista que todavia no
# existen (protect-tests, agent-preload, vulnerability-hunter, test-runner,
# commit-msg, test-swarmforge-workflow) son el nombre esperado para cuando se
# escriban, no una suite que se perdio: se nombran igual para que una etapa
# que no corrio nunca se reporte como una que paso.
#
# Se pasa como argv al recibo de RDD: sin un script real la alternativa es una
# cadena con operadores de shell, y ahi un `|| true` fabrica el exit 0 que el
# recibo dice haber verificado.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CLAUDE_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd -- "$CLAUDE_DIR/../.." && pwd)
cd "$REPO_ROOT"

SUITES=(
  .github/test/agent-preload.test.sh
  .github/test/vulnerability-hunter.test.sh
  .github/test/statusline.test.sh
  .github/test/project-integrations-check.test.sh
  .github/test/privacy-review.test.sh
  .github/test/protect-codegraph-tracking.test.sh
  .github/test/secret-detect.test.sh
  .github/test/quality-gate.test.sh
  .github/test/validate-safe-ops.test.sh
  .github/test/gauntlet-stop.test.sh
  .github/test/protect-tests.test.sh
  .github/test/task-contract.test.sh
  .github/test/automatic-workflow.test.sh
  .github/test/automatic-workflow-stop.test.sh
  .github/test/convergence-stop.test.sh
  .github/test/activate-convergence-on-apply.test.sh
  .github/test/compact-resume.test.sh
  .github/test/validate-task-roadmap.test.sh
  .github/test/compare-task-roadmaps.test.sh
  .github/test/convergence-start.test.sh
  .github/test/check-runtime-parity.test.sh
  .github/test/check-provider-runtime-parity.test.sh
  .github/test/sync-convergence-runtime.test.sh
  .github/test/test-runner.test.sh
  .github/test/test-swarmforge-workflow.sh
  .github/test/commit-msg.test.sh
)

SKIPPED=0
for suite in "${SUITES[@]}"; do
  if [ ! -f "$suite" ]; then
    printf '== %s not present (local suite)\n' "$suite"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi
  printf '== %s\n' "$suite"
  bash "$suite" >/dev/null
done

printf '== JSON manifests\n'
jq empty "$CLAUDE_DIR/settings.json"
jq empty "$CLAUDE_DIR/skills-lock.json"

printf '== provider overlays\n'
for overlay in \
  deepseek.settings.json \
  glm.settings.json \
  kimi.settings.json \
  minimax.settings.json \
  ollama.settings.json \
  openrouter.settings.json \
  qwen.settings.json; do
  # Upper bound is a sanity check against typos (an extra digit), not a
  # policy cap: kimi.settings.json legitimately declares 1048576 (2^20),
  # Moonshot's real long-context window, since its very first commit. 2000000
  # leaves headroom for that and similar real values without disabling the
  # check.
  jq -e '
    (.apiKeyHelper | type == "string" and length > 0)
    and (.env.ANTHROPIC_BASE_URL | type == "string" and length > 0)
    and (.env.ANTHROPIC_DEFAULT_FABLE_MODEL | type == "string" and length > 0)
    and (.env.ANTHROPIC_DEFAULT_OPUS_MODEL | type == "string" and length > 0)
    and (.env.ANTHROPIC_DEFAULT_SONNET_MODEL | type == "string" and length > 0)
    and (.env.ANTHROPIC_DEFAULT_HAIKU_MODEL | type == "string" and length > 0)
    and ((.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW | tonumber) >= 100000)
    and ((.env.CLAUDE_CODE_AUTO_COMPACT_WINDOW | tonumber) <= 2000000)
  ' "$CLAUDE_DIR/$overlay" >/dev/null
done

printf '== skill dependencies\n'
bash "$CLAUDE_DIR/scripts/check-skill-deps.sh" >/dev/null

# La etapa de linting solo corre si el binario esta disponible: en un host sin
# el, callar seria reportar una cobertura que no existe.
# (El comentario no puede abrir con la palabra reservada de la directiva: se
# parsea como tal y rompe el parseo del archivo entero.)
if command -v shellcheck >/dev/null 2>&1; then
  # Los .sh del repo, excluyendo lo que vive dentro de skills de terceros.
  # Sin mapfile: bash 3.2 (el que trae macOS) no lo tiene.
  SCRIPTS=()
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while IFS= read -r script; do
      # `git ls-files` también devuelve archivos eliminados del working tree;
      # El analizador no puede abrirlos y una eliminación legítima convertía
      # toda la validación en falso rojo.
      [ -f "$script" ] && SCRIPTS+=("$script")
    done < <(
      {
        git ls-files '*.sh' ':!:config/claude/skills/*'
        git ls-files --others --exclude-standard '*.sh' ':!:config/claude/skills/*'
      } | sort -u
    )
  else
    # GitHub permite descargar el repo como ZIP. Ese árbol no tiene `.git`,
    # pero debe recibir el mismo lint en vez de declarar VALID con la etapa
    # vacía. El ZIP no contiene archivos ignorados, así que este fallback no
    # incorpora las suites locales ni artefactos del desarrollador.
    while IFS= read -r script; do
      [ -f "$script" ] && SCRIPTS+=("$script")
    done < <(
      find . -type f -name '*.sh' \
        -not -path './config/claude/skills/*' \
        -not -path './.git/*' \
        -print | sed 's#^\./##' | sort
    )
  fi

  # Bajo `set -u`, expandir un array vacío aborta en bash 3.2. Un árbol sin
  # scripts es una etapa sin cobertura y se informa explícitamente.
  if [ ${#SCRIPTS[@]} -eq 0 ]; then
    printf '== linting with no shell scripts found\n'
    SKIPPED=$((SKIPPED + 1))
  else
    printf '== linting\n'
    shellcheck -S warning "${SCRIPTS[@]}"
  fi
else
  printf '== linting unavailable (shellcheck absent)\n'
  SKIPPED=$((SKIPPED + 1))
fi

if [ "$SKIPPED" -gt 0 ]; then
  printf 'CONFIG VALID — %s stage(s) skipped, none failed\n' "$SKIPPED"
else
  printf 'ALL GREEN\n'
fi
