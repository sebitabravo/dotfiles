---
description: Refresh model catalog and auto-fix invalid agent models
agent: sebastian
---

Run model synchronization for this environment:

1. Refresh OpenCode model catalog.
2. Validate configured agent models in `opencode.json` and `agents/*.md`.
3. Auto-replace invalid models with safe provider-family fallbacks.
4. Report what changed and any unresolved model IDs.

Execute:

`node ~/.config/opencode/scripts/validate-agent-models.mjs --apply`
