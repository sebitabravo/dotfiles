---
description: "Requisitos y patrones de testing"
globs: []
alwaysApply: true
---

# Testing

## Reglas

- **Todo feature nuevo lleva tests**. Sin excepción.
- **Todo bug fix lleva test de regresión** que falle sin el fix.
- **Tests deben ser determinísticos**. Sin `Math.random()`, sin dependencia de tiempo real.
- **Tests rápidos**. Si un test tarda >2s, mockeá la dependencia lenta.
- **Sin tests que dependan de orden de ejecución**. Cada test se corre aislado.

## Qué testear

1. **Caja negra** para lógica de negocio — entradas y salidas esperadas.
2. **Edge cases**: vacío, nulo, límites, caracteres especiales.
3. **Errores**: qué pasa cuando algo falla, no solo el happy path.
4. **Contratos de API**: schema de response, status codes, headers.

## Qué NO testear

- Implementación interna (métodos privados, detalles de algoritmo que no afectan output).
- Framework code (ruteo, ORM básico, serialización del framework).
- Tests de tests (no testees mocks, fixtures, o helpers de testeo).

## Estructura

- Un archivo de test por módulo/componente.
- `describe` anida escenarios. `it` describe el caso específico.
- Nombres de test describen el comportamiento esperado, no la implementación.
  - Bien: `it("retorna 404 cuando el usuario no existe")`
  - Mal: `it("test getUser con id inválido")`
