---
description: Initialize project context for SDD
agent: sdd-init
---

Initialize SDD context for this project.

Checklist:
1. Refresh skill registry if stale (`node ~/.config/opencode/scripts/update-skill-registry.mjs`).
2. Detect stack from project files (`package.json`, `composer.json`, `requirements.txt`, etc.).
3. Report which SDD phases are likely needed for upcoming work.
4. Do not implement feature code in this command.
