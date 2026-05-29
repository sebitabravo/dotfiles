# Skill Registry

Central catalog of installed skills for OpenCode.

**Last updated**: 2026-05-27
**Total skills**: 34

---

## Scanned sources

- `~/.config/opencode/skills` (opencode-skill)

---

## Available skills

### Engineering Skills

| Skill | Trigger | Path |
|---|---|---|
| tanstack-query | TanStack Query v5, data fetching, mutations, caching | `skills/tanstack-query/SKILL.md` |
| api-design | REST API design, endpoints, OpenAPI, versioning | `skills/api-design/SKILL.md` |
| security-review | OWASP Top 10, auth patterns, dependency auditing | `skills/security-review/SKILL.md` |
| code-review | Systematic code review: correctness, security, performance | `skills/code-review/SKILL.md` |
| deployment-patterns | CI/CD, Docker, GitOps, deployment strategies | `skills/deployment-patterns/SKILL.md` |
| database-migrations | Schema evolution, rollback strategies, Prisma/Drizzle | `skills/database-migrations/SKILL.md` |
| e2e-testing | Playwright, page objects, visual regression, CI | `skills/e2e-testing/SKILL.md` |
| docker-expert | Multi-stage builds, compose, security hardening | `skills/docker-expert/SKILL.md` |
| github-actions-docs | CI/CD pipelines, matrix builds, reusable workflows | `skills/github-actions-docs/SKILL.md` |
| fuzzing-primer | AFL++, ffuf, parameter discovery, vulnerability hunting | `skills/fuzzing-primer/SKILL.md` |

### Backend Language Skills

| Skill | Trigger | Path |
|---|---|---|
| python-design-patterns | SOLID, composition, DI, idiomatic Python | `skills/python-design-patterns/SKILL.md` |
| python-testing-patterns | pytest, fixtures, mocking, TDD, parametrize | `skills/python-testing-patterns/SKILL.md` |
| laravel-specialist | Eloquent, Sanctum, Horizon, Livewire, Pest | `skills/laravel-specialist/SKILL.md` |
| django-patterns | DRF, ORM optimization, caching, signals | `skills/django-patterns/SKILL.md` |
| golang-pro | Goroutines, channels, gRPC, microservices | `skills/golang-pro/SKILL.md` |
| dotnet-backend-patterns | ASP.NET Core, EF Core, Dapper, xUnit | `skills/dotnet-backend-patterns/SKILL.md` |

### Mobile Skills

| Skill | Trigger | Path |
|---|---|---|
| android-jetpack-compose | Compose state, navigation, Material 3 | `skills/android-jetpack-compose/SKILL.md` |
| android-clean-architecture | MVVM, Hilt, repository pattern, use cases | `skills/android-clean-architecture/SKILL.md` |
| swift | SwiftUI, SwiftData, async/await, Actors | `skills/swift/SKILL.md` |
| kotlin-coroutines-flows | Coroutines, Flow, StateFlow, SharedFlow | `skills/kotlin-coroutines-flows/SKILL.md` |
| mobile-app-testing | Espresso, XCTest, snapshot tests, CI | `skills/mobile-app-testing/SKILL.md` |
| unity-developer | Unity 6, URP/HDRP, C# patterns, Addressables | `skills/unity-developer/SKILL.md` |

### Media & Tools

| Skill | Trigger | Path |
|---|---|---|
| ffmpeg | Video/audio conversion, compression, filters | `skills/ffmpeg/SKILL.md` |

### Academic

| Skill | Trigger | Path |
|---|---|---|
| inacap | INACAP DOCX generation, academic documents, portada | `skills/inacap/SKILL.md` |

### Auto-Skills (Caveman Suite)

| Skill | Trigger | Path |
|---|---|---|
| caveman-commit | Auto-generate conventional commits from staged changes | `skills/caveman-commit/SKILL.md` |
| caveman-review | Code review: quality, security, architecture | `skills/caveman-review/SKILL.md` |
| compress | Compress markdown/memory content | `skills/compress/SKILL.md` |
| cavecrew | Delegate search/edit to subagents | `skills/cavecrew/SKILL.md` |

### Core Skills (Original)

| Skill | Trigger | Path |
|---|---|---|
| branch-pr | Branch creation, PR workflow, conventional commits | `skills/branch-pr/SKILL.md` |
| find-skills | Contextual skill loading | `skills/find-skills/SKILL.md` |
| skill-creator | Create new skills, agent instructions | `skills/skill-creator/SKILL.md` |
| skill-registry | Registry maintenance | `skills/skill-registry/SKILL.md` |
| systematic-debugging | Systematic debugging methodology | `skills/systematic-debugging/SKILL.md` |
| verification-before-completion | Evidence gate before declaring done | `skills/verification-before-completion/SKILL.md` |

---

## Notes

- Skills are loaded on demand via the `skill` tool.
- Auto-skills (caveman suite) are invoked proactively without slash commands.
- All skills in `~/.config/opencode/skills/` (global) or `.opencode/skills/` (project).
