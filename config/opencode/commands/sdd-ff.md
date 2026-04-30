---
description: Fast-forward SDD planning (propose -> spec -> design -> tasks)
agent: sebastian
---

Run fast-forward planning for change "$ARGUMENTS".

Workflow:
1. If "$ARGUMENTS" is empty, ask for a change name and STOP.
2. SDD init guard: ensure `sdd-init` has been run for this project in the current session. If not, delegate `sdd-init` first.
3. If this is the first meta-command in the session, ask execution mode (`auto` or `interactive`). Default to `interactive` and cache it for the session.
4. Execute phases in dependency order: `sdd-propose` -> `sdd-spec` -> `sdd-design` -> `sdd-tasks`.
5. If mode is `interactive`, pause after each phase, summarize results, and ask whether to continue.
6. If mode is `auto`, run all phases back-to-back and present one consolidated summary.
7. Summarize artifacts and ask whether to execute `sdd-apply`.

Rules:
- Keep phase boundaries strict; do not skip dependencies.
- Orchestrate only; do not implement feature code in this command.
