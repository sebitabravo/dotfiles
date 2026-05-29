---
name: caveman-review
description: Auto-skill for code review that analyzes diffs for quality, security, architecture, and correctness issues. Triggers on PR review requests.
---

## Review Checklist

### 1. Correctness
- Does the code do what the PR description says?
- Are edge cases handled? (null, empty, boundary values)
- Are error paths covered?
- Is there off-by-one or logic errors?

### 2. Security
- SQL injection? (string interpolation in queries)
- XSS? (unsanitized user input in HTML)
- Auth checks present on all endpoints?
- Secrets in code?
- Input validation at boundaries?

### 3. Architecture
- Follows existing patterns in codebase?
- SOLID principles respected?
- No god functions (>50 lines, >3 responsibilities)?
- Proper separation of concerns?
- No circular dependencies?

### 4. Performance
- N+1 queries? (loop with DB call)
- Unnecessary re-renders? (React)
- Missing indexes? (DB)
- Unbounded queries? (no pagination)
- Memory leaks? (event listeners not cleaned up)

### 5. Testing
- New code has tests?
- Tests cover happy path AND error paths?
- No flaky tests (time-dependent, order-dependent)?
- Mocks testing behavior, not implementation?

### 6. Style
- Consistent with codebase conventions?
- No unnecessary changes (drive-by refactors)?
- Meaningful variable/function names?
- No dead code or commented-out code?

## Review Output Format

```
## Summary
[1-2 sentence description of what this PR does]

## Issues Found

### CRITICAL (must fix before merge)
- [file:line] Description of critical issue

### IMPORTANT (should fix)
- [file:line] Description

### SUGGESTION (nice to have)
- [file:line] Description

## Positive Notes
- [What was done well]
```

## Rules

- Review the diff, not the whole file. Focus on what changed.
- CRITICAL = security vulnerability, data loss, breaking bug.
- IMPORTANT = potential bug, missing error handling, test gap.
- SUGGESTION = style, naming, minor improvement.
- Always comment on security findings with severity and fix.
- Flag drive-by refactors. PRs should be atomic.
- Verify the PR does what the description claims.
- No "looks good to me" without reading the diff.
