---
name: branch-pr
description: >
  Branch creation, PR workflow, and conventional commits.
  Trigger: When creating branches, commits, or pull requests.
license: MIT
metadata:
  author: sebita-programming
  version: "1.0"
---

## Branch Naming

```
main                          ← Producción (NUNCA push directo)
└── development               ← Desarrollo principal
    ├── feature/TECH-XX-...   ← Features nuevas
    ├── fix/descripcion       ← Bug fixes
    ├── refactor/descripcion  ← Refactoring
    └── hotfix/bug-urgente    ← Fixes urgentes en producción
```

### Formato

```bash
feature/TECH-XX-descripcion-corta   # Con ticket de Linear/Jira
feature/nombre-descriptivo          # Sin ticket
fix/descripcion-del-bug
refactor/que-se-refactoriza
hotfix/bug-urgente
```

## Conventional Commits (OBLIGATORIO)

### Formato

```
tipo(alcance): descripción en minúsculas
```

### Tipos permitidos

| Tipo | Cuándo |
|------|--------|
| `feat` | Feature nueva |
| `fix` | Bug fix |
| `refactor` | Refactoring sin cambio de comportamiento |
| `test` | Agregar o modificar tests |
| `ci` | Cambios en CI/CD |
| `docs` | Documentación |
| `chore` | Tareas de mantenimiento |

### Ejemplos

```bash
feat(auth): agregar login con google
fix(tenant): corregir validación de dominio
refactor(tests): mover tests a integración
test(carbon-footprint): agregar tests de validación
docs(api): actualizar documentación de endpoints
```

### WIP Commits

```bash
WIP: [feature] - descripción del progreso
WIP: sistema modular - contratos de dominio completados
WIP: guardado fin de día
```

## Flujo de Feature

```bash
# 1. Crear desde main limpio
git checkout main
git pull origin main
git checkout -b feature/nombre-feature

# 2. Desarrollar con commits frecuentes (cada 30-60 min)
git commit -m "feat(scope): estructura inicial"
git commit -m "feat(scope): implementación core"

# 3. Push para backup
git push -u origin feature/nombre-feature

# 4. Crear PR hacia development
# CI debe pasar antes de merge
```

## Crear Pull Request

### Antes de crear el PR

```bash
# Verificar que tests pasen (buscar comando en docs del proyecto)
# Squash commits en uno solo
git rebase -i HEAD~N  # N = cantidad de commits a squashear
```

### Checklist del PR

- [ ] Todos los tests pasan
- [ ] Quality checks pasan (linters, formatters)
- [ ] Commits squasheados en uno
- [ ] PR apunta a `development` (NO a main)
- [ ] Descripción clara del cambio

### Crear el PR con gh

```bash
gh pr create \
  --base development \
  --title "feat(scope): descripción del cambio" \
  --body "## Resumen
- Qué se hizo y por qué

## Cambios
- Lista de cambios principales

## Testing
- Cómo se testeó"
```

## Flujo de Merge

```
feature branch → development → main (producción)
```

## Hotfix (Urgente)

```bash
# 1. Guardar trabajo actual
git stash push --include-untracked -m "WIP: pausado por hotfix"

# 2. Crear branch de hotfix
git checkout main && git pull origin main
git checkout -b hotfix/descripcion-bug

# 3. Fix, test, commit
git commit -m "fix(scope): descripción del bug resuelto"

# 4. Merge y volver
git checkout main && git merge hotfix/descripcion-bug
git push origin main
git branch -d hotfix/descripcion-bug
git checkout branch-anterior && git stash pop
```

## Reglas de Seguridad

```
❌ NUNCA: git push --force (en main/development)
❌ NUNCA: git clean -fd (sin dry-run primero)
❌ NUNCA: git reset --hard (sin verificar estado)
❌ NUNCA: Push directo a main
❌ NUNCA: Rebase en branches compartidas
✅ SIEMPRE: git clean -n antes de git clean -fd
✅ SIEMPRE: git status antes de operaciones destructivas
```

## Keywords

branch, pr, pull request, commit, conventional commits, git workflow, merge
