# Tasks — {{FEATURE_NAME}}

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** spec-author
- **Status:** draft
- **Total tasks:** {{N}}
- **Linked spec:** `specs/{{FEATURE_NAME}}/requirements.md`
- **Linked design:** `specs/{{FEATURE_NAME}}/design.md`

## Format: `[ID] [P?] [US<n>] Description`

- **[P]**: can run in parallel (different files, no dependencies)
- **[US<n>]**: which user story it belongs to (US1, US2, US3)
- Include exact paths in the descriptions

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
