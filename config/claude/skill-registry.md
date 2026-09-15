# Skill Registry — Claude Code

Indice HUMANO de las skills incluidas en esta config. Claude Code descubre las
skills solo (lee el frontmatter de cada `~/.claude/skills/*/SKILL.md` y las lista
en contexto), asi que este archivo NO se carga en ninguna sesion y no hace falta
para que funcionen: sirve para hojear el catalogo desde el repo.

- **Total skills:** 54
- **Fuente:** `skills/` en este repo -> `~/.claude/skills/`
- **Invocacion:** por el `name` del frontmatter, que siempre coincide con el nombre del directorio.

> Si agregas o sacas una skill, actualiza esta tabla o borra el archivo. Un indice
> desactualizado miente peor que no tener indice.

---

## Engineering & DevOps

| Skill | Trigger |
|---|---|
| `fuzzing-primer` | Fuzzing fundamentals, harness design, crash triage, and safe mutation strategy. |
| `npm-security` | NPM supply chain hardening — 17 practices covering postinstall blocking, git dependency bans, version cooldown. |
| `acceptance-pipeline` | Gherkin-to-runner acceptance pipeline, generated entry points, and acceptance mutation. |
| `go-testing` | Focused Go unit, integration, Bubbletea, teatest, and golden-file testing patterns. |

## Backend Languages & Frameworks

| Skill | Trigger |
|---|---|
| `laravel-specialist` | Laravel 11+ patterns including Eloquent ORM, Sanctum auth, API resources, queues with Horizon, event broadcasting. |
| `laravel-inertia-react` | Laravel + Inertia.js + React integration patterns. |

## Frontend & Animation

| Skill | Trigger |
|---|---|
| `react-19` | > React 19 patterns with React Compiler. |
| `nextjs` | > Next.js 16 App Router patterns — file conventions, Server Components, Server Actions, async. |
| `typescript` | > TypeScript strict patterns and best practices. |
| `tailwind-4` | > Tailwind CSS 4 patterns and best practices. |
| `tanstack-query` | Patrones criticos de TanStack Query v5 — query keys, caching, mutations, SSR, optimistic updates. |
| `gsap-core` | Official GSAP skill for the core API — gsap.to(), from(), fromTo(), easing, duration, stagger, defaults. |
| `gsap-react` | Official GSAP skill for React — useGSAP hook, refs, gsap.context(), cleanup. |
| `gsap-frameworks` | Official GSAP skill for Vue, Svelte, and other non-React frameworks — lifecycle, scoping selectors, cleanup on. |
| `gsap-timeline` | Official GSAP skill for timelines — gsap.timeline(), position parameter, nesting, playback. |
| `gsap-scrolltrigger` | Official GSAP skill for ScrollTrigger — scroll-linked animations, pinning, scrub, triggers. |
| `gsap-plugins` | Official GSAP skill for GSAP plugins — registration, ScrollToPlugin, ScrollSmoother, Flip, Draggable, Inertia. |
| `gsap-performance` | Official GSAP skill for performance — prefer transforms, avoid layout thrashing, will-change, batching. |
| `gsap-utils` | Official GSAP skill for gsap.utils — clamp, mapRange, normalize, interpolate, random, snap, toArray, wrap, pipe. |

## Design (Stitch)

| Skill | Trigger |
|---|---|
| `taste-design` | Semantic Design System Skill for Google Stitch. |
| `design-md` | Analyze Stitch projects and synthesize a semantic design system into DESIGN.md files. |
| `enhance-prompt` | Transforms vague UI ideas into polished, Stitch-optimized prompts. |
| `stitch-generate-design` | >- Generate new screens from text prompts or images, edit existing screens with prompts and design system tokens. |
| `stitch-manage-design-system` | >- Manage design systems in Stitch using MCP tools. |
| `stitch-extract-design-md` | >- Extract a comprehensive design system (DESIGN.md) directly from frontend source code — React, Vue, Svelte. |
| `stitch-react-components` | Converts or syncs Stitch designs into modular Vite and React components using system-level networking and AST-based validation. |

## Media & Documents

| Skill | Trigger |
|---|---|
| `ffmpeg` | FFmpeg commands for video/audio conversion, compression, trimming, merging, filters, subtitle handling, and batch. |
| `diagram-design` | Create branded architecture, flowchart, sequence, ER, Gantt, UML, and 40+ more diagram types as standalone HTML/SVG/PNG; redraw .drawio or Mermaid sources. |
| `imagemagick` | ImageMagick (magick) for image conversion, resizing, compression, cropping, rotating, watermarking, format. |
| `pandoc` | Pandoc universal document converter between Markdown, DOCX, PDF, HTML, EPUB, LaTeX, and PPTX, with templates. |
| `pptx` | Use this skill any time a .pptx or .potx file is involved in any way — as input, output, or both. |
| `xlsx` | Use this skill any time a spreadsheet file is the primary input or output, including .xlsx, .xlsm, .xltx, .csv, or .tsv. |
| `inacap` | > Genera documentos academicos formato INACAP en DOCX (python-docx). |
| `remove-ai-marks` | > Strip AI provenance marks (Unicode, C2PA/metadata) from owned files and text. |

## Core & Workflow

| Skill | Trigger |
|---|---|
| `automatic-task-orchestrator` | Automatic one-shot planning, ordered execution, verification, acceptance, and root-cause iteration. |
| `swarmforge-workflow` | Claude-native two-pack, four-pack, and six-pack role handoffs for TDD, acceptance, CRAP/DRY, mutation, and QA. |
| `sdd-workflow` | Spec-Driven Development para features complejas con OpenSpec: artifacts, apply, verify y archive, más contratos de tareas y receipts. |
| `handoff` | Crea un archivo HANDOFF.md con el estado actual del proyecto para un traspaso limpio entre sesiones. |
| `cavecrew` | Protocolo de delegación a subagentes: escriben resultados a `/tmp/cavecrew/<tarea>-result.md` y devuelven solo el path. |
| `find-skills` | Helps users discover and install agent skills when they ask questions like "how do I do X", "find a skill for X". |
| `skill-creator` | > Creates new AI agent skills following the Agent Skills spec. |
| `prompt-engineering` | > Designing and optimizing prompts for LLMs — chain-of-thought, few-shot, XML structuring, model-tier calibration. |
| `chained-pr` | Split oversized changes into chained or stacked PR review slices. |
| `work-unit-commits` | Plan commits as reviewable work units and keep tests/docs with the behavior they verify. |
| `comment-writer` | Write concise, warm, direct GitHub, issue, review, and collaboration comments. |
| `issue-creation` | Create and triage GitHub issues from repository evidence and discovered policy. |
| `systemic-issue-triage` | Group repeated issues by root-cause cluster instead of patching symptoms one by one. |
| `skill-improver` | Audit and improve existing LLM-first `SKILL.md` files without deleting intent. |
| `skill-registry` | Index skills by trigger, scope, and exact path after skill changes. |
| `judgment-day` | Run explicit blind dual adversarial review with bounded correction rounds. |
| `rdd-defect-workflow` | Guide receipt-driven defects, lineage, recovery, and delivery-gate decisions. |

## Legal & Compliance (Chile)

| Skill | Trigger |
|---|---|
| `compliance-cl` | Auditoria y cumplimiento Ley 21.719 (datos personales) y Ley 21.595 (delitos economicos): RAT, DPA, EIPD, politica de privacidad, plan de brechas y modelo de prevencion de delitos. |

> `compliance-cl` es la unica skill vendorizada desde un upstream externo:
> https://github.com/Lelemon-studio/compliance-cl (MIT), commit
> `4972a821ff98caf777e809baf468d72517616ada`. Se copio sin `assets/`. Para
> actualizarla hay que volver al upstream, no editarla en su lugar.

## Quality & Testing

| Skill | Trigger |
|---|---|
| `mutation-testing` | Mutation testing to measure test quality. |
| `thermo-nuclear-code-quality-review` | Run an extremely strict maintainability review for abstraction quality, giant files, and spaghetti-condition growth. |
