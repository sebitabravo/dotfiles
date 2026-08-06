#!/usr/bin/env bash
# Audit local prerequisites for the curated Codex setup. It never installs.
set -u

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
SKILLS_ROOT="${SKILLS_ROOT:-$ROOT/skills}"
if [ ! -d "$SKILLS_ROOT" ] && [ -d "${HOME:-}/.agents/skills" ]; then
  SKILLS_ROOT="${HOME}/.agents/skills"
fi
missing=0

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'ok      %-12s %s\n' "$1" "$(command -v "$1")"
  else
    printf 'missing %-12s %s\n' "$1" "$2"
    missing=$((missing + 1))
  fi
}

echo "Codex prerequisites"
require_command git "required for status, diffs, SDD, and RDD"
require_command jq "required by Codex safety hooks"
require_command python3 "required by the SessionStart hook"
require_command rg "recommended for repository search"

if [ -d "$SKILLS_ROOT" ]; then
  echo
  echo "Skill metadata"
  while IFS= read -r skill_file; do
    if ! grep -q '^name:' "$skill_file" || ! grep -q '^description:' "$skill_file"; then
      printf 'invalid  %s\n' "${skill_file#"$SKILLS_ROOT/"}"
      missing=$((missing + 1))
    fi
  done < <(find "$SKILLS_ROOT" -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort)
else
  printf 'missing skills directory: %s\n' "$SKILLS_ROOT"
  missing=$((missing + 1))
fi

if [ "$missing" -gt 0 ]; then
  echo
  echo "$missing prerequisite or metadata issue(s) found. Fix them before enabling optional automation; this checker never installs." >&2
  exit 1
fi

echo
echo "All required prerequisites and curated skill metadata look available."
