---
description: "Escanea el diff actual o archivos en busca de vulnerabilidades de seguridad"
---

Ejecuta un escaneo de seguridad sobre ${ARGUMENTS:-el diff actual}.

Usa el skill `security-review`.

Verificar:
- Secrets expuestos (API keys, tokens, passwords).
- SQL injection, XSS, command injection.
- Auth y autorización en nuevas rutas.
- Dependencias con vulnerabilidades conocidas.
- Sin PII en logs o respuestas.

Emitir reporte con severidades: CRITICAL (bloquea deploy), HIGH, MEDIUM, Pass.
