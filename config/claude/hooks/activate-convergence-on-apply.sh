#!/usr/bin/env bash
# UserPromptSubmit hook — activa convergencia automáticamente al iniciar
# `/opsx:apply <change>`, sin tocar instalación, OpenSpec ni .gitignore.
set -u

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

INPUT=$(cat 2>/dev/null || printf '%s' '{}')
PROMPT=$(printf '%s' "$INPUT" | jq -r '.prompt // empty' 2>/dev/null || true)
case "$PROMPT" in
  /opsx:apply|'/opsx:apply '*) ;;
  *) exit 0 ;;
esac

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -d "$CWD" ] || exit 0
ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$ROOT" ] || exit 0
[ -d "$ROOT/openspec" ] || exit 0
command -v openspec >/dev/null 2>&1 || exit 0

# El segundo token es el change opcional. Si no viene, auto-seleccionamos sólo
# cuando hay exactamente uno; con varios dejamos que OPSX pida selección.
CHANGE=$(printf '%s\n' "$PROMPT" | awk '{print $2}')
if [ -z "$CHANGE" ]; then
  LIST_JSON=$(cd "$ROOT" && openspec list --json 2>/dev/null || true)
  COUNT=$(printf '%s' "$LIST_JSON" | jq -r '.changes | length' 2>/dev/null || printf '0')
  [ "$COUNT" = 1 ] || exit 0
  CHANGE=$(printf '%s' "$LIST_JSON" | jq -r '.changes[0].name // .changes[0].id // empty' 2>/dev/null || true)
fi

case "$CHANGE" in
  ''|*[!a-zA-Z0-9._-]*|.|..) exit 0 ;;
esac

START="${CLAUDE_CONVERGENCE_START:-$HOME/.claude/scripts/convergence-start.sh}"
[ -x "$START" ] || START="$(dirname "$0")/../scripts/convergence-start.sh"
[ -x "$START" ] || exit 0

if ! OUTPUT=$(cd "$ROOT" && "$START" "$CHANGE" 2>&1); then
  printf '[convergence] no se pudo activar el gate para /opsx:apply %s.\n%s\n' "$CHANGE" "$OUTPUT" >&2
  exit 2
fi

exit 0
