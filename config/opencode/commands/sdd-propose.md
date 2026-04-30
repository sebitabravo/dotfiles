---
description: Run SDD propose phase with options and trade-offs
agent: sebastian
---

Before delegating, run SDD init guard:
- ensure `sdd-init` has been run for this project in the current session
- if not, delegate `sdd-init` first

Delegate `sdd-propose` for change "$ARGUMENTS".

Return:
- at least 2 viable options
- trade-offs for each option
- recommended option and why

Rules:
- STOP for user approval after presenting the proposal.
- Keep phase boundaries strict; do not jump to `sdd-spec` or `sdd-design` automatically.
- Keep response contract structured: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.
