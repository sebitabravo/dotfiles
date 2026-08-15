#!/usr/bin/env bash
# UserPromptSubmit hook — detecta secrets/API keys en el prompt.
# Patrones basados en ECC AgentShield + GitHub secret scanning.
#
# Dos niveles a proposito:
#   BLOCK — prefijos de proveedor y cabeceras de clave privada. Practicamente no
#           dan falsos positivos, asi que cortan con exit 2. Antes todo salia con
#           exit 0 diciendo "cancela con Ctrl+C", pero el prompt YA estaba
#           enviado: el aviso llegaba despues de la fuga.
#   WARN  — heuristicas amplias (JWT). Avisan sin bloquear, porque un base64
#           legitimo en el prompt no puede dejarte sin poder trabajar.
set -euo pipefail

PROMPT=$(cat)

BLOCK_PATTERNS=(
  'sk-[A-Za-z0-9_-]{20,}'                                # OpenAI/Anthropic/LLM API keys
  'ghp_[A-Za-z0-9]{36}'                                  # GitHub PAT (classic)
  'github_pat_[A-Za-z0-9_]{20,}'                         # GitHub PAT (fine-grained)
  'glpat-[A-Za-z0-9_-]{20,}'                             # GitLab PAT
  'AKIA[0-9A-Z]{16}'                                     # AWS Access Key ID
  'ASIA[0-9A-Z]{16}'                                     # AWS STS Temporary
  'AIza[0-9A-Za-z_-]{35}'                                # Google API Key
  'ya29\.[0-9A-Za-z_-]{50,}'                             # Google OAuth Access Token
  'xox[bpas]-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24}'      # Slack bot/user/app tokens
  'sq0atp-[0-9A-Za-z_-]{22}'                             # Square Access Token
  'sq0csp-[0-9A-Za-z_-]{43}'                             # Square OAuth Secret
  '(pk|rk|sk)_live_[0-9A-Za-z]{24,}'                     # Stripe live keys
  '-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----' # Private keys
)

WARN_PATTERNS=(
  'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}' # JWT largo
)

blocked=0
warned=0

for pattern in "${BLOCK_PATTERNS[@]}"; do
  # El '--' es obligatorio: el patron de clave privada empieza con '-----' y sin
  # el separador grep lo parsea como flags y falla con exit 2 (que se lee como
  # "no matcheo"). La deteccion de claves privadas nunca disparo por esto.
  if echo "$PROMPT" | grep -qE -- "$pattern" 2>/dev/null; then
    blocked=$((blocked + 1))
  fi
done

for pattern in "${WARN_PATTERNS[@]}"; do
  # El '--' es obligatorio: el patron de clave privada empieza con '-----' y sin
  # el separador grep lo parsea como flags y falla con exit 2 (que se lee como
  # "no matcheo"). La deteccion de claves privadas nunca disparo por esto.
  if echo "$PROMPT" | grep -qE -- "$pattern" 2>/dev/null; then
    warned=$((warned + 1))
  fi
done

if [ "$blocked" -gt 0 ]; then
  {
    echo ""
    echo "========================================"
    echo "  PROMPT BLOCKED: secret detected"
    echo "========================================"
    echo "Detected $blocked pattern(s) of API key, token or private key."
    echo "The prompt was NOT sent to the model."
    echo ""
    echo "Remove the credential and replace it with a placeholder (\$API_KEY, <token>)."
    echo "If the credential is real and was already shared elsewhere, ROTATE IT."
    echo "========================================"
    echo ""
  } >&2
  exit 2
fi

if [ "$warned" -gt 0 ]; then
  {
    echo ""
    echo "[secret-detect] WARNING: the prompt contains something shaped like a JWT."
    echo "[secret-detect] If it is a real token, abort (Ctrl+C) and replace it with <token>."
    echo ""
  } >&2
fi

exit 0
