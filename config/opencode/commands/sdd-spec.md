---
description: Run SDD spec phase for functional requirements
agent: sebastian
---

Before delegating, run SDD init guard:
- ensure `sdd-init` has been run for this project in the current session
- if not, delegate `sdd-init` first

Delegate `sdd-spec` for change "$ARGUMENTS".

Return:
- functional requirements
- user scenarios and edge cases
- acceptance criteria

Rules:
- Run only after proposal approval.
- Keep response contract structured: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.
