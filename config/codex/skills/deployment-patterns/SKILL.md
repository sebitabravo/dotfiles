---
name: deployment-patterns
description: CI/CD pipelines, Docker optimization, health checks, rollback strategies, and deployment automation. Use when configuring deployments, writing Dockerfiles, or setting up CI/CD.
---

# Deployment Patterns

Deploy, CI/CD, and container patterns focused on zero-downtime and reliability.

## When to Use

- Configuring CI/CD pipeline.
- Writing or reviewing Dockerfile/docker-compose.yml.
- Planning deploy strategy (rolling, blue-green, canary).
- Debugging production deploy issues.

## Docker

### Dockerfile

```dockerfile
# Multi-stage build: build ≠ runtime
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --production=false
COPY . .
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
RUN addgroup -g 1001 app && adduser -u 1001 -G app -s /bin/sh -D app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/main.js"]
```

Rules:
- Multi-stage builds. Final image without build tools.
- Non-root user (`USER app`).
- `.dockerignore`: `node_modules`, `.git`, `.env*`, `dist` (in builder stage).
- Tags: `:latest` for dev, commit SHA for staging, semver for prod.
- No secrets in layers. `ARG` only for build-time, doesn't persist.

### Docker Compose

```yaml
services:
  app:
    build: .
    ports: ["3000:3000"]
    environment:
      - DATABASE_URL=postgres://${DB_USER}:${DB_PASS}@db:5432/${DB_NAME}
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 10s
      timeout: 5s
      retries: 3
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    volumes:
      - pgdata:/var/lib/postgresql/data
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
      POSTGRES_DB: ${DB_NAME}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

## Health Checks

Three levels:

1. **Liveness** (`/health`): is the process alive? Returns 200 if server responds.
2. **Readiness** (`/ready`): ready for traffic? Checks DB, Redis, and dependencies.
3. **Deep** (`/health/deep`): checks queries, worker health, disk space. Not for orchestrator, monitoring only.

## Deploy Strategies

| Strategy | Downtime | Rollback | Complexity | When |
|---|---|---|---|---|
| **Rolling** | 0 | Minutes | Medium | Default for most |
| **Blue-Green** | 0 | Instant | High | Critical applications |
| **Canary** | 0 | Instant | High | High-risk changes |

### Rolling (Kubernetes)

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

- `maxUnavailable: 0` guarantees no capacity loss.
- Health check must pass before marking pod as Ready.
- `minReadySeconds: 10` to avoid false positives.

## CI/CD Pipeline

```
Push → Lint → Test → Build → Scan → Deploy Staging → Smoke → Deploy Prod
```

Mandatory gates:
- Unit + integration tests pass.
- Security scan with no criticals.
- Successful build.
- Smoke test on staging (GET /health + critical endpoint).
- Manual approval for prod (if no mature continuous deployment).

## Rollback

Always have plan B before deploying:
- **DB migrations**: must be reversible. Forward migration + validated rollback script.
- **Feature flags**: toggle to disable problematic features without redeploy.
- **Rollback command**: one-liner: `kubectl rollout undo deployment/app` or `helm rollback`.
