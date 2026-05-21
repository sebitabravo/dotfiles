# Tasks — {{FEATURE_NAME}}

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** {{AUTHOR}}
- **Status:** draft
- **Total tasks:** {{N}}
- **Linked spec:** `specs/{{FEATURE_NAME}}/requirements.md`

## Pre-implementation

- [ ] Verificar que `requirements.md` este en estado `spec_ready`.
- [ ] Verificar que `design.md` tenga un File Structure Plan completo.
- [ ] Verificar que todas las dependencias esten instaladas.

## Tasks

<!-- Cada task = un commit. Boundary define archivos que toca. Depends bloquea ejecucion. -->

### T1 — {{TASK_TITLE}}

_Boundary:_ `src/{{file}}.ts`, `tests/{{file}}.test.ts`
_Depends:_ —
_TDD:_ RED → GREEN → REFACTOR

- [ ] RED: Escribir test que falle para {{R<n>}}
- [ ] GREEN: Implementar codigo minimo para pasar el test
- [ ] REFACTOR: Limpiar, re-correr tests, confirmar green
- [ ] Verificar cobertura de requisito: {{R<n>}}

### T2 — {{TASK_TITLE}}

_Boundary:_ `src/{{file}}.ts`, `tests/{{file}}.test.ts`
_Depends:_ T1
_TDD:_ RED → GREEN → REFACTOR

- [ ] RED: Escribir test que falle para {{R<n>}}
- [ ] GREEN: Implementar codigo minimo para pasar el test
- [ ] REFACTOR: Limpiar, re-correr tests, confirmar green
- [ ] Verificar cobertura de requisito: {{R<n>}}

<!-- Agregar mas T<n> segun necesidad -->

## Implementation Notes

<!-- El implementador propaga aprendizajes de tasks tempranas a tasks tardias aca -->
<!-- e.g.: "T1: Redis cache requiere serializacion manual para tipos Date" -->

## Final Verification

- [ ] Todos los tests pasan: `{{TEST_COMMAND}}`
- [ ] Cobertura no menor a main
- [ ] Linter limpio: `{{LINT_COMMAND}}`
- [ ] Type check limpio: `{{TYPECHECK_COMMAND}}`
- [ ] Trazabilidad completa: cada R<n> tiene al menos un test
