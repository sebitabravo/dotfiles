---
description: "Review the current diff or specified files using the code-reviewer agent"
---

Run a systematic code review on ${ARGUMENTS:-the current diff}.

Uses the `code-review` skill with the `code-reviewer` agent.

Dimensions to review: correctness, security, performance, maintainability, testing.

Output format:
```
path:line: <severity> <problem>. <fix suggestion>.
```
