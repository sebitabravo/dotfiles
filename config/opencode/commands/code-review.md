---
description: "Review code changes: staged diff, quality, security, and architecture assessment"
---

Perform a thorough code review of: ${ARGUMENTS:-staged changes}

1. **Scope**: `git diff --staged` (or specified range). If no staged changes, use `git diff HEAD~1`.
2. **Delegate** to `code-reviewer` agent with the diff.
3. **Check**:
   - Code correctness and edge cases
   - Security vulnerabilities (OWASP, injection, auth)
   - Performance implications
   - Test coverage for changed logic
   - Naming, readability, adherence to project style
4. **Report**:
   - Severity per finding (Critical/High/Medium/Low/Info)
   - Requirement coverage if requirements exist
   - Verdict: approve / changes-requested / block

Always use the `code-reviewer` agent for non-trivial reviews. For 1-line fixes, review inline.
