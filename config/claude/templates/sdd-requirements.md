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
  PRIORITIZED user stories, written as independent journeys.
  Each story must be INDEPENDENTLY TESTABLE — if you implement only ONE,
  you should still have a viable MVP that delivers value.

  P1 = critical (MVP), P2 = important, P3 = nice to have.
-->

### User Story 1 — {{TITLE}} (Priority: P1) 🎯 MVP

**Narrative:** [Describe the journey in plain language]

**Why this priority:** [Explain the value and why it is P1]

**Independent Test:** [How this story can be tested on its own — e.g. "Fully verifiable by creating an account and receiving the welcome email"]

**Acceptance Scenarios:**

1. **Given** [initial state], **When** [action], **Then** [expected result]
2. **Given** [initial state], **When** [action], **Then** [expected result]

---

### User Story 2 — {{TITLE}} (Priority: P2)

**Narrative:** [Describe the journey in plain language]

**Why this priority:** [Explain the value]

**Independent Test:** [How it can be tested on its own]

**Acceptance Scenarios:**

1. **Given** [initial state], **When** [action], **Then** [expected result]

---

### User Story 3 — {{TITLE}} (Priority: P3)

**Narrative:** [Describe the journey in plain language]

**Why this priority:** [Explain the value]

**Independent Test:** [How it can be tested on its own]

**Acceptance Scenarios:**

1. **Given** [initial state], **When** [action], **Then** [expected result]

---

<!-- Add more user stories if needed -->

## Functional Requirements (EARS)

<!--
  Use EARS notation: While/Action/Condition, When/Trigger, If/Condition.
  FR-001, FR-002... each one MUST be testable.
  Use [NEEDS CLARIFICATION: ...] when something is undefined.
-->

### FR-001 — {{REQUIREMENT_NAME}}

**Type:** Ubiquitous | Event-Driven | State-Driven | Optional | Unwanted

**Description:** <!-- The system MUST... -->

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

<!-- Add more FR<n> -->

## Key Entities

<!-- Only if the feature involves data. What they represent, key attributes, no implementation. -->

- **{{Entity 1}}**: [What it represents, key attributes]
- **{{Entity 2}}**: [What it represents, relationships with other entities]

## Non-Functional Requirements

### Performance
- <!-- e.g. Response < 200ms p95, 1000 req/s -->

### Security
- <!-- e.g. Input sanitized against XSS, OWASP Top 10 -->

### Accessibility
- <!-- e.g. WCAG 2.2 AA -->

## Edge Cases

| Case | Expected Behavior |
|---|---|
| {{EMPTY_INPUT}} | {{RESPONSE}} |
| {{MAX_INPUT}} | {{RESPONSE}} |
| {{NETWORK_ERROR}} | {{RESPONSE}} |
| {{CONCURRENT_ACCESS}} | {{RESPONSE}} |

## Success Criteria *(mandatory)*

<!--
  Measurable and technology-agnostic. Not "implement endpoint X" but
  "user completes task Y in under Z seconds".
-->

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g. "Users complete signup in < 2 minutes"]
- **SC-002**: [Measurable metric, e.g. "System handles 1000 concurrent users without degradation"]
- **SC-003**: [Satisfaction metric, e.g. "90% of users complete the main task on first attempt"]

## Assumptions

<!--
  What we assume based on reasonable defaults when the feature description
  does not specify certain details.
-->

- [Assumption about target users, e.g. "Users have a stable internet connection"]
- [Assumption about scope, e.g. "Mobile support out of scope for v1"]
- [Dependency on an existing system/service, e.g. "Requires access to the existing user profile API"]

## Out of Scope

- <!-- What is NOT built in this feature -->

## References

- <!-- Links to docs, APIs, related issues -->
