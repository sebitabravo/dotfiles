---
description: "Route to the optimal model based on task complexity, cost, and latency"
---

Analyze the current task and recommend the optimal model routing:

**Task**: ${ARGUMENTS:-current task}

**Decision matrix**:

| Complexity | Model | Use Case |
|---|---|---|
| Trivial (typos, 1-line) | small_model (fast) | Speed over intelligence |
| Standard (features, bugs) | default model | Balance |
| Complex (architecture, multi-agent) | heavy model | Maximum intelligence |
| Code review | default + code-reviewer | Quality gate |

**Factors to evaluate**:
1. How many files need to change?
2. Is security/auth logic involved?
3. Is this a new architecture or pattern?
4. Are subagents needed?
5. What is the cost/latency budget?

Output: recommended model + rationale + estimated token usage.
