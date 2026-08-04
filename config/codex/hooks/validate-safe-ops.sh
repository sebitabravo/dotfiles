#!/usr/bin/env bash
# PreToolUse/Bash: deny catastrophic or credential-leaking shell commands.
# Normal risky commands remain under Codex's approval_policy and rules layer.
# shellcheck disable=SC2016
set -u

if ! command -v jq >/dev/null 2>&1; then
  echo "[validate-safe-ops] jq is required; command blocked until it is installed." >&2
  exit 2
fi

INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || true)"
[ -z "$COMMAND" ] && exit 0

deny() {
  jq -nc --arg reason "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
}

if printf '%s' "$COMMAND" | grep -Eiq 'curl[^|]*\|[[:space:]]*(bash|sh|zsh)([[:space:]]|$)'; then
  deny "curl | shell is blocked. Download the script, inspect it, and run it separately if it is trusted."
fi

if printf '%s' "$COMMAND" | grep -Eiq 'wget[^|]*(-O[[:space:]]*-|--output-document=-)[^|]*\|[[:space:]]*(bash|sh|zsh)([[:space:]]|$)'; then
  deny "wget | shell is blocked. Download the script, inspect it, and run it separately if it is trusted."
fi

if printf '%s' "$COMMAND" | grep -Eiq '(^|[;&|])[[:space:]]*(env|printenv|export[[:space:]]+-p|set)[[:space:]]*($|[;&|])'; then
  deny "Environment dumps are blocked because they can expose credentials. Inspect one non-secret variable instead."
fi

if printf '%s' "$COMMAND" | grep -Eiq '(echo|printf|print|cat|tee|logger)[^;&|]*\$\{?[A-Za-z_][A-Za-z0-9_]*(KEY|SECRET|TOKEN|PASSWORD|CREDENTIAL)'; then
  deny "Printing a credential-shaped environment variable is blocked. Pass it directly to the trusted command or check only whether it is defined."
fi

if printf '%s' "$COMMAND" | grep -Eiq '(^|[;&|])[[:space:]]*(cat|bat|head|tail|less|more|source|\.)[[:space:]][^;&|]*(\.env([.[:space:];|&]|$)|credentials\.json|\.ssh[/[:space:];|&]|\.(pem|key|p12|pfx|ppk)([[:space:];|&]|$))'; then
  deny "Reading secret files through Bash is blocked. Use a safe, named environment variable or a redacted sample."
fi

if printf '%s' "$COMMAND" | grep -Eiq '(^|[;&|])[[:space:]]*(sudo[[:space:]]+)?rm[[:space:]]+(-[[:alnum:]]+[[:space:]]+)*(\/|~|\$HOME)([[:space:];|&]|$)'; then
  deny "Recursive deletion of a home or filesystem root is blocked. Verify the exact target manually."
fi

if printf '%s' "$COMMAND" | grep -Eiq '(^|[;&|])[[:space:]]*(mkfs([.][[:alnum:]]+)?|dd[^;&|]*(of=)?[[:space:]]*/dev/)'; then
  deny "Filesystem formatting or raw device writes are blocked."
fi

if printf '%s' "$COMMAND" | grep -Eiq 'chmod[[:space:]]+(-R[[:space:]]+)?0?777([[:space:]]|$)'; then
  deny "chmod 777 is blocked. Grant the smallest required permission instead."
fi

if printf '%s' "$COMMAND" | grep -Eiq '(^|[[:space:];|])git[[:space:]]+push[^;&|]*--(force|force-with-lease)([[:space:];|&]|$)'; then
  deny "Force-push is blocked by the safety hook. Confirm the remote history and run it manually if intentional."
fi

if printf '%s' "$COMMAND" | grep -Eiq '(^|[[:space:];|])git[[:space:]]+reset[[:space:]]+--hard([[:space:];|&]|$)'; then
  deny "git reset --hard is blocked. Preserve or explicitly review the worktree before discarding changes."
fi

if printf '%s' "$COMMAND" | grep -Eiq '(^|[[:space:];|])git[[:space:]]+clean[^;&|]*-([[:alnum:]]*d[[:alnum:]]*f|[[:alnum:]]*f[[:alnum:]]*d)'; then
  deny "git clean with deletion flags is blocked. Inspect untracked files and remove exact targets manually."
fi

if printf '%s' "$COMMAND" | grep -Eiq '(DROP[[:space:]]+(TABLE|DATABASE|SCHEMA)|migrate:(fresh|refresh|reset)|migrate[[:space:]]+reset|db:(drop|reset)|--(accept-data-loss|force-reset))'; then
  deny "Destructive database/schema operation blocked. Verify the target, backup, rollback, and blast radius manually."
fi

exit 0
