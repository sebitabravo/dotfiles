#!/usr/bin/env bash
# Valida esta configuracion: manifiestos JSON, dependencias de skills y linting
# de los scripts. Si ademas hay suites locales presentes, las corre.
#
# Este repo se clona para copiar la configuracion, no para desarrollarla: las
# suites `*.test.sh` no se versionan por defecto (ver .gitignore), asi que en
# un clone la mayoria de las etapas de suite simplemente no estan. Eso no es
# cobertura faltante, es una etapa que no aplica — pero se nombra igual,
# porque una etapa que no corrio nunca se reporta como una que paso.
# Excepcion: project-integrations-check.test.sh SI se versiona (negacion en
# .gitignore) porque tambien corre en CI via .github/test.sh; el resto sigue
# el criterio general.
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
  config/claude/agents/agent-preload.test.sh
  config/claude/agents/vulnerability-hunter.test.sh
  config/claude/statusline.test.sh
  config/claude/hooks/project-integrations-check.test.sh
  config/claude/hooks/privacy-review.test.sh
  config/claude/hooks/protect-codegraph-tracking.test.sh
  config/claude/hooks/secret-detect.test.sh
  config/claude/hooks/quality-gate.test.sh
  config/claude/hooks/validate-safe-ops.test.sh
  config/claude/hooks/gauntlet-stop.test.sh
  config/claude/hooks/protect-tests.test.sh
  config/claude/hooks/task-contract.test.sh
  config/claude/hooks/automatic-workflow.test.sh
  config/claude/hooks/automatic-workflow-stop.test.sh
  config/claude/hooks/convergence-stop.test.sh
  config/claude/hooks/activate-convergence-on-apply.test.sh
  config/claude/hooks/compact-resume.test.sh
  config/claude/scripts/validate-task-roadmap.test.sh
  config/claude/scripts/compare-task-roadmaps.test.sh
  config/claude/scripts/convergence-start.test.sh
  config/claude/scripts/check-runtime-parity.test.sh
  config/claude/scripts/check-provider-runtime-parity.test.sh
  config/claude/scripts/sync-convergence-runtime.test.sh
  config/claude/hooks/lib/test-runner.test.sh
  config/claude/scripts/test-swarmforge-workflow.sh
  git-hooks/commit-msg.test.sh
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
