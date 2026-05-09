---
description: "OWASP Top 10, secretos, dependencias — reglas de seguridad no negociables"
globs: []
alwaysApply: true
---

# Security

## No negociable

- **Nunca commits con secretos**. API keys, tokens, contraseñas = `.env` o vault.
- **Validar input de usuario SIEMPRE**. En el backend, aunque el frontend ya valide.
- **Sanitizar output**. XSS prevention. Escapar antes de renderizar.
- **Prepared statements para SQL**. Nunca concatenar queries con input.
- **HTTPS en producción**. HTTP solo para desarrollo local.

## Niveles de criticidad

| Nivel | Condición | Acción |
|---|---|---|
| **Crítico** | Secreto expuesto en código/commit | Rotar inmediatamente, purgar historial git |
| **Alto** | SQL injection, XSS, auth bypass | Fix antes del deploy |
| **Medio** | Dependencia vulnerable, falta rate limiting | Fix en esta iteración |

## Al generar código

- No generes tokens, passwords ni secretos de ejemplo (ni siquiera "test_sk_123").
- Usá variables de entorno o placeholders obvios: `$API_KEY`, `<tu-api-key>`.
- No uses algoritmos criptográficos obsoletos: MD5, SHA1, DES, RC4.
- No uses `eval()`, `exec()`, `Function()`, `system()` con strings dinámicos.

## Dependencias

- Antes de instalar: verificá que el paquete sea legítimo (typo-squatting).
- Mantené dependencias actualizadas. `npm audit`, `pip audit`, `cargo audit`.
- La cantidad mínima necesaria. Menos dependencias = menor superficie de ataque.
