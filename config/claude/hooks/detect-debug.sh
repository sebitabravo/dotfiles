#!/usr/bin/env bash
# detect-debug.sh — PostToolUse hook para Edit/Write/NotebookEdit.
#
# Avisa cuando un archivo recien escrito quedo con statements de debug.
# No bloquea: reporta a stderr y el agente decide.
#
# Reemplaza al hook inline anterior, que tenia dos bugs:
#   1. matcher 'tool == "Edit" || tool == "Write"' se evaluaba como regex JS.
#      El '||' genera una rama vacia, y una rama vacia matchea cualquier cosa,
#      asi que corria en CADA tool call de la sesion.
#   2. leia $CLAUDE_TOOL_INPUT_FILE_PATH, que no existe. Los hooks reciben el
#      input por stdin en JSON. La variable vacia hacia que el case nunca
#      matcheara: no-op silencioso.
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

[ -z "$FILE_PATH" ] && exit 0
[ -f "$FILE_PATH" ] || exit 0

# Solo lenguajes donde estos statements son debug real.
case "$FILE_PATH" in
  *.ts | *.tsx | *.js | *.jsx | *.mjs | *.cjs) ;;
  *.py | *.rb | *.go | *.rs | *.php | *.java | *.kt) ;;
  *) exit 0 ;;
esac

# Ancla al inicio de linea (con indentacion opcional) para no marcar la palabra
# dentro de un string, un comentario o un nombre de funcion.
FOUND=$(grep -nE '^[[:space:]]*(console\.(log|warn|error|debug)|print\(|var_dump\(|dd\(|debugger|binding\.pry|byebug|pdb\.set_trace|breakpoint\(\))' "$FILE_PATH" 2>/dev/null || true)

if [ -n "$FOUND" ]; then
  echo "[detect-debug] Debug statements in $FILE_PATH:" >&2
  echo "$FOUND" | head -10 >&2
  echo "[detect-debug] Remove them before declaring the task finished." >&2
fi

exit 0
