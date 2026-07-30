---
name: bdd-gherkin
description: Behavior-Driven Development with Gherkin. Write .feature files with Given-When-Then, map step definitions, and generate stakeholder-readable tests. Use when a feature has complex business logic, domain rules, or multi-step flows that need living documentation.
---

# BDD with Gherkin

## When to use this skill

Activate when:
- A feature has **complex business rules** (discounts, permissions, workflows, state machines)
- There are **multi-step flows** with multiple actors (checkout, approval, onboarding)
- The **stakeholder needs to validate** expected behavior before code
- There are **business edge cases** that are not obvious to developers

Do NOT use when:
- It's an internal utility, helper, or trivial CRUD
- The feature fits in 1-2 simple `it()` blocks
- It's a purely technical refactor with no behavior change

## BDD Flow

1. **Write Feature file** (`.feature`) in business language
2. **Validate with stakeholder** (if applicable) that scenarios cover expected behavior
3. **Write step definitions** that translate Gherkin to test code
4. **Implement production code** until all scenarios pass
5. **Refactor** while keeping scenarios green

## Gherkin Structure

```gherkin
Feature: Volume discount
  As a wholesale buyer
  I want to apply discounts based on quantity
  To pay less on large orders

  Background:
    Given a catalog with the following products
      | sku  | name       | price |
      | A001 | Widget     | 10.00 |
      | A002 | Gadget     | 25.00 |

  Scenario: 10% discount for buying 10+ units
    Given the cart has 10 units of "A001"
    When I apply discounts
    Then the total should be 90.00
    And the applied discount should be 10.00

  Scenario Outline: Tiered discounts
    Given the cart has <quantity> units of "A001"
    When I apply discounts
    Then the discount should be <discount>%

    Examples:
      | quantity | discount |
      | 5        | 0        |
      | 10       | 10       |
      | 50       | 15       |
      | 100      | 20       |
```

## Step definition rules

- **One step = one function**. Reuse across scenarios.
- **No business logic in steps**: steps translate Gherkin to API/function calls. Logic lives in production.
  ```ts
  // Good: step delegates to domain
  When('I apply discounts', async () => {
    cart = await discountService.apply(cart);
  });

  // Bad: step contains business logic
  When('I apply discounts', async () => {
    if (cart.items.length >= 10) {
      cart.total *= 0.9;  // NO: discount logic lives here
    }
  });
  ```
- **Assertions in Then, not in Given/When**.
- **Determinism**: mock time, network, and external dependencies.

## Frameworks by language

| Language | Framework | Setup |
|---|---|---|
| JavaScript/TypeScript | Cucumber.js | `npm i -D @cucumber/cucumber` |
| Python | Behave | `pip install behave` |
| Python (alt) | pytest-bdd | `pip install pytest-bdd` |
| Go | godog | `go get github.com/cucumber/godog` |
| Java | Cucumber JVM | `pom.xml` with cucumber-jvm |
| Ruby | Cucumber Ruby | `gem install cucumber` |
| PHP | Behat | `composer require behat/behat` |

## File structure

```
features/
  discount.feature
  checkout.feature
  auth.feature
features/step_definitions/
  discount.steps.ts
  checkout.steps.ts
  auth.steps.ts
features/support/
  world.ts          # shared context
  hooks.ts          # before/after
```

## Anti-patterns to avoid

1. **Gherkin as decoration**: writing `.feature` after the test to "comply". If you already wrote the test, the `.feature` adds no value.
2. **Steps with if/else**: if a step has conditional logic, it's business logic that belongs in production code.
3. **Given with actions**: `Given` describes state, `When` describes action. Do not mix.
4. **Then about implementation**: `Then the method returns true` is an implementation test. `Then the user sees the error message` is a behavior test.
5. **Giant feature**: more than 10 scenarios = probably 2 features. Split.
6. **UI-coupled steps**: if steps depend on CSS selectors, they are fragile. Prefer API or domain-level steps.

## SDD Integration

In the SDD flow, `.feature` files are written in the **Spec** phase (along with user stories in GWT format). Step definitions are written in the **Apply** phase (TDD).

See `rules/common/bdd.md` for the full rules.