# Codex CLI configuration

Configuración curada para Codex CLI: reglas globales, estilo Sebita, sandbox y
approval policy, hooks de seguridad, cinco agentes especializados, MCP,
perfiles, skills seleccionados, flujo SDD, RDD opt-in y tema TUI.

La configuración fuente vive en este repositorio. Codex la carga desde
`~/.codex/` y las skills desde `~/.agents/skills/` o desde `.agents/skills/` del
repositorio actual. Consulta la [documentación oficial de configuración](https://learn.chatgpt.com/docs/config-file/config-reference)
si tu versión cambia algún campo.

## Estructura

```text
config/codex/
├── AGENTS.md                       # reglas globales y estilo Sebita
├── config.toml                     # defaults, seguridad, MCP, agentes y TUI
├── work.config.toml                # perfil strong: Sol/high
├── personal.config.toml            # perfil estándar: Luna/high
├── quick.config.toml               # perfil cheap: Luna/low
├── hooks.json                      # lifecycle hooks Codex
├── hooks/                          # scripts de seguridad y contexto
├── rules/default.rules             # prompts/bloqueos para comandos fuera del sandbox
├── agents/*.toml                   # reviewer, security, debugger, tests, perf
├── skills/                         # skills curados para uso global
├── scripts/                        # auditoría de deps y RDD opt-in
├── skills/sdd-workflow/references/ # templates SDD incluidos en Codex
├── themes/sebita.tmTheme           # tema TUI nativo
├── mcp-servers.template.toml       # snippets MCP opcionales
├── engram-instructions.md          # protocolo Engram opcional
└── engram-compact-prompt.md        # recuperación después de compaction
```

## Statusline y tema

Claude y Codex no comparten el contrato del statusline. Claude ejecuta
`~/.claude/statusline.sh` y recibe un JSON con coste, contexto y workspace;
Codex 0.146.0 sólo acepta una lista ordenada de identificadores nativos en
`[tui].status_line`. Por eso Codex no puede cargar directamente el script de
Claude ni aceptar una clave `command` en ese campo.

La configuración nativa queda alineada con las partes equivalentes:

- `model-with-reasoning`: modelo y nivel de razonamiento.
- `current-dir` y `git-branch`: carpeta y rama activa.
- `context-used`: porcentaje de contexto consumido, equivalente al `ctx` de
  Claude.
- `task-progress`: avance del plan actual.
- `five-hour-limit` y `weekly-limit`: límites de uso disponibles.
- `status_line_use_colors = true` y `theme = "sebita"`: colores del tema
  Sebita para los segmentos nativos.

Codex no expone en el statusline nativo los contadores `+added/-removed`, el
estado real de conexión MCP, las alertas de peak pricing ni el badge Caveman
que calcula el script de Claude. Esos elementos no se simulan con una clave
inventada porque haría que Codex ignore o rechace la configuración. Las
configuraciones de Claude y Codex siguen siendo independientes.

## Instalación

Haz backup de tu configuración local antes de sincronizar.

**`config.toml` NO se copia sobre una instalación existente.** El archivo local
no es solo configuración: Codex guarda ahí estado de runtime que no se puede
regenerar — los `trusted_hash` de `[hooks.state]`, el `trust_level` de cada
proyecto, el registro de plugins del app y los bloques de Computer Use. La
versión del repo es la base portable para una máquina nueva; en una que ya
funciona, mezclá a mano solo las claves que cambiaron.

```bash
DOTFILES="$HOME/Developer/dotfiles"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
USER_SKILLS_DIR="$HOME/.agents/skills"

mkdir -p "$CODEX_HOME_DIR/agents" "$CODEX_HOME_DIR/hooks" "$CODEX_HOME_DIR/rules" "$CODEX_HOME_DIR/themes" "$CODEX_HOME_DIR/scripts" "$USER_SKILLS_DIR"

# Solo en una maquina nueva. Si ~/.codex/config.toml ya existe, NO lo pises:
# contiene estado de runtime (hooks.state, trust_level, plugins) irrecuperable.
[ -f "$CODEX_HOME_DIR/config.toml" ] || cp "$DOTFILES/config/codex/config.toml" "$CODEX_HOME_DIR/config.toml"
cp "$DOTFILES/config/codex/AGENTS.md" "$CODEX_HOME_DIR/AGENTS.md"
cp "$DOTFILES/config/codex/hooks.json" "$CODEX_HOME_DIR/hooks.json"
cp "$DOTFILES/config/codex/engram-compact-prompt.md" "$CODEX_HOME_DIR/engram-compact-prompt.md"
cp "$DOTFILES/config/codex/engram-instructions.md" "$CODEX_HOME_DIR/engram-instructions.md"
cp "$DOTFILES/config/codex/work.config.toml" "$CODEX_HOME_DIR/work.config.toml"
cp "$DOTFILES/config/codex/personal.config.toml" "$CODEX_HOME_DIR/personal.config.toml"
cp "$DOTFILES/config/codex/quick.config.toml" "$CODEX_HOME_DIR/quick.config.toml"
cp -R "$DOTFILES/config/codex/agents/." "$CODEX_HOME_DIR/agents/"
cp -R "$DOTFILES/config/codex/hooks/." "$CODEX_HOME_DIR/hooks/"
cp -R "$DOTFILES/config/codex/rules/." "$CODEX_HOME_DIR/rules/"
cp -R "$DOTFILES/config/codex/themes/." "$CODEX_HOME_DIR/themes/"
cp -R "$DOTFILES/config/codex/scripts/." "$CODEX_HOME_DIR/scripts/"
cp -R "$DOTFILES/config/codex/skills/." "$USER_SKILLS_DIR/"

chmod +x "$CODEX_HOME_DIR/hooks/"*.sh "$CODEX_HOME_DIR/hooks/"*.py
chmod +x "$CODEX_HOME_DIR/scripts/"*.sh
chmod +x "$USER_SKILLS_DIR/sdd-workflow/scripts/scaffold-sdd.sh"
```

Si usas otro path de dotfiles, cambia sólo `DOTFILES`. Reinicia Codex después
de sincronizar configuración, hooks o skills.

## Seguridad

- `approval_policy = "on-request"` mantiene aprobaciones explícitas.
- `sandbox_mode = "workspace-write"` limita las escrituras al workspace.
- `shell_environment_policy.filters` excluye variables con forma de credencial.
- `secret-detect.sh` bloquea claves pegadas en prompts.
- `validate-safe-ops.sh` bloquea RCE por pipe, lecturas de secretos, borrado de raíces, force-push, reset destructivo y operaciones de esquema destructivas.
- `privacy-review.sh` evita enviar rutas privadas, emails, tokens y hostnames locales a GitHub issue/PR creation.
- `protect-tests.sh` bloquea borrado de tests y archivos sensibles. Para un proyecto que requiere gate de edición de tests:

```bash
CODEX_PROTECT_EXISTING_TESTS=1 codex
```

- `stop-check.sh` ejecuta `qa-gate.py` antes de cerrar un turno. Para cambios de
  código de aplicación, tests o manifests, corre `git diff --check` y el runner
  nativo detectado (`npm test`, `uv run pytest` cuando el proyecto lo
  declara, `go test ./...`,`cargo test`, etc.).
  Si falla, expira, no existe un runner o hay whitespace inválido, devuelve
  `decision: "block"` y Codex continúa para corregirlo.
- Cambios de infraestructura en `config/codex/` no se fuerzan a pasar por un
  test runner de aplicación; se validan con fixtures, `bash -n`,
  compilación de Python, `codex --strict-config` y comprobaciones de paridad.
- El timeout predeterminado del gate es 180 segundos y se puede ajustar por
  repositorio con `CODEX_QA_TIMEOUT` (30–600 segundos). `CODEX_QA_RELAXED=1` o
  `.codex-qa-relaxed` sólo deben usarse en un scratch repo documentado.

Los hooks son guardrails, no una frontera de seguridad completa. Revisa siempre
el comando, el diff y el destino.

## MCP

Context7 está configurado en `config.toml` usando el transporte remoto
Streamable HTTP de Codex. Esto evita ejecutar `npx -y` y descargar una versión
mutable del servidor localmente:

```toml
[mcp_servers.context7]
url = "https://mcp.context7.com/mcp"
startup_timeout_sec = 20
tool_timeout_sec = 60
```

Comprueba el estado con:

```bash
codex mcp list
```

Engram está integrado en el perfil base como un MCP opcional. Puede compartir
su base de datos con cualquier otro cliente Engram, pero Codex no depende de
ninguna otra configuración. Primero verifica el binario:

```bash
command -v engram
```

La configuración base registra `engram mcp`, carga el protocolo desde
`engram-instructions.md` y usa `engram-compact-prompt.md` después de compaction.
Reinicia Codex y confirma que `codex mcp list` muestre `engram` como `enabled`.
Si el binario no está instalado, instala Engram antes de iniciar Codex.

### CodeGraph

CodeGraph se configura como servidor MCP local mediante `codegraph serve
--mcp`. El MCP queda declarado en `config.toml`; el binario debe estar
disponible en `PATH` (`codegraph --version`). La configuración es equivalente a
Claude Code y no duplica índices: CodeGraph usa el índice `.codegraph/` más
cercano al proyecto. No se debe ejecutar `codegraph init` automáticamente; esa
es una decisión explícita por repositorio.

Validación rápida:

```bash
codegraph --version
codex mcp list
codegraph status --json /ruta/al/proyecto
```

Para habilitar análisis en un repositorio concreto, inicializa su índice una
sola vez con `codegraph init /ruta/al/proyecto` y luego reinicia el cliente MCP.

## Perfiles

Los perfiles actuales se guardan como archivos separados, no como tablas
`[profiles.*]` dentro de `config.toml`:

```bash
codex --profile work
codex --profile personal
codex --profile quick
```

Los tres perfiles existentes también funcionan como los tres niveles de
Gentle-AI, sin crear archivos duplicados: `work` es strong (`gpt-5.6-sol`
con `high`), `personal` es estándar (`gpt-5.6-luna` con `high`) y `quick` es
cheap/rápido (`gpt-5.6-luna` con `low`). Edita esos tres archivos para ajustar
modelo, razonamiento, verbosity o permisos. No se usa `max`, `ultra` ni Terra.

La delegación queda habilitada con un techo técnico de cuatro subagentes, pero
las reglas de `AGENTS.md` recomiendan normalmente uno o dos. Los cinco roles
especializados existentes se conservan y no se duplican.

## Skill registry automático

El hook `SessionStart` ejecuta `refresh-skill-registry.sh` en `startup`,
`resume`, `clear` y `compact`. El wrapper no bloquea Codex si `gentle-ai` no
está instalado y muestra una advertencia si el refresh falla. El comando puede
crear `.atl/skill-registry.md` y `.atl/.skill-registry.cache.json` en el
proyecto actual.

Instala `gentle-ai` por separado y verifica el binario antes de esperar que el
registry se actualice:

```bash
command -v gentle-ai
gentle-ai version
```

## Skills

La colección global está deliberadamente curada. Incluye:

- `verification-before-completion`
- `systematic-debugging`
- `code-review`
- `security-review`
- `npm-security`
- `quality-metrics`
- `database-migrations`
- `deployment-patterns`
- `api-design`
- `handoff`
- `engram-memory` opcional
- `sdd-workflow`

Los skills pesados de documentos, diseño, mobile, WordPress y media no se
instalan globalmente para no contaminar el contexto de Codex. Si uno hace falta,
instálalo como skill de proyecto bajo `.agents/skills/`.

## SDD

Para una feature compleja:

```bash
"$HOME/.agents/skills/sdd-workflow/scripts/scaffold-sdd.sh" payments-retry
```

El script crea `specs/payments-retry/` con constitution, proposal,
requirements, design, tasks, apply-progress y checklist. Se niega a sobrescribir
una spec existente.

## RDD opt-in

RDD no corre automáticamente ni ejecuta comandos mediante `eval`:

```bash
config/codex/scripts/rdd.sh on
git add <archivos>
config/codex/scripts/rdd.sh freeze
config/codex/scripts/rdd.sh receipt -- npm test
config/codex/scripts/rdd.sh verify
```

Agrega `.codex-rdd/` al `.gitignore` del proyecto si el estado debe permanecer
local.

## Auditoría local

```bash
config/codex/scripts/check-skill-deps.sh
codex --strict-config --profile personal --help >/dev/null
```

Verifica hooks y MCP desde `/hooks` y `/mcp` dentro de Codex después de
reiniciar. Los hooks no gestionados requieren revisión/trust en la instalación
local. Si aparece `Hooks need review`, entra a `/hooks`, revisa el diff y elige
`Trust all and continue`; Codex guarda la confianza por hash, por lo que cada
cambio legítimo de un hook vuelve a pedir revisión una vez.
