#!/bin/bash
# SessionStart: checkea si hay stashes de auto-save pendientes del PreCompact
STASHES=$(git -C "$PWD" stash list --grep="auto-save:" 2>/dev/null)
if [ -n "$STASHES" ]; then
  echo "[SessionStart] ⚠️  PENDING AUTO-SAVE STASHES in $PWD:" >&2
  echo "$STASHES" >&2
  echo "   Recover with: git stash pop" >&2
fi
exit 0
