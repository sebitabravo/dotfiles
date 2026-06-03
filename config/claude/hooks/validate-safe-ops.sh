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
# Full command sin quotes — para patrones universales multi-linea
NO_QUOTES_FULL=$(echo "$COMMAND" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g")

deny() {
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"$1\"}}"
  exit 0
}

# === UNIVERSAL — full command (patrones RCE multi-linea) ===

# Pipe a bash (RCE classico — multi-linea, no restringir a primera linea)
if echo "$NO_QUOTES_FULL" | grep -qE 'curl.*\|.*(bash|sh|zsh)'; then
  deny "curl | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado."
fi
if echo "$NO_QUOTES_FULL" | grep -qE 'wget.*-O\s*-\s*.*\|.*(bash|sh|zsh)'; then
  deny "wget | bash bloqueado. Descarga el script, revisalo, y ejecutalo por separado."
fi

# DROP TABLE via echo/printf pipe (patron multi-comando)
if echo "$NO_QUOTES_FULL" | grep -qiE '(echo|printf|cat).*\bDROP\s+(TABLE|DATABASE|SCHEMA)\b.*\|'; then
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
    # --force($|[^-]) = --force al final o seguido de espacio (no --force-with-lease ni --force-without-lease)
    if echo "$NO_QUOTES" | grep -qE '\bpush\b.*--force($|[^-])'; then
      deny "git push --force bloqueado. Usa --force-with-lease si es necesario."
    fi
    if echo "$NO_QUOTES" | grep -qE '\bpush\b.*(\s-f\b|^-f\b)'; then
      deny "git push -f bloqueado. Usa --force-with-lease si es necesario."
    fi
    # reset como subcomando (no branch name: reset--hard-bug)
    if echo "$NO_QUOTES" | grep -qE '\breset\s+.*--hard(\s|$)'; then
      deny "git reset --hard bloqueado. Usa git stash o git checkout -- <file> para descartes selectivos."
    fi
    # AI footprint en commit messages
    if echo "$COMMAND" | grep -qiE 'Co-Authored-By:'; then
      deny "git commit con Co-Authored-By bloqueado. Regla CLAUDE.md: No AI footprint."
    fi
    ;;
  npm)
    # -g standalone (whitespace antes y despues, o fin de linea) — evita falsos positivos con paquetes que terminan en -g
    if echo "$NO_QUOTES" | grep -qE '\b(install|i)\b.*(\s-g(\s|$)|^-g(\s|$))'; then
      deny "npm install -g bloqueado. Usa npx para herramientas one-shot."
    fi
    ;;
  pip|pip3)
    if echo "$FIRST_LINE" | grep -qE '\binstall\b.*--break-system-packages'; then
      deny "pip install --break-system-packages bloqueado. By-passea la proteccion del venv. Usa un venv o uv."
    fi
    ;;
  kubectl)
    # delete como subcomando (no en flag values: --field-selector=name!=delete-me)
    if echo "$NO_QUOTES" | grep -qE '^\s*kubectl\s+delete\b'; then
      deny "kubectl delete bloqueado. Operacion destructiva en el cluster."
    fi
    ;;
  helm)
    # uninstall/delete como subcomando (no en flag values)
    if echo "$NO_QUOTES" | grep -qE '^\s*helm\s+(uninstall|delete)\b'; then
      deny "helm uninstall/delete bloqueado. Operacion destructiva en el cluster."
    fi
    ;;
  terraform)
    # terraform destroy como subcomando (no como parte de nombre de archivo: destroy.tfplan)
    if echo "$FIRST_LINE" | grep -qE '\bterraform\s+destroy\b|\bterraform\s+apply\b.*-auto-approve'; then
      deny "terraform destroy/apply -auto-approve bloqueado. Infraestructura como codigo requiere revision manual."
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
  mkfs|mkfs.*|newfs|newfs_msdos)
    deny "mkfs/newfs bloqueado. Formateo de filesystem es irreversible sin backup."
    ;;
esac

# Default: permitir
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}'
exit 0
