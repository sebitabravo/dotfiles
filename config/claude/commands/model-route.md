---
description: "Elegir el modelo óptimo según complejidad, costo y latencia de la tarea"
argument-hint: "[tarea a analizar]"
---

Analizá la tarea y recomendá el modelo óptimo: $ARGUMENTS.

**Matriz de decisión** (modelos Claude disponibles en esta config):

| Complejidad | Modelo | Caso de uso |
|---|---|---|
| Trivial (typos, 1 línea) | haiku | Velocidad sobre inteligencia |
| Standard (features, bugs) | sonnet | Balance |
| Compleja (arquitectura, multi-agente) | opus | Máxima inteligencia |
| Planificación pesada / specs | opusplan | Planificación larga |
| Code review | opus + agente code-reviewer | Quality gate |

**Factores a evaluar**:
1. ¿Cuántos archivos hay que cambiar?
2. ¿Hay lógica de seguridad/auth involucrada?
3. ¿Es arquitectura o patrón nuevo?
4. ¿Se necesitan subagentes?
5. ¿Cuál es el presupuesto de costo/latencia?

Output: modelo recomendado + rationale + estimación de token usage.
