---
description: Run SDD design phase for technical architecture
agent: sebastian
---

Before delegating, run SDD init guard:
- ensure `sdd-init` has been run for this project in the current session
- if not, delegate `sdd-init` first

Delegate `sdd-design` for change "$ARGUMENTS".

Return:
- architecture decisions
- data flow and component boundaries
- technical risks and mitigations

Rules:
- Run only after proposal approval.
- Keep response contract structured: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.
