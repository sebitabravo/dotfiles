#!/usr/bin/env bash
# Scaffold SDD artifacts without eval or overwriting an existing specification.
set -euo pipefail

FEATURE="${1:-}"
if [[ ! "$FEATURE" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Usage: scaffold-sdd.sh <feature-slug>" >&2
  exit 2
fi

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_ROOT="$SKILL_ROOT/references"
TARGET="$(pwd)/specs/$FEATURE"

if [ -e "$TARGET" ]; then
  echo "Refusing to overwrite existing path: $TARGET" >&2
  exit 1
fi

mkdir -p "$TARGET"
for mapping in \
  "sdd-constitution.md:constitution.md" \
  "sdd-proposal.md:proposal.md" \
  "sdd-requirements.md:requirements.md" \
  "sdd-design.md:design.md" \
  "sdd-tasks.md:tasks.md" \
  "sdd-apply-progress.md:apply-progress.md" \
  "sdd-checklist.md:checklist.md"; do
  source_name="${mapping%%:*}"
  target_name="${mapping#*:}"
  sed "s/{{FEATURE_NAME}}/$FEATURE/g" "$TEMPLATE_ROOT/$source_name" > "$TARGET/$target_name"
done

echo "Created SDD artifacts in $TARGET"
