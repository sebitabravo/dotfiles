---
description: "Scan the current diff or files for security vulnerabilities"
---

Run a security scan on ${ARGUMENTS:-the current diff}.

Uses the `security-review` skill.

Check for:
- Exposed secrets (API keys, tokens, passwords).
- SQL injection, XSS, command injection.
- Auth and authorization on new routes.
- Dependencies with known vulnerabilities.
- No PII in logs or responses.

Emit report with severities: CRITICAL (blocks deploy), HIGH, MEDIUM, Pass.
