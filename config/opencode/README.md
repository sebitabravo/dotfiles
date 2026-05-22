# OpenCode Config

Configuracion optimizada de OpenCode con agentes especializados, reglas, skills, MCP servers, y plugins. Disenada para desarrollo multi-agente con minima context window bloat.

## Estructura

```
config/opencode/
├── opencode.json                # Config principal: MCPs, permisos, plugins
├── AGENTS.md                    # Instrucciones globales para agentes
├── security_rules.md            # Reglas de seguridad (secrets, rutas bloqueadas)
├── dcp.jsonc                    # DCP (Dynamic Context Protocol) config
├── tui.json                     # TUI settings
├── skill-registry.md            # Registro de skills disponibles
├── skills-lock.json             # Lockfile de versiones de skills
├── README.md                    # Este archivo
├── agents/                      # Agentes especializados
├── .agents/                     # Agentes internos (ocultos)
├── prompts/                     # Plantillas de system prompts
├── rules/                       # Reglas adicionales
├── skill/                       # Skills instalados
├── templates/                   # Templates de artifactos (SDD, etc.)
└── themes/                      # Temas visuales
```

## Instalacion rapida

```bash
# 1. Archivos core (copia, no symlink — el dotfile se puede borrar sin perder config)
cp ~/Developer/dotfiles/config/opencode/opencode.json ~/.config/opencode/opencode.json
cp ~/Developer/dotfiles/config/opencode/AGENTS.md ~/.config/opencode/AGENTS.md
cp ~/Developer/dotfiles/config/opencode/security_rules.md ~/.config/opencode/security_rules.md
cp ~/Developer/dotfiles/config/opencode/dcp.jsonc ~/.config/opencode/dcp.jsonc
cp ~/Developer/dotfiles/config/opencode/tui.json ~/.config/opencode/tui.json

# 2. Directorios
mkdir -p ~/.config/opencode/{agents,skill,skills,rules,configs,themes,prompts,extensions,templates}

# 3. Agentes
cp -R ~/Developer/dotfiles/config/opencode/agents/* ~/.config/opencode/agents/

# 4. Skills
cp -R ~/Developer/dotfiles/config/opencode/skill/* ~/.config/opencode/skill/

# 5. Rules
cp -R ~/Developer/dotfiles/config/opencode/rules/common ~/.config/opencode/rules/common

# 6. Templates
cp -R ~/Developer/dotfiles/config/opencode/templates/* ~/.config/opencode/templates/
```

> Las configuraciones son copias independientes. Borrar `~/Developer/dotfiles/` no afecta OpenCode.

## MCP Servers

Configurados en `opencode.json` bajo la key `mcp`:

| Server | Estado | Utilidad |
|---|---|---|
| `context7` | ✅ Activo | Documentacion actualizada de librerias (via `npx @upstash/context7-mcp`) |
| `engram` | ✅ Activo | Memoria persistente entre sesiones con cloud autosync |
| `playwright` | ❌ Deshabilitado | E2E testing y web scraping (pesado, ~500MB) |
| `unity` | ❌ Deshabilitado | Integracion con Unity 3D para desarrollo de juegos |
| `resolve` | ❌ Deshabilitado | DaVinci Resolve Studio — 52 tools: edicion, color, Fusion, render, transcripcion |

### Resolve MCP — Setup adicional

El MCP de Resolve requiere pasos extra fuera de OpenCode:

**1. Clonar e instalar**

```bash
git clone https://github.com/barckley75/resolve-claude-mcp.git ~/Developer/resolve-claude-mcp
cd ~/Developer/resolve-claude-mcp && uv sync
```

**2. Habilitar scripting en Resolve**

`Preferences > General > External scripting using` → **Local**

**3. Activar en opencode.json**

Cambiar `"enabled": false` a `true` en la entrada `mcp.resolve`.

> ⚠️ Solo macOS Apple Silicon. Requiere DaVinci Resolve **Studio** (paga). La version gratis tiene scripting limitado.
> El path `RESOLVE_SCRIPT_LIB` en `opencode.json` asume Resolve en `/Applications/DaVinci Resolve.app`. Si tu instalacion difiere, ajusta las variables de entorno.

### Unity MCP — Setup adicional

El MCP de Unity requiere pasos extra fuera de OpenCode:

**1. Instalar package en Unity**

En Unity Editor: `Window > Package Manager > + > Add package from git URL...`

```
https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#main
```

**2. Iniciar el servidor**

`Window > MCP for Unity > Start Server > Configure` y elegir cliente OpenCode.

**3. Requisitos previos**

- Unity 2021.3 LTS+
- Python 3.10+ con `uv` (ya en Brewfile)

### Plugins

Configurados en `opencode.json` bajo la key `plugin`:

| Plugin | Utilidad |
|---|---|
| `@warp-dot-dev/opencode-warp` | Integracion con Warp terminal |
| `@tarquinen/opencode-dcp` | Dynamic Context Protocol |
| `opencode-worktree` | Aislamiento de trabajo en git worktrees |

## Agentes

Configurados en `opencode.json` bajo `agent`:

| Agente | Descripcion |
|---|---|
| `sebastian` | Senior Architect — agente principal, temperatura 0.1, permisos amplios |

Agentes adicionales en `agents/` con configuraciones especificas por dominio.

## Permisos

### Bash — operaciones protegidas (ask)

- `git commit*`, `git push*`, `git rebase*`
- `git reset --hard*`, `git clean*`, `git checkout -f*`
- `rm -rf *`, `rm -f *`

### Read — archivos bloqueados (deny)

`.env*`, `.ssh/**`, `id_*`, `*.pem`, `*.key`, `*.ppk`, `*.p12`, `*.pfx`, `*.pvk`, `secrets/**`, `credentials.json`, `.DS_Store`

## Filosofia

- **Curado > masivo**. 4 MCPs (2 activos), agentes enfocados, skills por necesidad.
- **Context window first**. Cada feature compite por tokens con tu codigo.
- **Seguridad por defecto**. Rutas de secrets bloqueadas, git ops con confirmacion.
- **Plugins con proposito**. Cada plugin tiene una funcion concreta.
