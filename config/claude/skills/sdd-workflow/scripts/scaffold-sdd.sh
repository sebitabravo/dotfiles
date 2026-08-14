#!/usr/bin/env bash
# Crea specs/<feature-slug>/ desde las plantillas SDD.
#
# Las plantillas viven en ~/.claude/templates/ y NO se duplican dentro del skill:
# una sola copia significa que arreglar una plantilla la arregla en todos lados.
#
# Sin eval y sin sobrescribir: si el directorio ya existe, sale. Un scaffolder
# que pisa una spec a medio llenar borra el trabajo que venia a organizar.
set -euo pipefail

FEATURE="${1:-}"
if [[ ! "$FEATURE" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Uso: scaffold-sdd.sh <feature-slug>" >&2
  exit 2
fi

TEMPLATE_ROOT="${CLAUDE_TEMPLATE_ROOT:-$HOME/.claude/templates}"
if [ ! -d "$TEMPLATE_ROOT" ]; then
  echo "No existe el directorio de plantillas: $TEMPLATE_ROOT" >&2
  exit 1
fi

TARGET="$(pwd)/specs/$FEATURE"
if [ -e "$TARGET" ]; then
  echo "Ya existe, no se sobrescribe: $TARGET" >&2
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
  if [ ! -f "$TEMPLATE_ROOT/$source_name" ]; then
    echo "Falta la plantilla $source_name en $TEMPLATE_ROOT" >&2
    exit 1
  fi
  sed "s/{{FEATURE_NAME}}/$FEATURE/g" "$TEMPLATE_ROOT/$source_name" > "$TARGET/$target_name"
done

echo "Artefactos SDD creados en $TARGET"
