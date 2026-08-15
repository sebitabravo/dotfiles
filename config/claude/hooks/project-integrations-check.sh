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
  codegraph_mcp_detail="The CodeGraph server was not found in the global Claude configuration."
fi

codegraph_state="READY"
codegraph_detail=""
if [ -z "$CODEGRAPH_BIN" ] || [ ! -x "$CODEGRAPH_BIN" ]; then
  codegraph_state="CLI_MISSING"
  codegraph_detail="The codegraph CLI was not found in PATH."
else
  CODEGRAPH_STATUS=$("$CODEGRAPH_BIN" status --json "$CWD" 2>/dev/null || true)
  CODEGRAPH_INITIALIZED=$(printf '%s' "$CODEGRAPH_STATUS" | jq -r '.initialized // false' 2>/dev/null || printf 'false')
  CODEGRAPH_INDEX=$(printf '%s' "$CODEGRAPH_STATUS" | jq -r '.indexPath // empty' 2>/dev/null || true)
  if [ "$CODEGRAPH_INITIALIZED" != "true" ]; then
    codegraph_state="NOT_INITIALIZED"
    codegraph_detail="The project has no initialized CodeGraph index."
  elif [ -z "$CODEGRAPH_INDEX" ] || [ ! -d "$CODEGRAPH_INDEX" ]; then
    codegraph_state="BROKEN"
    codegraph_detail="CodeGraph reports it is initialized, but its index directory is missing."
  fi
fi

codegraph_gitignore_state="NOT_APPLICABLE"
codegraph_gitignore_detail=""
if git -C "$CWD" rev-parse --show-toplevel >/dev/null 2>&1; then
  CODEGRAPH_TRACKED_PATH=$(git -C "$CWD" ls-files -- .codegraph 2>/dev/null | head -n 1 || true)
  if [ -n "$CODEGRAPH_TRACKED_PATH" ]; then
    codegraph_gitignore_state="TRACKED_EXISTING"
    codegraph_gitignore_detail="CodeGraph was already versioned; that tracking is preserved and left unchanged."
  else
    CODEGRAPH_IGNORE_MATCH=$(git -C "$CWD" check-ignore -v -- .codegraph/ 2>/dev/null || true)
    CODEGRAPH_IGNORE_SOURCE=${CODEGRAPH_IGNORE_MATCH%%:*}
    if [ "$CODEGRAPH_IGNORE_SOURCE" = ".gitignore" ] || [ "$CODEGRAPH_IGNORE_SOURCE" = "$CWD/.gitignore" ]; then
      codegraph_gitignore_state="CONFIGURED"
    else
      codegraph_gitignore_state="NOT_CONFIGURED"
      codegraph_gitignore_detail="The project root does not ignore .codegraph/ in its .gitignore."
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
    openspec_gitignore_detail="OpenSpec was already versioned; that tracking is preserved and left unchanged."
  else
    OPENSPEC_IGNORE_MATCH=$(git -C "$CWD" check-ignore -v -- openspec/ 2>/dev/null || true)
    OPENSPEC_IGNORE_SOURCE=${OPENSPEC_IGNORE_MATCH%%:*}
    if [ "$OPENSPEC_IGNORE_SOURCE" = ".gitignore" ] || [ "$OPENSPEC_IGNORE_SOURCE" = "$CWD/.gitignore" ]; then
      openspec_gitignore_state="CONFIGURED"
    else
      openspec_gitignore_state="NOT_CONFIGURED"
      openspec_gitignore_detail="The project root does not ignore openspec/ in its .gitignore."
    fi
  fi
  if [ -z "$OPENSPEC_BIN" ] || [ ! -x "$OPENSPEC_BIN" ]; then
    openspec_state="CLI_MISSING"
    openspec_detail="The project uses OpenSpec, but the openspec CLI was not found in PATH."
  elif [ ! -d "$CWD/openspec/specs" ] || [ ! -d "$CWD/openspec/changes" ]; then
    openspec_state="NOT_INITIALIZED"
    openspec_detail="The openspec/specs + openspec/changes structure is missing."
  elif ! (cd "$CWD" && "$OPENSPEC_BIN" status --json >/dev/null 2>&1); then
    openspec_state="BROKEN"
    openspec_detail="OpenSpec is present, but openspec status --json does not pass."
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
PROJECT PREFLIGHT: project integrations are missing or incomplete in $CWD.

CodeGraph: $codegraph_state${codegraph_detail:+ — $codegraph_detail}
CodeGraph MCP: $codegraph_mcp_state${codegraph_mcp_detail:+ — $codegraph_mcp_detail}
CodeGraph .gitignore: $codegraph_gitignore_state${codegraph_gitignore_detail:+ — $codegraph_gitignore_detail}
OpenSpec: $openspec_state${openspec_detail:+ — $openspec_detail}
OpenSpec .gitignore: $openspec_gitignore_state${openspec_gitignore_detail:+ — $openspec_gitignore_detail}

Before exploring or modifying code, do not assume these integrations are available:
1. CodeGraph: if its MCP is missing, run \`codegraph install\`; then run \`codegraph init\` inside the project and verify with \`codegraph status --json\`.
2. Git: add ".codegraph/" to the project root ".gitignore" before continuing.
3. OpenSpec: install the CLI and run "openspec init" with explicit authorization; keep "openspec/" in ".gitignore" unless it was already tracked. Then verify with "openspec status --json".

Do not run those commands silently: they can create project files. Ask for authorization or report the blocker. Do not claim that CodeGraph MCP, the index, the ".codegraph/" exclusion, OpenSpec or the "openspec/" exclusion work until you have that evidence. Configuration/documentation questions may continue without editing code.
EOF
)

if command -v jq >/dev/null 2>&1; then
  jq -nc --arg event "$EVENT" --arg context "$MESSAGE" \
    '{hookSpecificOutput:{hookEventName:$event,additionalContext:$context}}'
else
  printf '%s\n' "$MESSAGE" >&2
fi

exit 0
