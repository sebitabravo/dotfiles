---
name: cavecrew
description: Subagent delegation protocol. Subagents persist results to files and return a short delivery receipt; inline summaries never replace the durable report.
---

## Delegation protocol

Complements the ANTI-TELEPHONE rule in CLAUDE.md with the file convention and the delegation template.

### When to delegate

- Broad codebase exploration (>3 file reads)
- Searches across many files
- Parallel research tasks
- Context-heavy operations that would bloat the main context

### Rules

1. **Subagents write the complete result to the unique path supplied by the coordinator before signaling completion.**
2. **Return a short receipt:** `REPORT_READY: <path>`, `status: clean|findings|blocked`, and one-line summary.
3. **Never depend on inline text or a completion notification as the only delivery channel.** Chat can be truncated or dropped; the report file survives compaction and notification races.
4. **An inline request is additive, not an exception:** write the file first, then include a concise inline summary and the exact path.
5. **If the subagent gives no path, recover once by requesting the path and status.** Do not keep asking for the same inline report; inspect the task/session status and logs, then read the report when available.
6. **The main agent reads and verifies the file before using its claims.** It must exist, be non-empty, and contain the requested format/evidence.

### Output file convention

```
/tmp/cavecrew/<task-name>-<session-or-task-id>-result.md
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
3. A unique output path and expected report format
4. Receipt format: `REPORT_READY: <path>` plus status and one-line summary
5. Constraints (time limit, depth)

### Delegation example

```
Task: Find every endpoint that accepts user input without validation.
Scope: src/routes/ and src/controllers/
Output: Write findings to /tmp/cavecrew/validation-audit-<session-or-task-id>-result.md
Format: Table with file, endpoint, parameter, current validation state
Final reply: `REPORT_READY: <exact path>`; include `status` and a one-line summary.
```

### Anti-patterns

- Do not delegate trivial tasks (single file read, simple grep).
- Do not delegate and then run the same search yourself.
- Do not accept inline results as the only delivery. Always require and verify a file path.
- Do not delegate if you already have the answer in context.
