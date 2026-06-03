# Checklist — {{FEATURE_NAME}}

> **Propósito:** Verificación sistemática para cada fase del SDD flow. NO es opcional — cada item debe marcarse antes de avanzar a la siguiente fase.
>
> **Uso:** Copiar en `specs/{{FEATURE_NAME}}/checklist.md` al iniciar el feature.

---

## Phase 1: Explore → Propose

- [ ] CHK001 Problema claramente definido en una frase
- [ ] CHK002 Scope In/Out documentado sin ambigüedad
- [ ] CHK003 Al menos 2 alternativas consideradas y rechazadas con razón documentada
- [ ] CHK004 Constitution Check inicial: sin violaciones no justificadas
- [ ] CHK005 Affected areas mapeadas (archivos/módulos que se tocarán)

---

## Phase 2: Spec (Requirements)

- [ ] CHK006 Cada user story tiene prioridad (P1/P2/P3) y justificación
- [ ] CHK007 Cada user story es INDEPENDIENTEMENTE TESTEABLE
- [ ] CHK008 Acceptance scenarios en formato Given/When/Then
- [ ] CHK009 Functional Requirements cubren todos los user stories (trazables vía FR-xxx)
- [ ] CHK010 Edge cases documentados (vacío, máximo, error, concurrencia)
- [ ] CHK011 Success criteria son medibles y technology-agnostic
- [ ] CHK012 Assumptions explícitas — nada asumido implícitamente
- [ ] CHK013 Sin [NEEDS CLARIFICATION] abiertos — todos resueltos

---

## Phase 3: Design

- [ ] CHK014 Technical Context table completa (sin N/A genéricos)
- [ ] CHK015 Constitution Check re-verificado post-design
- [ ] CHK016 Data model definido (tipos, relaciones, constraints)
- [ ] CHK017 File structure plan con paths concretos
- [ ] CHK018 Dependencies listadas con versión y propósito
- [ ] CHK019 Riesgos identificados con mitigación
- [ ] CHK020 Complexity Tracking lleno si hay violaciones a la constitución

---

## Phase 4: Tasks

- [ ] CHK021 Tasks agrupadas en fases (Setup → Foundational → US<n> → Polish)
- [ ] CHK022 [P] marcado en tasks paralelizables
- [ ] CHK023 [US<n>] tag en cada task de implementación
- [ ] CHK024 Cada user story tiene Independent Test documentado
- [ ] CHK025 Checkpoints definidos entre fases
- [ ] CHK026 Orden de dependencias correcto (T00X depende de T00Y está bien)

---

## Phase 5: Apply

- [ ] CHK027 TDD: RED → GREEN → REFACTOR por task
- [ ] CHK028 Cada FR tiene al menos un test que lo cubre
- [ ] CHK029 Sin TODOs ni código comentado en el diff final
- [ ] CHK030 Commits usan Conventional Commits, sin AI footprint

---

## Phase 6: Verify

- [ ] CHK031 Tests pasan: `{{TEST_COMMAND}}`
- [ ] CHK032 Linter limpio: `{{LINT_COMMAND}}`
- [ ] CHK033 Type check: `{{TYPECHECK_COMMAND}}`
- [ ] CHK034 Coverage no menor que main
- [ ] CHK035 Cada user story funciona independientemente
- [ ] CHK036 Success criteria del requirements.md cumplidos
- [ ] CHK037 Security review pasó (si aplica)
- [ ] CHK038 Performance verification pasó (si aplica)

---

## Phase 7: Archive

- [ ] CHK039 `apply-progress.md` completo y finalizado
- [ ] CHK040 Specs movidos a `specs/archived/` o equivalente
- [ ] CHK041 Lecciones aprendidas documentadas (si hay algo no obvio)

---

## Notes

<!--
  Usar para:
  - Items que se saltan con justificación (ej: "CHK038 skipped — no perf requirements")
  - Bloqueantes encontrados durante la verificación
  - Decisiones de último momento
-->
