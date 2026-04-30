---
description: Code review for local changes or GitHub PRs with severity analysis and release verdict
agent: sebastian
---

Review "$ARGUMENTS".

## Auto-detect mode

- If arguments contain a PR number or GitHub PR URL → PR review mode
- If user says "comprehensive", "full", "multi-angle", "all angles", "security + architecture + performance" → comprehensive mode
- Otherwise → simple review mode

## Simple Review Mode (default)

Delegate to `code-reviewer` agent, which follows code-review-pro skill:
- Security → Correctness → Performance → Quality
- Uses false-positive filtering
- Returns severity findings + verdict

## Comprehensive Multi-Angle Mode

Use when user requests "comprehensive", "full", "multi-angle", "all perspectives", "security + architecture + performance", etc.

**Execution:**
1. Delegate to `code-reviewer` AND `backend-architect` AND `performance-engineer` **in parallel**
2. Wait for all three to return
3. Synthesize findings into ONE unified report:

```markdown
# Comprehensive Review Report

## Angles Analyzed
- Security (code-reviewer): ✅ / ⚠️
- Architecture (backend-architect): ✅ / ⚠️
- Performance (performance-engineer): ✅ / ⚠️

## Combined Severity
- 🔴 Critical: X
- 🟠 High: X
- 🟡 Medium: X

## Findings by Angle
### Security
[from code-reviewer]
### Architecture  
[from backend-architect]
### Performance
[from performance-engineer]

## Final Verdict
**approve** / **changes-requested** / **block**
```

## PR Review Mode

- Load `pr-review` skill
- Review ALL commits in the PR (not only latest diff)
- Use comprehensive if user requests it

## Output (all modes)

- Findings grouped by severity
- Requirement coverage table if requirements exist
- Regression risk notes
- Verdict: `approve` / `changes-requested` / `block`

## Fallback

If delegation fails from provider/quota/model:
1. Retry with `universal-free-fallback` preserving output contract
2. If all fail, run inline using `code-review-pro` skill and mark as `fallback-inline-review`