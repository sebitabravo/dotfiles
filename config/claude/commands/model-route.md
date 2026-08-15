---
description: "Pick the optimal model based on task complexity, cost and latency"
argument-hint: "[task to analyze]"
---

Analyze the task and recommend the optimal model: $ARGUMENTS.

**Decision matrix** (Claude models available in this config):

| Complexity | Model | Use case |
|---|---|---|
| Trivial (typos, 1 line) | haiku | Speed over intelligence |
| Standard (features, bugs) | sonnet | Balance |
| Complex (architecture, multi-agent) | opus | Maximum intelligence |
| Heavy planning / specs | opusplan | Long-horizon planning |
| Code review | opus + code-reviewer agent | Quality gate |

**Factors to evaluate**:
1. How many files have to change?
2. Is security/auth logic involved?
3. Is it new architecture or a new pattern?
4. Are subagents needed?
5. What is the cost/latency budget?

Output: recommended model + rationale + token usage estimate.
