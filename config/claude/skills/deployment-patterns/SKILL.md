---
name: deployment-patterns
description: CI/CD pipelines, Docker optimization, health checks, rollback strategies, and deployment automation. Use when configuring deployments, writing Dockerfiles, or setting up CI/CD.
---

# Deployment Patterns

Patrones de deploy, CI/CD, y contenedores con foco en zero-downtime y confiabilidad.

## When to Use

- Configurar CI/CD pipeline.
- Escribir o revisar Dockerfile/docker-compose.yml.
- Planificar estrategia de deploy (rolling, blue-green, canary).
- Debuggear problemas de deploy en producción.

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

Reglas:
- Multi-stage builds. Imagen final sin herramientas de build.
- Usuario no-root (`USER app`).
- `.dockerignore`: `node_modules`, `.git`, `.env*`, `dist` (en builder stage).
- Tags: `:latest` para dev, commit SHA para staging, semver para prod.
- Sin secrets en layers. `ARG` solo para build-time, no persiste.

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

Tres niveles:

1. **Liveness** (`/health`): ¿el proceso está vivo? Retorna 200 si el servidor responde.
2. **Readiness** (`/ready`): ¿listo para recibir tráfico? Verifica DB, Redis, y dependencias.
3. **Deep** (`/health/deep`): verifica queries, salud de workers, espacio en disco. No usarlo para orquestador, solo monitoreo.

## Deploy Strategies

| Estrategia | Downtime | Rollback | Complejidad | Cuándo |
|---|---|---|---|---|
| **Rolling** | 0 | Minutos | Media | Default para la mayoría |
| **Blue-Green** | 0 | Instantáneo | Alta | Aplicaciones críticas |
| **Canary** | 0 | Instantáneo | Alta | Cambios de alto riesgo |

### Rolling (Kubernetes)

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

- `maxUnavailable: 0` garantiza sin pérdida de capacidad.
- Health check debe pasar antes de marcar el pod como Ready.
- `minReadySeconds: 10` para evitar falso-positivo.

## CI/CD Pipeline

```
Push → Lint → Test → Build → Scan → Deploy Staging → Smoke → Deploy Prod
```

Gates obligatorios:
- Tests unitarios + integración pasan.
- Security scan sin críticos.
- Build exitoso.
- Smoke test en staging (GET /health + endpoint crítico).
- Aprobación manual para prod (si no hay continuous deployment maduro).

## Rollback

Siempre tener plan B antes de deployar:
- **DB migrations**: deben ser reversibles. Migración forward + rollback script validado.
- **Feature flags**: toggle para desactivar features problemáticos sin redeploy.
- **Rollback command**: una línea: `kubectl rollout undo deployment/app` o `helm rollback`.
