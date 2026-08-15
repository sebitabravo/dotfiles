---
description: "Review code changes: diff, quality, security and architecture"
argument-hint: "[diff range | files | empty = staged]"
---

Perform an exhaustive code review of: $ARGUMENTS (if empty, use `git diff --staged`; if nothing is staged, `git diff HEAD~1`).

Process:
1. **Scope**: determine the exact diff to review.
2. **Delegate** to the `code-reviewer` agent with the diff.
3. **Check**:
   - Correctness and edge cases
   - Security vulnerabilities (OWASP, injection, auth)
   - Performance implications
   - Test coverage of the changed logic
   - Naming, readability, adherence to the project style
4. **Report**:
   - Severity per finding (Critical/High/Medium/Low/Info)
   - Requirements coverage when requirements exist
   - Verdict: approve / changes-requested / block

Always use the `code-reviewer` agent for non-trivial reviews. For 1-line fixes, review inline.
