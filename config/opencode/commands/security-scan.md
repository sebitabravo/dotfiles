---
description: "Run a comprehensive security audit: dependency scan, secret detection, OWASP check, and permission review"
---

Execute a full security scan of the current project:

1. **Dependency audit**: Run the audit command declared by the project (`npm audit` or `bun audit` or `pnpm audit` or `pip audit` for JavaScript projects).
2. **Secret detection**: Scan for hardcoded secrets, API keys, tokens in source files
3. **OWASP quick check**: Review auth patterns, input validation, error handling for top 10 vulnerabilities
4. **Permission review**: Check file permissions, .gitignore coverage, sensitive file exposure
5. **Supply chain**: Verify lockfile integrity, check for git dependencies, validate provenance

Project: ${ARGUMENTS:-current directory}

Report format:

- Severity: Critical / High / Medium / Low / Info
- Per finding: description, file:line, remediation
- Executive summary with risk score
