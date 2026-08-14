# Claude Code Config

Configuracion de Claude Code con agentes especializados, reglas, skills, hooks y MCP.

## Sync rapido

`rsync --delete`, no `cp -R`: con `cp` una skill que borrás del repo sobrevive
para siempre en `~/.claude/skills/` y el agente la sigue viendo.

```bash
DOTFILES="$HOME/Developer/dotfiles/config/claude"

for d in agents skills hooks rules templates scripts output-styles; do
  rsync -aL --delete --exclude __pycache__ --exclude .DS_Store "$DOTFILES/$d/" "$HOME/.claude/$d/"
done
cp -p "$DOTFILES"/*.{json,md,sh} "$HOME/.claude/"
chmod +x ~/.claude/hooks/*.sh ~/.claude/hooks/lib/*.sh
```

`-L` resuelve symlinks copiando el contenido en vez del enlace. Hoy no queda
ninguno en `config/claude/` (el unico era `config/opencode/rules/common`, que se
fue con opencode), asi que el flag no cambia nada — se deja porque el dia que
vuelva a haber uno, sin `-L` el destino queda apuntando a una ruta inexistente y
el sync reporta exito igual.

**`settings.json` lleva hooks inyectados por apps externas** (Orca escribe en
`PermissionRequest`, `SubagentStart`, `TeammateIdle` y otros). Están mezclados en
la versión del repo. Si instalás otra app que escriba ahí, injertá sus entradas
al repo antes del próximo sync o el sync se las come.

## Que hay

| Categoria | Cantidad | Detalle |
|---|---|---|
| Agentes | 22 | Ingenieria (backend-architect, code-reviewer, debugger, deployment-engineer, frontend-developer, observability-engineer, performance-engineer, product-manager, qa-engineer, security-auditor, technical-writer, ui-ux-designer, vulnerability-hunter, data-analyst) + Negocio (ceo-strategist, cfo-finance, customer-success, hr-people-ops, legal-compliance, marketing-strategist, operations-manager, sales-representative) |
| Skills | 60 | Engineering, Backend, Mobile, Frontend/Animation, Design/Stitch, Media/Documents, Core/Workflow, Quality/Testing |
| Rules | 6 | `coding-style.md`, `git-workflow.md`, `testing.md`, `security.md`, `context-management.md`, `destructive-operations.md`. BDD, mutation testing, quality metrics, arquitectura y npm-security viven ahora como skills (`bdd-gherkin`, `mutation-testing`, `quality-metrics`, `architecture-patterns`, `npm-security`) |
| Hooks | 12 scripts + `scripts/rdd.sh` y `scripts/check-skill-deps.sh` | `PreToolUse` (validate-safe-ops, privacy-review, quality-gate, protect-tests), `UserPromptSubmit` (secret-detect), `SessionStart` (check-auto-save-stash, handoff-session-start), `PostCompact`, `PostToolUse` (detect-debug), `PostToolUseFailure`, `Stop` (qa-checklist, gauntlet-stop, stop-check-pending, handoff-stop), `SessionEnd` |
| SDD Templates | 7 | constitution, proposal, requirements, design, tasks, apply-progress, checklist |
| MCP | 2 | context7, codegraph |
| Plugins | 3 | caveman, engram, warp |
| Modelos | opusplan / opus (advisor) / haiku (subagentes) | |

## Principios

- **Testing**: todo requiere tests. Coverage >= 80% line, >= 70% branch.
- **BDD**: features complejas requieren `.feature` con Gherkin.
- **Mutation testing**: >= 80% score en features criticos.
- **Quality gate**: lint + tests + coverage antes de commit (`quality-gate.sh`).
- **Independent review**: code-reviewer + security-auditor en parallel, nunca self-review.
- **Defensa en profundidad**: security rules + npm-security + hooks de validacion.
- **Context window first**: cada feature compite por tokens con tu codigo.
