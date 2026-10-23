# Skill Registry — Claude Code

Índice HUMANO de las skills incluidas en esta config. Claude Code las descubre
solo (lee el frontmatter de cada `~/.claude/skills/*/SKILL.md` y las lista en
contexto), así que este archivo NO se carga en ninguna sesión: sirve para hojear
el catálogo desde el repo.

- **Total skills de este repo:** 30
- **Fuente:** `skills/` en este repo → `~/.claude/skills/`
- **Criterio:** solo skills agnósticas de stack. Las de frameworks y librerías se instalan por proyecto.
- **Invocación:** por el `name` del frontmatter, que siempre coincide con el nombre del directorio.

`~/.claude/skills/` puede contener más de las que salen acá (p. ej. `synced/`):
`install.sh` sincroniza `skills/` entrada por entrada justamente para no borrar
lo que este repo no versiona.

> Si agregas o sacas una skill, actualiza esta tabla o borra el archivo. Un índice
> desactualizado miente peor que no tener índice.

---

## Calidad y seguridad

| Skill | Para qué |
|---|---|
| `mutation-testing` | Medir calidad de tests con mutantes (Stryker, PIT, Infection). |
| `npm-security` | Endurecimiento de la cadena de suministro npm: 16 prácticas. |

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

## Roles (antes subagentes)

Se cargan solas por el trigger "Use PROACTIVELY when…" de su `description`.

| Skill | Para qué |
|---|---|
| `backend-architect` | APIs, modelos de datos, servicios y decisiones de arquitectura backend. |
| `ui-ux-designer` | Jerarquía, espaciado, estados, responsive, a11y y motion. |
| `code-reviewer` | Review adversarial de diffs y PRs con lentes de riesgo, legibilidad, fiabilidad y resiliencia. |
| `security-auditor` | Auditoría de seguridad y caza de vulnerabilidades (OWASP, flujo de datos). |
| `debugger` | Diagnóstico de fallas con hipótesis ordenadas por evidencia. |
| `qa-engineer` | Estrategia de pruebas, casos borde y QA final. |
| `performance-engineer` | Perfilado, cuellos de botella y optimización medida. |
| `deployment-engineer` | CI/CD, contenedores, releases y rollback. |
| `data-analyst` | SQL, análisis exploratorio y métricas. |
| `technical-writer` | Documentación técnica, READMEs, guías y ADRs. |
| `product-manager` | Requisitos, priorización, PRDs y criterios de aceptación. |
| `business-strategy` | Estrategia, marketing, ventas, customer success y operaciones (una sección por rol). |

## Flujo de trabajo y colaboración

| Skill | Para qué |
|---|---|
| `judgment-day` | Review adversarial doble con dos jueces ciegos y hasta dos rondas de fix. |
| `thermo-nuclear-code-quality-review` | Review estricto de estructura y simplificación. |
| `work-unit-commits` | Planear commits como unidades de trabajo revisables. |
| `chained-pr` | Dividir PRs de más de 400 líneas en PRs encadenados. |

## Diseño

| Skill | Para qué |
|---|---|

## Meta

| Skill | Para qué |
|---|---|
| `handoff` | Escribe `HANDOFF.md` para cortar limpio entre sesiones o antes de `/clear`. |
| `prompt-engineering` | Diseñar y optimizar prompts, elegir tier de modelo, armar evals. |
