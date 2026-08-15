---
description: "Auditoría de seguridad completa: dependencias, secretos, OWASP y permisos"
argument-hint: "[ruta del proyecto | vacío = directorio actual]"
---

Ejecutá un escaneo de seguridad completo de: $ARGUMENTS (si vacío, el directorio actual).

1. **Dependency audit**: corré el audit del runner del proyecto (`npm audit`, `bun audit`, `pnpm audit`, o `pip-audit`).
2. **Detección de secretos**: buscá hardcoded secrets, API keys y tokens en archivos fuente.
3. **OWASP quick check**: revisá patrones de auth, validación de input y manejo de errores contra el top 10.
4. **Permission review**: permisos de archivos, cobertura de .gitignore, exposición de archivos sensibles.
5. **Supply chain**: integridad del lockfile, dependencias git, provenance (usá la skill `npm-security` para proyectos JS/TS).

## Agentes

Levantá **`vulnerability-hunter` siempre**: es el único que tiene las herramientas
de escaneo en su allowlist (`semgrep`, `gitleaks`, `bandit`, `npm audit`,
`pip-audit`, `trivy`, más el análisis de binarios), así que es el que ejecuta los
pasos 1, 2 y la parte verificable del 5. Los demás agentes solo pueden opinar
sobre esos puntos; este los corre.

Sumá `security-auditor` en paralelo cuando el proyecto no sea trivial o el paso 3
importe: aporta el lente de threat model, OWASP y arquitectura de auth, que es
juicio de diseño y no sale de un scanner.

Si una herramienta no está instalada en el host, reportá esa etapa como **no
ejecutada**. Un scanner ausente no es un hallazgo limpio: presentarlo como verde
es peor que no correrlo, porque compra confianza que nadie verificó.

Formato de reporte:
- Severidad: Critical / High / Medium / Low / Info
- Por hallazgo: descripción, archivo:línea, remediación
- Resumen ejecutivo con risk score
