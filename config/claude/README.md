# Claude Code

Configuración personal de Claude Code con `opusplan`, agentes, skills, reglas,
hooks, MCP y overlays opcionales para proveedores compatibles con la API de
Anthropic.

Esta carpeta se puede copiar de forma independiente. Los proveedores y las
claves son opcionales: Claude Code normal funciona sin ellos.

## Qué contiene

| Ruta | Propósito |
|---|---|
| `settings.json` | Configuración principal, permisos, hooks, MCP y `opusplan`. |
| `CLAUDE.md` | Instrucciones globales para Claude Code. |
| `agents/` | Agentes especializados. |
| `skills/` | Skills reutilizables y workflows. |
| `rules/` | Reglas de estilo, seguridad, testing y operaciones. |
| `hooks/` | Validaciones y automatizaciones de ciclo de vida. |
| `templates/` | Plantillas para SDD y documentación. |
| `output-styles/` | Estilos de respuesta. |
| `scripts/` | Helpers de validación, dependencias y autenticación. |
| `statusline.sh` | Statusline personalizada. |
| `mcp-servers.json` | Servidores MCP declarados por esta configuración. |
| `*.settings.json` | Overlays independientes para proveedores alternativos. |

Los overlays no se inyectan dentro de `settings.json`. Cada uno es un archivo
separado que se activa con `--settings`.

## Instalación

Ejecutá esto apuntando `CLAUDE_DIR` a la carpeta que contiene esta
configuración:

```bash
# Si copiaste sólo esta carpeta:
CLAUDE_DIR="/ruta/a/claude"
# O desde la raíz del repositorio:
CLAUDE_DIR="$PWD/config/claude"

mkdir -p "$HOME/.claude"

# Sólo borra contenido dentro de estas carpetas gestionadas.
for dir in agents skills hooks rules templates scripts output-styles; do
  rsync -a --delete \
    --exclude='__pycache__' \
    --exclude='.DS_Store' \
    "$CLAUDE_DIR/$dir/" "$HOME/.claude/$dir/"
done

for file in \
  CLAUDE.md \
  statusline.sh \
  mcp-servers.json \
  skills-lock.json \
  tweakcc-theme.json \
  skill-registry.md \
  settings.json \
  deepseek.settings.json \
  glm.settings.json \
  kimi.settings.json \
  minimax.settings.json \
  ollama.settings.json \
  openrouter.settings.json; do
  cp -p "$CLAUDE_DIR/$file" "$HOME/.claude/$file"
done

chmod +x "$HOME/.claude"/scripts/*.sh "$HOME/.claude"/hooks/*.sh \
  "$HOME/.claude"/hooks/lib/*.sh 2>/dev/null || true
```

El bloque no borra `~/.claude/settings.local.json`, autenticación, cachés ni
otros archivos locales. Sí reemplaza `~/.claude/settings.json` y los overlays
versionados. Si una aplicación externa —por ejemplo Orca— escribe entradas
personalizadas en `settings.json`, respaldalas o integrá esas entradas en el
repositorio antes de copiarlo.

> `rsync --delete` se usa sólo dentro de las carpetas gestionadas. Así, si
> eliminás una skill del repositorio, también desaparece del destino sin tocar
> el resto de tu instalación de Claude Code.

## Configuración principal

El comando normal sigue usando Anthropic y el modelo configurado en
`settings.json`:

```bash
claude
```

La configuración actual declara:

- `model: "opusplan"`;
- Opus para planificación;
- Sonnet para la ejecución principal;
- Haiku para tareas livianas y subagentes, cuando Claude Code lo selecciona;
- autocompact en `204800` tokens;
- permisos, hooks y MCP definidos en el archivo principal.

## Proveedores alternativos

Todos son opcionales. Cada proveedor tiene su propio settings y su propio
helper de autenticación:

| Proveedor | Overlay | Endpoint | Opus | Sonnet | Haiku / subagentes |
|---|---|---|---|---|---|
| DeepSeek | `deepseek.settings.json` | `api.deepseek.com/anthropic` | `deepseek-v4-pro[1m]` | `deepseek-v4-flash[1m]` | `deepseek-v4-flash` |
| GLM / Z.AI | `glm.settings.json` | `api.z.ai/api/anthropic` | `glm-5.3[1m]` | `glm-4.7` | `glm-4.5` |
| Kimi / Moonshot | `kimi.settings.json` | `api.moonshot.ai/anthropic` | `kimi-k3[1m]` | `kimi-k2.7-code` | `kimi-k2.6` |
| MiniMax | `minimax.settings.json` | `api.minimax.io/anthropic` | `MiniMax-M3[1m]` | `MiniMax-M2.7-highspeed` | `MiniMax-M3` |
| Ollama Cloud | `ollama.settings.json` | `ollama.com` | `minimax-m3:cloud` | `gpt-oss:120b-cloud` | `gpt-oss:20b-cloud` |
| OpenRouter | `openrouter.settings.json` | `openrouter.ai/api` | `deepseek/deepseek-v4-pro` | `openai/gpt-5.6-luna` | `openrouter/free` |

Los modelos de la tabla son **las elecciones de esta configuración**, no
defaults universales. La disponibilidad, los precios y los límites de cada
proveedor pueden cambiar.

### Activación

Si también copiaste el wrapper de `.zshrc`, podés usar los comandos cortos:

```bash
claude --deepseek
claude --glm
claude --kimi
claude --minimax
claude --ollama
claude --openrouter
```

El wrapper de `.zshrc` **no está dentro de `config/claude/`**. Si copiás sólo
esta carpeta, usá directamente el overlay que necesités:

```bash
claude --settings ~/.claude/deepseek.settings.json
claude --settings ~/.claude/openrouter.settings.json
```

El resto de los overlays se activa de la misma forma cambiando el nombre del
archivo.

### API keys

Las claves nunca forman parte del repositorio. Los helpers buscan estos
archivos locales, todos con permisos `0600`:

| Proveedor | Archivo |
|---|---|
| DeepSeek | `~/.config/claude/deepseek.key` |
| GLM / Z.AI | `~/.config/claude/glm.key` |
| Kimi / Moonshot | `~/.config/claude/kimi.key` |
| MiniMax | `~/.config/claude/minimax.key` |
| Ollama Cloud | `~/.config/claude/ollama.key` |
| OpenRouter | `~/.config/claude/openrouter.key` |

Ejemplo para crear una clave sin dejarla en el historial del shell:

```bash
mkdir -p ~/.config/claude
umask 077
printf 'API key: '
IFS= read -r -s API_KEY
printf '\n'
printf '%s\n' "$API_KEY" > ~/.config/claude/deepseek.key
unset API_KEY
chmod 600 ~/.config/claude/deepseek.key
```

Para otro proveedor, cambiá el nombre del archivo. También podés usar una
ubicación distinta exportando la variable correspondiente, por ejemplo:

```bash
export DEEPSEEK_API_KEY_FILE="$HOME/.config/claude/deepseek.key"
```

Los nombres de las variables disponibles son `DEEPSEEK_API_KEY_FILE`,
`GLM_API_KEY_FILE`, `KIMI_API_KEY_FILE`, `MINIMAX_API_KEY_FILE`,
`OLLAMA_API_KEY_FILE` y `OPENROUTER_API_KEY_FILE`.

Si falta una clave, Claude Code normal sigue funcionando; sólo falla el
proveedor cuyo helper no puede leer su archivo.

## Cambios locales y archivos que no se copian

No versionés ni sobrescribas estos datos al compartir esta configuración:

- `~/.claude/settings.local.json`;
- autenticación y sesiones de Claude Code;
- `~/.config/claude/*.key`;
- cachés y archivos temporales;
- credenciales de MCP o de otras aplicaciones.

Si adaptás `settings.json` a tu máquina, mantené tus cambios separados de la
configuración pública. En particular, revisá las entradas que puedan agregar
Orca, plugins u otras aplicaciones antes de volver a sincronizar.

## Validación opcional

No hace falta un `Makefile` ni una suite de tests para instalar estos dotfiles.
Para revisar una copia local, desde `CLAUDE_DIR`:

```bash
bash "$CLAUDE_DIR/scripts/validate.sh"
```

La validación comprueba la estructura de la configuración, los manifiestos y
las dependencias declaradas. No prueba credenciales ni garantiza que un
proveedor externo responda.

## Principios de esta configuración

- Mantener `opusplan` y el flujo nativo de Claude Code, sin commands que
  sombreen `/plan`.
- Separar los overlays de proveedores del settings principal.
- No guardar secretos en Git, `settings.json` ni `.zshrc`.
- Proteger secretos y operaciones de red: `deny` para archivos sensibles y
  `ask` para installs y push. Fallar explícitamente si falta una clave.
- Mantener la configuración portable: lo específico de macOS o del shell vive
  fuera de esta carpeta.
