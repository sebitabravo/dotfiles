# Design — {{FEATURE_NAME}}

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** spec-author
- **Status:** draft
- **Date:** {{DATE}}

## Technical Decisions

| Decision | Rejected Alternative | Reason |
|---|---|---|
| {{CHOSEN_OPTION}} | {{REJECTED_OPTION}} | {{WHY}} |

## Architecture

```
<!-- Diagram of affected components/directories -->
<!-- Use Mermaid when applicable: -->
<!--
graph TD
    A[Controller] --> B[Service]
    B --> C[Repository]
-->
```

## Data Model

<!-- Interfaces, types, DB schemas. NO business logic here. -->

```typescript
// Example: new or modified types/interfaces
interface {{NAME}} {
  {{FIELD}}: {{TYPE}};
}
```

## File Structure Plan

<!-- Files to create/modify. This defines boundaries for tasks. -->

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

- <!-- Existing patterns in the codebase, external docs, APIs -->
