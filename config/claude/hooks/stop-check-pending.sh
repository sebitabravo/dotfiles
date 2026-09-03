#!/bin/bash
# Stop hook — chequea cambios sin commitear y stashes pendientes.
#
# Stop dispara una vez por TURNO, no al cerrar sesion, y durante cualquier
# trabajo real siempre hay archivos sin commitear: el aviso salia en todas las
# respuestas. Se emite una sola vez por sesion (marcador por session_id) y se
# re-arma si aparecen stashes de auto-save, que si son urgentes.
INPUT=$(cat 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null | tr -cd 'a-zA-Z0-9-')
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
PROJECT_DIR="${CWD:-$PWD}"
ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || exit 0)

cd "$ROOT" 2>/dev/null || exit 0
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || exit 0

UNSTAGED=$(git diff --name-only 2>/dev/null | head -10)
STAGED=$(git diff --cached --name-only 2>/dev/null | head -10)
STASHES=$(git stash list --grep="auto-save:" 2>/dev/null)

[ -z "$UNSTAGED" ] && [ -z "$STAGED" ] && [ -z "$STASHES" ] && exit 0

MARKER="${TMPDIR:-/tmp}/claude-pending-hint-${SESSION_ID:-nosession}"
if [ -f "$MARKER" ] && [ -z "$STASHES" ]; then
  exit 0
fi
: >"$MARKER"

echo "" >&2
echo "⚠️  PENDING CHANGES in $ROOT:" >&2
[ -n "$UNSTAGED" ] && echo "   🔴 Unstaged files: $(echo "$UNSTAGED" | wc -l | tr -d ' ')" >&2
[ -n "$STAGED" ] && echo "   🟡 Staged files (not committed): $(echo "$STAGED" | wc -l | tr -d ' ')" >&2
[ -n "$STASHES" ] && echo "   📦 Pending auto-save stashes: $(echo "$STASHES" | wc -l | tr -d ' ')" >&2
echo "" >&2
exit 0
