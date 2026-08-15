#!/usr/bin/env bash
# SessionStart/UserPromptSubmit hook — verifies project-local CodeGraph and
# OpenSpec projects used by the SDD workflow.
#
# This hook is deliberately read-only. `codegraph init` creates project files,
# so the hook reports the exact remediation instead of silently mutating an
# arbitrary repository.
set -u

INPUT=$(cat 2>/dev/null || printf '%s' '{}')

if command -v jq >/dev/null 2>&1; then
  CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
  EVENT=$(printf '%s' "$INPUT" | jq -r '.hook_event_name // .hookEventName // empty' 2>/dev/null || true)
else
  CWD=""
  EVENT=""
fi

CWD="${PROJECT_ROOT:-${CWD:-${PWD:-}}}"
[ -d "$CWD" ] || exit 0

if [ -z "${PROJECT_ROOT:-}" ]; then
  PROJECT_ROOT_RESOLVED=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
  [ -n "$PROJECT_ROOT_RESOLVED" ] && CWD="$PROJECT_ROOT_RESOLVED"
fi

[ -d "$CWD" ] || exit 0

case "$EVENT" in
  SessionStart|UserPromptSubmit) ;;
  *) EVENT="UserPromptSubmit" ;;
esac

resolve_binary() {
  local override="$1"
  if [ -n "$override" ]; then
    printf '%s' "$override"
    return 0
  fi
  command -v "$2" 2>/dev/null || true
}

CODEGRAPH_BIN=$(resolve_binary "${CODEGRAPH_BIN:-}" codegraph)
OPENSPEC_BIN=$(resolve_binary "${OPENSPEC_BIN:-}" openspec)

codegraph_mcp_state="CONFIGURED"
codegraph_mcp_detail=""
MCP_CONFIG="${CLAUDE_CONFIG:-$HOME/.claude.json}"
if [ ! -f "$MCP_CONFIG" ] || ! jq -e '.mcpServers.codegraph.command // empty' "$MCP_CONFIG" >/dev/null 2>&1; then
  codegraph_mcp_state="NOT_CONFIGURED"
  codegraph_mcp_detail="No se encontró el servidor CodeGraph en la configuración global de Claude."
fi

codegraph_state="READY"
codegraph_detail=""
if [ -z "$CODEGRAPH_BIN" ] || [ ! -x "$CODEGRAPH_BIN" ]; then
  codegraph_state="CLI_MISSING"
  codegraph_detail="No se encontró el CLI codegraph en el PATH."
else
  CODEGRAPH_STATUS=$("$CODEGRAPH_BIN" status --json "$CWD" 2>/dev/null || true)
  CODEGRAPH_INITIALIZED=$(printf '%s' "$CODEGRAPH_STATUS" | jq -r '.initialized // false' 2>/dev/null || printf 'false')
  CODEGRAPH_INDEX=$(printf '%s' "$CODEGRAPH_STATUS" | jq -r '.indexPath // empty' 2>/dev/null || true)
  if [ "$CODEGRAPH_INITIALIZED" != "true" ]; then
    codegraph_state="NOT_INITIALIZED"
    codegraph_detail="El proyecto no tiene un índice CodeGraph inicializado."
  elif [ -z "$CODEGRAPH_INDEX" ] || [ ! -d "$CODEGRAPH_INDEX" ]; then
    codegraph_state="BROKEN"
    codegraph_detail="CodeGraph reporta inicialización, pero falta su directorio de índice."
  fi
fi

codegraph_gitignore_state="NOT_APPLICABLE"
codegraph_gitignore_detail=""
if git -C "$CWD" rev-parse --show-toplevel >/dev/null 2>&1; then
  CODEGRAPH_TRACKED_PATH=$(git -C "$CWD" ls-files -- .codegraph 2>/dev/null | head -n 1 || true)
  if [ -n "$CODEGRAPH_TRACKED_PATH" ]; then
    codegraph_gitignore_state="TRACKED_EXISTING"
    codegraph_gitignore_detail="CodeGraph ya estaba versionado; se conserva y no se cambia su tracking."
  else
    CODEGRAPH_IGNORE_MATCH=$(git -C "$CWD" check-ignore -v -- .codegraph/ 2>/dev/null || true)
    CODEGRAPH_IGNORE_SOURCE=${CODEGRAPH_IGNORE_MATCH%%:*}
    if [ "$CODEGRAPH_IGNORE_SOURCE" = ".gitignore" ] || [ "$CODEGRAPH_IGNORE_SOURCE" = "$CWD/.gitignore" ]; then
      codegraph_gitignore_state="CONFIGURED"
    else
      codegraph_gitignore_state="NOT_CONFIGURED"
      codegraph_gitignore_detail="La raíz del proyecto no ignora .codegraph/ en su .gitignore."
    fi
  fi
fi

# OpenSpec is local-only in this setup: do not add its AI planning artifacts to
# repositories unless they were already tracked. Once an openspec/ directory
# exists (or OPENSPEC_REQUIRED is enabled), validate it without initializing or
# installing anything automatically.
openspec_state="NOT_ENABLED"
openspec_detail=""
openspec_gitignore_state="NOT_APPLICABLE"
openspec_gitignore_detail=""
if [ -d "$CWD/openspec" ] || [ "${OPENSPEC_REQUIRED:-false}" = "true" ]; then
  OPENSPEC_TRACKED_PATH=$(git -C "$CWD" ls-files -- openspec 2>/dev/null | head -n 1 || true)
  if [ -n "$OPENSPEC_TRACKED_PATH" ]; then
    openspec_gitignore_state="TRACKED_EXISTING"
    openspec_gitignore_detail="OpenSpec ya estaba versionado; se conserva y no se cambia su tracking."
  else
    OPENSPEC_IGNORE_MATCH=$(git -C "$CWD" check-ignore -v -- openspec/ 2>/dev/null || true)
    OPENSPEC_IGNORE_SOURCE=${OPENSPEC_IGNORE_MATCH%%:*}
    if [ "$OPENSPEC_IGNORE_SOURCE" = ".gitignore" ] || [ "$OPENSPEC_IGNORE_SOURCE" = "$CWD/.gitignore" ]; then
      openspec_gitignore_state="CONFIGURED"
    else
      openspec_gitignore_state="NOT_CONFIGURED"
      openspec_gitignore_detail="La raíz del proyecto no ignora openspec/ en su .gitignore."
    fi
  fi
  if [ -z "$OPENSPEC_BIN" ] || [ ! -x "$OPENSPEC_BIN" ]; then
    openspec_state="CLI_MISSING"
    openspec_detail="El proyecto usa OpenSpec, pero no se encontró el CLI openspec en el PATH."
  elif [ ! -d "$CWD/openspec/specs" ] || [ ! -d "$CWD/openspec/changes" ]; then
    openspec_state="NOT_INITIALIZED"
    openspec_detail="Falta la estructura openspec/specs + openspec/changes."
  elif ! (cd "$CWD" && "$OPENSPEC_BIN" status --json >/dev/null 2>&1); then
    openspec_state="BROKEN"
    openspec_detail="OpenSpec está presente, pero openspec status --json no pasa."
  else
    openspec_state="READY"
  fi
fi

# Healthy projects produce no context noise on every prompt.
if [ "$codegraph_state" = "READY" ] && [ "$codegraph_mcp_state" = "CONFIGURED" ] &&
  { [ "$codegraph_gitignore_state" = "CONFIGURED" ] || [ "$codegraph_gitignore_state" = "TRACKED_EXISTING" ] || [ "$codegraph_gitignore_state" = "NOT_APPLICABLE" ]; } &&
  { [ "$openspec_state" = "READY" ] || [ "$openspec_state" = "NOT_ENABLED" ]; } &&
  { [ "$openspec_gitignore_state" = "CONFIGURED" ] || [ "$openspec_gitignore_state" = "TRACKED_EXISTING" ] || [ "$openspec_gitignore_state" = "NOT_APPLICABLE" ]; }; then
  exit 0
fi

MESSAGE=$(cat <<EOF
PROJECT PREFLIGHT: faltan o están incompletas integraciones del proyecto en $CWD.

CodeGraph: $codegraph_state${codegraph_detail:+ — $codegraph_detail}
CodeGraph MCP: $codegraph_mcp_state${codegraph_mcp_detail:+ — $codegraph_mcp_detail}
CodeGraph .gitignore: $codegraph_gitignore_state${codegraph_gitignore_detail:+ — $codegraph_gitignore_detail}
OpenSpec: $openspec_state${openspec_detail:+ — $openspec_detail}
OpenSpec .gitignore: $openspec_gitignore_state${openspec_gitignore_detail:+ — $openspec_gitignore_detail}

Antes de explorar o modificar código, no asumas que estas integraciones están disponibles:
1. CodeGraph: si falta su MCP, ejecutá \`codegraph install\`; luego ejecutá \`codegraph init\` dentro del proyecto y verificá con \`codegraph status --json\`.
2. Git: agregá ".codegraph/" al archivo ".gitignore" de la raíz del proyecto antes de continuar.
3. OpenSpec: instalá el CLI y ejecutá "openspec init" con autorización explícita; mantené "openspec/" en el ".gitignore" salvo que ya estuviera trackeado. Luego verificá "openspec status --json".

No ejecutes esos comandos silenciosamente: pueden crear archivos del proyecto. Pedí autorización o indicá el bloqueo. No afirmes que CodeGraph MCP, el índice, la exclusión de ".codegraph/", OpenSpec o la exclusión de "openspec/" funcionan hasta contar con esa evidencia. Las consultas de configuración/documentación pueden continuar sin editar código.
EOF
)

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg event "$EVENT" --arg context "$MESSAGE" \
    '{hookSpecificOutput:{hookEventName:$event,additionalContext:$context}}'
else
  printf '%s\n' "$MESSAGE" >&2
fi

exit 0
