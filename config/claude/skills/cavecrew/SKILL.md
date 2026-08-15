---
name: cavecrew
description: Subagent delegation protocol. Subagents write results to files and return ONLY the path, never verbatim content through chat.
---

## Delegation protocol

Complements the ANTI-TELEPHONE rule in CLAUDE.md with the file convention and the delegation template.

### When to delegate

- Broad codebase exploration (>3 file reads)
- Searches across many files
- Parallel research tasks
- Context-heavy operations that would bloat the main context

### Rules

1. **Subagents write results to files.** They return ONLY the path.
2. **Never pass verbatim content through chat.** Chat corrupts the signal; files survive compaction.
3. **If a subagent does not give you a path, demand one.**
4. **The main agent reads the file when it needs it.** Not before.

### Output file convention

```
/tmp/cavecrew/<task-name>-result.md
```

### Subagent types (Claude)

| Type | Use |
|------|-----|
| `explore` | Codebase exploration, finding patterns, understanding architecture |
| `code-reviewer` | Diff review, security analysis |
| `debugger` | Root cause analysis, error investigation |
| `general` | Research, documentation lookup, multi-step tasks |
| `security-auditor` | Auth, permission and secret audits |

### Delegation template

When delegating a task, include:
1. A clear objective
2. Scope (which files/dirs to search)
3. Expected output format (path of the results file)
4. Constraints (time limit, depth)

### Delegation example

```
Task: Find every endpoint that accepts user input without validation.
Scope: src/routes/ and src/controllers/
Output: Write findings to /tmp/cavecrew/validation-audit-result.md
Format: Table with file, endpoint, parameter, current validation state
```

### Anti-patterns

- Do not delegate trivial tasks (single file read, simple grep).
- Do not delegate and then run the same search yourself.
- Do not accept inline results. Always demand a file path.
- Do not delegate if you already have the answer in context.
