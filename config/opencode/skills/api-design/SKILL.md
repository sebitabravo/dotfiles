---
name: api-design
description: REST API design patterns, endpoint conventions, error handling, pagination, versioning, and OpenAPI specification best practices.
---

## REST Conventions

### URL Structure

```
GET    /api/v1/users              # List
POST   /api/v1/users              # Create
GET    /api/v1/users/:id          # Get single
PATCH  /api/v1/users/:id          # Update (partial)
PUT    /api/v1/users/:id          # Replace (full)
DELETE /api/v1/users/:id          # Delete

GET    /api/v1/users/:id/posts    # Nested resource list
POST   /api/v1/users/:id/posts    # Create nested resource
```

### Naming Rules

- Plural nouns for collections: `/users`, `/orders`
- Kebab-case: `/user-profiles`, not `/userProfiles`
- No verbs in URLs: use HTTP methods instead
- No nested resources beyond 2 levels — flatten with query params

```
# BAD
GET /api/v1/users/:userId/posts/:postId/comments/:commentId

# GOOD
GET /api/v1/comments?post_id=123&user_id=456
```

### Standard Response Envelope

```json
{
  "data": { ... },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2025-01-15T10:00:00Z"
  }
}
```

### List Response with Pagination

```json
{
  "data": [...],
  "meta": {
    "request_id": "uuid",
    "timestamp": "2025-01-15T10:00:00Z"
  },
  "pagination": {
    "page": 1,
    "per_page": 20,
    "total": 150,
    "total_pages": 8,
    "has_next": true,
    "has_prev": false
  }
}
```

### Cursor Pagination (for large datasets)

```
GET /api/v1/messages?cursor=eyJpZCI6MTAwfQ&limit=50

{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MjAwfQ",
    "prev_cursor": null,
    "has_more": true
  }
}
```

## Error Handling

### Error Response Format

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Human-readable message",
    "details": [
      {
        "field": "email",
        "message": "Invalid email format",
        "code": "INVALID_FORMAT"
      }
    ]
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2025-01-15T10:00:00Z"
  }
}
```

### Standard Error Codes

| Status | Code | Usage |
|--------|------|-------|
| 400 | `VALIDATION_ERROR` | Invalid input |
| 401 | `UNAUTHORIZED` | Missing/invalid token |
| 403 | `FORBIDDEN` | Insufficient permissions |
| 404 | `NOT_FOUND` | Resource not found |
| 409 | `CONFLICT` | Duplicate/unique violation |
| 422 | `UNPROCESSABLE` | Semantic validation failure |
| 429 | `RATE_LIMITED` | Too many requests |
| 500 | `INTERNAL_ERROR` | Unexpected failure |

## Versioning

- URL versioning: `/api/v1/`, `/api/v2/`
- Never remove fields between versions — deprecate with `x-deprecated` in OpenAPI
- Add fields freely (non-breaking)
- Field removal = new major version

## Filtering, Sorting, Search

```
# Filtering
GET /api/v1/products?category=electronics&price_min=100&price_max=500

# Sorting
GET /api/v1/products?sort=-created_at,price    # - = descending

# Search
GET /api/v1/products?q=wireless+keyboard&fields=name,description

# Field selection (sparse fieldsets)
GET /api/v1/products?fields=id,name,price

# Include related resources
GET /api/v1/orders?include=items,shipping_address
```

## OpenAPI 3.1 Spec Template

```yaml
openapi: "3.1.0"
info:
  title: API Name
  version: "1.0.0"
  description: API description

servers:
  - url: https://api.example.com/v1
    description: Production

security:
  - BearerAuth: []

paths:
  /users:
    get:
      operationId: listUsers
      summary: List users
      tags: [Users]
      parameters:
        - name: page
          in: query
          schema: { type: integer, default: 1 }
        - name: per_page
          in: query
          schema: { type: integer, default: 20, maximum: 100 }
      responses:
        "200":
          description: Success
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/UserListResponse"

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

## Rules

- Consistent envelope across all endpoints.
- Snake_case for JSON fields.
- `request_id` in every response for tracing.
- Paginate all list endpoints (default limit, max limit).
- Validate input at API boundary — never trust client data.
- Document every endpoint with OpenAPI.
- Rate limit by default.
- CORS whitelist, never `*` in production.
