---
description: "Testing requirements and patterns"
globs: []
alwaysApply: true
---

# Testing

## Rules

- **Every new feature requires tests**. No exceptions.
- **Every bug fix requires a regression test** that fails without the fix.
- **Tests must be deterministic**. No `Math.random()`, no real-time dependencies.
- **Fast tests**. If a test takes >2s, mock the slow dependency.
- **No tests that depend on execution order**. Each test runs in isolation.

## What to test

1. **Black box** for business logic — expected inputs and outputs.
2. **Edge cases**: empty, null, boundaries, special characters.
3. **Errors**: what happens when things fail, not just the happy path.
4. **API contracts**: response schema, status codes, headers.

## What NOT to test

- Internal implementation (private methods, algorithm details that don't affect output).
- Framework code (routing, basic ORM, framework serialization).
- Tests of tests (don't test mocks, fixtures, or test helpers).

## Structure

- One test file per module/component.
- `describe` nests scenarios. `it` describes the specific case.
- Test names describe expected behavior, not implementation.
  - Good: `it("returns 404 when user does not exist")`
  - Bad: `it("test getUser with invalid id")`
