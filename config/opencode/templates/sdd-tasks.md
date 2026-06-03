# Tasks — {{FEATURE_NAME}}

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** spec-author
- **Status:** draft
- **Total tasks:** {{N}}
- **Linked spec:** `specs/{{FEATURE_NAME}}/requirements.md`
- **Linked design:** `specs/{{FEATURE_NAME}}/design.md`

## Format: `[ID] [P?] [US<n>] Description`

- **[P]**: Puede ejecutarse en paralelo (diferentes archivos, sin dependencias)
- **[US<n>]**: A qué user story pertenece (US1, US2, US3)
- Incluir paths exactos en las descripciones

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose:** Inicialización del proyecto y estructura base.

**Prerequisites:**
- [ ] `requirements.md` en estado `spec_ready`
- [ ] `design.md` completo con File Structure Plan
- [ ] Dependencias instaladas

- [ ] T001 Crear estructura del proyecto según design.md
- [ ] T002 [P] Inicializar proyecto con dependencias
- [ ] T003 [P] Configurar linting y formateo

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose:** Infraestructura core que DEBE estar completa ANTES de cualquier user story.

**⚠️ CRITICAL:** Ninguna user story comienza hasta que esta fase esté completa.

- [ ] T004 Setup base de datos y migraciones
- [ ] T005 [P] Implementar autenticación/autorización
- [ ] T006 [P] Setup routing y middleware
- [ ] T007 Crear modelos/entidades base que todas las stories necesitan
- [ ] T008 [P] Configurar error handling y logging
- [ ] T009 [P] Configurar environment y variables

**Checkpoint:** Foundation ready — empieza implementación de user stories

---

## Phase 3: User Story 1 — {{TITLE}} (Priority: P1) 🎯 MVP

**Goal:** [Qué entrega esta story]

**Independent Test:** [Cómo verificar que funciona sola]

### Tests for User Story 1 *(solo si se solicitaron tests)*

> **Escribir tests PRIMERO, verificar que FALLEN antes de implementar**

- [ ] T010 [P] [US1] Contract test para {{endpoint}} en `tests/contract/test_{{name}}.test.ts`
- [ ] T011 [P] [US1] Integration test para {{user_journey}} en `tests/integration/test_{{name}}.test.ts`

### Implementation for User Story 1

- [ ] T012 [P] [US1] Crear modelo {{Entity1}} en `src/models/{{entity1}}.ts`
- [ ] T013 [P] [US1] Crear modelo {{Entity2}} en `src/models/{{entity2}}.ts`
- [ ] T014 [US1] Implementar {{Service}} en `src/services/{{service}}.ts` (depende de T012, T013)
- [ ] T015 [US1] Implementar {{endpoint}} en `src/{{location}}/{{file}}.ts`
- [ ] T016 [US1] Agregar validación y error handling
- [ ] T017 [US1] Agregar logging para operaciones de US1

**Verification:**
- [ ] TDD: RED → GREEN → REFACTOR completado para esta story
- [ ] Cobertura de requisitos: {{FR-xxx, FR-yyy}}

**Checkpoint:** User Story 1 funcional y testeable independientemente ✅

---

## Phase 4: User Story 2 — {{TITLE}} (Priority: P2)

**Goal:** [Qué entrega esta story]

**Independent Test:** [Cómo verificar que funciona sola]

### Tests for User Story 2 *(solo si se solicitaron tests)*

- [ ] T018 [P] [US2] Contract test para {{endpoint}} en `tests/contract/test_{{name}}.test.ts`
- [ ] T019 [P] [US2] Integration test para {{user_journey}} en `tests/integration/test_{{name}}.test.ts`

### Implementation for User Story 2

- [ ] T020 [P] [US2] Crear modelo {{Entity}} en `src/models/{{entity}}.ts`
- [ ] T021 [US2] Implementar {{Service}} en `src/services/{{service}}.ts`
- [ ] T022 [US2] Implementar {{endpoint}} en `src/{{location}}/{{file}}.ts`
- [ ] T023 [US2] Integrar con componentes de User Story 1 (si aplica)

**Verification:**
- [ ] TDD: RED → GREEN → REFACTOR completado para esta story
- [ ] Cobertura de requisitos: {{FR-xxx}}

**Checkpoint:** User Stories 1 Y 2 funcionales independientemente ✅

---

## Phase 5: User Story 3 — {{TITLE}} (Priority: P3)

**Goal:** [Qué entrega esta story]

**Independent Test:** [Cómo verificar que funciona sola]

### Tests for User Story 3 *(solo si se solicitaron tests)*

- [ ] T024 [P] [US3] Contract test para {{endpoint}} en `tests/contract/test_{{name}}.test.ts`
- [ ] T025 [P] [US3] Integration test para {{user_journey}} en `tests/integration/test_{{name}}.test.ts`

### Implementation for User Story 3

- [ ] T026 [P] [US3] Crear modelo {{Entity}} en `src/models/{{entity}}.ts`
- [ ] T027 [US3] Implementar {{Service}} en `src/services/{{service}}.ts`
- [ ] T028 [US3] Implementar {{endpoint}} en `src/{{location}}/{{file}}.ts`

**Verification:**
- [ ] TDD: RED → GREEN → REFACTOR completado para esta story
- [ ] Cobertura de requisitos: {{FR-xxx}}

**Checkpoint:** Todas las user stories funcionales independientemente ✅

---

<!-- Agregar más fases de user stories si es necesario -->

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose:** Refinamientos que aplican a todas las user stories.

- [ ] T{{N}} [P] Documentación de API / README
- [ ] T{{N+1}} [P] Limpieza de código y eliminación de TODOs
- [ ] T{{N+2}} Security review (OWASP Top 10)
- [ ] T{{N+3}} Performance verification contra success criteria

---

## Implementation Notes

<!-- El implementador propaga aprendizajes de tareas tempranas a tareas posteriores -->
<!-- ej: "T012: Redis cache requiere serialización manual para tipos Date" -->

## Final Verification

- [ ] Todos los tests pasan: `{{TEST_COMMAND}}`
- [ ] Coverage no menor que main
- [ ] Linter limpio: `{{LINT_COMMAND}}`
- [ ] Type check limpio: `{{TYPECHECK_COMMAND}}`
- [ ] Trazabilidad completa: cada FR tiene al menos un test
- [ ] Cada user story es independientemente funcional
- [ ] Constitution Check re-verificado post-implementación
