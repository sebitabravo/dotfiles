---
name: skill-registry
description: >
  Auto-refresh and maintain the OpenCode skill registry.
  Trigger: When skill files are added/removed/updated or registry is stale/missing.
license: MIT
metadata:
  author: sebita-programming
  version: "1.0"
---

## Objetivo

Mantener `~/.config/opencode/skill-registry.md` SIEMPRE actualizado sin depender de comandos manuales.

## Regla principal

Antes de cualquier tarea de código:

1. Verificar si el registry existe
2. Verificar si está desactualizado contra los `SKILL.md`
3. Si falta o está viejo, regenerar automáticamente

## Comando de regeneración

```bash
node ~/.config/opencode/scripts/update-skill-registry.mjs
```

## Criterio de "stale"

El registry está stale si:

- No existe `~/.config/opencode/skill-registry.md`
- Algún `~/.config/opencode/skill/*/SKILL.md` tiene fecha de modificación más nueva

## Reglas

- NO editar manualmente `skill-registry.md` (se pisa en la próxima regeneración)
- SIEMPRE regenerar después de agregar, borrar o editar skills
- Si la regeneración falla, informar error y continuar con los skills actuales

## Keywords

skill registry, auto refresh, stale registry, skill discovery, opencode skills
