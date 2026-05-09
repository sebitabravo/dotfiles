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
