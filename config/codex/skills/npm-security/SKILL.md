---
name: npm-security
description: NPM supply chain hardening — 17 practices covering postinstall blocking, git dependency bans, version cooldown, lockfile integrity, dependency confusion, provenance, and 2FA. Use when installing packages, auditing dependencies, configuring a package manager, reviewing a lockfile, or responding to a supply chain advisory.
---

# NPM Security — Supply Chain Hardening

Based on [lirantal/npm-security-best-practices](https://github.com/lirantal/npm-security-best-practices). 17 practices. Each one: what it protects, how it is exploited, how to mitigate.

---

## 1. Block postinstall scripts

**Vector**: `postinstall` runs arbitrary code on install. Attacks: Shai-Hulud (2025), Nx (2025), event-stream (2018), TanStack (May 2026 — 42 packages, 84 versions).

**Mitigation**:

```bash
# Global — blocks ALL lifecycle scripts
npm config set ignore-scripts true

# Per-install
npm install --ignore-scripts <pkg>

# pnpm (v10+): blocks by default. Explicit allow-list:
# pnpm-workspace.yaml
onlyBuiltDependencies:
  - esbuild
  - sharp

# Bun: blocks by default. trustedDependencies in package.json:
{
  "trustedDependencies": ["esbuild", "sharp"]
}
```

**npm install / npm i requires explicit confirmation.** Prefer `npm ci`.

---

## 2. Block git dependencies

**Vector**: `"dep": "git+https://malicious.com/repo.git"` in package.json. Bypasses the registry, evades security scanning, may include `.npmrc` that re-enables lifecycle scripts.

**Mitigation** (npm CLI 11.10.0+):

```bash
npm config set allow-git none

# pnpm 10.26+ — blocks exotic subdependencies (git, tarball URLs):
# pnpm-workspace.yaml
blockExoticSubdeps: true
```

---

## 3. Cooldown on new versions

**Vector**: malicious package published, installed within <3 hours. LiteLLM/Telnyx (March 2026): 119k+ malicious downloads in <3h. TanStack: propagation in hours.

**Mitigation**:

```bash
# npm — 3 days minimum
npm config set min-release-age 3

# pnpm 10.16+ — 14 days (20160 minutes)
# pnpm-workspace.yaml
minimumReleaseAge: 20160

# Bun 1.3+ — 3 days (259200 seconds)
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

**Vector**: malicious PR modifies the `resolved` URL and `integrity` hash in the lockfile. Package installed from the attacker's server with a hash that matches the malicious payload.

**Mitigation**:

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

pnpm is not susceptible to this vector by lockfile design.

---

## 5. Deterministic installation

```bash
npm ci                        # respects lockfile, does not run postinstall
npm ci --only=production      # CI/CD

yarn install --immutable --immutable-cache
pnpm install --frozen-lockfile
bun install --frozen-lockfile
```

**Always commit lockfiles** (`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lock`).

---

## 6. Pre-audit packages before installing

### npq — pre-install firewall

```bash
npm install -g npq
npq install express --dry-run
alias npm='npq-hero'

# Cross-manager:
NPQ_PKG_MGR=pnpm npq install fastify
NPQ_PKG_MGR=bun npq install fastify

# Disable specific checks:
MARSHALL_DISABLE_SNYK=1 npq install express
```

Checks: vulnerabilities (Snyk), package age, typosquatting, provenance, new binaries, install scripts, trampoline maintenance.

### Socket Firewall (sfw)

```bash
npm install -g sfw
sfw npm install express
sfw pnpm add express
sfw pip install requests
```

Real-time firewall. Intercepts package manager commands. Blocks packages flagged by Socket's deep analysis.

---

## 7. No blind upgrades

**Vector**: mass `npm update`. Attacks: colors.js (2022), node-ipc (2022) — legitimate maintainers inserted malware in new versions.

**Alternatives**:

```bash
npx npm-check-updates --interactive
```

Dependabot/Snyk/Renovate with cooldown configured.

---

## 8. npx hardening

**Vector**: `npx` downloads and runs packages without verification. If the package is compromised, immediate execution.

**Mitigation**: pre-install in a lockfile-verified workspace, force offline.

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

## 9. No secrets in .env

**Vector**: `.env` with plaintext secrets. Accidental commit = exposed secret. Manual rotation.

**Alternatives**:

```bash
# .env — references, not values
DATABASE_PASSWORD=op://vault/database/password
API_KEY=infisical://project/env/api-key

# Runtime injection
op run -- npm start
op run --env-file="./.env" -- node --env-file="./.env" server.js
```

Use 1Password CLI, Infisical, Doppler, HashiCorp Vault.

---

## 10. Shrink the dependency tree

**Vector**: every dependency = attack surface. An average `node_modules` has >1000 packages.

**Principle**: prefer Node/JavaScript built-ins over external dependencies.

```js
// Instead of lodash.uniq
const unique = [...new Set(array)];

// Instead of axios (if you don't need interceptors)
const response = await fetch(url);

// Instead of lodash.isempty
const isEmpty = obj => Object.keys(obj).length === 0;

// Instead of left-pad
const padded = str.padStart(10);
```

---

## 11. Verify the package before installing

**Vector**: the npmjs.com page omits git/HTTPS dependencies. The displayed code may differ from the installed tarball.

```bash
npm pack <pkg> --dry-run        # inspect before installing
npm pack <pkg> && tar -tzf <pkg>-<version>.tgz  # review actual content
```

---

## 12. Prevent dependency confusion

**Vector**: attacker publishes to the public registry a package with the same name as your internal package, with a higher version. The resolver picks it.

**Mitigation**:

- Use scoped names: `@yourcompany/internal-tool`
- `.npmrc`:
  ```
  @yourcompany:registry=https://npm.yourcompany.com/
  ```
- Yarn (`.yarnrc.yml`):
  ```yaml
  npmScopes:
    yourcompany:
      npmRegistryServer: "https://npm.yourcompany.com/"
  ```
- Claim internal unscoped names as placeholders in the public registry

---

## 13. 2FA on the npm account

```bash
npm profile enable-2fa auth-and-writes   # publishing
npm profile enable-2fa auth-only         # login only
```

---

## 14. Publish with provenance

```yaml
# GitHub Actions
permissions:
  id-token: write
steps:
  - run: npm publish --provenance
```

Cryptographic proof of build origin. Requires npm CLI 9.5.0+.

---

## 15. Publish with OIDC

Eliminates long-lived tokens. Trusted publishing with short-lived tokens scoped to specific workflows. Configure at npmjs.com → Trusted Publishers.

---

## 16. Consult the Snyk Security Database

Before adopting a package: `https://security.snyk.io/package/npm/<name>`

Evaluate: health score, security, popularity, maintenance, community.

---

## 17. pnpm trust policy

**Vector**: a package published with OIDC/provenance is suddenly published without it. Signal of takeover.

```yaml
# pnpm-workspace.yaml (pnpm 10.21+)
trustPolicy: no-downgrade
trustPolicyExclude:
  - 'chokidar@4.0.3'
trustPolicyIgnoreAfter: 43200  # minutes (pnpm 10.27+)
```

---

## Rules for Codex

1. **`npm install` / `npm i` BLOCKED without confirmation.**
2. **`npm install -g` BLOCKED.** Use `npx` or `pnpm dlx`.
3. **`npm ci` preferred** for deterministic installs.
4. **Prefer `pnpm`** as the default package manager (blocks postinstall by default).
5. **Always verify `package.json`/lockfile** before suggesting an install.
6. **Never commit secrets.** Use vault references.
7. **Lockfile always committed.**
8. **Audit before installing:** `npq --dry-run` for new packages.
9. **3-day cooldown** for new packages.
