#!/usr/bin/env bash
# Detecta secrets/API keys en el prompt antes de enviarlo al modelo.
# Patrones basados en ECC AgentShield + GitHub secret scanning.
set -euo pipefail

PROMPT=$(cat)

# Patrones de alto riesgo — si matchean, WARNING visible
PATTERNS=(
  'sk-[A-Za-z0-9]{32,}'           # OpenAI/Anthropic/LLM API keys
  'sk-[A-Za-z0-9_-]{20,}'         # Stripe secret keys
  'ghp_[A-Za-z0-9]{36}'           # GitHub PAT (classic)
  'github_pat_[A-Za-z0-9_]{20,}'  # GitHub PAT (fine-grained)
  'glpat-[A-Za-z0-9_-]{20,}'      # GitLab PAT
  'AKIA[0-9A-Z]{16}'              # AWS Access Key ID
  'ASIA[0-9A-Z]{16}'              # AWS STS Temporary
  'AIza[0-9A-Za-z_-]{35}'         # Google API Key
  'ya29\.[0-9A-Za-z_-]{50,}'     # Google OAuth Access Token
  'xoxb-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24}'    # Slack Bot Token
  'xoxp-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24}'    # Slack User Token
  'xapp-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24}'    # Slack App Token
  'sq0atp-[0-9A-Za-z_-]{22}'      # Square Access Token
  'sq0csp-[0-9A-Za-z_-]{43}'      # Square OAuth Secret
  'pk_live_[0-9A-Za-z]{24,}'      # Stripe live publishable key (menor riesgo pero warn)
  'rk_live_[0-9A-Za-z]{24,}'      # Stripe live restricted key
  'sk_live_[0-9A-Za-z]{24,}'      # Stripe live secret key
  '-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----'  # Private keys
  'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'  # JWTs largos (posible token)
)

WARN=0
MATCHED=()

for pattern in "${PATTERNS[@]}"; do
  if echo "$PROMPT" | grep -qE "$pattern" 2>/dev/null; then
    WARN=1
    MATCHED+=("$pattern")
  fi
done

if [ "$WARN" -eq 1 ]; then
  echo "" >&2
  echo "========================================" >&2
  echo "  ATENCION: Posible secret en prompt" >&2
  echo "========================================" >&2
  echo "Se detectaron patrones de API keys, tokens o credenciales." >&2
  echo "Cancela este prompt (Ctrl+C) y revisa antes de enviar." >&2
  echo "Patrones detectados: ${#MATCHED[@]}" >&2
  echo "========================================" >&2
  echo "" >&2
fi

exit 0
