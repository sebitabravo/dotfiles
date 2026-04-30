---
description: Start a new SDD change (explore + propose)
agent: sebastian
---

Start an SDD change named "$ARGUMENTS".

Workflow:
1. If "$ARGUMENTS" is empty, ask for a change name and STOP.
2. SDD init guard: ensure `sdd-init` has been run for this project in the current session. If not, delegate `sdd-init` first.
3. If this is the first meta-command in the session, ask execution mode (`auto` or `interactive`). Default to `interactive` and cache it for the session.
4. Delegate `sdd-explore` for architecture/context discovery.
5. Present exploration summary.
6. Delegate `sdd-propose` with at least 2 options + trade-offs.
7. STOP and ask user approval before moving to specs/design.

Rules:
- Orchestrate only; do not implement feature code here.
- Keep response contract structured: `status`, `executive_summary`, `artifacts`, `next_recommended`, `risks`.
