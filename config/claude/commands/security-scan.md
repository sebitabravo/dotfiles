---
description: "Full security audit: dependencies, secrets, OWASP and permissions"
argument-hint: "[project path | empty = current directory]"
---

Run a full security scan of: $ARGUMENTS (if empty, the current directory).

1. **Dependency audit**: run the project runner's audit (`npm audit`, `bun audit`, `pnpm audit`, or `pip-audit`).
2. **Secret detection**: look for hardcoded secrets, API keys and tokens in source files.
3. **OWASP quick check**: review auth patterns, input validation and error handling against the top 10.
4. **Permission review**: file permissions, .gitignore coverage, exposure of sensitive files.
5. **Supply chain**: lockfile integrity, git dependencies, provenance (use the `npm-security` skill for JS/TS projects).

## Agents

Spawn **`vulnerability-hunter` always**: it is the only one with the scanning
tools in its allowlist (`semgrep`, `gitleaks`, `bandit`, `npm audit`,
`pip-audit`, `trivy`, plus binary analysis), so it is the one that executes
steps 1, 2 and the verifiable part of 5. The other agents can only opine on
those points; this one runs them.

Add `security-auditor` in parallel when the project is non-trivial or step 3
matters: it brings the threat model, OWASP and auth architecture lens, which is
design judgment and does not come out of a scanner.

If a tool is not installed on the host, report that stage as **not executed**.
A missing scanner is not a clean finding: presenting it as green is worse than
not running it, because it buys confidence nobody verified.

Report format:
- Severity: Critical / High / Medium / Low / Info
- Per finding: description, file:line, remediation
- Executive summary with risk score
