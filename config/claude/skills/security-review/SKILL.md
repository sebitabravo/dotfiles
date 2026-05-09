---
name: security-review
description: Complete a security review of pending changes. Audits for OWASP Top 10 vulnerabilities, exposed secrets, injection risks, auth bypasses, and dependency issues. Use on git diffs, PRs, or before deployment.
---

# Security Review

Revisión de seguridad enfocada en cambios pendientes. Auditoría sistemática, no teórica.

## When to Use

- Antes de mergear un PR.
- Al modificar auth, rutas, DB queries, o input de usuario.
- Cuando el usuario pide "security review", "audit", "check security".
- Post-incidente, para verificar que el fix no introduce nuevas vulnerabilidades.

## Checklist

### Secrets & Credentials
- No API keys, tokens, passwords en el diff.
- No URLs con credenciales embebidas.
- Variables de entorno referenciadas, nunca hardcodeadas.

### Injection
- SQL: prepared statements o query builder con parámetros bindeados. Nunca concatenación.
- XSS: output escapado en HTML/JSX. `dangerouslySetInnerHTML` solo con sanitización explícita.
- Command: sin `exec()`, `system()`, `subprocess` con strings del usuario.
- Path traversal: sin concatenar input en paths de archivos.

### Authentication & Authorization
- Middleware de auth en todas las rutas protegidas.
- Roles/permisos verificados en el backend, no solo en el frontend.
- JWT: expiración configurada, refresh token separado.

### Data Exposure
- Sin PII en logs o respuestas de error.
- Sin stack traces en producción.
- Rate limiting en endpoints públicos.

### Dependencies
- Nuevas dependencias: verificadas, legítimas, mantenidas.
- Sin `*` en versiones de package.json/requirements.txt.

## Output

Al finalizar, emitir:

```
## Security Review: [branch/PR]

### Crítico (bloquea deploy)
- [hallazgos]

### Alto
- [hallazgos]

### Medio
- [hallazgos]

### Pass
- [controles que pasaron]

Seguridad: [X]/100
```
