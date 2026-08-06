---
name: deployment-patterns
description:
  CI/CD patterns, Docker best practices, GitOps workflows, deployment strategies
  (blue-green, canary, rolling), and infrastructure-as-code conventions.
---

## Docker Patterns

### Multi-stage Build

```dockerfile
# Build stage
FROM node:22-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json pnpm-lock.yaml ./
RUN corepack enable pnpm && pnpm install --frozen-lockfile
RUN npm ci
COPY . .
RUN pnpm build

# Production stage
FROM node:22-alpine AS runner
RUN addgroup -g 1001 appgroup && adduser -u 1001 -G appgroup -s /bin/sh -D appuser
WORKDIR /app
COPY --from=builder --chown=appuser:appgroup /app/dist ./dist
COPY --from=builder --chown=appuser:appgroup /app/package.json ./
USER appuser
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Docker Compose (dev)

```yaml
services:
  app:
    build:
      context: .
      target: builder
    ports: ['3000:3000']
    volumes: ['.:/app', '/app/node_modules']
    environment:
      DATABASE_URL: postgres://user:pass@db:5432/app
    depends_on:
      db: { condition: service_healthy }

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: app
    volumes: ['pgdata:/var/lib/postgresql/data']
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U user']
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

## GitHub Actions CI/CD

### CI Pipeline

```yaml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v4
        with: { version: 10 }
      - uses: actions/setup-node@v4
        with: { node-version: 22, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm typecheck
      - run: pnpm test
      - run: pnpm build

  docker:
    needs: validate
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - uses: docker/build-push-action@v6
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.sha }}
            ghcr.io/${{ github.repository }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Preview Deployments

```yaml
preview:
  needs: validate
  if: github.event_name == 'pull_request'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - run: echo "Deploy preview for PR #${{ github.event.number }}"
    - run: ./scripts/deploy-preview.sh
    - uses: actions/github-script@v7
      with:
        script: |
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: 'Preview: https://pr-${{ github.event.number }}.preview.example.com'
          })
```

## Deployment Strategies

### Blue-Green

- Two identical environments (blue = current, green = new)
- Deploy to idle environment → health check → switch DNS/LB
- Instant rollback: switch back to previous environment
- Requires 2x infrastructure

### Canary

- Deploy to N% of traffic → monitor errors/latency → increase or rollback
- Use feature flags or service mesh for traffic splitting
- Typical progression: 5% → 25% → 50% → 100%
- Automated rollback on error rate threshold

### Rolling Update

- Replace instances one by one
- Default for Kubernetes Deployments
- `maxSurge` and `maxUnavailable` control pace
- Zero-downtime with health checks

## GitOps (ArgoCD/Flux)

```yaml
# argocd-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/manifests
    targetRevision: main
    path: overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Rules

- Multi-stage Docker builds. Non-root user. Minimal base image.
- `--frozen-lockfile` in CI. No `npm install`.
- `npm ci` in CI. No mutable install.
- Health checks on all services.
- Automated rollback on error thresholds.
- Preview deployments for every PR.
- GitOps for production: declarative, versioned, auditable.
- Secrets via vault/sealed-secrets, never in manifests.
