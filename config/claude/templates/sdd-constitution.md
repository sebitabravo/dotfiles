# Constitution — {{PROJECT_NAME}}

> **Qué es:** Principios no-negociables que definen cómo se construye software en este proyecto. Cada PR, feature, y decisión técnica DEBE alinearse con estos principios.
>
> **Cuándo se usa:** Antes de cualquier feature, el Constitution Check verifica que la propuesta no viole estos principios. Si una violación es necesaria, se documenta en Complexity Tracking.
>
> **Basado en:** Spec Kit constitution template. Adaptado al flujo SDD.

---

## Meta

- **Project:** {{PROJECT_NAME}}
- **Version:** 1.0.0
- **Ratified:** {{DATE}}
- **Last Amended:** {{DATE}}

---

## Core Principles *(5+, cada uno no-negociable)*

<!--
  Cada principio DEBE ser accionable (no "be excellent"),
  verificable (se puede chequear con tooling automático),
  y NO-NEGOCIABLE (si se viola, requiere justificación explícita).
-->

### I. {{PRINCIPLE_NAME}}

**Statement:** [Qué significa, en una frase clara y directa]

**Rationale:** [Por qué existe este principio. Qué problema previene.]

**Verification:**
- [ ] [Cómo se verifica automáticamente — lint rule, test pattern, CI gate]

**Non-Negotiable:** [Qué NO se permite bajo ninguna circunstancia sin Complexity Tracking]

---

### II. {{PRINCIPLE_NAME}}

**Statement:**

**Rationale:**

**Verification:**
- [ ]

**Non-Negotiable:**

---

### III. {{PRINCIPLE_NAME}}

**Statement:**

**Rationale:**

**Verification:**
- [ ]

**Non-Negotiable:**

---

### IV. {{PRINCIPLE_NAME}}

**Statement:**

**Rationale:**

**Verification:**
- [ ]

**Non-Negotiable:**

---

### V. {{PRINCIPLE_NAME}}

**Statement:**

**Rationale:**

**Verification:**
- [ ]

**Non-Negotiable:**

---

## Additional Constraints

### Security
- [Requerimientos mínimos de seguridad — ej: OWASP Top 10, secrets en vault, 2FA en cuentas]

### Performance
- [Métricas mínimas aceptables — ej: LCP < 2.5s, API p95 < 200ms]

### Accessibility
- [Estándar mínimo — ej: WCAG 2.2 AA en todos los componentes]

### Data Privacy
- [Política de datos — ej: No PII en logs, GDPR compliance para datos de EU]

---

## Development Workflow

### Quality Gates *(todos los PRs DEBEN pasar)*

1. [Gate 1: ej: Tests pasan — `npm test` exit 0]
2. [Gate 2: ej: Linter limpio — `npm run lint` sin warnings]
3. [Gate 3: ej: Type check — `tsc --noEmit`]
4. [Gate 4: ej: Code review — al menos 1 approve]
5. [Gate 5: ej: Constitution Check — sin violaciones no justificadas]

### Branch Strategy
- [Convención de branches — ej: `feature/{{name}}`, `fix/{{name}}`]

### Commit Convention
- [Formato — ej: Conventional Commits, sin AI footprint]

---

## Governance

### Amendment Process

1. Proponer cambio vía PR a `specs/constitution-amendment-{{description}}.md`
2. Discusión con equipo (mínimo 48h)
3. Aprobación requiere [N] approves
4. Version bump según semver de constitution

### Version Policy

| Cambio | Bump |
|---|---|
| Nuevo principio, relaja constraint | MAJOR |
| Refuerza principio existente | MINOR |
| Clarificación, typo | PATCH |

### Compliance Review

- Cada feature: Constitution Check en proposal y design
- Mensual: auditoría de PRs mergeados contra principios
- Trimestral: revisión completa de la constitución (¿sigue vigente?)
