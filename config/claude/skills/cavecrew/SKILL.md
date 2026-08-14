---
name: cavecrew
description: Protocolo de delegación a subagentes. Los subagentes escriben resultados a archivos y devuelven SOLO el path, nunca contenido verbatim por chat.
---

## Protocolo de delegación

Complementa la regla ANTI-TELEPHONE de CLAUDE.md con la convención de archivos y el template de delegación.

### Cuándo delegar

- Exploración amplia del codebase (>3 lecturas de archivos)
- Búsquedas en muchos archivos
- Tareas de investigación en paralelo
- Operaciones context-heavy que inflarían el contexto principal

### Reglas

1. **Los subagentes escriben resultados a archivos.** Devuelven SOLO el path.
2. **Nunca pasar contenido verbatim por chat.** El chat corrompe la señal; los archivos sobreviven a la compactación.
3. **Si un subagente no te da un path, exigíselo.**
4. **El agente principal lee el archivo cuando lo necesita.** No antes.

### Convención de archivos de salida

```
/tmp/cavecrew/<nombre-tarea>-result.md
```

### Tipos de subagente (Claude)

| Tipo | Uso |
|------|-----|
| `explore` | Exploración de codebase, encontrar patrones, entender arquitectura |
| `code-reviewer` | Revisión de diffs, análisis de seguridad |
| `debugger` | Root cause analysis, investigación de errores |
| `general` | Research, búsqueda de documentación, tareas multi-paso |
| `security-auditor` | Auditorías de auth, permisos, secretos |

### Template de delegación

Al delegar una tarea, incluí:
1. Objetivo claro
2. Scope (qué archivos/dirs buscar)
3. Formato de salida esperado (path del archivo con resultados)
4. Constraints (límite de tiempo, profundidad)

### Ejemplo de delegación

```
Tarea: Encontrar todos los endpoints que aceptan input de usuario sin validación.
Scope: src/routes/ y src/controllers/
Output: Escribir hallazgos en /tmp/cavecrew/validation-audit-result.md
Formato: Tabla con archivo, endpoint, parámetro, estado de validación actual
```

### Anti-patterns

- No delegues tareas triviales (lectura de un solo archivo, grep simple).
- No delegues y después hagas la misma búsqueda vos.
- No aceptes resultados inline. Exigí siempre un path de archivo.
- No delegues si ya tenés la respuesta en contexto.
