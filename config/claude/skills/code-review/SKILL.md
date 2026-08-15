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

### 5. Structure and design
- **1k line rule**: a PR should not push a file from <1k to >1k lines without strong justification. If it crosses, propose decomposing first.
- **Anti-spaghetti growth**: new ad-hoc conditionals, scattered special cases or one-off branches in unrelated flows = design flag, not a nit.
- **Radical simplification**: if the behavior can be kept with fewer concepts, branches or layers, look for that path. Prefer the refactor that DELETES complexity over the one that moves it.
- **Boring over magic**: distrust wrappers/identity helpers/pass-throughs that add indirection without buying clarity.
- **Logic in the right layer**: feature logic should not leak into shared paths. Use canonical utilities instead of one-offs.

### 6. Testing
- Tests for the happy path.
- Tests for at least 2 edge cases.
- Tests for error behavior.
- No tests that depend on execution order or mutable global state.

## Precision gate

Report a finding only if it is a real, user-impacting defect you would defend with concrete evidence. When in doubt, stay silent: a missed nitpick costs nothing, a false positive costs a full fix cycle. Style and preference findings are banned unless they obscure a defect.

One exhaustive pass over the diff, then stop. A second pass only for hot paths (auth, payments, migrations, concurrency) or diffs over 400 changed lines. There is no loop-until-dry.

## Output

Emit findings in this format:

```
path:line: <severity> <problem>. <fix suggestion>.
```

Severities: `BLOCKER`, `CRITICAL`, `WARNING`, `SUGGESTION`.

Only BLOCKER and CRITICAL drive fixes. WARNING and SUGGESTION are reported once as informational and never block a merge.

Don't emit praise. Don't comment on formatting if the linter covers it. Only actionable findings.
