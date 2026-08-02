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
| Skills | 51 | Engineering, Backend, Mobile, Frontend/Animation, Design/Stitch, Media/Documents, Core/Workflow, Quality/Testing |
| Rules | 9 | `coding-style.md`, `git-workflow.md`, `testing.md`, `bdd.md`, `security.md`, `patterns.md`, `quality-metrics.md`, `mutation-testing.md`, `npm-security.md` |
| Hooks | 8 | `PreToolUse` (validate-safe-ops, quality-gate), `UserPromptSubmit` (secret-detect), `SessionStart`, `PreCompact`, `PostCompact`, `PostToolUse`, `PostToolUseFailure`, `Stop` (qa-checklist, stop-check-pending, handoff) |
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
