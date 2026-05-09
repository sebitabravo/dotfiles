---
name: code-review
description: Systematic code review for correctness, security, performance, and maintainability. Use before merging PRs, after completing features, or when asked to review code.
---

# Code Review

Revisión sistemática de código. Una pasada por dimensión, no un vistazo general.

## When to Use

- PR listo para review.
- Feature recién completada.
- El usuario pide "review this", "check my code", "code review".
- Antes de commit significativo.

## Review Dimensions

Revisar en este orden. Cada dimensión es un pase independiente:

### 1. Correctness
- ¿Hace lo que debe? Leer el diff contra los requisitos.
- Casos borde: null, vacío, límites, timeouts, errores de red.
- Condiciones de carrera si hay código concurrente/asíncrono.
- Errores de off-by-one, condiciones invertidas.

### 2. Security
- Input validado y sanitizado.
- SQL injection, XSS, path traversal.
- Secrets ausentes del diff.
- Auth y autorización en nuevas rutas.
- Rate limiting en endpoints públicos.

### 3. Performance
- N+1 queries: loops con llamadas a DB.
- Operaciones bloqueantes en event loop (sync I/O en Node/Python async).
- Memoria: arrays/objetos grandes sin necesidad, leaks en event listeners.
- Índices necesarios para nuevas queries.

### 4. Maintainability
- Nombres claros y consistentes.
- Funciones con una sola responsabilidad.
- Sin abstracciones prematuras.
- Sin código comentado o dead code.
- Testabilidad: ¿se puede testear esto fácilmente?

### 5. Testing
- Tests para el happy path.
- Tests para al menos 2 edge cases.
- Tests para comportamiento de error.
- Sin tests que dependan de orden de ejecución o estado global mutable.

## Output

Emitir hallazgos en este formato:

```
path:line: <severidad> <problema>. <sugerencia de fix>.
```

Severidades: `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`.

No emitir halagos. No comentar formato si el linter lo cubre. Solo hallazgos accionables.
