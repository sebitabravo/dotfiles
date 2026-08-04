#!/usr/bin/env bash
# Refresh Gentle-AI's project skill index without making Codex dependent on it.
set -u

if ! command -v gentle-ai >/dev/null 2>&1; then
  exit 0
fi

if gentle-ai skill-registry refresh \
  --quiet \
  --no-gitignore \
  --cwd "${PWD:-.}" >/dev/null 2>&1; then
  exit 0
fi

if command -v jq >/dev/null 2>&1; then
  jq -nc '{systemMessage:"Skill registry refresh failed; Codex continued with the previous registry."}'
else
  printf '%s\n' '[skill-registry] refresh failed; Codex continued with the previous registry.' >&2
fi

# A stale registry is safer than blocking every new Codex session.
exit 0
