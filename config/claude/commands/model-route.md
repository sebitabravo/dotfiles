---
description: "Selecciona el modelo adecuado según la complejidad de la tarea"
---

Evalúa la complejidad de ${ARGUMENTS:-la tarea actual} y sugiere el modelo óptimo.

| Complejidad | Tarea típica | Modelo |
|---|---|---|
| **Baja** | Typo fix, rename, comment cleanup, 1-line change | `haiku` |
| **Media** | Feature simple, refactor acotado, test nuevo | `sonnet` |
| **Alta** | Arquitectura, sistema nuevo, bug complejo, diseño | `opus` |

Si estás en DeepSeek API, todos los modelos mapean al mismo backend. La diferencia está en el comportamiento del sistema.
