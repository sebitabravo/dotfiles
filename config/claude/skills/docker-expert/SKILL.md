---
name: docker-expert
description: >
  Docker patterns including multi-stage builds, compose orchestration, image
  optimization, networking, volumes, security hardening, and production best
  practices. Use when writing or reviewing a Dockerfile or compose file,
  shrinking an image, or hardening a container for production.
---

## Multi-Stage Builds

### Node.js

```dockerfile
FROM node:22-alpine AS base
RUN corepack enable pnpm
WORKDIR /app
COPY package.json package-lock.json pnpm-lock.yaml ./

FROM base AS deps
RUN pnpm install --frozen-lockfile --prod

FROM base AS builder
COPY . .
RUN pnpm install --frozen-lockfile
RUN pnpm build

FROM node:22-alpine AS runner
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/package.json ./
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1
CMD ["node", "dist/server.js"]
```

### Python

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim
RUN useradd -m appuser
WORKDIR /app
COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appuser . .
USER appuser
ENV PATH=/home/appuser/.local/bin:$PATH
CMD ["python", "-m", "app.main"]
```

## Image Optimization

```dockerfile
# Layer caching: copy dependency files first
COPY package.json package-lock.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .

# .dockerignore
node_modules
.git
.env*
*.md
dist
coverage
```

### Size Comparison

| Base                         | Size   |
| ---------------------------- | ------ |
| `node:22`                    | ~1.1GB |
| `node:22-slim`               | ~250MB |
| `node:22-alpine`             | ~180MB |
| `gcr.io/distroless/nodejs22` | ~130MB |

## Docker Compose

### Development

```yaml
services:
  app:
    build:
      context: .
      target: builder
    ports: ['3000:3000']
    volumes:
      - .:/app
      - app_node_modules:/app/node_modules
    environment:
      NODE_ENV: development
      DATABASE_URL: postgres://user:pass@db:5432/app_dev
    depends_on:
      db: { condition: service_healthy }
      redis: { condition: service_healthy }

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: app_dev
    ports: ['5432:5432']
    volumes: [pgdata:/var/lib/postgresql/data]
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U user']
      interval: 5s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports: ['6379:6379']
    healthcheck:
      test: ['CMD', 'redis-cli', 'ping']
      interval: 5s

volumes:
  pgdata:
  app_node_modules:
```

### Production Override

```yaml
# docker-compose.prod.yml
services:
  app:
    build:
      context: .
      target: runner
    environment:
      NODE_ENV: production
    deploy:
      replicas: 3
      resources:
        limits: { cpus: '0.5', memory: 512M }
      restart_policy:
        condition: on-failure
        max_attempts: 3
    volumes: [] # No bind mounts in prod
```

## Networking

```yaml
services:
  api:
    networks: [frontend, backend]
  db:
    networks: [backend]
  nginx:
    networks: [frontend]

networks:
  frontend:
  backend:
    internal: true # No external access
```

## Security Hardening

```dockerfile
# Non-root user
RUN addgroup -g 1001 app && adduser -u 1001 -G app -D appuser
USER appuser

# Read-only filesystem
# docker run --read-only --tmpfs /tmp --tmpfs /home/appuser/.cache

# No new privileges
# docker run --security-opt=no-new-privileges

# Drop all capabilities, add only needed
# docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE
```

## Health Checks

```dockerfile
# HTTP
HEALTHCHECK --interval=30s --timeout=3s --retries=3 --start-period=10s \
  CMD wget -qO- http://localhost:3000/health || exit 1

# TCP
HEALTHCHECK CMD nc -z localhost 5432 || exit 1
```

## Useful Commands

```bash
# Build
docker build -t app:latest .
docker build --target builder -t app:dev .

# Run
docker compose up -d
docker compose logs -f app
docker compose exec app sh

# Cleanup
docker system prune -af --volumes
docker builder prune -af

# Debug
docker compose run --rm app sh
docker compose logs --since 1h app
```

## Rules

- Multi-stage builds. Always.
- Non-root user in final stage.
- `.dockerignore` with everything not needed.
- Alpine or distroless for minimal attack surface.
- Health checks on all services.
- `--frozen-lockfile` during build. No `npm install` in production image.
- `npm ci` during build. No mutable install in production image.
- Explicit `depends_on` with health checks.
- Named volumes for persistent data.
- No bind mounts in production.
