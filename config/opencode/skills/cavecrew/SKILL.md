---
name: cavecrew
description: Auto-skill that delegates search, edit, and exploration tasks to subagents. Returns file paths, never verbatim content through chat.
---

## Delegation Protocol

### When to Delegate

- Broad codebase exploration (>3 file reads needed)
- Search operations across many files
- Parallel research tasks
- Context-heavy operations that would bloat main context

### Rules

1. **Subagents write results to files.** Return ONLY the file path.
2. **Never pass verbatim content through chat.** Chat corrupts signal; files persist after compaction.
3. **If a subagent doesn't give you a path, demand it.**
4. **Main agent reads the file when needed.** Not before.

### Output File Convention

```
/tmp/cavecrew/<task-name>-result.md
```

### Agent Types

| Type | Use For |
|------|---------|
| `Explore` | Codebase exploration, finding patterns, understanding architecture |
| `code-reviewer` | Reviewing diffs, security analysis |
| `debugger` | Root cause analysis, error investigation |
| `research` | Documentation lookup, API research |

### Delegation Template

When delegating a task, include:
1. Clear objective
2. Scope (which files/dirs to search)
3. Expected output format (file path with results)
4. Constraints (time limit, depth)

### Example Delegation

```
Task: Find all API endpoints that accept user input without validation.
Scope: src/routes/ and src/controllers/
Output: Write findings to /tmp/cavecrew/validation-audit-result.md
Format: Table with file, endpoint, parameter, current validation status
```

### Anti-Patterns

- Don't delegate trivial tasks (single file read, simple grep).
- Don't delegate and then do the same search yourself.
- Don't accept inline results. Always demand a file path.
- Don't delegate if you already have the answer in context.
