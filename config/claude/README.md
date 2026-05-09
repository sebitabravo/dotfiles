# Claude Code Config

Configuracion optimizada de Claude Code con agentes especializados, reglas, skills, comandos, hooks, y MCP servers. Diseñada para maxima productividad con minima context window bloat.

## Estructura

```
config/claude/
├── CLAUDE.md                    # Instrucciones globales (senior architect mode)
├── settings.json                # Hooks, permisos, env vars, modelo
├── statusline.sh                # Statusline custom
├── mcp-servers.template.json    # Template de MCP servers
├── README.md                    # Este archivo
├── rules/
│   └── common/                  # Reglas siempre activas
│       ├── coding-style.md      # Estándares de código
│       ├── git-workflow.md      # Conventional commits, branching
│       ├── testing.md           # Requisitos y patrones de testing
│       ├── security.md          # OWASP, secretos, dependencias
│       └── patterns.md          # SOLID, arquitectura, diseño
├── agents/                      # 21 agentes especializados
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
│   └── ui-ux-designer.md
├── skills/                      # Skills invocables por contexto
│   ├── api-design/SKILL.md
│   ├── code-review/SKILL.md
│   ├── database-migrations/SKILL.md
│   ├── deployment-patterns/SKILL.md
│   ├── find-skills/SKILL.md
│   ├── security-review/SKILL.md
│   └── skill-creator/SKILL.md
└── commands/                    # Slash commands
    ├── code-review.md
    ├── model-route.md
    ├── plan.md
    └── security-scan.md
```

## Instalacion rapida

```bash
# 1. Symlinks de archivos core
ln -sf ~/Developer/dotfiles/config/claude/settings.json ~/.claude/settings.json
ln -sf ~/Developer/dotfiles/config/claude/CLAUDE.md ~/.claude/CLAUDE.md
ln -sf ~/Developer/dotfiles/config/claude/statusline.sh ~/.claude/statusline.sh
ln -sf ~/Developer/dotfiles/config/claude/mcp-servers.template.json ~/.claude/mcp-servers.json

# 2. Directorios
mkdir -p ~/.claude/agents ~/.claude/skills ~/.claude/commands ~/.claude/rules

# 3. Agentes (symlinks)
for f in ~/Developer/dotfiles/config/claude/agents/*.md; do
  ln -sf "$f" ~/.claude/agents/
done

# 4. Skills
for d in ~/Developer/dotfiles/config/claude/skills/*/; do
  skill_name=$(basename "$d")
  ln -sfn "$d" ~/.claude/skills/"$skill_name"
done

# 5. Commands
for f in ~/Developer/dotfiles/config/claude/commands/*.md; do
  ln -sf "$f" ~/.claude/commands/
done

# 6. Rules
ln -sfn ~/Developer/dotfiles/config/claude/rules/common ~/.claude/rules/common
```

O en una linea:

```bash
ln -sf ~/Developer/dotfiles/config/claude/settings.json ~/.claude/ && ln -sf ~/Developer/dotfiles/config/claude/CLAUDE.md ~/.claude/ && ln -sf ~/Developer/dotfiles/config/claude/statusline.sh ~/.claude/ && cp -n ~/Developer/dotfiles/config/claude/mcp-servers.template.json ~/.claude/mcp-servers.json && mkdir -p ~/.claude/{agents,skills,commands,rules} && for f in ~/Developer/dotfiles/config/claude/agents/*.md; do ln -sf "$f" ~/.claude/agents/; done && for d in ~/Developer/dotfiles/config/claude/skills/*/; do ln -sfn "$d" ~/.claude/skills/$(basename "$d"); done && for f in ~/Developer/dotfiles/config/claude/commands/*.md; do ln -sf "$f" ~/.claude/commands/; done && ln -sfn ~/Developer/dotfiles/config/claude/rules/common ~/.claude/rules/common && echo 'OK - Config instalada'
```

## Plugins recomendados

```bash
# Caveman - compresion de comunicacion ~75%
claude plugin marketplace add JuliusBrussee/caveman
claude plugin install caveman@caveman

# Engram - memoria persistente entre sesiones
claude plugin marketplace add Gentleman-Programming/engram
claude plugin install engram@engram
```

## MCP Servers

Copiar `mcp-servers.template.json` a `~/.claude/mcp-servers.json` y configurar credenciales.

**Regla**: maximo 8-10 MCPs activos. Cada MCP tool description consume tokens de la context window de 200k. Mas MCPs = menos espacio para tu codigo.

| Server | Utilidad |
|---|---|
| `context7` | Documentacion actualizada de librerias |
| `playwright` | E2E testing y web scraping |
| `github` | PRs, issues, code search |
| `postgres` | Consultas y schema de DB |
| `brave-search` | Busqueda web (API key gratuita) |

## Hooks

Configurados en `settings.json`:

| Evento | Accion |
|---|---|
| `SessionStart` | Log de inicio de sesion |
| `PreCompact` | Git auto-commit checkpoint |
| `PostToolUse` | Deteccion de debug statements (console.log, var_dump, etc.) |
| `Stop` | Guardado de checkpoint en Engram (si disponible) |

## Modelos

Default: `opusplan` (Opus en razonamiento + Sonnet en ejecucion).

Per-task switching: `/model opus` | `/model sonnet` | `/model haiku`

Si usas DeepSeek API, todos los modelos mapean al mismo backend. La diferencia esta en el comportamiento del sistema (cuanto razonamiento aplica).

## Filosofia

- **Curado > masivo**. 7 skills y 21 agentes, no 182 skills y 48 agentes.
- **Context window first**. Cada feature compite por tokens con tu codigo.
- **Convenciones sobre configuracion**. Reglas claras en `rules/common/`.
- **Hooks con proposito**. Cada hook tiene una funcion concreta, no es ruido.
