---
description: Continue next dependency-ready SDD phase
agent: sebastian
---

Continue SDD for change "$ARGUMENTS".

Workflow:
1. If "$ARGUMENTS" is empty, ask for a change name and STOP.
2. SDD init guard: ensure `sdd-init` has been run for this project in the current session. If not, delegate `sdd-init` first.
3. If this is the first meta-command in the session, ask execution mode (`auto` or `interactive`). Default to `interactive` and cache it for the session.
4. Check what already exists (proposal/spec/design/tasks/apply/verify status).
5. Pick the next valid phase by dependency graph:
   proposal -> [spec + design] -> tasks -> apply -> verify -> archive
6. In `interactive` mode, summarize planned next phase and ask confirmation before delegating.
7. Delegate that phase.
8. Present result and next step.

Rules:
- Keep dependencies strict; never jump directly to downstream phases when prerequisites are missing.
- If verification reports CRITICAL issues, send flow back to `sdd-apply`.
