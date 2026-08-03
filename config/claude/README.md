# Claude Code Config

Configuracion de Claude Code con agentes especializados, reglas, skills, hooks y MCP.

## Sync rapido

```bash
cp -R ~/Developer/dotfiles/config/claude/{*.{json,md,sh},agents,skills,hooks,rules,templates,scripts,output-styles} ~/.claude/
chmod +x ~/.claude/hooks/*.sh ~/.claude/hooks/lib/*.sh
```

## Que hay

| Categoria | Cantidad | Detalle |
|---|---|---|
| Agentes | 22 | Ingenieria (backend-architect, code-reviewer, debugger, deployment-engineer, frontend-developer, observability-engineer, performance-engineer, product-manager, qa-engineer, security-auditor, technical-writer, ui-ux-designer, vulnerability-hunter, data-analyst) + Negocio (ceo-strategist, cfo-finance, customer-success, hr-people-ops, legal-compliance, marketing-strategist, operations-manager, sales-representative) |
| Skills | 62 | Engineering, Backend, Mobile, Frontend/Animation, Design/Stitch, Media/Documents, Core/Workflow, Quality/Testing |
| Rules | 6 | `coding-style.md`, `git-workflow.md`, `testing.md`, `security.md`, `context-management.md`, `destructive-operations.md`. BDD, mutation testing, quality metrics, arquitectura y npm-security viven ahora como skills (`bdd-gherkin`, `mutation-testing`, `quality-metrics`, `architecture-patterns`, `npm-security`) |
| Hooks | 12 scripts + `scripts/rdd.sh` y `scripts/check-skill-deps.sh` | `PreToolUse` (validate-safe-ops, privacy-review, quality-gate, protect-tests), `UserPromptSubmit` (secret-detect), `SessionStart` (check-auto-save-stash, handoff-session-start), `PostCompact`, `PostToolUse` (detect-debug), `PostToolUseFailure`, `Stop` (qa-checklist, gauntlet-stop, stop-check-pending, handoff-stop), `SessionEnd` |
| SDD Templates | 7 | constitution, proposal, requirements, design, tasks, apply-progress, checklist |
| MCP | 3 | context7, codegraph, playwright |
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
