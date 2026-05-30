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

## Objective

Keep `~/.config/opencode/skill-registry.md` ALWAYS up to date without relying on manual commands.

## Main Rule

Before any code task:

1. Check whether the registry exists
2. Check whether it is stale against the `SKILL.md` files
3. If missing or outdated, regenerate automatically

## Regeneration Command

```bash
node ~/.config/opencode/scripts/update-skill-registry.mjs
```

## "Stale" Criteria

The registry is stale if:

- `~/.config/opencode/skill-registry.md` does not exist
- Any `~/.config/opencode/skill/*/SKILL.md` has a newer modification date

## Rules

- Do NOT manually edit `skill-registry.md` (it gets overwritten on the next regeneration)
- ALWAYS regenerate after adding, deleting, or editing skills
- If regeneration fails, report the error and continue with the current skills

## Keywords

skill registry, auto refresh, stale registry, skill discovery, opencode skills
