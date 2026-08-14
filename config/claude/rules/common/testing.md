# Testing

## When a test goes red: diagnosis order

**The test is right until proven otherwise.** It is the only part of the repo that encodes what the system MUST do; the code only says what it does today. When they disagree, the default suspect is the code.

Walk the hypotheses **in this order** and skip none:

1. **Is the new code wrong?** This is the case the vast majority of the time. Read the assert, understand which behavior it expected, fix the code to satisfy it. **Do not touch the test.**
2. **Is the code fine but it broke a contract other code relied on?** The test is flagging a real side effect. Adapt your implementation so it holds, or bring it to the conversation if the contract genuinely has to change.
3. **Is the test flaky, not wrong?** Order-dependent, clock-dependent, stale mock, busy port. Fix the flakiness **without touching what it verifies**. A test that starts verifying less was not fixed, it was muted.
4. **Is the test itself wrong?** Only here. It happens: an assert that encoded a misunderstanding, or a requirement that truly changed. **STOP AND ASK FOR AUTHORIZATION**, stating which test, why you believe it is wrong, and what it covers after the change.

**Never jump straight to 4 because it is the shortest path to green.** If the first instinct is to edit the assert, it almost always means you have not understood why it fails yet.

**Green is not the goal, it is the evidence.** A commented-out test, a `skip`, a relaxed assert or an inflated timeout produce the same green as a passing test — which is exactly why green alone does not count as proof.

## Before saying "done"

Three questions. Any "no" means you are not finished:

1. **Did I run the tests after the last change?** Not before: after. A change made after the run invalidates the run.
2. **Did I see the result with my own eyes, or assume it?** "Should pass" is not a run.
3. **If the change is visible (UI, layout, text, styling), did I look at it?** A visual change is verified by seeing it — screenshot or browser. Deducing that a layout is fine because the CSS "looks right" is what turns one fix into twenty round-trips.

## Rules

- **ALL code requires tests. No exceptions.** Even a "hello world" has a test verifying it returns "hello world". The goal is code built to the highest standard with no errors, and tests are the only evidence of that.
- **Every bug fix requires a regression test** that fails without the fix.
- **Tests must be deterministic**. No `Math.random()`, no real-time dependencies.
- **Fast tests**. If a test takes >2s, mock the slow dependency.
- **No tests that depend on execution order**. Each test runs in isolation.
- **If the project has no test runner configured, configure it BEFORE writing code**. No test runner is not an excuse to skip tests.

## What requires tests

- **ALL production code**: functions, endpoints, components, utilities, helpers, scripts.
- **Trivial code too**: a `hello()` returning "hello" has a test `expect(hello()).toBe("hello")`.
- **Config that affects behavior**: if it changes how the system behaves, it has a test.
- **Bug fixes**: regression test that fails without the fix.

## What does NOT require tests

- **Documentation** (README, comments, ADRs).
- **Static config** that does not affect behavior (format, style, metadata).
- **CI/infra config** (workflows, dependabot, deploy YAML, lockfiles): no se testea con unit tests; se valida con linters (actionlint) y con la corrida de CI misma.
- **Generated code** (ORM models, protobuf, OpenAPI stubs).
- **Tests of tests** (do not test mocks, fixtures, or test helpers).

## What to test

1. **Black box** for business logic — expected inputs and outputs.
2. **Edge cases**: empty, null, boundaries, special characters.
3. **Errors**: what happens when things fail, not just the happy path.
4. **API contracts**: response schema, status codes, headers.
5. **Trivial cases**: the simplest happy path. If `add(1, 1)` should return `2`, there is a test that verifies it.

## Structure

- One test file per module/component.
- `describe` nests scenarios. `it` describes the specific case.
- Test names describe expected behavior, not implementation.
  - Good: `it("returns 404 when user does not exist")`
  - Bad: `it("test getUser with invalid id")`

## Coverage

- **Line coverage >= 80%**. Non-negotiable floor for production code.
- **Branch coverage >= 70%**. More important than line coverage.
- **Function coverage >= 90%**. Every public function must have at least one test.
- 100% coverage is NOT the goal. Coverage measures execution, not quality. Invoke the `mutation-testing` skill.
- Exclude from coverage: tests, mocks, fixtures, config, migrations, generated code.
- Invoke the `quality-metrics` skill for full thresholds and tools by language.

## BDD / Gherkin

- Complex features with business logic require tests in Gherkin format (`.feature`).
- Do NOT apply to internal utilities, trivial CRUD, or purely technical refactors.
- Invoke the `bdd-gherkin` skill for full rules and the workflow.

## Mutation Testing

- Mutation testing measures test QUALITY, not just coverage.
- **Mutation score >= 80%** on critical features.
- Run in CI, not on every commit (it's expensive).
- Invoke the `mutation-testing` skill for full rules and configuration.
