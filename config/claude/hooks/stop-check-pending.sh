#!/bin/bash
# Stop hook — chequea cambios sin commitear y stashes pendientes
cd "$PWD" 2>/dev/null || exit 0

if git rev-parse --git-dir >/dev/null 2>&1; then
  UNSTAGED=$(git diff --name-only 2>/dev/null | head -10)
  STAGED=$(git diff --cached --name-only 2>/dev/null | head -10)
  STASHES=$(git stash list --grep="auto-save:" 2>/dev/null)

  if [ -n "$UNSTAGED" ] || [ -n "$STAGED" ] || [ -n "$STASHES" ]; then
    echo "" >&2
    echo "⚠️  CAMBIOS PENDIENTES al cerrar sesión en $PWD:" >&2
    [ -n "$UNSTAGED" ] && echo "   🔴 Archivos sin stage: $(echo "$UNSTAGED" | wc -l | tr -d ' ')" >&2
    [ -n "$STAGED" ] && echo "   🟡 Archivos staged (sin commit): $(echo "$STAGED" | wc -l | tr -d ' ')" >&2
    [ -n "$STASHES" ] && echo "   📦 Auto-save stashes pendientes: $(echo "$STASHES" | wc -l | tr -d ' ')" >&2
    echo "" >&2
  fi
fi
exit 0
