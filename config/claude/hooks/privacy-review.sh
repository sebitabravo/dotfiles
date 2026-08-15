#!/usr/bin/env bash
# privacy-review.sh — Pre-submission privacy scan for gh issue/pr create
# Blocks commands that contain private identifiers (home paths, hostnames, tokens, emails).
# Gentle-ai pattern: replace with explicit placeholders, never redact into nothingness.

set -euo pipefail

# Only intercept gh issue create / gh pr create / gh api with --input
input="$(cat)"
cmd_str=""

# Extract command from JSON stdin
if command -v jq &>/dev/null; then
  if ! cmd_str="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)"; then
    echo "[Privacy Review] BLOCKED — no se pudo parsear el input del hook; no se puede revisar el contenido antes de publicar en GitHub." >&2
    exit 2
  fi
elif command -v python3 &>/dev/null; then
  if ! cmd_str="$(printf '%s' "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)"; then
    echo "[Privacy Review] BLOCKED — python3 no pudo parsear el input del hook; no se puede revisar el contenido antes de publicar en GitHub." >&2
    exit 2
  fi
else
  echo "[Privacy Review] BLOCKED — jq/python3 no esta disponible; no se puede revisar el contenido antes de publicar en GitHub." >&2
  exit 2
fi

[[ -z "$cmd_str" ]] && exit 0

# Only scan gh issue/pr create commands
if ! echo "$cmd_str" | grep -qE 'gh\s+(issue|pr)\s+create'; then
  exit 0
fi

# Detect private identifiers
PRIVATE_PATTERNS=(
  "/Users/[a-zA-Z0-9]+"          # macOS home dirs
  "/home/[a-zA-Z0-9]+"           # Linux home dirs
  "hostname:.*\.local"           # local hostnames
  "ghp_[a-zA-Z0-9]{36,}"         # GitHub personal access tokens (classic, >=36 chars)
  "github_pat_[a-zA-Z0-9_]{22,}" # GitHub fine-grained tokens
  "sk-[a-zA-Z0-9]{32,}"          # OpenAI keys
  "AKIA[0-9A-Z]{16}"             # AWS access keys
  "xox[bprs]-[0-9A-Za-z-]+"     # Slack tokens
)

violations=""
for pattern in "${PRIVATE_PATTERNS[@]}"; do
  # Use ggrep (GNU grep) if available, fall back to grep -E with basic patterns
  # El '--' separa flags del patron: sin el, un patron que empieza con '-' se
  # parsea como opciones y el match falla en silencio.
  if command -v ggrep &>/dev/null; then
    match="$(echo "$cmd_str" | ggrep -oP -- "$pattern" 2>/dev/null | head -5 || true)"
  elif command -v rg &>/dev/null; then
    # ripgrep supports PCRE2 with --pcre2 flag
    match="$(echo "$cmd_str" | rg -oP -- "$pattern" 2>/dev/null | head -5 || true)"
  else
    # Last resort: grep -E (limited, won't match all patterns)
    match="$(echo "$cmd_str" | grep -oE -- "$pattern" 2>/dev/null | head -5 || true)"
  fi
  if [[ -n "$match" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      violations+="  - Found: $line"$'\n'
    done <<< "$match"
  fi
done

# Emails reales, aparte del loop de arriba porque necesitan exclusion de
# dominios (RFC 2606 + noreply de GitHub, que son justo los placeholders que
# este mismo hook recomienda usar). La version anterior metia la exclusion
# como negative lookahead '(?!...)' dentro del patron: ggrep/rg lo soportan
# via PCRE, pero el ultimo recurso (grep -E, ERE puro) no — el patron entero
# fallaba en silencio ahi, y el detector de emails quedaba mudo en cualquier
# maquina sin ggrep ni rg instalados.
# Match simple + filtro por separado funciona igual en los tres grep, porque
# ninguno de los dos pasos necesita lookahead.
EMAIL_PATTERN="[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"
EMAIL_EXCLUDE='@(example\.(com|org|net)|test|invalid|localhost|users\.noreply\.github\.com)($|[^A-Za-z0-9_])'
email_match="$(echo "$cmd_str" | grep -oE -- "$EMAIL_PATTERN" 2>/dev/null | grep -vE -- "$EMAIL_EXCLUDE" | head -5 || true)"
if [[ -n "$email_match" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    violations+="  - Found: $line"$'\n'
  done <<< "$email_match"
fi

if [[ -n "$violations" ]]; then
  {
    echo "[Privacy Review] BLOCKED — private identifiers detected in gh issue/pr create body:"
    echo "$violations"
    echo ""
    echo "Replace private identifiers with explicit placeholders BEFORE publishing:"
    echo "  /Users/<username>  →  <project-path>"
    echo "  user@example.com   →  <email>"
    echo "  ghp_*              →  <token>"
    echo "  hostname.local     →  <hostname>"
    echo ""
    echo "Never redact into nothingness — preserve reproduction structure with placeholders."
    echo "Fix the body and retry."
  } >&2
  exit 2
fi

exit 0
