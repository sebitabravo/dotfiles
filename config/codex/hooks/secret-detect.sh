#!/usr/bin/env bash
# UserPromptSubmit: block obvious credentials before the prompt is submitted.
set -u

PROMPT="$(cat)"
[ -z "$PROMPT" ] && exit 0

has_match() {
  printf '%s' "$PROMPT" | grep -Eq -- "$1"
}

blocked=0
for pattern in \
  'sk-[A-Za-z0-9_-]{20,}' \
  'ghp_[A-Za-z0-9]{36}' \
  'github_pat_[A-Za-z0-9_]{20,}' \
  'glpat-[A-Za-z0-9_-]{20,}' \
  'AKIA[0-9A-Z]{16}' \
  'ASIA[0-9A-Z]{16}' \
  'AIza[0-9A-Za-z_-]{35}' \
  'ya29\.[0-9A-Za-z_-]{50,}' \
  'xox[bpas]-[0-9]{10,}-[0-9]{10,}-[A-Za-z0-9]{24}' \
  '(pk|rk|sk)_live_[0-9A-Za-z]{24,}' \
  '-----BEGIN (RSA|OPENSSH|EC|DSA|PGP) PRIVATE KEY-----'; do
  if has_match "$pattern"; then
    blocked=$((blocked + 1))
  fi
done

if [ "$blocked" -gt 0 ]; then
  printf '%s\n' '{"decision":"block","reason":"Prompt blocked: an API key, access token, or private key pattern was detected. Replace it with a placeholder and rotate it if it was real."}'
  exit 0
fi

if has_match 'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}'; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Warning: the prompt contains a JWT-shaped value. Verify that it is not a live credential before continuing."}'
fi

exit 0
