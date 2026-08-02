# Security

## Restricted zones (never read, print, or exfiltrate)

- **Secrets**: `.env` and any `.env.*`, `secrets/`, `credentials.json`.
- **Keys**: SSH private keys (`id_rsa`, `id_ed25519`, ...).
- **Certs**: `.pem`, `.key`, `.ppk`, `.p12`, `.pfx`, `.pvk`.
- **Noise** (don't waste tokens): `node_modules/`, `.git/objects/`, `.DS_Store`, `Thumbs.db`.

`permissions.deny` in `settings.json` blocks the `Read` tool on most of these, but it does NOT cover shelling out — `cat .env` bypasses the rule entirely. The deny list is a backstop, not the boundary. The boundary is this rule.

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

## Dependencies & supply chain

- Before installing: verify the package is legitimate (typo-squatting).
- Keep dependencies updated. `npm audit`, `pip audit`, `cargo audit`.
- Minimum necessary amount. Fewer dependencies = smaller attack surface.
- `npm install` / `npm i` requires explicit confirmation. Prefer `npm ci`.
- `npm install -g` is BLOCKED. Use `npx` or `pnpm dlx`.
- Prefer `pnpm` as default package manager (blocks postinstall by default).
- 3-day cooldown before adopting a newly published version.
- Audit before installing a new package: `npq --dry-run`.
- Full 17-practice hardening guide: invoke the `npm-security` skill.

## Autonomy bias

- **Routine safe actions** (reading, searching, focused verification, small requested edits): proceed and report the result.
- **Destructive, irreversible, or remote actions**: STOP and confirm. Full protocol with blast radius, rollback plan, and backup verification in `rules/common/destructive-operations.md`.
- When in doubt, prefer safe local verification first and ask before anything irreversible.
