# Skill Registry — Claude Code

Catalogo central de skills para Claude Code. Las skills se auto-descubren desde
`~/.claude/skills/` (cada una con su `SKILL.md`). Esta tabla es la referencia rapida:
escanea triggers ANTES de codear y aplica la skill que calce.

- **Total skills:** 51
- **Fuente:** `~/.claude/skills/`
- **Invocacion:** Claude carga la skill por su `name` del frontmatter cuando el contexto calza.
- **Ultima sync:** 2026-07-30

---

## Engineering & DevOps

| Skill | Trigger |
|---|---|
| `api-design` | Disenar APIs RESTful: status codes, paginacion, versionado, HATEOAS. |
| `code-review` | Revisar correctness/seguridad/perf/mantenibilidad antes de merge. |
| `security-review` | OWASP Top 10, secrets, injection, auth bypass sobre diffs/PRs. |
| `database-migrations` | Migraciones zero-downtime, rollback-ready. |
| `deployment-patterns` | CI/CD, Docker, health checks, estrategias de rollback. |
| `docker-expert` | Multi-stage builds, compose, hardening de imagenes. |
| `github-actions-docs` | Workflows CI/CD, reusable workflows, matrix builds. |
| `e2e-testing` | Playwright, Page Object Model, integracion en CI. |
| `fuzzing-primer` | AFL++, libFuzzer, ffuf, parameter discovery. |

## Backend Languages

| Skill | Trigger |
|---|---|
| `python-design-patterns` | SOLID, composicion, dependency injection en Python. |
| `python-testing-patterns` | pytest, fixtures, mocking, TDD. |
| `laravel-specialist` | Laravel 11+, Eloquent, Sanctum, Horizon, Livewire, Pest. |
| `django-patterns` | DRF, ORM, viewsets, signals. |
| `golang-pro` | goroutines, channels, gRPC, microservicios. |
| `dotnet-backend-patterns` | ASP.NET Core, EF Core, Dapper, xUnit. |

## Mobile

| Skill | Trigger |
|---|---|
| `android-jetpack-compose` | Compose: state, navegacion, Material3. |
| `android-clean-architecture` | Clean Arch MVVM, Hilt, repository pattern. |
| `swift` | SwiftUI, SwiftData, async/await, Actors. |
| `kotlin-coroutines-flows` | Structured concurrency, Flow, StateFlow. |
| `mobile-app-testing` | Espresso/XCTest, snapshot testing, CI. |
| `unity-developer` | Unity 6 LTS, URP/HDRP, addressables. |

## Frontend & Animation

| Skill | Trigger |
|---|---|
| `tanstack-query` | TanStack Query v5: keys, caching, mutations, SSR. |
| `gsap-core` | gsap.to/from/fromTo, easing, matchMedia. |
| `gsap-react` | useGSAP, gsap.context, cleanup. |
| `gsap-frameworks` | Integracion Vue/Svelte con lifecycle. |
| `gsap-timeline` | Sequencing, position parameter. |
| `gsap-scrolltrigger` | Scroll-linked, pinning, scrub. |
| `gsap-plugins` | ScrollTo, ScrollSmoother, Flip, Draggable, SplitText. |
| `gsap-performance` | Transforms, 60fps, will-change. |
| `gsap-utils` | clamp, mapRange, random, snap. |

## Design (Stitch)

| Skill | Trigger |
|---|---|
| `taste-design` | Semantic Design System para Google Stitch, anti-UI generica. |
| `design-md` | Analizar proyectos Stitch -> DESIGN.md. |
| `enhance-prompt` | Ideas UI vagas -> prompts optimizados para Stitch. |
| `stitch::generate-design` | Generar pantallas desde texto/imagenes via Stitch MCP. |
| `stitch::manage-design-system` | Gestionar design systems via Stitch MCP. |
| `stitch-extract-design-md` | Extraer DESIGN.md desde codigo frontend. |
| `stitch-react-components` | Disenos Stitch -> componentes Vite/React, validacion AST. |

## Media & Documents

| Skill | Trigger |
|---|---|
| `ffmpeg` | Convertir/comprimir video y audio, filtros. |
| `imagemagick` | Convert/resize/compress, favicon, WebP/AVIF. |
| `pandoc` | Conversor universal MD/DOCX/PDF/HTML/EPUB/LaTeX/PPTX. |
| `pptx` | Cualquier .pptx: decks, slides, presentaciones. |
| `xlsx` | Cualquier planilla .xlsx/.xlsm/.csv/.tsv como input/output. |
| `inacap` | DOCX academico formato INACAP (python-docx). |

## Core & Workflow

| Skill | Trigger |
|---|---|
| `branch-pr` | Crear branch, workflow de PR, conventional commits. |
| `systematic-debugging` | Root-cause-first para bugs y test failures. |
| `verification-before-completion` | Gate de evidencia antes de "done"/commit/PR. |
| `handoff` | Estado HANDOFF.md para traspaso de sesion. |
| `find-skills` | Descubrir/instalar skills nuevas. |
| `skill-creator` | Crear skills nuevas segun la Agent Skills spec. |

## Quality & Testing

| Skill | Trigger |
|---|---|
| `bdd-gherkin` | BDD with Gherkin: .feature, step definitions, Given-When-Then. |
| `mutation-testing` | Stryker, mutmut, PIT: measure test quality, kill mutants. |
| `thermo-nuclear-code-quality-review` | Extremely strict maintainability review: abstractions, spaghetti, giant files. |
