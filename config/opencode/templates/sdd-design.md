# Design — {{FEATURE_NAME}}

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** {{AUTHOR}}
- **Status:** draft
- **Date:** {{DATE}}

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

<!-- Interfaces, tipos, esquemas DB. SIN logica de negocio aca. -->

```typescript
// Ejemplo: tipos/interfaces nuevos o modificados
interface {{NAME}} {
  {{FIELD}}: {{TYPE}};
}
```

## File Structure Plan

<!-- Archivos a crear/modificar. Esto define boundaries para las tasks. -->

```
src/
  {{path}}/{{file}}.ts  — {{purpose}}
tests/
  {{path}}/{{file}}.test.ts  — {{what_it_covers}}
```

## Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| {{PACKAGE}} | {{VERSION}} | {{WHAT_FOR}} |

## Risks

| Risk | Mitigation |
|---|---|
| {{DESCRIPTION}} | {{HOW_TO_MITIGATE}} |

## References

- <!-- Patrones existentes en el codebase, docs externos, APIs -->
