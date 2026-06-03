#!/bin/bash
# SessionStart: checkea si hay stashes de auto-save pendientes del PreCompact
STASHES=$(git -C "$PWD" stash list --grep="auto-save:" 2>/dev/null)
if [ -n "$STASHES" ]; then
  echo "[SessionStart] ⚠️  AUTO-SAVE STASHES PENDIENTES en $PWD:" >&2
  echo "$STASHES" >&2
  echo "   Recuperá con: git stash pop" >&2
fi
exit 0
