---
name: sdd-workflow
description: Spec-Driven Development for complex features, multi-file behavior changes, or ambiguous architecture work. Guides Explore, Proposal, Requirements, Design, Tasks, Apply, and Verify with human gates and a scaffolding script. Use when a feature is too big to implement directly, when scope is unclear, or when resuming an existing spec under specs/.
---

# Spec-Driven Development workflow

Use this skill only when the change is complex enough to benefit from explicit
scope, requirements, design, and task traceability. Skip it for small fixes,
documentation, configuration, and mechanical edits — CLAUDE.md already says
trivial features get direct implementation.

Templates live in `~/.claude/templates/`, not inside this skill. There is one
copy so a fix to a template applies everywhere.

## Before starting

1. Read the project `CLAUDE.md`, README, architecture docs, and existing specs.
2. Identify the stack, test runner, deploy path, and relevant constraints.
3. Create `specs/<feature-slug>/` only after confirming the requested scope.
4. Use the templates; do not invent a second spec format.

## Scaffolding

```bash
~/.claude/skills/sdd-workflow/scripts/scaffold-sdd.sh <feature-slug>
```

Copies every template into `specs/<feature-slug>/` with `{{FEATURE_NAME}}`
substituted. It refuses to overwrite an existing spec directory.

## Phases

### 1. Explore -> Proposal

- State the problem in one sentence.
- Record scope in and out.
- Inspect existing patterns and affected modules.
- Consider at least two viable alternatives when the decision is architectural.
- Record assumptions and unresolved questions.

**Human gate.** Do not proceed to requirements without approval.

### 2. Requirements

- Write independently testable user stories with priorities (P1/P2/P3).
- Express observable acceptance scenarios in Given/When/Then form when useful.
- Give each functional requirement a stable `FR-###` identifier.
- Define edge cases, non-functional constraints, success criteria, out of scope.
- Resolve `[NEEDS CLARIFICATION]` before implementation, or document the bounded
  assumption explicitly.

### 3. Design

- Map concrete files, modules, data flow, boundaries, dependencies, risks, rollback.
- Reuse the repository's existing architecture unless the proposal justifies a change.
- Record rejected alternatives and the reason for rejection.
- Re-check security, performance, accessibility, privacy, and operational impact.

**Human gate.** Requirements + design get approved together before any code.

### 4. Tasks

- Break work into small, verifiable tasks with exact paths.
- Mark only genuinely independent work as `[P]`.
- Link implementation tasks to user stories and requirements (`[US<n>]`).
- Put tests before implementation — rules/common/testing.md is not optional here.
- Add checkpoints between foundational work and user-story work.

### 5. Apply

- Work one task at a time and update `apply-progress.md` with evidence.
- Preserve unrelated changes.
- Do not weaken tests or quality gates to make a task appear complete.
- Stop when a task is blocked rather than accumulating speculative edits.

### 6. Verify

- Run the smallest fresh commands that prove each requirement.
- Use the project's own formatter, linter, type checker, test runner, build.
- Review the final diff for scope, secrets, debug code, TODOs, generated files,
  and migration safety.
- Record skipped checks with a reason; never imply they passed.
- `checklist.md` carries CHK001–CHK041 for the systematic pass.

Max 2 verify -> apply cycles. If it still fails, escalate instead of looping.

## Phase report

Every phase closes with the same five fields. The human gates are where someone
decides whether to spend the next phase's work, and that decision needs a
scannable report — not the artifact re-read out loud.

| Field | Content |
|---|---|
| `status` | done / blocked / needs-decision |
| `executive_summary` | 2-3 sentences. What this phase settled |
| `artifacts` | Paths written or updated in this phase |
| `next_recommended` | The single next phase or action, not a menu |
| `risks` | What could still invalidate this, or "none identified" |

This is the one place the Response Length Contract yields: a gate report is
structured because someone is approving spend, not reading prose.

## Resuming

To continue an existing feature: read `specs/<change>/`, detect which artifact is
the last one filled in, and continue from the next phase. No agent needed.

## Archiving

Completed specs move to `specs/archived/`.
