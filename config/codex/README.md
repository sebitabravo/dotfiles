# Codex CLI Config

Configuracion optimizada de Codex CLI con agentes especializados, reglas globales, Engram memory protocol, y MCP servers. Diseñada para consistencia con la config de Claude Code en este mismo dotfile.

## Estructura

```
config/codex/
├── AGENTS.md                    # Instrucciones globales (senior architect mode)
├── config.toml                  # Modelo, seguridad, agentes, perfiles
├── hooks.json                   # Hooks (Notification no-op, template base)
├── engram-compact-prompt.md     # Prompt de compactacion consciente de Engram
├── engram-instructions.md       # Protocolo Engram (save/search/session close)
├── mcp-servers.template.json    # Template de MCP servers
├── README.md                    # Este archivo
└── agents/                      # 5 agentes especializados (TOML)
    ├── reviewer.toml            # Code review: correctness, security, edge cases
    ├── security-auditor.toml    # Security audit: OWASP, auth, secrets, supply chain
    ├── debugger.toml            # Debugging: root cause, test failures, error traces
    ├── test-writer.toml         # Test generation: unit, integration, E2E, regression
    └── perf-profiler.toml       # Performance: N+1 queries, caching, Core Web Vitals
```

## Instalacion

Ajusta `DOTFILES` al path donde clonaste el repo.

```bash
# 1. Instalar Codex CLI
npm install -g @openai/codex

# 2. Directorio base de Codex
DOTFILES=~/Developer/dotfiles
mkdir -p ~/.codex/agents

# 3. Copiar archivos core
cp "$DOTFILES/config/codex/config.toml" ~/.codex/config.toml
cp "$DOTFILES/config/codex/AGENTS.md" ~/.codex/AGENTS.md
cp "$DOTFILES/config/codex/hooks.json" ~/.codex/hooks.json
cp "$DOTFILES/config/codex/engram-compact-prompt.md" ~/.codex/engram-compact-prompt.md
cp "$DOTFILES/config/codex/engram-instructions.md" ~/.codex/engram-instructions.md

# 4. Copiar agentes
cp "$DOTFILES/config/codex/agents/"*.toml ~/.codex/agents/

# 5. MCP servers (template — editalo con tus credenciales)
cp -n "$DOTFILES/config/codex/mcp-servers.template.json" ~/.codex/mcp-servers.json
```

Para actualizar la config en el futuro, volve a copiar los archivos. Si personalizaste `mcp-servers.json`, no lo pises.

## Agentes

5 agentes especializados con modelo, effort y sandbox independiente. Cada uno definido en `agents/<nombre>.toml`.

| Agente | Modelo | Effort | Sandbox | Proposito |
|---|---|---|---|---|
| `reviewer` | gpt-5.5 | high | read-only | Code review: correctness, security, edge cases |
| `security-auditor` | gpt-5.5 | xhigh | read-only | OWASP Top 10, secrets, supply chain, auth |
| `debugger` | gpt-5.5 | high | workspace-write | Root cause analysis, test failures, error traces |
| `test-writer` | gpt-5.5 | medium | workspace-write | Unit, integration, E2E, regression tests |
| `perf-profiler` | gpt-5.5 | high | read-only | N+1 queries, caching, Core Web Vitals, bottlenecks |

Los agentes se configuran en `config.toml` via `[agents.<nombre>]` con `config_file` apuntando al TOML. Max 6 threads concurrentes, profundidad 1.

## Seguridad

Tres llaves maestras en `config.toml`:

| Setting | Valor | Efecto |
|---|---|---|
| `approval_policy` | `on-request` | Pide confirmacion para comandos destructivos |
| `sandbox_mode` | `workspace-write` | Lee todo el filesystem, escribe solo en workspace |
| `web_search` | `live` | Busqueda web habilitada (context7 cubre docs) |

**Proteccion de secrets en shell:**

```toml
[shell_environment_policy]
exclude = ["*_KEY", "*_SECRET", "*_TOKEN", "*_PASSWORD", "*_CREDENTIAL*"]
```

Las env vars que matchean estos patrones NO se pasan al shell del agente. Previene exposicion accidental de credenciales en logs o output.

**Privacidad:** `commit_attribution = ""` — el agente no firma commits con atribucion de IA.

## Perfiles

Tres perfiles para distintos contextos de uso. Cambiar con `codex --profile <nombre>`.

| Perfil | Modelo | Effort | Uso |
|---|---|---|---|
| `work` | gpt-5.5 | high | Trabajo pesado — features, refactors, debugging |
| `personal` | gpt-5.5 | medium | Tareas personales, scripts, configuracion |
| `quick` | gpt-5.3-codex | minimal | Consultas rapidas, one-shots, preguntas simples |

El perfil default (sin `--profile`) usa los settings del root de `config.toml`: gpt-5.5, medium effort.

## MCP Servers

Copiar `mcp-servers.template.json` a `~/.codex/mcp-servers.json` y ajustar paths/credenciales.

| Server | Utilidad | Requisito |
|---|---|---|
| `context7` | Documentacion actualizada de librerias | Node.js, `@upstash/context7-mcp` |
| `engram` | Memoria persistente entre sesiones | `brew install engram` |

## Hooks

Estructura base en `hooks.json`. El hook `Notification` ejecuta `true` por defecto (no-op). Reemplazar `command` con el path a tu script de notificacion.

Para desactivar hooks: `hooks = false` en `config.toml`.

## Filosofia

- **Core config portable**. Solo modelo, seguridad, agentes y perfiles en el dotfile.
- **Plugins y marketplaces son locales**. Cada maquina decide que plugins instalar.
- **MCP servers como template**. Las credenciales y paths son locales, no se commitean.
- **Agentes curados**. 5 agentes con proposito claro, no 20 agentes genericos.
- **Seguridad por defecto**. approval_policy, sandbox_mode, y shell_environment_policy desde el primer start.
- **Consistencia con Claude Code**. Misma estructura, mismos principios, mismas reglas.
