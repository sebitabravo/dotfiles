# Claude Code Config

Configuracion optimizada de Claude Code con agentes especializados, reglas, skills, comandos, hooks, y MCP servers. Diseñada para maxima productividad con minima context window bloat.

## Estructura

```
config/claude/
├── CLAUDE.md                     # Instrucciones globales (senior architect mode)
├── settings.json                 # Hooks, permisos, env vars, modelo
├── settings.local.json           # Overrides locales (git-user, env, permisos extra)
├── statusline.sh                 # Statusline custom
├── skill-registry.md             # Catalogo de skills con triggers
├── security_rules.md             # Protocolos de seguridad y zonas restringidas
├── tweakcc-theme.json            # Tema visual
├── mcp-servers.json              # MCP servers activos (con credenciales)
├── mcp-servers.template.json     # Template sin credenciales
├── README.md                     # Este archivo
├── agents/                       # 22 agentes especializados
│   ├── backend-architect.md
│   ├── ceo-strategist.md
│   ├── cfo-finance.md
│   ├── code-reviewer.md
│   ├── customer-success.md
│   ├── data-analyst.md
│   ├── debugger.md
│   ├── deployment-engineer.md
│   ├── frontend-developer.md
│   ├── hr-people-ops.md
│   ├── legal-compliance.md
│   ├── marketing-strategist.md
│   ├── observability-engineer.md
│   ├── operations-manager.md
│   ├── performance-engineer.md
│   ├── product-manager.md
│   ├── qa-engineer.md
│   ├── sales-representative.md
│   ├── security-auditor.md
│   ├── technical-writer.md
│   ├── ui-ux-designer.md
│   └── vulnerability-hunter.md
├── skills/                       # 49 skills invocables por contexto
│   ├── Engineering & DevOps (9): api-design, code-review, security-review,
│   │   database-migrations, deployment-patterns, docker-expert,
│   │   github-actions-docs, e2e-testing, fuzzing-primer
│   ├── Backend Languages (6): python-design-patterns, python-testing-patterns,
│   │   laravel-specialist, django-patterns, golang-pro, dotnet-backend-patterns
│   ├── Mobile (6): android-jetpack-compose, android-clean-architecture,
│   │   swift, kotlin-coroutines-flows, mobile-app-testing, unity-developer
│   ├── Frontend & Animation (9): tanstack-query, gsap-core, gsap-react,
│   │   gsap-frameworks, gsap-timeline, gsap-scrolltrigger, gsap-plugins,
│   │   gsap-performance, gsap-utils
│   ├── Design / Stitch (7): taste-design, design-md, enhance-prompt,
│   │   stitch-generate-design, stitch-manage-design-system,
│   │   stitch-extract-design-md, stitch-react-components
│   ├── Media & Documents (6): ffmpeg, imagemagick, pandoc, pptx, xlsx, inacap
│   └── Core & Workflow (6): branch-pr, systematic-debugging,
│       verification-before-completion, handoff, find-skills, skill-creator
├── commands/                     # Slash commands
│   ├── code-review.md
│   ├── model-route.md
│   ├── plan.md
│   └── security-scan.md
├── hooks/                        # Scripts de hooks
│   ├── validate-safe-ops.sh      # Bloqueo de comandos peligrosos
│   ├── secret-detect.sh          # Deteccion de secrets en prompts
│   ├── check-auto-save-stash.sh  # Verificacion de auto-save stashes
│   ├── handoff-session-start.py  # Inyeccion de HANDOFF.md al iniciar
│   ├── handoff-stop.sh           # Archivo de HANDOFF.md al terminar
│   └── stop-check-pending.sh     # Alerta de cambios sin commit
├── templates/                    # Plantillas SDD
│   ├── sdd-constitution.md
│   ├── sdd-proposal.md
│   ├── sdd-requirements.md
│   ├── sdd-design.md
│   ├── sdd-tasks.md
│   ├── sdd-apply-progress.md
│   └── sdd-checklist.md
├── scripts/
│   └── squash-auto-saves.sh      # Squash de commits auto-save
├── output-styles/
│   └── sebita.md                 # Estilo de output personalizado
└── rules/
    ├── common/
    │   ├── coding-style.md
    │   ├── git-workflow.md
    │   ├── testing.md
    │   ├── security.md
    │   └── patterns.md
    └── npm-security.md           # Supply chain hardening (17 practicas)
```

## Instalacion rapida

```bash
# 1. Archivos core
cp ~/Developer/dotfiles/config/claude/settings.json ~/.claude/settings.json
cp ~/Developer/dotfiles/config/claude/CLAUDE.md ~/.claude/CLAUDE.md
cp ~/Developer/dotfiles/config/claude/statusline.sh ~/.claude/statusline.sh
cp ~/Developer/dotfiles/config/claude/skill-registry.md ~/.claude/skill-registry.md
cp ~/Developer/dotfiles/config/claude/security_rules.md ~/.claude/security_rules.md
cp ~/Developer/dotfiles/config/claude/tweakcc-theme.json ~/.claude/tweakcc-theme.json
cp -n ~/Developer/dotfiles/config/claude/mcp-servers.template.json ~/.claude/mcp-servers.json

# 2. Directorios
mkdir -p ~/.claude/{agents,skills,commands,rules/common,hooks,templates,scripts,output-styles}

# 3. Agentes
cp -R ~/Developer/dotfiles/config/claude/agents/* ~/.claude/agents/

# 4. Skills
cp -R ~/Developer/dotfiles/config/claude/skills/* ~/.claude/skills/

# 5. Commands
cp -R ~/Developer/dotfiles/config/claude/commands/* ~/.claude/commands/

# 6. Rules
cp -R ~/Developer/dotfiles/config/claude/rules/common ~/.claude/rules/common
cp ~/Developer/dotfiles/config/claude/rules/npm-security.md ~/.claude/rules/npm-security.md

# 7. Hooks
cp -R ~/Developer/dotfiles/config/claude/hooks/* ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# 8. Templates
cp -R ~/Developer/dotfiles/config/claude/templates/* ~/.claude/templates/

# 9. Scripts
cp -R ~/Developer/dotfiles/config/claude/scripts/* ~/.claude/scripts/

# 10. Output styles
cp -R ~/Developer/dotfiles/config/claude/output-styles/* ~/.claude/output-styles/
```

> Las configuraciones son copias independientes. Borrar `~/Developer/dotfiles/` no afecta Claude Code.

## Plugins

Plugins instalados y activos (`settings.json` → `enabledPlugins`):

| Plugin | Funcion |
|---|---|
| `caveman@caveman` | Compresion de comunicacion ~75%. Modos: lite, full, ultra. Skills: cavecrew (investigator, builder, reviewer), caveman-commit, caveman-review. |
| `engram@engram` | Memoria persistente entre sesiones. Guarda decisiones, bugs, descubrimientos, convenciones. |
| `warp@claude-code-warp` | Integracion con Warp terminal. |

## MCP Servers

Configurados en `mcp-servers.json`. **Regla**: maximo 8-10 MCPs activos. Cada MCP tool description consume tokens de la context window. Mas MCPs = menos espacio para tu codigo.

| Server | Utilidad | Setup |
|---|---|---|
| `context7` | Documentacion actualizada de librerias | Ninguno |
| `codegraph` | Grafo semantico de codigo — elimina grep/read loops | `curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh \| sh` |
| `playwright` | E2E testing y web scraping | Ninguno |

## Hooks

Configurados en `settings.json`:

| Evento | Script(s) | Funcion |
|---|---|---|
| `PreToolUse` | `validate-safe-ops.sh` | Bloqueo de comandos peligrosos (`rm -rf`, `sudo`, `force push`, `DROP TABLE`) |
| `UserPromptSubmit` | `secret-detect.sh` | Deteccion de secrets en prompts (API keys, tokens, private keys) |
| `SessionStart` | echo log + `check-auto-save-stash.sh` + `handoff-session-start.py` | Log de inicio, alerta de stashes sin commit, inyeccion de HANDOFF.md |
| `PreCompact` | `git stash` inline | Auto-save checkpoint antes de compactacion |
| `PostCompact` | printf context + `git stash pop` | Reinyeccion de reglas CLAUDE.md + recuperacion de working tree |
| `PostToolUse` | grep debug statements + `git add` | Deteccion de `console.log`/`var_dump`/`debugger` + auto-stage de archivos editados |
| `PostToolUseFailure` | echo alert | Alerta de tool call fallido |
| `Stop` | `stop-check-pending.sh` + engram save + `handoff-stop.sh` | Alerta de cambios sin commit, checkpoint en Engram, archivo de HANDOFF.md |

## Modelos

Default: `opusplan` (razonamiento + ejecucion). Advisor: `opus`.

Per-task switching: `/model opus` | `/model sonnet` | `/model haiku`

Subagentes: `haiku` por defecto (`CLAUDE_CODE_SUBAGENT_MODEL`). Workflows habilitados (`enableWorkflows: true`).

## Herramientas recomendadas

### CodeGraph — Knowledge graph para tu codebase

Indexa la codebase en un grafo semantico (SQLite + FTS5) y lo expone como MCP server. Claude consulta el grafo en vez de hacer grep/read loops.

**Impacto medido** (benchmarks sobre 7 codebases reales):

```bash
# macOS/Linux
curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh

# Windows (PowerShell)
irm https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.ps1 | iex
```

> CodeGraph previene el patron que mas contexto quema: `grep → read → grep → read`. Con una sola llamada MCP obtenes definiciones, callers, callees y codigo relacionado.

### AgentShield — Auditoria de seguridad para config

Escanea CLAUDE.md, settings.json, MCPs, hooks y agentes buscando secrets expuestos, permisos peligrosos, hook injection y mala configuracion.

```bash
npx ecc-agentshield scan              # escaneo rapido (102 reglas)
npx ecc-agentshield scan --fix        # auto-fix de issues seguros
npx ecc-agentshield scan --opus       # analisis profundo con 3 agentes Opus
```

## SDD Flow

Para features complejas: `[constitution] → explore → propose → spec ∥ design → tasks → apply → verify → archive`.

Templates en `templates/`. Artefactos en `specs/{change-name}/`. Human gates en proposal y spec+design.

## Filosofia

- **Curado > masivo**. 49 skills y 22 agentes, seleccionados por utilidad real.
- **Context window first**. Cada feature compite por tokens con tu codigo.
- **Convenciones sobre configuracion**. Reglas claras en `rules/common/`.
- **Hooks con proposito**. Cada hook tiene una funcion concreta, no es ruido.
- **Defensa en profundidad**. Security rules + npm-security.md + hooks de validacion.
