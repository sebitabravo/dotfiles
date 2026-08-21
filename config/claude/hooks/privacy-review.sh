#!/usr/bin/env bash
# privacy-review.sh — Pre-submission privacy scan for GitHub writes.
# Blocks private identifier categories without echoing the matched value back
# into Claude's transcript.
# Gentle-ai pattern: replace with explicit placeholders, never redact into nothingness.

set -euo pipefail

# Intercept common issue/PR publication commands and write-oriented gh api.
input="$(cat)"
cmd_str=""

# Extract command from JSON stdin
if command -v jq &>/dev/null; then
  if ! cmd_str="$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)"; then
    echo "[Privacy Review] BLOCKED — could not parse the hook input; the content cannot be reviewed before publishing to GitHub." >&2
    exit 2
  fi
elif command -v python3 &>/dev/null; then
  if ! cmd_str="$(printf '%s' "$input" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))" 2>/dev/null)"; then
    echo "[Privacy Review] BLOCKED — python3 could not parse the hook input; the content cannot be reviewed before publishing to GitHub." >&2
    exit 2
  fi
else
  echo "[Privacy Review] BLOCKED — jq/python3 is not available; the content cannot be reviewed before publishing to GitHub." >&2
  exit 2
fi

[[ -z "$cmd_str" ]] && exit 0

# `gh api --input` publishes a file whose contents are not visible in the hook
# command. Fail closed rather than claiming it was reviewed.
if echo "$cmd_str" | grep -qE '(^|[;&|[:space:]])gh[[:space:]]+api\b' && \
  echo "$cmd_str" | grep -qE '(^|[[:space:]])--input([=[:space:]]|$)'; then
  echo '[Privacy Review] BLOCKED — gh api --input publishes file contents that this command-only review cannot verify. Review the file explicitly and use redacted inline fields or publish it manually.' >&2
  exit 2
fi

if ! echo "$cmd_str" | grep -qE '(^|[;&|[:space:]])gh[[:space:]]+((issue|pr)[[:space:]]+(create|comment|review)\b|api\b)'; then
  exit 0
fi

# Detect private identifiers
PRIVATE_PATTERNS=(
  "macOS home path|/Users/[a-zA-Z0-9]+"
  "Linux home path|/home/[a-zA-Z0-9]+"
  "local hostname|hostname:.*\.local"
  "GitHub classic token|ghp_[a-zA-Z0-9]{36,}"
  "GitHub fine-grained token|github_pat_[a-zA-Z0-9_]{22,}"
  "OpenAI-style token|sk-[a-zA-Z0-9]{32,}"
  "AWS access key|AKIA[0-9A-Z]{16}"
  "Slack token|xox[bprs]-[0-9A-Za-z-]+"
)

violations=""
for entry in "${PRIVATE_PATTERNS[@]}"; do
  label=${entry%%|*}
  pattern=${entry#*|}
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
    violations+="  - ${label}"$'\n'
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
  violations+="  - email address"$'\n'
fi

if [[ -n "$violations" ]]; then
  {
    echo "[Privacy Review] BLOCKED — private identifier categories detected in GitHub publication:"
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
