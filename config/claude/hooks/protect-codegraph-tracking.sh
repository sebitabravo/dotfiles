#!/usr/bin/env bash
# PreToolUse(Bash) hook — protects newly-created AI planning artifacts.
# CodeGraph indexes and OpenSpec artifacts already tracked by a repository are
# preserved. New artifacts stay out of Git unless explicitly overridden.
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "[protect-codegraph-tracking] jq is not installed: blocking preventively; install it with: brew install jq" >&2
  exit 2
fi

INPUT=$(cat 2>/dev/null || printf '%s' '{}')
COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
CWD="${CWD:-${PWD:-}}"
[ -n "$COMMAND" ] || exit 0

# Explicit user override for a repository that intentionally wants to track a
# newly-created artifact. Normal agent workflows must not use this escape hatch.
printf '%s' "$COMMAND" | grep -qE '(^|[[:space:];|])(CODEGRAPH_TRACKING_OVERRIDE|AI_ARTIFACT_TRACKING_OVERRIDE)=1([[:space:];|]|$)' && exit 0

ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$ROOT" ] || exit 0

deny() {
  jq -nc --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

IS_COMMIT=false
printf '%s' "$COMMAND" | grep -qE '(^|[[:space:];|])git[[:space:]]+commit([[:space:];|]|$)' && IS_COMMIT=true
IS_ADD=false
printf '%s' "$COMMAND" | grep -qE '(^|[[:space:];|])git[[:space:]]+add([[:space:]]|$)' && IS_ADD=true

# A direct .gitignore update is allowed so the user/agent can repair
# protection. Any broad staging command remains blocked while a new artifact
# is unignored.
ONLY_GITIGNORE_ADD=false
printf '%s' "$COMMAND" | grep -qE 'git[[:space:]]+add([[:space:]]+--)?[[:space:]]+\.gitignore([[:space:]]*|[;&|])' && ONLY_GITIGNORE_ADD=true

for artifact in ".codegraph:CodeGraph" "openspec:OpenSpec"; do
  RELATIVE_PATH=${artifact%%:*}
  LABEL=${artifact#*:}
  TRACKED=$(git -C "$ROOT" ls-files -- "$RELATIVE_PATH" 2>/dev/null | head -n 1 || true)
  STAGED_ADD=$(git -C "$ROOT" diff --cached --diff-filter=A --name-only -- "$RELATIVE_PATH" 2>/dev/null | head -n 1 || true)

  # A staged addition is never committed by the agent unless the explicit
  # override is present. Existing tracked files are not affected.
  if [ -n "$STAGED_ADD" ] && [ "$IS_COMMIT" = true ]; then
    deny "Do not add to the commit a $LABEL artifact created in this session. If the repository already versioned it before, preserve that state; for an explicit exception use AI_ARTIFACT_TRACKING_OVERRIDE=1."
  fi

  # Existing tracked artifacts are preserved exactly as requested.
  [ -n "$TRACKED" ] && continue
  [ -e "$ROOT/$RELATIVE_PATH" ] || continue

  # Once the root .gitignore protects it, ordinary git add cannot stage it.
  git -C "$ROOT" check-ignore -q -- "$RELATIVE_PATH/" && continue

  if [ "$IS_ADD" = true ] && [ "$ONLY_GITIGNORE_ADD" = false ]; then
    deny "Do not stage $RELATIVE_PATH: it was created in this session and is not protected by the root .gitignore. Add $RELATIVE_PATH/ to .gitignore and only then use git add; only an explicit user instruction can change this rule."
  fi
done

exit 0
