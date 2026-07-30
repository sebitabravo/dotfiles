# BDD / Gherkin

## When to apply

- **Complex features with business logic** (domain rules, multi-step flows, business edge cases).
- **Do NOT apply to**: internal utilities, helpers, trivial CRUD, purely technical refactors.
- If the feature fits in 1-2 simple `it()` blocks, it does not need Gherkin.

## Gherkin structure

```gherkin
Feature: <descriptive name>
  As a <role>
  I want <action>
  So that <benefit>

  Scenario: <specific case>
    Given <precondition>
    When <action>
    Then <expected result>
    And <optional postcondition>
```

## Rules

- **One Scenario = one behavior**. Do not combine multiple behaviors in one Scenario.
- **Given** describes initial state, NOT actions. Max 3 Givens per Scenario.
- **When** describes ONE action. Multiple actions means separate Scenarios.
- **Then** describes observable results, NOT implementation.
- **Background** for shared preconditions across Scenarios in the same Feature.
- **Scenario Outline** + `Examples` table for parameterized cases.
- Feature and Scenario names in business language, not technical.
  - Good: `Scenario: Customer cannot checkout with insufficient balance`
  - Bad: `Scenario: Test checkout function with negative balance`

## Mapping to tests

- One `.feature` file per Feature.
- Step definitions in a separate file (`*.steps.ts`, `*_steps.py`, etc).
- One step definition = one function. Reuse steps across Scenarios.
- Do NOT test implementation details in steps. Only observable input/output.
- Steps must be deterministic. Mock time, network, and external dependencies.

## File structure

```
features/
  checkout.feature
  auth.feature
  search.feature
features/step_definitions/
  checkout.steps.ts
  auth.steps.ts
  search.steps.ts
```

Or per project framework convention (Cucumber, Behave, pytest-bdd, CodeceptJS).

## Anti-patterns

- **Gherkin as decoration**: writing `.feature` after the test to "comply". If you already wrote the test, the `.feature` adds no value.
- **Steps with business logic**: steps should be literal translations of Gherkin, not contain complex if/else/loops. Logic lives in production code.
- **Given with actions**: `Given` is NOT `When`. If you do something in `Given`, it is a `When` in disguise.
- **Then about implementation**: `Then the method returns true` is an implementation test. `Then the user sees the error message` is a behavior test.
- **Giant feature files**: more than 10 Scenarios = probably 2 Features. Split.