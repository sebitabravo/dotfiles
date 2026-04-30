---
name: pr-review
description: >
  Reviews GitHub PRs with multi-angle analysis: security, correctness, performance, quality.
  Trigger: When user asks to review a PR, check a PR, or gives a PR URL.
  Uses false-positive filtering to avoid noise.
license: Apache-2.0
metadata:
  author: sebita-programming
  version: "2.0"
---

## When to Use This Skill

Use this skill when:
- User shares a PR URL or number
- User asks to "review this PR"
- User says "check this pull request"
- User wants comprehensive PR analysis

## Philosophy

**Be a helpful colleague, not a robot.**

You're reviewing code like a senior dev who CARES about:
1. **Security** (real vulnerabilities, not theoretical)
2. **Correctness** (bugs that will break in production)
3. **Performance** (real bottlenecks, not premature optimization)
4. **Quality** (maintainability, not style)

Not a linter. Not a checklist machine. Focus on what MATTERS.

---

## Review Workflow

### Step 1: Fetch PR Information

```bash
# Get PR metadata (owner/repo from the URL)
gh pr view {number} --json title,body,files,additions,deletions,author,state,baseRefName,headRefName

# Get ALL commits in the PR (not just latest diff)
gh api "repos/{owner}/{repo}/pulls/{number}/commits" | jq '.[].sha'

# Get the diff (exclude lockfiles - they're noise)
gh pr diff {number} -- ':(exclude)**/pnpm-lock.yaml' ':(exclude)**/package-lock.json' ':(exclude)**/yarn.lock'
```

### Step 2: Categorize Issues

**Only comment on things that MATTER:**

| Category | When to Comment |
|----------|-----------------|
| **CRITICAL** | Security vulnerability with real exploit path, data loss risk, auth bypass |
| **NEEDS REVIEW** | Might be wrong, need author to confirm intent |
| **QUESTION** | Curious about a choice, not necessarily wrong |

**DO NOT comment on (False Positives):**
- Style preferences (that's what linters are for)
- "You could also do X" suggestions (unless X is significantly better)
- Minor nitpicks
- Things that are correct but you'd do differently
- Generic "missing input validation" without proven attack
- "Missing rate limiting" without evidence of abuse
- Missing CSRF on GET requests
- Console.log statements (unless logging secrets)
- Missing security headers on non-sensitive endpoints

### Step 3: Multi-Angle Analysis

For each changed file, check in order:

1. **Security** — SQL injection, XSS, auth bypass, hardcoded secrets, command injection
2. **Correctness** — logic errors, null handling, race conditions
3. **Performance** — N+1 queries, blocking ops
4. **Quality** — function length, complexity

### Step 4: Verify Before Commenting

**NEVER assume.** If you're not sure:

```bash
# Check official docs for the framework/pattern
# Search for the API/convention being used
# Verify the claim before saying "this is wrong"
```

Example: If someone uses a new API signature, CHECK if that's the standard before flagging it.

---

## False Positive Filtering (CRITICAL)

**Before posting ANY comment, verify it's not noise.**

### Questions to Ask

1. **Does this have a REAL attack vector?** (not theoretical)
2. **What's the actual impact?** (not hypothetical)
3. **Does the codebase already have mitigations?**
4. **Would a real attacker care?**
5. **Is this framework/environment-specific?**

### Common False Positives to SKIP

| Pattern | Why Skip |
|---------|----------|
| "Missing rate limiting" | Only if no rate limiting AND evidence of abuse |
| "Generic input validation" | Most apps need validation, not all exploitable |
| "Missing CSRF on GET" | Only POST/PUT/DELETE matter |
| "Console.log statements" | Only if logging secrets |
| "Missing security headers" | Only critical for sensitive data |
| "Missing try/catch" | Only if unhandled error causes data loss |

---

## Writing Comments

### Tone

Write like you're talking to a colleague on Slack. Not a formal code review template.

**BAD (robotic):**
```
Issue: SQL Injection vulnerability detected at line 42.
Severity: Critical
Recommendation: Use parameterized queries.
Fix: db.query('SELECT * FROM users WHERE id = ?', [userId])
```

**GOOD (helpful):**
```
Hey! Found a SQL injection issue at db.js:42 — the userId is being concatenated directly into the query. Should use parameterized queries instead:

```javascript
// Instead of:
const query = `SELECT * FROM users WHERE id = '${userId}'`

// Use:
const query = 'SELECT * FROM users WHERE id = ?'
db.query(query, [userId])
```

Does this look right?
```

### Structure

Keep it simple:

1. What you noticed (with line number)
2. Why it might be a problem (with evidence if needed)
3. Suggested fix (with code)
4. Ask for confirmation if you're not 100% sure

### One Comment, Multiple Points

If you have several related things, put them ALL in one comment. Don't spam the PR.

```
Hey! Did a review. Found a few things:

**1. SQL injection risk** at db.js:42 — user input concatenated into query.

**2. Missing auth check** at orders.js:15 — no verification that user owns the order.

**3. Good stuff** — the error handling in auth.js is solid, nice work!

Let me know if any of these need clarification!
```

---

## Posting the Comment

```bash
# Regular comment
gh pr comment {number} --body "Your comment here"

# Inline comment on specific line
gh api repos/{owner}/{repo}/pulls/{number}/comments \
  -f body="Your comment" \
  -f path="file.ts" \
  -f line=42 \
  -f side="RIGHT"
```

---

## What Makes a Good PR Review

1. **Helpful** — Focus on real issues, not nitpicks
2. **Humble** — Ask questions when unsure instead of demanding
3. **Human** — Reads like a person wrote it, not a template
4. **Verified** — Claims backed by docs/evidence
5. **Actionable** — Author knows exactly what to do
6. **Selective** — Don't comment on everything, focus on impact

---

## Anti-Patterns to Avoid

- ❌ Starting with "LGTM" then listing 15 issues
- ❌ "This is wrong" without explaining why
- ❌ Suggesting rewrites of working code just because you'd do it differently
- ❌ Commenting on every file just to show you reviewed everything
- ❌ Being condescending ("Obviously you should...")
- ❌ Using formal severity templates for everything
- ❌ Reporting false positives (see filtering section)
- ❌ Being overly pedantic about style (use linters)

---

## Output Template for User

After reviewing, summarize for the user:

```
Listo, dejé comentarios en el PR: {url}

## Resumen:
- 🔴 Critical: X (fix antes de merge)
- 🟠 High: X (recomiendo fix)
- 🟡 Medium: X (considerar)
- 🟢 Low: X (mejoras opcionales)

## Puntos principales:
1. {brief summary of critical/review items}
2. {another point}

## Cosas bien:
- {praise specific good code}

## Veredicto:
approve / changes-requested / block

A esperar respuesta del autor.
```

---

## Security-Specific PR Review

When reviewing PRs for security, check these specific patterns:

### SQL Injection
```bash
# Search for dangerous patterns
rg "query\s*\(\s*\`" --type js
rg "execute\s*\(\s*\`" --type js
rg "raw\s*\(" --type js
```

### XSS
```bash
# Search for dangerous patterns
rg "innerHTML\s*=" --type js
rg "dangerouslySetInnerHTML" --type js
rg "v-html" --type vue
```

### Auth Bypass
```bash
# Search for missing auth
rg "req\.user" --type js -A 2
rg "if\s*\(!.*user" --type js
```

### Hardcoded Secrets
```bash
# Search for secrets
rg "(apiKey|password|secret|token)\s*=\s*['\"]" --type js
rg "sk-" --type js
```

---

## Keywords

pr, pull request, review, github, code review, gh, security review, pr audit, code audit