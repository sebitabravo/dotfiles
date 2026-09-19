#!/bin/bash
# SessionStart: checkea si hay stashes de auto-save pendientes del PreCompact
INPUT=$(cat 2>/dev/null || printf '%s' '{}')
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
PROJECT_DIR="${CWD:-$PWD}"
ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PROJECT_DIR")
STASHES=$(git -C "$ROOT" stash list --grep="auto-save:" 2>/dev/null)
if [ -n "$STASHES" ]; then
  echo "[SessionStart] ⚠️  PENDING AUTO-SAVE STASHES in $ROOT:" >&2
  echo "$STASHES" >&2
  echo "   Recover with: git stash pop" >&2
fi
exit 0
