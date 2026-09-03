# Security

## Restricted zones (never read, print, or exfiltrate)

- **Secrets**: `.env` and any `.env.*`, `secrets/`, `credentials.json`.
- **Keys**: SSH private keys (`id_rsa`, `id_ed25519`, ...).
- **Certs**: `.pem`, `.key`, `.ppk`, `.p12`, `.pfx`, `.pvk`.
- **Noise** (don't waste tokens): `node_modules/`, `.git/objects/`, `.DS_Store`, `Thumbs.db`.

`permissions.deny` in `settings.json` blocks the `Read` tool on most of these, and `validate-safe-ops.sh` denies the same targets through Bash, so `cat .env` is stopped on both paths. Neither one is the boundary. Both match patterns, and a rule that only exists as a pattern is one unlisted path, one new file name, or one `base64 -d` away from being silent. The boundary is this rule.

## Non-negotiable

- **Never commit secrets**. API keys, tokens, passwords = `.env` or vault.
- **ALWAYS validate user input**. Backend-side, even if frontend validates.
- **Sanitize output**. XSS prevention. Escape before rendering.
- **Prepared statements for SQL**. Never concatenate queries with user input.
- **HTTPS in production**. HTTP only for local development.

## Severity levels

| Level | Condition | Action |
| --- | --- | --- |
| **Critical** | Secret exposed in code/commit | Rotate immediately, purge git history |
| **High** | SQL injection, XSS, auth bypass | Fix before deploy |
| **Medium** | Vulnerable dependency, missing rate limiting | Fix this iteration |

## When generating code

- Never generate tokens, passwords, or example secrets (not even "test_sk_123").
- Use environment variables or obvious placeholders: `$API_KEY`, `<your-api-key>`.
- Never use obsolete cryptographic algorithms: MD5, SHA1, DES, RC4.
- Never use `eval()`, `exec()`, `Function()`, `system()` with dynamic strings.

## Dependencies & supply chain

- Before installing: verify the package is legitimate (typo-squatting).
- Keep dependencies updated. Use the audit script declared by the project; for
  JavaScript projects prefer `npm audit` or `bun audit` or `cargo audit` or `pip-audit`.
- Minimum necessary amount. Fewer dependencies = smaller attack surface.
- **Package manager preference: `bun` > `pnpm` > `npm`.** Both bun and pnpm 10+
  block lifecycle scripts by default and support a publish-age cooldown, which is
  why they come first.
- **An existing project's lockfile overrides that preference and is not yours to
  change.** `bun.lock` means bun, `pnpm-lock.yaml` means pnpm, `package-lock.json`
  means npm, `uv.lock` means uv. Switching re-resolves the entire dependency tree,
  which is itself a supply-chain event. Client and employer repos pinned to npm
  stay on npm.
- `npm install` / `npm i` requires explicit confirmation. Prefer `npm ci`.
- `npm install -g` is BLOCKED. Use `npx`, `pnpm dlx`, `bunx`, or a project-local
  `npm exec`.
- When a project forces npm, the hardening in `~/.npmrc` is what replaces what
  bun/pnpm give for free: `ignore-scripts=true`, `allow-git=none`,
  `min-release-age=3`. Never override those per-project. npm 12+ blocks install
  scripts by default; until this host runs 12+, that `.npmrc` is the equivalent.
- 3-day cooldown before adopting a newly published version.
- Audit before installing a new package: `npq --dry-run`.
- Full 17-practice hardening guide: invoke the `npm-security` skill.

## Autonomy bias

- **Routine safe actions** (reading, searching, focused verification, small requested edits): proceed and report the result.
- **Destructive, irreversible, or remote actions**: STOP and confirm. Full protocol with blast radius, rollback plan, and backup verification in `rules/common/destructive-operations.md`.
- When in doubt, prefer safe local verification first and ask before anything irreversible.
