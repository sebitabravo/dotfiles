#!/usr/bin/env bash
# PreToolUse hook — bloquea comandos peligrosos antes de ejecucion.
# Inspirado en ECC AgentShield + patrones elite 2025-2026.
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Si no se puede parsear el comando, permitir (fail open controlado)
if [ -z "$COMMAND" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
fi

# === PATRONES BLOQUEADOS ===

# Destruccion de filesystem
if echo "$COMMAND" | grep -qE '\brm\s+-rf\b'; then
  REASON="rm -rf bloqueado. Usa mv a trash o git clean en su lugar."
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$REASON\"}}"
  exit 0
fi

# Privilege escalation
if echo "$COMMAND" | grep -qE '\bsudo\b'; then
  REASON="sudo bloqueado. Ejecuta sin privilegios elevados."
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$REASON\"}}"
  exit 0
fi

# Force push (permitir solo con confirmacion via ask en permissions)
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(-f|--force)'; then
  REASON="git push --force bloqueado. Usa --force-with-lease si es necesario."
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$REASON\"}}"
  exit 0
fi

# Destruccion de base de datos
if echo "$COMMAND" | grep -qiE '\bDROP\s+(TABLE|DATABASE|SCHEMA)\b'; then
  REASON="DROP TABLE/DATABASE bloqueado. Ejecuta manualmente si es intencional."
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$REASON\"}}"
  exit 0
fi

# Pipe a bash (RCE classico)
if echo "$COMMAND" | grep -qE 'curl.*\|.*(bash|sh|zsh)'; then
  REASON="curl | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado."
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$REASON\"}}"
  exit 0
fi
if echo "$COMMAND" | grep -qE 'wget.*-O\s*-\s*\|.*(bash|sh|zsh)'; then
  REASON="wget | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado."
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$REASON\"}}"
  exit 0
fi

# Permisos inseguros
if echo "$COMMAND" | grep -qE '\bchmod\s+777\b'; then
  REASON="chmod 777 bloqueado. Usa permisos mas restrictivos (644, 755, 700)."
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$REASON\"}}"
  exit 0
fi

# Sobrescritura de disco
if echo "$COMMAND" | grep -qE '\bdd\s+if='; then
  REASON="dd bloqueado. Operacion de bajo nivel peligrosa."
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$REASON\"}}"
  exit 0
fi

# Default: permitir
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
