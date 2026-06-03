#!/bin/bash
# PreToolUse hook — bloquea git commit con AI footprint ANTES de ejecutar
# Capa 2 de defensa: intercepta en Claude Code antes de que llegue a git
#
# Variables disponibles (Claude Code PreToolUse):
#   CLAUDE_TOOL_NAME     — "Bash"
#   CLAUDE_TOOL_INPUT    — JSON: {"command": "...", "description": "..."}

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-{}}"
COMMAND=$(echo "$TOOL_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('command',''))" 2>/dev/null)

# Solo aplica a git commit
if ! echo "$COMMAND" | grep -qE 'git\s+commit'; then
    exit 0
fi

# Escanear flag -m (todas las ocurrencias)
MESSAGES=$(echo "$COMMAND" | python3 -c "
import sys, re
cmd = sys.stdin.read()
# Extraer todos los mensajes de -m '...' o -m \"...\"
msgs = re.findall(r'-m\s*([\"'"'"'])(.*?)\1', cmd)
for q, m in msgs:
    print(m)
" 2>/dev/null)

if echo "$MESSAGES" | grep -qiE "Co-Authored-By:|co-authored-by:"; then
    echo "" >&2
    echo "⛔ BLOQUEADO por block-ai-footprint.sh" >&2
    echo "   Co-Authored-By detectado en git commit -m" >&2
    echo "   CLAUDE.md: 'No AI footprint' — esto NO se negocia" >&2
    echo "" >&2
    exit 1
fi

exit 0
