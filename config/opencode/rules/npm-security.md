# NPM Security — Supply Chain Hardening

Basado en [lirantal/npm-security-best-practices](https://github.com/lirantal/npm-security-best-practices). 17 practicas. Cada una: que protege, como se explota, como mitigar.

---

## 1. Bloquear postinstall scripts

**Vector**: `postinstall` ejecuta codigo arbitrario al instalar. Ataques: Shai-Hulud (2025), Nx (2025), event-stream (2018), TanStack (Mayo 2026 — 42 paquetes, 84 versiones).

**Mitigacion**:

```bash
# Global — bloquea TODOS los lifecycle scripts
npm config set ignore-scripts true

# Per-install
npm install --ignore-scripts <pkg>

# pnpm (v10+): bloquea por defecto. Allow-list explicito:
# pnpm-workspace.yaml
onlyBuiltDependencies:
  - esbuild
  - sharp

# Bun: bloquea por defecto. trustedDependencies en package.json:
{
  "trustedDependencies": ["esbuild", "sharp"]
}
```

**npm install / npm i requiere confirmacion explicita.** Preferir `npm ci`.

---

## 2. Bloquear dependencias via git

**Vector**: `"dep": "git+https://malicious.com/repo.git"` en package.json. By-passea el registry, evade escaneo de seguridad, puede incluir `.npmrc` que re-habilita lifecycle scripts.

**Mitigacion** (npm CLI 11.10.0+):

```bash
npm config set allow-git none

# pnpm 10.26+ — bloquea subdependencias exoticas (git, tarball URLs):
# pnpm-workspace.yaml
blockExoticSubdeps: true
```

---

## 3. Cooldown de versiones nuevas

**Vector**: paquete malicioso publicado, instalado en <3 horas. LiteLLM/Telnyx (Marzo 2026): 119k+ descargas maliciosas en <3h. TanStack: propagation en horas.

**Mitigacion**:

```bash
# npm — 3 dias minimo
npm config set min-release-age 3

# pnpm 10.16+ — 14 dias (20160 minutos)
# pnpm-workspace.yaml
minimumReleaseAge: 20160

# Bun 1.3+ — 3 dias (259200 segundos)
# bunfig.toml
minimumReleaseAge = 259200

# Yarn 4.10+
# .yarnrc.yml
npmMinimalAgeGate: "3d"
```

**Dependabot** (`.github/dependabot.yml`):

```yaml
cooldown:
  default-days: 7
  semver-major-days: 7
  semver-minor-days: 7
  semver-patch-days: 7
```

**Renovate**: `minimumReleaseAge` option.

---

## 4. Lockfile integrity

**Vector**: PR malicioso modifica `resolved` URL e `integrity` hash en lockfile. Package instalado desde servidor del atacante con hash que matchea el payload malicioso.

**Mitigacion**:

```bash
npm install --save-dev lockfile-lint

# package.json
{
  "scripts": {
    "lint:lockfile": "lockfile-lint --path package-lock.json --type npm --allowed-hosts npm --validate-https"
  }
}

npx lockfile-lint --path package-lock.json --type npm --allowed-hosts npm yarn --validate-https
```

pnpm no es susceptible a este vector por diseño del lockfile.

---

## 5. Instalacion determinista

```bash
npm ci                        # respeta lockfile, no ejecuta postinstall
npm ci --only=production      # CI/CD

yarn install --immutable --immutable-cache
pnpm install --frozen-lockfile
bun install --frozen-lockfile
```

**Siempre commitear lockfiles** (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`).

---

## 6. Pre-auditar paquetes antes de instalar

### npq — firewall pre-install

```bash
npm install -g npq
npq install express --dry-run
alias npm='npq-hero'

# Cross-manager:
NPQ_PKG_MGR=pnpm npq install fastify
NPQ_PKG_MGR=bun npq install fastify

# Deshabilitar checks especificos:
MARSHALL_DISABLE_SNYK=1 npq install express
```

Checks: vulnerabilidades (Snyk), edad del paquete, typosquatting, provenance, binarios nuevos, scripts de install, trampoline maintenance.

### Socket Firewall (sfw)

```bash
npm install -g sfw
sfw npm install express
sfw pnpm add express
sfw pip install requests
```

Firewall en tiempo real. Intercepta comandos del package manager. Bloquea paquetes flaggeados por analisis profundo de Socket.

---

## 7. No upgrades ciegos

**Vector**: `npm update` masivo. Ataques: colors.js (2022), node-ipc (2022) — maintainers legítimos insertaron malware en nuevas versiones.

**Alternativas**:

```bash
npx npm-check-updates --interactive
```

Dependabot/Snyk/Renovate con cooldown configurado.

---

## 8. Hardening de npx

**Vector**: `npx` descarga y ejecuta paquetes sin verificacion. Si el paquete esta comprometido, ejecucion inmediata.

**Mitigacion**: pre-instalar en workspace lockfile-verificado, forzar offline.

```bash
mkdir -p $HOME/mcp && cd $HOME/mcp
npm init -y
npm install @modelcontextprotocol/server-filesystem
npx --include-workspace-root --workspace $HOME/mcp --no --offline @modelcontextprotocol/server-filesystem /path
```

**MCP server config**:

```json
{
  "command": "npx",
  "args": ["--include-workspace-root", "--workspace", "$HOME/mcp", "--no", "--offline", "..."]
}
```

---

## 9. No secrets en .env

**Vector**: `.env` con plaintext secrets. Commit accidental = secret expuesto. Rotacion manual.

**Alternativas**:

```bash
# .env — referencias, no valores
DATABASE_PASSWORD=op://vault/database/password
API_KEY=infisical://project/env/api-key

# Runtime injection
op run -- npm start
op run --env-file="./.env" -- node --env-file="./.env" server.js
```

Usar 1Password CLI, Infisical, Doppler, HashiCorp Vault.

---

## 10. Reducir arbol de dependencias

**Vector**: cada dependencia = superficie de ataque. `node_modules` promedio tiene >1000 paquetes.

**Principio**: preferir built-ins de Node/JavaScript sobre dependencias externas.

```js
// En vez de lodash.uniq
const unique = [...new Set(array)];

// En vez de axios (si no necesitas interceptores)
const response = await fetch(url);

// En vez de lodash.isempty
const isEmpty = obj => Object.keys(obj).length === 0;

// En vez de left-pad
const padded = str.padStart(10);
```

---

## 11. Verificar paquete antes de instalar

**Vector**: la pagina de npmjs.com omite dependencias git/HTTPS. El codigo mostrado puede diferir del tarball instalado.

```bash
npm pack <pkg> --dry-run        # inspeccionar antes de instalar
npm pack <pkg> && tar -tzf <pkg>-<version>.tgz  # revisar contenido real
```

---

## 12. Prevenir dependency confusion

**Vector**: atacante publica en registry publico un paquete con mismo nombre que tu paquete interno, version mas alta. El resolver lo elige.

**Mitigacion**:

- Usar scoped names: `@tuempresa/herramienta-interna`
- `.npmrc`:
  ```
  @tuempresa:registry=https://npm.tuempresa.com/
  ```
- Yarn (`.yarnrc.yml`):
  ```yaml
  npmScopes:
    tuempresa:
      npmRegistryServer: "https://npm.tuempresa.com/"
  ```
- Claimear nombres internos unscoped como placeholders en registry publico

---

## 13. 2FA en cuenta npm

```bash
npm profile enable-2fa auth-and-writes   # publicacion
npm profile enable-2fa auth-only         # solo login
```

---

## 14. Publicar con provenance

```yaml
# GitHub Actions
permissions:
  id-token: write
steps:
  - run: npm publish --provenance
```

Prueba criptografica de origen del build. Requiere npm CLI 9.5.0+.

---

## 15. Publicar con OIDC

Elimina tokens long-lived. Trusted publishing con tokens short-lived scoped a workflows especificos. Configurar en npmjs.com → Trusted Publishers.

---

## 16. Consultar Snyk Security Database

Antes de adoptar un paquete: `https://security.snyk.io/package/npm/<nombre>`

Evaluar: health score, security, popularity, maintenance, community.

---

## 17. pnpm trust policy

**Vector**: paquete publicado con OIDC/provenance de repente se publica sin eso. Señal de takeover.

```yaml
# pnpm-workspace.yaml (pnpm 10.21+)
trustPolicy: no-downgrade
trustPolicyExclude:
  - 'chokidar@4.0.3'
trustPolicyIgnoreAfter: 43200  # minutos (pnpm 10.27+)
```

---

## Reglas para OpenCode

1. **`npm install` / `npm i` requiere confirmacion explicita.**
2. **`npm install -g` BLOQUEADO.** Usar `npx` o `pnpm dlx`.
3. **`npm ci` preferido** para instalaciones deterministas.
4. **Preferir `pnpm`** como package manager default (bloquea postinstall por defecto).
5. **Siempre verificar `package.json`/lockfile** antes de sugerir install.
6. **Nunca commitear secrets.** Usar referencias a vault.
7. **Lockfile siempre commitado.**
8. **Auditar antes de instalar:** `npq --dry-run` para paquetes nuevos.
9. **Cooldown de 3 dias** para paquetes nuevos.
