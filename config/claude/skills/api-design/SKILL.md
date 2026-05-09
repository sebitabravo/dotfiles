---
name: api-design
description: Design RESTful APIs with proper status codes, pagination, error responses, versioning, and HATEOAS. Use when creating new endpoints, reviewing API design, or refactoring routes.
---

# API Design

Diseño de APIs RESTful con foco en consistencia, escalabilidad y developer experience.

## When to Use

- Crear nuevos endpoints o recursos.
- Revisar diseño de API existente.
- Definir contratos de API para microservicios.
- El usuario pregunta sobre versionado, paginación, o estructura de responses.

## Principles

### URLs
- Sustantivos en plural: `/users`, `/users/:id/orders`.
- Sin verbos en la URL. La acción la define el método HTTP.
- Hasta 3 niveles de anidación máximo. Más → evaluar un recurso raíz.

### Métodos HTTP

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/users` | Listar con filtros y paginación |
| `GET` | `/users/:id` | Obtener uno |
| `POST` | `/users` | Crear |
| `PUT` | `/users/:id` | Reemplazar completo |
| `PATCH` | `/users/:id` | Actualizar parcial |
| `DELETE` | `/users/:id` | Eliminar (soft delete) |

### Status Codes

| Códigos | Uso |
|---|---|
| `200` | GET/PUT/PATCH exitoso |
| `201` | POST exitoso (con Location header) |
| `204` | DELETE exitoso (sin body) |
| `400` | Error de validación del cliente |
| `401` | No autenticado |
| `403` | Autenticado pero sin permisos |
| `404` | Recurso no encontrado |
| `409` | Conflicto (duplicado, estado inválido) |
| `422` | Entidad no procesable (errores de validación) |
| `429` | Rate limit excedido |
| `500` | Error interno (nunca exponer detalles) |

### Response Envelope

Toda respuesta sigue esta estructura:

```json
{
  "data": {},
  "error": null,
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 150
  }
}
```

Error:
```json
{
  "data": null,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "El campo email es requerido",
    "details": [{"field": "email", "reason": "required"}]
  },
  "meta": null
}
```

### Paginación

- Siempre paginar colecciones. Sin excepción.
- Parámetros: `?page=1&per_page=20`. Máximo `per_page=100`.
- Response incluye `meta` con `page`, `per_page`, `total`, `total_pages`.
- Cursor-based para datasets grandes o tiempo real.

### Versionado

- En el header: `Accept: application/vnd.api.v2+json`.
- Fallback a URL: `/v2/users` si el header no es viable.
- Deprecación: warning en header `Sunset` + documentación de migration path.

### Filtering, Sorting, Search

```
GET /users?status=active&role=admin     → filtros exactos
GET /users?q=juan                        → búsqueda textual
GET /users?sort=-created_at,name         → ordenamiento (- para desc)
GET /users?include=orders,profile        → recursos relacionados
```

### Rate Limiting

Headers obligatorios en toda response:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 987
X-RateLimit-Reset: 1623456789
```
