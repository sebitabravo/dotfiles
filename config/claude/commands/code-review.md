---
description: "Revisar cambios de código: diff, calidad, seguridad y arquitectura"
argument-hint: "[rango de diff | archivos | vacío = staged]"
---

Hacé una revisión de código exhaustiva de: $ARGUMENTS (si vacío, usá `git diff --staged`; si no hay staged, `git diff HEAD~1`).

Proceso:
1. **Scope**: determiná el diff exacto a revisar.
2. **Delegá** al agente `code-reviewer` con el diff.
3. **Chequeá**:
   - Corrección y edge cases
   - Vulnerabilidades de seguridad (OWASP, inyección, auth)
   - Implicaciones de performance
   - Cobertura de tests de la lógica cambiada
   - Naming, legibilidad, adherencia al estilo del proyecto
4. **Reportá**:
   - Severidad por hallazgo (Critical/High/Medium/Low/Info)
   - Cobertura de requerimientos si existen
   - Veredicto: approve / changes-requested / block

Siempre usá el agente `code-reviewer` para revisiones no triviales. Para fixes de 1 línea, revisá inline.
