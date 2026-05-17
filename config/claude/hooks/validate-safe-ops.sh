#!/usr/bin/env bash
# PreToolUse hook — bloquea comandos peligrosos antes de ejecucion.
# Inspirado en ECC AgentShield + patrones elite 2025-2026.
# Arquitectura: binario-especifico + NO_QUOTES para eliminar falsos positivos.
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# Si no se puede parsear el comando, permitir (fail open controlado)
if [ -z "$COMMAND" ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
  exit 0
fi

FIRST_LINE=$(echo "$COMMAND" | head -1)
BINARY=$(echo "$FIRST_LINE" | awk '{print $1}' | xargs basename 2>/dev/null || echo "")
# Comando sin strings quoted — evita falsos positivos en mensajes de commit/heredocs
NO_QUOTES=$(echo "$FIRST_LINE" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

deny() {
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$1\"}}"
  exit 0
}

# === UNIVERSAL — full command (patrones RCE multi-linea) ===

# Pipe a bash (RCE classico — multi-linea, no restringir a primera linea)
if echo "$COMMAND" | grep -qE 'curl.*\|.*(bash|sh|zsh)'; then
  deny "curl | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado."
fi
if echo "$COMMAND" | grep -qE 'wget.*-O\s*-\s*\|.*(bash|sh|zsh)'; then
  deny "wget | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado."
fi

# DROP TABLE via echo/printf pipe (patron multi-comando)
if echo "$COMMAND" | grep -qiE '(echo|printf|cat).*\bDROP\s+(TABLE|DATABASE|SCHEMA)\b.*\|'; then
  deny "DROP TABLE via pipe bloqueado. Ejecuta manualmente si es intencional."
fi

# === NO_QUOTES — patrones universales sin falsos positivos en strings ===

# Destruccion de filesystem
if echo "$NO_QUOTES" | grep -qE '\brm\s+-rf\b'; then
  deny "rm -rf bloqueado. Usa mv a trash o git clean en su lugar."
fi

# Permisos inseguros
if echo "$NO_QUOTES" | grep -qE '\bchmod\s+777\b'; then
  deny "chmod 777 bloqueado. Usa permisos mas restrictivos (644, 755, 700)."
fi

# === BINARY-SPECIFIC — solo cuando el binario coincide ===

case "$BINARY" in
  sudo)
    deny "sudo bloqueado. Ejecuta sin privilegios elevados."
    ;;
  git)
    if echo "$NO_QUOTES" | grep -qE '\bpush\b.*(--force|-f\b)'; then
      deny "git push --force bloqueado. Usa --force-with-lease si es necesario."
    fi
    ;;
  npm)
    if echo "$NO_QUOTES" | grep -qE '\b(install|i)\b.*-g\b'; then
      deny "npm install -g bloqueado. Usa npx para herramientas one-shot."
    fi
    ;;
  pip|pip3)
    if echo "$FIRST_LINE" | grep -qE '\binstall\b.*--break-system-packages'; then
      deny "pip install --break-system-packages bloqueado. By-passea la proteccion del venv. Usa un venv o uv."
    fi
    ;;
  mysql|psql|sqlite3|mongo|mongosh|redis-cli|mariadb|cockroach|sqlplus|duckdb|clickhouse-client|bq|snowsql|mysqlsh)
    # FIRST_LINE (con quotes) porque DROP TABLE suele ir dentro de -e "..." o -c "..."
    if echo "$FIRST_LINE" | grep -qiE '\bDROP\s+(TABLE|DATABASE|SCHEMA)\b'; then
      deny "DROP TABLE/DATABASE bloqueado. Ejecuta manualmente si es intencional."
    fi
    ;;
  dd)
    if echo "$NO_QUOTES" | grep -qE '\bif='; then
      deny "dd bloqueado. Operacion de bajo nivel peligrosa."
    fi
    ;;
esac

# Default: permitir
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
