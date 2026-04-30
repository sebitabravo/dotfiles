---
description: Run SDD verification against spec/design
agent: sebastian
---

Before delegating, run SDD init guard:
- ensure `sdd-init` has been run for this project in the current session
- if not, delegate `sdd-init` first

Delegate `sdd-verify` for change "$ARGUMENTS".

Return findings grouped by severity:
- CRITICAL
- WARNING
- SUGGESTION

If CRITICAL findings exist, recommend going back to `sdd-apply`.

Rules:
- Keep response contract structured: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.
