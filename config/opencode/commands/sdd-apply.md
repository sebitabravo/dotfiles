---
description: Execute SDD apply phase (implementation)
agent: sebastian
---

Before delegating, run SDD init guard:
- ensure `sdd-init` has been run for this project in the current session
- if not, delegate `sdd-init` first

Delegate `sdd-apply` for change "$ARGUMENTS".

Rules:
- implement task-by-task in safe batches
- keep changes minimal and aligned with existing patterns
- report completed tasks and remaining tasks
- if required planning artifacts are missing (spec/design/tasks), stop and route back to the missing phase
- Keep response contract structured: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.
