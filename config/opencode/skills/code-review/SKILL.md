---
name: code-review
description: Systematic code review for correctness, security, performance, and maintainability. Use before merging PRs, after completing features, or when asked to review code.
---

# Code Review

Systematic code review. One pass per dimension, not a general glance.

## When to Use

- PR ready for review.
- Feature just completed.
- User asks "review this", "check my code", "code review".
- Before a significant commit.

## Review Dimensions

Review in this order. Each dimension is an independent pass:

### 1. Correctness
- Does it do what it should? Read the diff against requirements.
- Edge cases: null, empty, boundaries, timeouts, network errors.
- Race conditions if there's concurrent/async code.
- Off-by-one errors, inverted conditions.

### 2. Security
- Input validated and sanitized.
- SQL injection, XSS, path traversal.
- Secrets absent from the diff.
- Auth and authorization on new routes.
- Rate limiting on public endpoints.

### 3. Performance
- N+1 queries: loops with DB calls.
- Blocking operations on event loop (sync I/O in Node/Python async).
- Memory: large arrays/objects unnecessarily, leaks in event listeners.
- Indexes needed for new queries.

### 4. Maintainability
- Clear and consistent names.
- Single-responsibility functions.
- No premature abstractions.
- No commented-out code or dead code.
- Testability: can this be tested easily?

### 5. Testing
- Tests for the happy path.
- Tests for at least 2 edge cases.
- Tests for error behavior.
- No tests that depend on execution order or mutable global state.

## Output

Emit findings in this format:

```
path:line: <severity> <problem>. <fix suggestion>.
```

Severities: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`.

Don't emit praise. Don't comment on formatting if the linter covers it. Only actionable findings.
