---
description: "OWASP Top 10, secrets, dependencies — non-negotiable security rules"
globs: []
alwaysApply: true
---

# Security

## Non-negotiable

- **Never commit secrets**. API keys, tokens, passwords = `.env` or vault.
- **ALWAYS validate user input**. Backend-side, even if frontend validates.
- **Sanitize output**. XSS prevention. Escape before rendering.
- **Prepared statements for SQL**. Never concatenate queries with user input.
- **HTTPS in production**. HTTP only for local development.

## Severity levels

| Level | Condition | Action |
|---|---|---|
| **Critical** | Secret exposed in code/commit | Rotate immediately, purge git history |
| **High** | SQL injection, XSS, auth bypass | Fix before deploy |
| **Medium** | Vulnerable dependency, missing rate limiting | Fix this iteration |

## When generating code

- Never generate tokens, passwords, or example secrets (not even "test_sk_123").
- Use environment variables or obvious placeholders: `$API_KEY`, `<your-api-key>`.
- Never use obsolete cryptographic algorithms: MD5, SHA1, DES, RC4.
- Never use `eval()`, `exec()`, `Function()`, `system()` with dynamic strings.

## Dependencies

- Before installing: verify the package is legitimate (typo-squatting).
- Keep dependencies updated. `npm audit`, `pip audit`, `cargo audit`.
- Minimum necessary amount. Fewer dependencies = smaller attack surface.

### npm install — requiere confirmacion

- **`npm install` / `npm i` requiere confirmacion explicita**. Ejecuta scripts de postinstall arbitrarios sin verificacion de integridad del lockfile. Vector de supply chain attack documentado:
  - **Axios (Marzo 2026)**: credenciales de maintainer comprometidas → publicaron `axios@1.14.1` + dependencia maliciosa `plain-crypto-js@4.2.1` → postinstall script (`node setup.js`) descargaba RAT multiplataforma (macOS/Linux/Windows) → script se autolimpiaba, `npm audit` no detectaba nada.
  - **TanStack (Mayo 2026)**: 42 paquetes, 84 versiones, propagacion a Mistral, UiPath, PyPI.
- **Preferi `npm ci`** para instalaciones deterministas que respetan el lockfile y no ejecutan postinstall scripts.
- **Alternativa preferida: `pnpm`**. pnpm 11+ bloquea install-scripts por defecto (con approval prompt, no binario como `--ignore-scripts`) y tiene `minimumReleaseAge=1440` (1 dia) por defecto.
- **`npm install -g` esta BLOQUEADO**. Usa `npx` o `pnpm dlx` para herramientas one-shot.

#### Cooldown de versiones (minimum release age)

- **`min-release-age=1` en `~/.npmrc`** (npm 11.10.0+, Febrero 2026). Bloquea instalacion de paquetes publicados hace <1 dia. El ataque Axios duro <24h antes de deteccion — un cooldown de 1 dia lo hubiera frenado completamente.
  ```ini
  # ~/.npmrc (global) o .npmrc (proyecto)
  min-release-age=1
  ```
- **No uses `ignore-scripts=true` global**. Rompe paquetes con native addons (esbuild, node-gyp, sharp, etc.). Para proyectos que no necesitan native addons, configuralo por proyecto.
- **pnpm ya lo trae por defecto**. `minimumReleaseAge=1440` (minutos = 1 dia) desde pnpm 11.0. No requiere configuracion adicional.
- Para emergencias (parche de seguridad critico): `npm install --min-release-age=0 <pkg>`.

### pip install — requiere confirmacion

- **`pip install` requiere confirmacion explicita**. ~1/3 de los paquetes en PyPI usan source distributions (`.tar.gz` con `setup.py`) que **ejecutan codigo arbitrario al instalarse** — incluso `pip download` ejecuta `setup.py`. Mas peligroso estructuralmente que npm: no existe equivalente a `npm ci` que saltee scripts. Incidente LiteLLM/Telnyx (Marzo 2026): 119k+ descargas maliciosas en <3 horas, vector via CI/CD compromise.
- **`--only-binary :all:` siempre**. Fuerza wheels (`.whl`) que no ejecutan codigo al instalarse. Equivalente funcional a "bloquear postinstall scripts" en npm. Si un paquete no tiene wheel disponible, instalalo manualmente con revision de `setup.py`.
  ```bash
  pip install --only-binary :all: <paquete>
  ```
- **`--require-hashes` para integridad**. Verifica checksums criptograficos contra un lockfile. No es autenticidad (el autor malicioso publica sus propios hashes), pero detecta tampering en transito o en el registry. Usa `pip-compile --generate-hashes` para generar lockfiles; `pip freeze` NO es un lockfile (no incluye hashes).
- **Cooldown de dependencias**. pip 26.1+ soporta `uploaded-prior-to = P3D` en `pip.conf`. Bloquea paquetes publicados hace <3 dias — el ataque LiteLLM duro 2.5h, un cooldown lo hubiera frenado. En proyectos, configura `exclude-newer = "P3D"` con uv.
- **Siempre dentro de un venv**. Nunca `pip install` global en el sistema.
- **`pip install --break-system-packages` BLOQUEADO**. By-passea la proteccion del venv.
- **`pip install` sin venv activo esta BLOQUEADO**. Usa `uv` (alternativa moderna de Rust, lockfile con hashes por defecto, mas rapido) o `pipx` para herramientas CLI.
- **`pip-audit` en CI**. Escaneo de CVEs en cada commit. `uvx pip-audit --requirement requirements.txt`.
