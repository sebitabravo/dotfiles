# Seguridad

## Zonas restringidas (nunca leer, imprimir ni exfiltrar)

- **Secrets**: `.env` y cualquier `.env.*`, `secrets/`, `credentials.json`.
- **Llaves**: claves SSH privadas (`id_rsa`, `id_ed25519`, ...).
- **Certificados**: `.pem`, `.key`, `.ppk`, `.p12`, `.pfx`, `.pvk`.
- **Ruido** (no gastes tokens): `node_modules/`, `.git/objects/`, `.DS_Store`.

`validate-safe-ops.sh` niega por Bash el acceso a este mismo núcleo de secretos
(`.env*`, `secrets/`, credenciales, llaves SSH, certificados, `~/.gnupg`,
configs de CLI cloud) y a `npm install -g`, así que `cat .env` se detiene por
ese camino. **No hay un `permissions.deny` en `settings.json` que replique esto
para el tool nativo `Read`/`Edit`** — un `Read(.env)` directo no tiene barrera
estructural. El límite es esta regla: una que solo existe como patrón está a
una ruta no listada, un nombre nuevo o un `base64 -d` de volverse silenciosa;
acá no hay ni siquiera el patrón.

## Al generar código

- Nunca generes tokens, contraseñas ni secrets de ejemplo — ni siquiera
  `test_sk_123`. Usa variables de entorno o placeholders obvios: `$API_KEY`,
  `<your-api-key>`.
- Nunca uses criptografía obsoleta: MD5, SHA1, DES, RC4.
- Nunca uses `eval()`, `exec()`, `Function()` ni `system()` con strings dinámicos.
- Input de usuario validado en el backend aunque el frontend ya valide. Output
  escapado antes de renderizar. SQL con prepared statements, nunca concatenando.

## Severidad

| Nivel | Condición | Acción |
|---|---|---|
| **Crítico** | Secret expuesto en código o commit | Rotar ya, purgar historia de git |
| **Alto** | SQL injection, XSS, bypass de auth | Arreglar antes de desplegar |
| **Medio** | Dependencia vulnerable, falta rate limiting | Arreglar en esta iteración |

## Dependencias y cadena de suministro

- Antes de instalar, verifica que el paquete sea legítimo (typo-squatting).
- Cooldown de 3 días antes de adoptar una versión recién publicada.
- Auditoría antes de instalar algo nuevo: `npq --dry-run`. Para auditar el árbol
  existente usa el script del proyecto, o `npm audit` / `bun audit` /
  `cargo audit` / `pip-audit`.
- **Preferencia de package manager: `bun` > `pnpm` > `npm`.** Bun y pnpm 10+
  bloquean lifecycle scripts por defecto y soportan cooldown por antigüedad de
  publicación; por eso van primero.
- **El lockfile de un proyecto existente gana sobre esa preferencia y no es tuyo
  para cambiarlo.** `bun.lock` significa bun, `pnpm-lock.yaml` pnpm,
  `package-lock.json` npm, `uv.lock` uv. Cambiar re-resuelve el árbol de
  dependencias completo, lo que es en sí mismo un evento de cadena de suministro.
  Los repos de clientes o del trabajo clavados a npm se quedan en npm.
- `npm install` / `npm i` requiere confirmación explícita. Prefiere `npm ci`.
- `npm install -g` está BLOQUEADO. Usa `npx`, `pnpm dlx`, `bunx` o `npm exec` local.
- Cuando un proyecto obliga a npm, el endurecimiento de `~/.npmrc` es lo que
  reemplaza lo que bun y pnpm dan gratis: `ignore-scripts=true`,
  `allow-git=none`, `min-release-age=3`. Nunca los sobreescribas por proyecto.
- Guía completa de endurecimiento: skill `npm-security`.

## Sesgo de autonomía

Acciones seguras y rutinarias (leer, buscar, verificar, ediciones chicas que te
pidieron): avanza y reporta el resultado. Acciones destructivas, irreversibles o
remotas: para y confirma — el protocolo completo está en
`rules/common/destructive-operations.md`.
