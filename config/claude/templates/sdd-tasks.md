# Tasks — {{FEATURE_NAME}}

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** spec-author
- **Status:** draft
- **Total tasks:** {{N}}
- **Linked spec deltas:** `openspec/changes/{{FEATURE_NAME}}/specs/`
- **Linked design:** `openspec/changes/{{FEATURE_NAME}}/design.md`

## Format: `[ID] [P?] [US<n>] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- **[US<n>]**: which user story it belongs to (US1, US2, US3)
- Include exact paths in the descriptions

## Native task contract

When the implementation uses Claude Code's native `TaskCreate`/`TaskUpdate`
tools, every task description must include these machine-checkable lines. The
global task hooks reject creation or completion when the contract is missing.

```text
ROADMAP: openspec/changes/{{FEATURE_NAME}}/tasks.md
DEPENDS_ON: none
PATHS: path/to/affected/files
ACCEPTANCE: observable condition that makes the task complete
VERIFY: exact project-native command or verification gate
RECEIPT: .claude/task-receipts/{{TASK_ID}}.md
```

For a roadmap that will be checked as a graph, append the dependency annotation
to each checklist entry: `- [ ] T002 [depends_on: T001] Description`. Use
`[depends_on: none]` for roots. For tasks intended to share a theoretical
parallel frontier, also annotate ownership explicitly:
`[paths: src/a.py; tests/a.py]`. The stdlib validator checks duplicate IDs,
missing dependencies, self-dependencies, cycles, and conservative path overlap
without running task commands. `paths: none` is equivalent to no ownership
annotation, and globs such as `src/*.py` remain unproven until a
repository-aware analyzer expands them; they must not be used to claim a safe
parallel frontier.

Run it before applying a durable roadmap:

```bash
python3 ~/.claude/scripts/validate-task-roadmap.py \
  openspec/changes/{{FEATURE_NAME}}/tasks.md
```

With `--json`, the validator also reports descriptive graph metrics such as
critical-path length, theoretical frontier width, and tasks runnable from the
current statuses. These metrics are observability only: they do not prove
file ownership or authorize parallel execution. Run
`--require-paths-for-parallel` before applying a direct roadmap to reject an
unannotated or glob-ambiguous parallel frontier; any path overlap remains a
conflict requiring serial execution or a re-plan. Ownership paths must be
relative and cannot contain `.` or `..` components.

`VERIFY:` is evidence metadata, not shell input for a hook: the hook never
evaluates arbitrary task text. Before `TaskUpdate(status=completed)`, the
receipt must exist and contain the matching `TASK_ID:`, `STATUS: PASS`,
`ACCEPTANCE: PASS`, `VERIFY_EXIT: 0`, and a non-empty `EVIDENCE:` line. These
fields are evidence requirements, not a substitute for running the command;
the project-native verifier remains authoritative. Use `DEPENDS_ON: none` for
a root task; dependencies must also be represented in the native task list so
the runtime can keep blocked tasks from being claimed prematurely.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose:** project initialization and base structure.

**Prerequisites:**
- [ ] `requirements.md` en estado `spec_ready`
- [ ] `design.md` complete with File Structure Plan
- [ ] Dependencias instaladas

- [ ] T001 Create the project structure per design.md
- [ ] T002 [P] Initialize the project with dependencies
- [ ] T003 [P] Configure linting and formatting

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose:** core infrastructure that MUST be complete BEFORE any user story.

**⚠️ CRITICAL:** no user story starts until this phase is complete.

- [ ] T004 Setup base de datos y migraciones
- [ ] T005 [P] Implement authentication/authorization
- [ ] T006 [P] Setup routing y middleware
- [ ] T007 Create the base models/entities every story needs
- [ ] T008 [P] Set up error handling and logging
- [ ] T009 [P] Set up environment and variables

**Checkpoint:** foundation ready — user story implementation starts

---

## Phase 3: User Story 1 — {{TITLE}} (Priority: P1) 🎯 MVP

**Goal:** [What this story delivers]

**Independent Test:** [How to verify it works on its own]

### Tests for User Story 1 *(only if tests were requested)*

> **Write the tests FIRST, confirm they FAIL before implementing**

- [ ] T010 [P] [US1] Contract test for {{endpoint}} in `tests/contract/test_{{name}}.test.ts`
- [ ] T011 [P] [US1] Integration test for {{user_journey}} in `tests/integration/test_{{name}}.test.ts`

### Implementation for User Story 1

- [ ] T012 [P] [US1] Create model {{Entity1}} in `src/models/{{entity1}}.ts`
- [ ] T013 [P] [US1] Create model {{Entity2}} in `src/models/{{entity2}}.ts`
- [ ] T014 [US1] Implement {{Service}} in `src/services/{{service}}.ts` (depends on T012, T013)
- [ ] T015 [US1] Implement {{endpoint}} in `src/{{location}}/{{file}}.ts`
- [ ] T016 [US1] Add validation and error handling
- [ ] T017 [US1] Add logging for US1 operations

**Verification:**
- [ ] TDD: RED → GREEN → REFACTOR completed for this story
- [ ] Cobertura de requisitos: {{FR-xxx, FR-yyy}}

**Checkpoint:** User Story 1 funcional y testeable independientemente ✅

---

## Phase 4: User Story 2 — {{TITLE}} (Priority: P2)

**Goal:** [What this story delivers]

**Independent Test:** [How to verify it works on its own]

### Tests for User Story 2 *(only if tests were requested)*

- [ ] T018 [P] [US2] Contract test for {{endpoint}} in `tests/contract/test_{{name}}.test.ts`
- [ ] T019 [P] [US2] Integration test for {{user_journey}} in `tests/integration/test_{{name}}.test.ts`

### Implementation for User Story 2

- [ ] T020 [P] [US2] Create model {{Entity}} in `src/models/{{entity}}.ts`
- [ ] T021 [US2] Implement {{Service}} in `src/services/{{service}}.ts`
- [ ] T022 [US2] Implement {{endpoint}} in `src/{{location}}/{{file}}.ts`
- [ ] T023 [US2] Integrate with User Story 1 components (if applicable)

**Verification:**
- [ ] TDD: RED → GREEN → REFACTOR completed for this story
- [ ] Cobertura de requisitos: {{FR-xxx}}

**Checkpoint:** User Stories 1 Y 2 funcionales independientemente ✅

---

## Phase 5: User Story 3 — {{TITLE}} (Priority: P3)

**Goal:** [What this story delivers]

**Independent Test:** [How to verify it works on its own]

### Tests for User Story 3 *(only if tests were requested)*

- [ ] T024 [P] [US3] Contract test for {{endpoint}} in `tests/contract/test_{{name}}.test.ts`
- [ ] T025 [P] [US3] Integration test for {{user_journey}} in `tests/integration/test_{{name}}.test.ts`

### Implementation for User Story 3

- [ ] T026 [P] [US3] Create model {{Entity}} in `src/models/{{entity}}.ts`
- [ ] T027 [US3] Implement {{Service}} in `src/services/{{service}}.ts`
- [ ] T028 [US3] Implement {{endpoint}} in `src/{{location}}/{{file}}.ts`

**Verification:**
- [ ] TDD: RED → GREEN → REFACTOR completed for this story
- [ ] Cobertura de requisitos: {{FR-xxx}}

**Checkpoint:** every user story working independently ✅

---

<!-- Add more user story phases if needed -->

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose:** refinements that apply across every user story.

- [ ] T{{N}} [P] API documentation / README
- [ ] T{{N+1}} [P] Code cleanup and TODO removal
- [ ] T{{N+2}} Security review (OWASP Top 10)
- [ ] T{{N+3}} Performance verification contra success criteria

---

## Implementation Notes

<!-- El implementador propaga aprendizajes de tareas tempranas a tareas posteriores -->
<!-- e.g. "T012: Redis cache needs manual serialization for Date types" -->

## Final Verification

- [ ] All tests pass: `{{TEST_COMMAND}}`
- [ ] Coverage not lower than main
- [ ] Linter limpio: `{{LINT_COMMAND}}`
- [ ] Type check limpio: `{{TYPECHECK_COMMAND}}`
- [ ] Full traceability: every FR has at least one test
- [ ] Cada user story es independientemente funcional
- [ ] Constitution Check re-verified post-implementation
