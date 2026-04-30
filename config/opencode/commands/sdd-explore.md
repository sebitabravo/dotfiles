---
description: Run SDD explore phase for a topic/change
agent: sebastian
---

Before delegating, run SDD init guard:
- ensure `sdd-init` has been run for this project in the current session
- if not, delegate `sdd-init` first

Delegate `sdd-explore` for "$ARGUMENTS" and return:
- current architecture relevant to the request
- constraints and risks
- recommended next phase

Rules:
- Orchestrate only; do not implement feature code in this command.
- Keep response contract structured: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.
