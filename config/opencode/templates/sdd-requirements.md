# Requirements — {{FEATURE_NAME}}

## Meta

- **Feature:** {{FEATURE_NAME}}
- **Author:** spec-author
- **Status:** draft | spec_ready
- **Date:** {{DATE}}
- **Constitution:** [ ] Verified against project constitution

## Context

<!-- What problem does this feature solve? Why now? -->

## User Stories *(mandatory)*

<!--
  User stories PRIORIZADAS como journeys independientes.
  Cada historia debe ser INDEPENDIENTEMENTE TESTEABLE — si implementás UNA sola,
  deberías tener un MVP viable que entregue valor.

  P1 = crítico (MVP), P2 = importante, P3 = deseable.
-->

### User Story 1 — {{TITLE}} (Priority: P1) 🎯 MVP

**Narrativa:** [Describir el journey en lenguaje simple]

**Por qué esta prioridad:** [Explicar el valor y por qué es P1]

**Test Independiente:** [Cómo se puede testear esta historia sola — ej: "Se puede verificar completamente creando una cuenta y recibiendo el email de bienvenida"]

**Acceptance Scenarios:**

1. **Given** [estado inicial], **When** [acción], **Then** [resultado esperado]
2. **Given** [estado inicial], **When** [acción], **Then** [resultado esperado]

---

### User Story 2 — {{TITLE}} (Priority: P2)

**Narrativa:** [Describir el journey en lenguaje simple]

**Por qué esta prioridad:** [Explicar el valor]

**Test Independiente:** [Cómo se puede testear sola]

**Acceptance Scenarios:**

1. **Given** [estado inicial], **When** [acción], **Then** [resultado esperado]

---

### User Story 3 — {{TITLE}} (Priority: P3)

**Narrativa:** [Describir el journey en lenguaje simple]

**Por qué esta prioridad:** [Explicar el valor]

**Test Independiente:** [Cómo se puede testear sola]

**Acceptance Scenarios:**

1. **Given** [estado inicial], **When** [acción], **Then** [resultado esperado]

---

<!-- Agregar más user stories si es necesario -->

## Functional Requirements (EARS)

<!--
  Usar notación EARS: While/Action/Condition, When/Trigger, If/Condition.
  FR-001, FR-002... cada uno DEBE ser testeable.
  Usar [NEEDS CLARIFICATION: ...] cuando algo no está definido.
-->

### FR-001 — {{REQUIREMENT_NAME}}

**Type:** Ubiquitous | Event-Driven | State-Driven | Optional | Unwanted

**Description:** <!-- El sistema DEBE... -->

**Acceptance Criteria:**
- [ ] {{CRITERION_1}}
- [ ] {{CRITERION_2}}

### FR-002 — {{REQUIREMENT_NAME}}

**Type:**

**Description:**

**Acceptance Criteria:**
- [ ] {{CRITERION_1}}

### FR-003 — {{REQUIREMENT_NAME}} [NEEDS CLARIFICATION: {{WHAT_IS_UNCLEAR}}]

**Type:**

**Description:**

**Acceptance Criteria:**
- [ ] {{CRITERION_1}}

<!-- Agregar más FR<n> -->

## Key Entities

<!-- Solo si el feature involucra datos. Qué representan, atributos clave sin implementación. -->

- **{{Entity 1}}**: [Qué representa, atributos clave]
- **{{Entity 2}}**: [Qué representa, relaciones con otras entidades]

## Non-Functional Requirements

### Performance
- <!-- ej: Response < 200ms p95, 1000 req/s -->

### Security
- <!-- ej: Input sanitizado contra XSS, OWASP Top 10 -->

### Accessibility
- <!-- ej: WCAG 2.2 AA -->

## Edge Cases

| Case | Expected Behavior |
|---|---|
| {{EMPTY_INPUT}} | {{RESPONSE}} |
| {{MAX_INPUT}} | {{RESPONSE}} |
| {{NETWORK_ERROR}} | {{RESPONSE}} |
| {{CONCURRENT_ACCESS}} | {{RESPONSE}} |

## Success Criteria *(mandatory)*

<!--
  Medibles y technology-agnostic. No "implementar endpoint X" sino
  "usuario completa tarea Y en menos de Z segundos".
-->

### Measurable Outcomes

- **SC-001**: [Métrica medible, ej: "Usuarios completan registro en < 2 minutos"]
- **SC-002**: [Métrica medible, ej: "Sistema soporta 1000 usuarios concurrentes sin degradación"]
- **SC-003**: [Métrica de satisfacción, ej: "90% de usuarios completa tarea principal en primer intento"]

## Assumptions

<!--
  Lo que asumimos basado en defaults razonables cuando la descripción
  del feature no especifica ciertos detalles.
-->

- [Asunción sobre usuarios objetivo, ej: "Usuarios tienen conexión estable a internet"]
- [Asunción sobre alcance, ej: "Soporte mobile fuera de scope para v1"]
- [Dependencia en sistema/servicio existente, ej: "Requiere acceso a API de perfil de usuario existente"]

## Out of Scope

- <!-- Lo que NO se construye en este feature -->

## References

- <!-- Links a docs, APIs, issues relacionados -->
