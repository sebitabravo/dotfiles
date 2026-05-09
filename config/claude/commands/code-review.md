---
description: "Revisa el diff actual o archivos especificados con el agente code-reviewer"
---

Ejecuta una revisión de código sistemática sobre ${ARGUMENTS:-el diff actual}.

Usa el skill `code-review` con el agente `code-reviewer`.

Dimensiones a revisar: correctness, security, performance, maintainability, testing.

Formato de output:
```
path:line: <severidad> <problema>. <sugerencia de fix>.
```
