# Design — {{FEATURE_NAME}}

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** spec-author
- **Status:** draft
- **Date:** {{DATE}}
- **Spec:** `specs/{{FEATURE_NAME}}/requirements.md`

## Summary

<!-- Extraer del spec: requerimiento principal + enfoque técnico -->

## Technical Context

<!--
  ACTION REQUIRED: Reemplazar con los detalles técnicos reales del proyecto.
  Usar [NEEDS CLARIFICATION] donde no esté definido.
-->

| Field | Value |
|---|---|
| **Language/Version** | {{LANG_AND_VERSION}} |
| **Primary Dependencies** | {{FRAMEWORKS_AND_LIBS}} |
| **Storage** | {{DB_OR_N_A}} |
| **Testing** | {{TEST_FRAMEWORK}} |
| **Target Platform** | {{PLATFORM}} |
| **Project Type** | {{PROJECT_TYPE}} |
| **Performance Goals** | {{PERF_GOALS}} |
| **Constraints** | {{CONSTRAINTS}} |
| **Scale/Scope** | {{SCALE}} |

## Constitution Check

*GATE: Debe pasar antes de Phase 0 research. Re-check después de Phase 1 design.*

<!-- Verificar cada principio de la constitución del proyecto -->

| Principle | Status | Evidence |
|---|---|---|
| {{PRINCIPLE_1}} | ✅ / ❌ / ⚠️ | {{HOW_IT_COMPLIES}} |
| {{PRINCIPLE_2}} | ✅ / ❌ / ⚠️ | {{HOW_IT_COMPLIES}} |
| {{PRINCIPLE_3}} | ✅ / ❌ / ⚠️ | {{HOW_IT_COMPLIES}} |

## Technical Decisions

| Decision | Rejected Alternative | Reason |
|---|---|---|
| {{CHOSEN_OPTION}} | {{REJECTED_OPTION}} | {{WHY}} |

## Architecture

```
<!-- Diagrama de componentes/directorios afectados -->
<!-- Usar Mermaid cuando aplique: -->
<!--
graph TD
    A[Controller] --> B[Service]
    B --> C[Repository]
-->
```

## Data Model

<!-- Interfaces, types, DB schemas. SIN lógica de negocio. -->

```typescript
// Ejemplo: tipos/interfaces nuevos o modificados
interface {{NAME}} {
  {{FIELD}}: {{TYPE}};
}
```

## Project Structure

### Documentation (este feature)

```text
specs/{{FEATURE_NAME}}/
├── proposal.md          # Propuesta inicial (fase explore → propose)
├── requirements.md      # Este archivo (fase spec)
├── design.md            # Este archivo (fase design)
├── tasks.md             # Fase tasks
└── apply-progress.md    # Fase apply
```

### Source Code (repository root)

```text
src/
  {{path}}/{{file}}.ts  — {{purpose}}
tests/
  {{path}}/{{file}}.test.ts  — {{what_it_covers}}
```

**Structure Decision:** [Documentar la estructura seleccionada]

## Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| {{PACKAGE}} | {{VERSION}} | {{WHAT_FOR}} |

## Complexity Tracking

> **Llenar SOLO si el Constitution Check tiene violaciones que deben justificarse**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| {{VIOLATION}} | {{CURRENT_NEED}} | {{WHY_SIMPLER_WASNT_ENOUGH}} |

## Risks

| Risk | Mitigation |
|---|---|
| {{DESCRIPTION}} | {{HOW_TO_MITIGATE}} |

## References

- <!-- Patrones existentes en el codebase, docs externos, APIs -->
