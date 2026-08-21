# Design — {{FEATURE_NAME}}

> **Legacy compatibility template:** OpenSpec projects use the generated
> `openspec/changes/<name>/design.md` instead of this template.

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** spec-author
- **Status:** draft
- **Date:** {{DATE}}
- **Spec:** `specs/{{FEATURE_NAME}}/requirements.md`

## Summary

<!-- Pull from the spec: main requirement + technical approach -->

## Technical Context

<!--
  ACTION REQUIRED: replace with the real technical details of the project.
  Use [NEEDS CLARIFICATION] wherever it is undefined.
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

*GATE: must pass before Phase 0 research. Re-check after Phase 1 design.*

<!-- Verify each principle of the project's constitution -->

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
<!-- Diagram of affected components/directories -->
<!-- Use Mermaid where it applies: -->
<!--
graph TD
    A[Controller] --> B[Service]
    B --> C[Repository]
-->
```

## Data Model

<!-- Interfaces, types, DB schemas. NO business logic. -->

```typescript
// Example: new or modified types/interfaces
interface {{NAME}} {
  {{FIELD}}: {{TYPE}};
}
```

## Project Structure

### Documentation (this feature)

```text
specs/{{FEATURE_NAME}}/
├── proposal.md          # Initial proposal (explore -> propose phase)
├── requirements.md      # Spec phase
├── design.md            # This file (design phase)
├── tasks.md             # Tasks phase
└── apply-progress.md    # Apply phase
```

### Source Code (repository root)

```text
src/
  {{path}}/{{file}}.ts  — {{purpose}}
tests/
  {{path}}/{{file}}.test.ts  — {{what_it_covers}}
```

**Structure Decision:** [Document the structure that was selected]

## Dependencies

| Dependency | Version | Purpose |
|---|---|---|
| {{PACKAGE}} | {{VERSION}} | {{WHAT_FOR}} |

## Complexity Tracking

> **Fill in ONLY if the Constitution Check has violations that need justification**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| {{VIOLATION}} | {{CURRENT_NEED}} | {{WHY_SIMPLER_WASNT_ENOUGH}} |

## Risks

| Risk | Mitigation |
|---|---|
| {{DESCRIPTION}} | {{HOW_TO_MITIGATE}} |

## References

- <!-- Existing patterns in the codebase, external docs, APIs -->
