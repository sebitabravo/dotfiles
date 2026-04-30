---
description: Run SDD tasks phase to produce ordered implementation steps
agent: sebastian
---

Before delegating, run SDD init guard:
- ensure `sdd-init` has been run for this project in the current session
- if not, delegate `sdd-init` first

Delegate `sdd-tasks` for change "$ARGUMENTS".

Return:
- ordered implementation tasks
- dependencies between tasks
- verification notes for each task or batch

Rules:
- Run only when spec and design artifacts exist.
- Keep response contract structured: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.
