---
name: handoff
description: Creates a HANDOFF.md file with the current project state for a clean handoff between sessions. Use when the session is long, the model is going in circles on the same solution, or before running /clear. The file is archived automatically when the next session starts.
---

# Handoff — clean transfer between sessions

Writes a `HANDOFF.md` at the project root with ALL the context a fresh session needs to continue without dragging along the noise.

## When to use it

- Long session (>30 min) and the model starts repeating patterns
- 3+ failed attempts at the same solution
- Before running `/clear` or closing the session
- When the user says "handoff", "traspaso", or "crea handoff"

## HANDOFF.md structure

Generate the file in THIS exact format. The headings stay in Spanish because the user reads them:

```markdown
# Handoff — [date/time]

## Objetivo
[What we are trying to achieve. One clear sentence. No ambiguity.]

## Estado Actual
[Where we are. What works. What does NOT work. Be honest — this is the most important part.]

## Archivos Clave
- `absolute/path/file.ts` — what it is and why it matters
- `absolute/path/other.tsx` — what it is and why it matters

## Cambios Hechos
- [Change 1] — why it was made
- [Change 2] — why it was made

## Intentos Fallidos
- [Attempt 1] — why it failed. Do NOT repeat this approach.
- [Attempt 2] — why it failed. Do NOT repeat this approach.

## Próximos Pasos
1. [Concrete step 1]
2. [Concrete step 2]
3. [Concrete step 3]

## Notas
[Any extra context: conventions, decisions, warnings, git state]
```

Write the body content in Spanish — the handoff is read by the user, not only by the next session.

## Rules

- **No fiction.** If something was not tested, write "no verificado".
- **Failures > successes.** Documenting what did NOT work is worth more than what did.
- **Absolute paths.** No `./` or `../`.
- **Overwrite without fear.** If HANDOFF.md already exists, replace it (the new one is fresher).
- **Do not commit HANDOFF.md.** It is temporary. It belongs in .gitignore.

## After generating

1. Say explicitly: "HANDOFF.md creado. Cerrá esta sesión y abrí una nueva. Leerá el handoff automáticamente."
2. Do not keep working after generating the handoff. The whole point is to CLOSE the session.
