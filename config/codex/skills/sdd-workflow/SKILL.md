---
name: sdd-workflow
description: Use for complex features, multi-file behavior changes, or ambiguous architecture work. Guides Explore, Proposal, Requirements, Design, Tasks, Apply, and Verify phases with project-specific gates.
---

# Spec-Driven Development workflow

Use this skill only when the change is complex enough to benefit from explicit
scope, requirements, design, and task traceability. Skip it for small fixes,
documentation, configuration, and mechanical edits.

## Before starting

1. Read the closest `AGENTS.md`, project README, architecture docs, and existing specs.
2. Identify the project stack, test runner, deploy path, and relevant constraints.
3. Create `specs/<feature-slug>/` only after confirming the requested scope.
4. Use the templates in `references/`; do not invent a second spec format.

## Phases

### 1. Explore -> Proposal

- State the problem in one sentence.
- Record scope in and out.
- Inspect existing patterns and affected modules.
- Consider at least two viable alternatives when the decision is architectural.
- Record assumptions and unresolved questions.

### 2. Requirements

- Write independently testable user stories with priorities.
- Express observable acceptance scenarios in Given/When/Then form when useful.
- Give each functional requirement a stable `FR-###` identifier.
- Define edge cases, non-functional constraints, success criteria, and out of scope.
- Resolve `[NEEDS CLARIFICATION]` before implementation or explicitly document the bounded assumption.

### 3. Design

- Map concrete files, modules, data flow, boundaries, dependencies, risks, and rollback.
- Reuse the repository's existing architecture unless the proposal justifies a change.
- Record rejected alternatives and the reason for rejection.
- Re-check security, performance, accessibility, privacy, and operational impact.

### 4. Tasks

- Break work into small, verifiable tasks with exact paths.
- Mark only genuinely independent work as `[P]`.
- Link implementation tasks to user stories and requirements.
- Put tests before implementation when the project supports a test-first flow.
- Add checkpoints between foundational work and user-story work.

### 5. Apply

- Work one task at a time and update `apply-progress.md` with evidence.
- Preserve unrelated changes.
- Do not weaken tests or quality gates to make a task appear complete.
- Stop when the task is blocked rather than accumulating speculative edits.

### 6. Verify

- Run the smallest fresh commands that prove each requirement.
- Use the project's own formatter, linter, type checker, test runner, and build commands.
- Review the final diff for scope, secrets, debug code, TODOs, generated files, and migration safety.
- Record skipped checks with a reason; never imply they passed.

## Artifacts

The bundled references provide:

- `sdd-constitution.md`
- `sdd-proposal.md`
- `sdd-requirements.md`
- `sdd-design.md`
- `sdd-tasks.md`
- `sdd-apply-progress.md`
- `sdd-checklist.md`
- `project-context.md`

Use `scripts/scaffold-sdd.sh <feature-slug>` when the skill is installed and a
new spec directory should be created. The script refuses to overwrite an
existing spec.
