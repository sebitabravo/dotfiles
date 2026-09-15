# Skill Registry — Claude Code

Índice HUMANO de las skills incluidas en esta config. Claude Code las descubre
solo (lee el frontmatter de cada `~/.claude/skills/*/SKILL.md` y las lista en
contexto), así que este archivo NO se carga en ninguna sesión: sirve para hojear
el catálogo desde el repo.

- **Total skills:** 21
- **Fuente:** `skills/` en este repo → `~/.claude/skills/`
- **Invocación:** por el `name` del frontmatter, que siempre coincide con el nombre del directorio.

> Si agregas o sacas una skill, actualiza esta tabla o borra el archivo. Un índice
> desactualizado miente peor que no tener índice.

---

## Web y frameworks

| Skill | Para qué |
|---|---|
| `typescript` | Patrones de TypeScript estricto: tipos, interfaces, genéricos. |
| `react-19` | React 19 con React Compiler; sin `useMemo` / `useCallback` manuales. |
| `nextjs` | Next.js 16 App Router: Server Components, Server Actions, caching. |
| `tailwind-4` | Tailwind CSS 4: `cn()`, theme variables, sin `var()` en className. |
| `tanstack-query` | TanStack Query v5: query keys, caché, mutations, SSR, optimistic updates. |
| `laravel-specialist` | Laravel 11+: Eloquent, Sanctum, API resources, colas con Horizon, Livewire, Pest. |
| `laravel-inertia-react` | Laravel + Inertia + React: `useForm`, shared data, layouts persistentes. |

## Calidad y seguridad

| Skill | Para qué |
|---|---|
| `mutation-testing` | Medir calidad de tests con mutantes (Stryker, PIT, Infection). |
| `npm-security` | Endurecimiento de la cadena de suministro npm: 17 prácticas. |

## Chile y documentos

| Skill | Para qué |
|---|---|
| `chile` | Marco tributario (SII), laboral (DT) y societario chileno. |
| `compliance-cl` | Genera RAT, DPA, EIPD, política de privacidad, MPD. Ley 21.719 y 21.595. |
| `inacap` | Documentos académicos formato INACAP en DOCX. |

## Archivos y conversión

| Skill | Para qué |
|---|---|
| `pptx` | Crear, leer y editar presentaciones `.pptx` / `.potx`. |
| `xlsx` | Crear, leer y arreglar planillas `.xlsx` / `.csv`. |
| `pandoc` | Conversión entre Markdown, DOCX, PDF, HTML, EPUB, LaTeX. |
| `imagemagick` | Conversión, resize, compresión, favicons y thumbnails. |
| `ffmpeg` | Conversión, compresión, corte y subtitulado de audio y video. |
| `remove-ai-marks` | Quitar C2PA, metadata de IA y Unicode invisible de archivos propios. |

## Meta

| Skill | Para qué |
|---|---|
| `handoff` | Escribe `HANDOFF.md` para cortar limpio entre sesiones o antes de `/clear`. |
| `skill-creator` | Crear una skill nueva siguiendo la spec de Agent Skills. |
| `prompt-engineering` | Diseñar y optimizar prompts, elegir tier de modelo, armar evals. |
