# Tasks — {{FEATURE_NAME}}

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** spec-author
- **Status:** draft
- **Total tasks:** {{N}}
- **Linked spec:** `specs/{{FEATURE_NAME}}/requirements.md`

## Pre-implementation

- [ ] Verify that `requirements.md` is in `spec_ready` state.
- [ ] Verify that `design.md` has a complete File Structure Plan.
- [ ] Verify that all dependencies are installed.

## Tasks

<!-- Each task = one commit. Boundary defines files it touches. Depends blocks execution. -->

### T1 — {{TASK_TITLE}}

_Boundary:_ `src/{{file}}.ts`, `tests/{{file}}.test.ts`
_Depends:_ —
_TDD:_ RED → GREEN → REFACTOR

- [ ] RED: Write failing test for {{R<n>}}
- [ ] GREEN: Implement minimum code to pass test
- [ ] REFACTOR: Clean up, re-run tests, confirm green
- [ ] Verify requirement coverage: {{R<n>}}

### T2 — {{TASK_TITLE}}

_Boundary:_ `src/{{file}}.ts`, `tests/{{file}}.test.ts`
_Depends:_ T1
_TDD:_ RED → GREEN → REFACTOR

- [ ] RED: Write failing test for {{R<n>}}
- [ ] GREEN: Implement minimum code to pass test
- [ ] REFACTOR: Clean up, re-run tests, confirm green
- [ ] Verify requirement coverage: {{R<n>}}

<!-- Add more T<n> as needed -->

## Implementation Notes

<!-- Implementer propagates learnings from early tasks to later tasks here -->
<!-- e.g.: "T1: Redis cache requires manual serialization for Date types" -->

## Final Verification

- [ ] All tests pass: `{{TEST_COMMAND}}`
- [ ] Coverage not lower than main
- [ ] Linter clean: `{{LINT_COMMAND}}`
- [ ] Type check clean: `{{TYPECHECK_COMMAND}}`
- [ ] Full traceability: each R<n> has at least one test
