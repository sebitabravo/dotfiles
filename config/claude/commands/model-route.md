---
description: "Select the right model based on task complexity"
---

Evaluate the complexity of ${ARGUMENTS:-the current task} and suggest the optimal model.

| Complexity | Typical task | Model |
|---|---|---|
| **Low** | Typo fix, rename, comment cleanup, 1-line change | `haiku` |
| **Medium** | Simple feature, bounded refactor, new test | `sonnet` |
| **High** | Architecture, new system, complex bug, design | `opus` |

If on DeepSeek API, all models map to the same backend. The difference is in system behavior.
