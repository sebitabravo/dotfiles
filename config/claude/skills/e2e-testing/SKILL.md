---
name: e2e-testing
description: E2E testing with Playwright. Page Object Model, test strategy, CI integration, and regression prevention. Use when writing browser tests, designing test suites, or setting up E2E CI pipelines.
---

# E2E Testing

End-to-end testing with Playwright. Focus on user flows, not implementation details.

## When to Use

- Writing new E2E tests for a feature.
- Designing test strategy for a project.
- Setting up E2E in CI/CD.
- Debugging flaky tests or slow suites.
- User asks for "E2E tests", "Playwright", "browser tests".

## Test Strategy

### What to test (E2E)
- Critical user flows (login, checkout, onboarding).
- Multi-service interactions and API contract boundaries.
- Cross-browser regressions (Chromium + Firefox + WebKit).
- Mobile viewport (iPhone 14, Pixel 7).

### What NOT to test (E2E)
- Visual details (use snapshot tests).
- Every possible input combination (use unit/integration).
- Internal state or implementation details.

## Playwright Patterns

### Page Object Model

```
pages/
  login.page.ts    # selectors + actions for /login
  checkout.page.ts # selectors + actions for /checkout
```

- Selectors in page objects, assertions in tests.
- One page object per route/component.
- Async methods returning locators, not raw elements.

### Fixtures

- `test.beforeEach`: authenticated state via `page.context().storageState()`.
- `test.use({ storageState })`: reuse auth across tests.
- Seed DB via API, not UI.

### Selectors

Priority: `getByRole` > `getByLabel` > `getByTestId` > `getByText` > CSS.

```typescript
// Good
page.getByRole('button', { name: 'Enviar' })
page.getByLabel('Email')
page.getByTestId('checkout-total')

// Avoid
page.locator('.btn-primary')      // breaks on restyle
page.locator('//div[2]/button')   // breaks on restructure
```

## CI Configuration

```yaml
# Playwright in CI
- uses: actions/checkout@v4
- uses: actions/setup-node@v4
- run: npx playwright install --with-deps chromium
- run: npx playwright test --reporter=html
- uses: actions/upload-artifact@v4
  if: failure()
  with:
    name: playwright-report
    path: playwright-report/
```

- `--retries=2` in CI, `--retries=0` locally.
- `--workers=1` in CI for deterministic runs.
- HTML report uploaded on failure for debugging.

## Flaky Test Prevention

- Auto-wait for elements (Playwright default). No `page.waitForTimeout(500)`.
- `page.waitForURL()` after navigation, not `page.waitForTimeout()`.
- Mock external APIs with `page.route()` — isolate from third-party failures.
- Atomic tests: each test seeds its own data, no inter-test dependencies.
- Run 10x locally before marking as stable: `npx playwright test --repeat-each=10`.

## Debugging

```bash
npx playwright test --debug           # step-by-step
npx playwright test --ui              # interactive UI
npx playwright codegen <url>          # record actions → test code
npx playwright show-trace test-results/failed/trace.zip
```

- `await page.screenshot({ path: 'debug.png' })` mid-test.
- Trace: `use: { trace: 'on-first-retry' }` in config.

## Output

Emit at completion:

```
## E2E: [feature/flow]

### Test Plan
- [flow]: [scenarios] scenarios

### Coverage
- Happy path: [covered/not covered]
- Errors: [covered]
- Edge cases: [covered]
- Mobile: [covered/not covered]

### CI
- Command: [npx playwright test ...]
- Retries: [N]
- Estimated runtime: [Xs]
```
