---
name: e2e-testing
description: End-to-end testing patterns with Playwright, including page objects, test fixtures, visual regression, API mocking, and CI integration.
---

## Playwright Setup

### Installation

```bash
pnpm add -D @playwright/test
npx playwright install
```

### Config

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test'

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI
    ? [['github'], ['html', { open: 'never' }]]
    : [['list'], ['html', { open: 'on-failure' }]],
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
  },
})
```

## Page Object Model

```typescript
// e2e/pages/login.page.ts
import { type Page, type Locator, expect } from '@playwright/test'

export class LoginPage {
  readonly page: Page
  readonly emailInput: Locator
  readonly passwordInput: Locator
  readonly submitButton: Locator
  readonly errorMessage: Locator

  constructor(page: Page) {
    this.page = page
    this.emailInput = page.getByLabel('Email')
    this.passwordInput = page.getByLabel('Password')
    this.submitButton = page.getByRole('button', { name: 'Sign in' })
    this.errorMessage = page.getByRole('alert')
  }

  async goto() {
    await this.page.goto('/login')
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email)
    await this.passwordInput.fill(password)
    await this.submitButton.click()
  }

  async expectError(message: string) {
    await expect(this.errorMessage).toContainText(message)
  }
}
```

## Test Patterns

### Basic Test

```typescript
// e2e/auth/login.spec.ts
import { test, expect } from '@playwright/test'
import { LoginPage } from '../pages/login.page'

test.describe('Login', () => {
  let loginPage: LoginPage

  test.beforeEach(async ({ page }) => {
    loginPage = new LoginPage(page)
    await loginPage.goto()
  })

  test('successful login redirects to dashboard', async ({ page }) => {
    await loginPage.login('user@example.com', 'password123')
    await expect(page).toHaveURL('/dashboard')
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible()
  })

  test('invalid credentials shows error', async () => {
    await loginPage.login('user@example.com', 'wrong')
    await loginPage.expectError('Invalid credentials')
  })
})
```

### Fixtures for Auth

```typescript
// e2e/fixtures/auth.fixture.ts
import { test as base, expect } from '@playwright/test'

type AuthFixture = {
  authenticatedPage: Page
}

export const test = base.extend<AuthFixture>({
  authenticatedPage: async ({ page }, use) => {
    // Login via API (faster than UI)
    const response = await page.request.post('/api/auth/login', {
      data: { email: 'user@example.com', password: 'password123' },
    })
    expect(response.ok()).toBeTruthy()
    await page.goto('/dashboard')
    await use(page)
  },
})
```

### API Mocking

```typescript
test('shows error when API fails', async ({ page }) => {
  await page.route('**/api/users', (route) =>
    route.fulfill({
      status: 500,
      body: JSON.stringify({ error: 'Internal Server Error' }),
    })
  )

  await page.goto('/users')
  await expect(page.getByText('Something went wrong')).toBeVisible()
})
```

### Visual Regression

```typescript
test('dashboard layout matches snapshot', async ({ page }) => {
  await page.goto('/dashboard')
  await expect(page).toHaveScreenshot('dashboard.png', {
    maxDiffPixelRatio: 0.01,
    animations: 'disabled',
  })
})
```

### Network Interception

```typescript
test('tracks analytics events', async ({ page }) => {
  const analyticsEvents: any[] = []

  await page.route('**/analytics/**', (route) => {
    analyticsEvents.push(route.request().postDataJSON())
    route.fulfill({ status: 200, body: '{}' })
  })

  await page.goto('/products/123')
  await page.getByRole('button', { name: 'Add to cart' }).click()

  expect(analyticsEvents).toContainEqual(
    expect.objectContaining({ event: 'add_to_cart', product_id: '123' })
  )
})
```

### File Upload

```typescript
test('uploads avatar', async ({ page }) => {
  await page.goto('/settings')
  const fileInput = page.getByLabel('Avatar')
  await fileInput.setInputFiles('./e2e/fixtures/avatar.png')
  await page.getByRole('button', { name: 'Save' }).click()
  await expect(page.getByRole('img', { name: 'Avatar' })).toBeVisible()
})
```

## CI Integration

```yaml
# .github/workflows/e2e.yml
jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm exec playwright install --with-deps chromium
      - run: pnpm exec playwright test
      - uses: actions/upload-artifact@v4
        if: failure()
        with:
          name: playwright-report
          path: playwright-report/
          retention-days: 7
```

## Rules

- Page Object Model for any page with >3 interactions.
- API-based auth in fixtures (faster than UI login).
- `getByRole` and `getByLabel` over CSS selectors.
- Mock external APIs, not internal ones.
- Visual regression for stable layouts only.
- `test.describe` to group related tests.
- `test.beforeEach` for setup, not `test.beforeAll` (isolation).
- Parallel by default. Disable only for flaky tests.
