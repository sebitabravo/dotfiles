---
name: security-review
description: Complete a security review of pending changes. Audits for OWASP Top 10 vulnerabilities, exposed secrets, injection risks, auth bypasses, and dependency issues. Use on git diffs, PRs, or before deployment.
---

# Security Review

Security review focused on pending changes. Systematic audit, not theoretical.

## When to Use

- Before merging a PR.
- When modifying auth, routes, DB queries, or user input.
- When the user asks for "security review", "audit", "check security".
- Post-incident, to verify the fix doesn't introduce new vulnerabilities.

## Checklist

### Secrets & Credentials
- No API keys, tokens, passwords in the diff.
- No URLs with embedded credentials.
- Environment variables referenced, never hardcoded.

### Injection
- SQL: prepared statements or query builder with bound parameters. Never concatenation.
- XSS: output escaped in HTML/JSX. `dangerouslySetInnerHTML` only with explicit sanitization.
- Command: no `exec()`, `system()`, `subprocess` with user strings.
- Path traversal: no concatenating user input into file paths.

### Authentication & Authorization
- Auth middleware on all protected routes.
- Roles/permissions verified on the backend, not just frontend.
- JWT: expiration configured, separate refresh token.

### Data Exposure
- No PII in logs or error responses.
- No stack traces in production.
- Rate limiting on public endpoints.

### Dependencies
- New dependencies: verified, legitimate, maintained.
- No `*` in package.json/requirements.txt versions.

## Output

Emit at completion:

```
## Security Review: [branch/PR]

### Critical (blocks deploy)
- [findings]

### High
- [findings]

### Medium
- [findings]

### Pass
- [passed checks]

Security: [X]/100
```
