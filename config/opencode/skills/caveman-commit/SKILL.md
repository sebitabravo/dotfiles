---
name: caveman-commit
description:
  Auto-skill that generates conventional commit messages from staged changes.
  Triggers on commit-related tasks.
---

## Conventional Commit Format

```
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

## Types

| Type       | Usage                                    |
| ---------- | ---------------------------------------- |
| `feat`     | New feature                              |
| `fix`      | Bug fix                                  |
| `refactor` | Code restructure (no behavior change)    |
| `perf`     | Performance improvement                  |
| `test`     | Adding or updating tests                 |
| `docs`     | Documentation only                       |
| `style`    | Formatting, whitespace (no logic change) |
| `chore`    | Build, CI, tooling, dependencies         |
| `ci`       | CI/CD configuration                      |
| `build`    | Build system or external deps            |
| `revert`   | Revert a previous commit                 |

## Rules

1. **Analyze `git diff --cached`** to understand what changed.
2. **Determine type** from the nature of changes.
3. **Determine scope** from the files/modules affected.
4. **Write imperative mood**: "add feature" not "added feature".
5. **Subject line**: max 72 chars, no period.
6. **Body**: explain WHY, not WHAT. Wrap at 72 chars.
7. **Breaking changes**: `feat(api)!: change authentication flow` +
   `BREAKING CHANGE:` in footer.

## Examples

```
feat(auth): add JWT refresh token rotation
fix(api): handle null response from payment gateway
refactor(users): extract validation to shared module
perf(queries): add composite index on orders.created_at
test(checkout): add integration tests for payment flow
docs(api): update OpenAPI spec with new endpoints
chore(deps): upgrade pnpm to 10.16
ci: add preview deployment for PRs
```

## Generation Process

1. Run `git diff --cached --stat` for overview.
2. Run `git diff --cached` for detailed changes.
3. Identify the primary type and scope.
4. Generate subject line.
5. If changes are complex, add body explaining motivation.
6. If breaking change, add `!` and footer.

## Anti-patterns

- NO "update", "changes", "fixes", "misc" as descriptions. Be specific.
- NO mentioning the issue number in the subject. Put in footer.
- NO co-authored-by unless actually co-authored.
- NO AI attribution or signatures.
