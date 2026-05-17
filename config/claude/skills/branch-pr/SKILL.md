---
name: branch-pr
description: >
  Branch creation, PR workflow, and conventional commits.
  Trigger: When creating branches, commits, or pull requests.
license: MIT
metadata:
  author: sebita-programming
  version: "1.0"
---

## Branch Naming

```
main                          ← Production (NEVER push direct)
└── development               ← Main development branch
    ├── feature/TECH-XX-...   ← New features
    ├── fix/description       ← Bug fixes
    ├── refactor/description  ← Refactoring
    └── hotfix/urgent-bug     ← Urgent production fixes
```

### Format

```bash
feature/TECH-XX-short-description   # With Linear/Jira ticket
feature/descriptive-name            # Without ticket
fix/bug-description
refactor/what-is-refactored
hotfix/urgent-bug
```

## Conventional Commits (MANDATORY)

### Format

```
type(scope): lowercase description
```

### Allowed types

| Type | When |
|------|------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Refactoring without behavior change |
| `test` | Add or modify tests |
| `ci` | CI/CD changes |
| `docs` | Documentation |
| `chore` | Maintenance tasks |

### Examples

```bash
feat(auth): add google login
fix(tenant): fix domain validation
refactor(tests): move tests to integration
test(carbon-footprint): add validation tests
docs(api): update endpoint documentation
```

### WIP Commits

```bash
WIP: [feature] - progress description
WIP: modular system - domain contracts completed
WIP: end of day save
```

## Feature Flow

```bash
# 1. Create from clean main
git checkout main
git pull origin main
git checkout -b feature/feature-name

# 2. Develop with frequent commits (every 30-60 min)
git commit -m "feat(scope): initial structure"
git commit -m "feat(scope): core implementation"

# 3. Push for backup
git push -u origin feature/feature-name

# 4. Create PR to development
# CI must pass before merge
```

## Create Pull Request

### Before creating the PR

```bash
# Verify tests pass (check project docs for command)
# Squash commits into one
git rebase -i HEAD~N  # N = number of commits to squash
```

### PR Checklist

- [ ] All tests pass
- [ ] Quality checks pass (linters, formatters)
- [ ] Commits squashed into one
- [ ] PR targets `development` (NOT main)
- [ ] Clear description of change

### Create PR with gh

```bash
gh pr create \
  --base development \
  --title "feat(scope): change description" \
  --body "## Summary
- What was done and why

## Changes
- List of main changes

## Testing
- How it was tested"
```

## Merge Flow

```
feature branch → development → main (production)
```

## Hotfix (Urgent)

```bash
# 1. Save current work
git stash push --include-untracked -m "WIP: paused for hotfix"

# 2. Create hotfix branch
git checkout main && git pull origin main
git checkout -b hotfix/bug-description

# 3. Fix, test, commit
git commit -m "fix(scope): description of resolved bug"

# 4. Merge and return
git checkout main && git merge hotfix/bug-description
git push origin main
git branch -d hotfix/bug-description
git checkout previous-branch && git stash pop
```

## Security Rules

```
❌ NEVER: git push --force (on main/development)
❌ NEVER: git clean -fd (without dry-run first)
❌ NEVER: git reset --hard (without checking status)
❌ NEVER: Push direct to main
❌ NEVER: Rebase on shared branches
✅ ALWAYS: git clean -n before git clean -fd
✅ ALWAYS: git status before destructive operations
```

## Keywords

branch, pr, pull request, commit, conventional commits, git workflow, merge
