#!/usr/bin/env bash
# sync-convergence-runtime.sh — instala sólo el gate de convergencia.
#
# Es deliberadamente más angosto que install.sh: no borra archivos runtime-only
# ni reemplaza toda la configuración de Claude. Por seguridad, la ejecución
# predeterminada es dry-run; cualquier escritura exige --apply explícito.
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(cd -- "$SOURCE_ROOT/../.." && pwd)
PARITY=${CLAUDE_PARITY_SCRIPT:-$REPO_ROOT/.github/test/check-runtime-parity.sh}
RUNTIME_ROOT=${CLAUDE_RUNTIME_DIR:-$HOME/.claude}
APPLY=false
STAMP=$(date +%Y%m%d%H%M%S)

case "${1:-}" in
  --apply) APPLY=true ;;
  ''|--dry-run) ;;
  -h|--help)
    cat <<'EOF'
Uso: sync-convergence-runtime.sh [--dry-run|--apply]

Audita o instala sólo los archivos/hooks críticos de convergencia en
CLAUDE_RUNTIME_DIR (por defecto ~/.claude). El modo predeterminado es dry-run.
--apply exige autorización explícita y crea backups antes de reemplazar
archivos existentes. No borra runtime-only ni sincroniza el resto de Claude.
EOF
    exit 0
    ;;
  *)
    printf '[sync] argumento desconocido: %s\n' "$1" >&2
    exit 2
    ;;
esac

command -v jq >/dev/null 2>&1 || {
  printf '[sync] jq es requerido.\n' >&2
  exit 2
}

FILES=(
  hooks/activate-convergence-on-apply.sh
  hooks/automatic-workflow.sh
  hooks/automatic-workflow-stop.sh
  hooks/secret-detect.sh
  hooks/convergence-stop.sh
  hooks/compact-resume.py
  hooks/lib/test-runner.sh
  hooks/lib/automatic-workflow-state.sh
  hooks/task-contract.sh
  scripts/convergence-start.sh
  scripts/validate-task-roadmap.py
  skills/automatic-task-orchestrator/SKILL.md
)
SOURCE_SETTINGS="$SOURCE_ROOT/settings.json"
RUNTIME_SETTINGS="$RUNTIME_ROOT/settings.json"
# Claude Code expande `~` al ejecutar el handler. Se conserva literal para que
# settings.json sea portable y no duplique el mismo hook con una ruta absoluta.
# shellcheck disable=SC2088
AUTOMATIC_USER_PROMPT_CMD='~/.claude/hooks/automatic-workflow.sh'
# shellcheck disable=SC2088
USER_PROMPT_CMD='~/.claude/hooks/activate-convergence-on-apply.sh'
# shellcheck disable=SC2088
AUTOMATIC_STOP_CMD='~/.claude/hooks/automatic-workflow-stop.sh'
# shellcheck disable=SC2088
STOP_CMD='~/.claude/hooks/convergence-stop.sh'

for relative in "${FILES[@]}"; do
  [ -f "$SOURCE_ROOT/$relative" ] || {
    printf '[sync] falta fuente: %s\n' "$relative" >&2
    exit 1
  }
  case "$relative" in
    *.sh|hooks/compact-resume.py)
      [ -x "$SOURCE_ROOT/$relative" ] || {
        printf '[sync] fuente no ejecutable: %s\n' "$relative" >&2
        exit 1
      }
      ;;
  esac
done
jq empty "$SOURCE_SETTINGS" >/dev/null 2>&1 || {
  printf '[sync] la fuente settings.json no es JSON válido.\n' >&2
  exit 1
}
if [ -f "$RUNTIME_SETTINGS" ]; then
  jq empty "$RUNTIME_SETTINGS" >/dev/null 2>&1 || {
    printf '[sync] el runtime settings.json no es JSON válido; no se modifica nada.\n' >&2
    exit 1
  }
fi
if [ "$APPLY" = true ]; then
  for relative in "${FILES[@]}"; do
    if [ -L "$RUNTIME_ROOT/$relative" ]; then
      printf '[sync] el target es symlink: %s; no se reemplaza automáticamente.\n' "$RUNTIME_ROOT/$relative" >&2
      exit 1
    fi
  done
  if [ -L "$RUNTIME_SETTINGS" ]; then
    printf '[sync] runtime settings.json es symlink; no se reemplaza automáticamente.\n' >&2
    exit 1
  fi
fi

backup() {
  local target="$1"
  [ -e "$target" ] || [ -L "$target" ] || return 0
  local backup_path="$target.backup.$STAMP"
  if [ "$APPLY" = true ]; then
    cp -p -- "$target" "$backup_path"
  else
    printf '  DRY BACKUP %s\n' "$backup_path"
  fi
}

copy_file() {
  local relative="$1" source="$SOURCE_ROOT/$1" target="$RUNTIME_ROOT/$1"
  if [ -f "$target" ] && cmp -s -- "$source" "$target"; then
    printf '  SAME %s\n' "$target"
    return 0
  fi
  if [ "$APPLY" = true ]; then
    mkdir -p -- "$(dirname -- "$target")"
    backup "$target"
    cp -p -- "$source" "$target"
    printf '  COPY %s\n' "$target"
  else
    printf '  DRY COPY %s -> %s\n' "$source" "$target"
  fi
}

merge_settings() {
  local temp filter
  if [ "$APPLY" = false ]; then
    printf '  DRY MERGE %s (preserva hooks existentes y agrega sólo convergencia)\n' "$RUNTIME_SETTINGS"
    return 0
  fi

  mkdir -p -- "$RUNTIME_ROOT"
  temp="$RUNTIME_SETTINGS.tmp.$$"
  filter='
    def without_commands($commands):
      map(
        .hooks = ((.hooks // []) | map(select((.command // "") as $command | ($commands | index($command) | not))))
      )
      | map(select((.hooks | length) > 0));

    .hooks = (.hooks // {})
    | .hooks.UserPromptSubmit = (.hooks.UserPromptSubmit // [])
    | .hooks.Stop = (.hooks.Stop // [])
    | .hooks.UserPromptSubmit = (
        .hooks.UserPromptSubmit
        | without_commands([$automatic_user_prompt, $automatic_user_prompt_absolute])
        + [{hooks: [{type: "command", command: $automatic_user_prompt, timeout: 10}]}]
      )
    | .hooks.UserPromptSubmit = (
        .hooks.UserPromptSubmit
        | without_commands([$user_prompt, $user_prompt_absolute])
        + [{hooks: [{type: "command", command: $user_prompt, timeout: 10}]}]
      )
    | .hooks.Stop = (
        .hooks.Stop
        | without_commands([$automatic_stop, $automatic_stop_absolute])
        + [{hooks: [{type: "command", command: $automatic_stop, timeout: 180}]}]
      )
    | .hooks.Stop = (
        .hooks.Stop
        | without_commands([$stop, $stop_absolute])
        + [{hooks: [{type: "command", command: $stop, timeout: 180}]}]
      )
  '
  if [ -f "$RUNTIME_SETTINGS" ]; then
    jq --arg automatic_user_prompt "$AUTOMATIC_USER_PROMPT_CMD" \
      --arg automatic_user_prompt_absolute "$HOME/.claude/hooks/automatic-workflow.sh" \
      --arg user_prompt "$USER_PROMPT_CMD" \
      --arg user_prompt_absolute "$HOME/.claude/hooks/activate-convergence-on-apply.sh" \
      --arg automatic_stop "$AUTOMATIC_STOP_CMD" \
      --arg automatic_stop_absolute "$HOME/.claude/hooks/automatic-workflow-stop.sh" \
      --arg stop "$STOP_CMD" \
      --arg stop_absolute "$HOME/.claude/hooks/convergence-stop.sh" "$filter" \
      "$RUNTIME_SETTINGS" 2>/dev/null >"$temp"
  else
    jq -n --arg automatic_user_prompt "$AUTOMATIC_USER_PROMPT_CMD" \
      --arg automatic_user_prompt_absolute "$HOME/.claude/hooks/automatic-workflow.sh" \
      --arg user_prompt "$USER_PROMPT_CMD" \
      --arg user_prompt_absolute "$HOME/.claude/hooks/activate-convergence-on-apply.sh" \
      --arg automatic_stop "$AUTOMATIC_STOP_CMD" \
      --arg automatic_stop_absolute "$HOME/.claude/hooks/automatic-workflow-stop.sh" \
      --arg stop "$STOP_CMD" \
      --arg stop_absolute "$HOME/.claude/hooks/convergence-stop.sh" "$filter" \
      >"$temp"
  fi || {
    [ -f "$temp" ] && rm -- "$temp"
    printf '[sync] no se pudo fusionar settings.json; no se reemplazó el archivo.\n' >&2
    exit 1
  }
  if [ -f "$RUNTIME_SETTINGS" ] && cmp -s "$temp" "$RUNTIME_SETTINGS"; then
    rm -- "$temp"
    printf '  SAME %s\n' "$RUNTIME_SETTINGS"
    return 0
  fi
  backup "$RUNTIME_SETTINGS"
  chmod -- "$(stat -f '%Lp' "$SOURCE_SETTINGS" 2>/dev/null || printf '600')" "$temp" 2>/dev/null || true
  mv -- "$temp" "$RUNTIME_SETTINGS"
  printf '  MERGE %s\n' "$RUNTIME_SETTINGS"
}

verify_runtime_minimal() {
  local failures=0 relative
  for relative in "${FILES[@]}"; do
    if [ ! -f "$RUNTIME_ROOT/$relative" ]; then
      printf '[sync] falta en runtime: %s\n' "$relative" >&2
      failures=$((failures + 1))
    elif [[ "$relative" == *.sh || "$relative" == hooks/compact-resume.py ]] \
      && [ ! -x "$RUNTIME_ROOT/$relative" ]; then
      printf '[sync] runtime no ejecutable: %s\n' "$relative" >&2
      failures=$((failures + 1))
    fi
  done

  if ! jq -e --arg automatic_user_prompt "$AUTOMATIC_USER_PROMPT_CMD" \
    --arg user_prompt "$USER_PROMPT_CMD" \
    --arg automatic_stop "$AUTOMATIC_STOP_CMD" \
    --arg stop "$STOP_CMD" '
      ([.hooks.UserPromptSubmit[]?.hooks[]?.command] | map(select(. == $automatic_user_prompt)) | length == 1)
      and ([.hooks.UserPromptSubmit[]?.hooks[]?.command] | map(select(. == $user_prompt)) | length == 1)
      and ([.hooks.Stop[]?.hooks[]?.command] | map(select(. == $automatic_stop)) | length == 1)
      and ([.hooks.Stop[]?.hooks[]?.command] | map(select(. == $stop)) | length == 1)
    ' "$RUNTIME_SETTINGS" >/dev/null; then
    printf '[sync] settings.json no contiene exactamente los hooks de convergencia esperados.\n' >&2
    failures=$((failures + 1))
  fi

  return "$failures"
}

printf 'source:  %s\nruntime: %s\nmode:    %s\n' \
  "$SOURCE_ROOT" "$RUNTIME_ROOT" "$([ "$APPLY" = true ] && printf apply || printf dry-run)"
for relative in "${FILES[@]}"; do
  copy_file "$relative"
done
merge_settings

if [ "$APPLY" = true ]; then
  if [ -f "$PARITY" ]; then
    CLAUDE_SOURCE_DIR="$SOURCE_ROOT" bash "$PARITY" --strict
  else
    printf '[sync] parity suite no disponible; ejecuto verificación mínima del runtime.\n'
    verify_runtime_minimal
  fi
else
  printf '[sync] dry-run: no se modificó ningún archivo.\n'
fi
