#!/usr/bin/env bash
# Valida esta configuracion: suites, manifiestos JSON, dependencias de skills y
# linting de los scripts. Una etapa faltante bloquea: nunca se reporta cobertura
# parcial como una validacion verde.
#
# Todas las suites viven en .github/test/, versionadas y corridas en CI via
# .github/test.sh -- ningun directorio administrado (config/claude/**, etc.)
# tiene sus propias suites, asi que install.sh no necesita excluirlas por
# convencion de nombre al copiar. Esta lista contiene sólo suites implementadas;
# una prueba futura se agrega recién cuando su archivo existe.
#
# Se pasa como argv al recibo de RDD: sin un script real la alternativa es una
# cadena con operadores de shell, y ahi un `|| true` fabrica el exit 0 que el
# recibo dice haber verificado.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TEST_DIR="$SCRIPT_DIR/test"
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
CLAUDE_DIR="$REPO_ROOT/config/claude"
cd "$REPO_ROOT"

if ! command -v shellcheck >/dev/null 2>&1; then
  printf 'VALIDATION BLOCKED: shellcheck is required; no lint coverage was run.\n' >&2
  exit 2
fi

if [ -e "$CLAUDE_DIR/scripts/validate.sh" ]; then
  printf 'ERROR: test-only tool remains under config/claude/scripts: validate.sh\n' >&2
  exit 1
fi

# Estas herramientas prueban o auditan el repositorio; no son capacidades que
# Claude deba cargar desde ~/.claude. Mantener la lista explícita evita que una
# futura suite vuelva a contaminar el árbol de runtime por accidente.
TEST_ONLY_SCRIPTS=(
  check-provider-runtime-parity.sh
  check-runtime-parity.sh
  check-skill-deps.sh
  compare-task-roadmaps.sh
  doctor.sh
  smoke-automatic-workflow.sh
  smoke-claude-hook-engine.sh
)
for script in "${TEST_ONLY_SCRIPTS[@]}"; do
  if [ -e "$CLAUDE_DIR/scripts/$script" ]; then
    printf 'ERROR: test-only tool remains under config/claude/scripts: %s\n' "$script" >&2
    exit 1
  fi
  if [ ! -f "$TEST_DIR/$script" ]; then
    printf 'ERROR: expected test-only tool is missing from .github/test: %s\n' "$script" >&2
    exit 1
  fi
done
leftover_suite=$(find "$CLAUDE_DIR" -type f -name '*.test.sh' -print -quit)
if [ -n "$leftover_suite" ]; then
  printf 'ERROR: repository test suite remains under config/claude: %s\n' "$leftover_suite" >&2
  exit 1
fi

SUITES=(
  .github/test/validate-contract.test.sh
  .github/test/statusline.test.sh
  .github/test/project-integrations-check.test.sh
  .github/test/privacy-review.test.sh
  .github/test/protect-codegraph-tracking.test.sh
  .github/test/secret-detect.test.sh
  .github/test/quality-gate.test.sh
  .github/test/validate-safe-ops.test.sh
  .github/test/gauntlet-stop.test.sh
  .github/test/task-contract.test.sh
  .github/test/automatic-workflow.test.sh
  .github/test/automatic-workflow-stop.test.sh
  .github/test/convergence-stop.test.sh
  .github/test/activate-convergence-on-apply.test.sh
  .github/test/compact-resume.test.sh
  .github/test/validate-task-roadmap.test.sh
  .github/test/compare-task-roadmaps.test.sh
  .github/test/doctor.test.sh
  .github/test/convergence-start.test.sh
  .github/test/check-runtime-parity.test.sh
  .github/test/check-provider-runtime-parity.test.sh
  .github/test/sync-convergence-runtime.test.sh
  .github/test/test-runner.test.sh
  .github/test/hooks-edge-cases.test.sh
  .github/test/herdr-autostart.test.sh
)

for suite in "${SUITES[@]}"; do
  if [ ! -f "$suite" ]; then
    printf 'VALIDATION BLOCKED: required suite is missing: %s\n' "$suite" >&2
    exit 2
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
  ollama.settings.json \
  openrouter.settings.json; do
  # Upper bound is a sanity check against typos (an extra digit), not a
  # policy cap. 2000000 leaves headroom for real long-context values without
  # disabling the check.
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
bash "$TEST_DIR/check-skill-deps.sh" >/dev/null

# Lint de todos los .sh del repo, excluyendo lo que vive dentro de skills de
# terceros. Sin mapfile: bash 3.2 (el que trae macOS) no lo tiene.
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
  # pero debe recibir el mismo lint. El ZIP no contiene archivos ignorados,
  # así que este fallback no incorpora artefactos del desarrollador.
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
# scripts no tiene cobertura y bloquea la validación.
if [ ${#SCRIPTS[@]} -eq 0 ]; then
  printf 'VALIDATION BLOCKED: no shell scripts found; no lint coverage was run.\n' >&2
  exit 2
fi
printf '== linting\n'
shellcheck -S warning "${SCRIPTS[@]}"

printf 'ALL GREEN — %s suite(s), manifests and lint passed\n' "${#SUITES[@]}"
