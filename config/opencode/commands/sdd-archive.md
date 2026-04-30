---
description: Archive completed SDD change
agent: sebastian
---

Before delegating, validate that verification is complete and no unresolved CRITICAL findings remain.

Delegate `sdd-archive` for change "$ARGUMENTS".

Return a concise close-out:
- what shipped
- key decisions
- open follow-ups

Rules:
- If verification is missing or blocked, route back to `sdd-verify` before archiving.
- Keep response contract structured: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.
