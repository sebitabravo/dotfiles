---
name: api-design
description: Design RESTful APIs with proper status codes, pagination, error responses, versioning, and HATEOAS. Use when creating new endpoints, reviewing API design, or refactoring routes.
---

# API Design

RESTful API design focused on consistency, scalability, and developer experience.

## When to Use

- Creating new endpoints or resources.
- Reviewing existing API design.
- Defining API contracts for microservices.
- User asks about versioning, pagination, or response structure.

## Principles

### URLs
- Plural nouns: `/users`, `/users/:id/orders`.
- No verbs in the URL. The action is defined by the HTTP method.
- Max 3 nesting levels. More → evaluate a root resource.

### HTTP Methods

| Method | Route | Description |
|---|---|---|
| `GET` | `/users` | List with filters and pagination |
| `GET` | `/users/:id` | Get one |
| `POST` | `/users` | Create |
| `PUT` | `/users/:id` | Full replace |
| `PATCH` | `/users/:id` | Partial update |
| `DELETE` | `/users/:id` | Delete (soft delete) |

### Status Codes

| Codes | Use |
|---|---|
| `200` | Successful GET/PUT/PATCH |
| `201` | Successful POST (with Location header) |
| `204` | Successful DELETE (no body) |
| `400` | Client validation error |
| `401` | Not authenticated |
| `403` | Authenticated but no permissions |
| `404` | Resource not found |
| `409` | Conflict (duplicate, invalid state) |
| `422` | Unprocessable entity (validation errors) |
| `429` | Rate limit exceeded |
| `500` | Internal error (never expose details) |

### Response Envelope

Every response follows this structure:

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
    "message": "The email field is required",
    "details": [{"field": "email", "reason": "required"}]
  },
  "meta": null
}
```

### Pagination

- Always paginate collections. No exceptions.
- Parameters: `?page=1&per_page=20`. Max `per_page=100`.
- Response includes `meta` with `page`, `per_page`, `total`, `total_pages`.
- Cursor-based for large datasets or real-time.

### Versioning

- In the header: `Accept: application/vnd.api.v2+json`.
- Fallback to URL: `/v2/users` if header isn't viable.
- Deprecation: warning in `Sunset` header + migration path documentation.

### Filtering, Sorting, Search

```
GET /users?status=active&role=admin     → exact filters
GET /users?q=juan                        → text search
GET /users?sort=-created_at,name         → sorting (- for desc)
GET /users?include=orders,profile        → related resources
```

### Rate Limiting

Mandatory headers on every response:
```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 987
X-RateLimit-Reset: 1623456789
```
