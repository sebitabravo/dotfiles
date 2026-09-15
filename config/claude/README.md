# Claude Code

Configuración personal de Claude Code con `opusplan`, skills, reglas, hooks, MCP
y overlays opcionales para proveedores compatibles con la API de Anthropic.

Esta carpeta se puede copiar de forma independiente. Los proveedores y las
claves son opcionales: Claude Code normal funciona sin ellos.

## Qué contiene

| Ruta | Propósito |
| --- | --- |
| `settings.json` | Configuración principal, permisos, hooks, MCP y `opusplan`. |
| `CLAUDE.md` | Instrucciones globales para Claude Code. |
| `skills/` | Skills reutilizables, cargadas bajo demanda. |
| `skill-registry.md` | Índice humano de `skills/`. No se carga en sesión. |
| `rules/` | Reglas de estilo, seguridad, testing y operaciones. |
| `hooks/` | Validaciones y automatizaciones de ciclo de vida. |
| `templates/` | Plantilla de `CLAUDE.md` para proyectos. |
| `output-styles/` | Estilos de respuesta. |
| `scripts/` | Helpers de runtime: RDD y autenticación de proveedores. |
| `agent-tools/` | Manifest de herramientas Python/Node/Rust sin runtimes duplicados. |
| `statusline.sh` | Statusline personalizada. |
| `mcp-servers.json` | Servidores MCP declarados por esta configuración. |
| `*.settings.json` | Overlays independientes para proveedores alternativos. |

Los overlays no se inyectan dentro de `settings.json`. Cada uno es un archivo
separado que se activa con `--settings`.

La carpeta contiene sólo fuentes que el runtime puede usar. Que un archivo
contenga la palabra `test` o `validate` no lo vuelve automáticamente una suite:
`hooks/lib/test-runner.sh` es una librería runtime consumida por el gate de
commit, y los validadores dentro de una skill implementan capacidades de esa
skill. Las auditorías del repositorio, smoke tests, paridad, dependencias y el
doctor viven fuera de esta carpeta, en `.github/test/`, y no se instalan en
`~/.claude`.

### Confianza de runners

El gate de commit (`hooks/quality-gate.sh`) no ejecuta automáticamente
`test.sh`, `.github/test.sh`, Make/Just, scripts de manifiestos ni wrappers del
repositorio sólo porque los detecte. Esos comandos son código controlado por el
repositorio y requieren una decisión explícita del usuario fuera del
repositorio. Agregá la ruta absoluta exacta del root Git, una por línea, a:

```text
~/.claude/trusted-repositories
```

La ruta alternativa `CLAUDE_REPOSITORY_TRUST_FILE` permite probar una política
aislada sin tocar la configuración real; `CLAUDE_TRUSTED_REPOSITORY` es un
opt-in equivalente para una invocación puntual. Si falta la confianza, el gate
devuelve un bloqueo tipado y no ejecuta el runner ni inventa PASS. La decisión
no se puede almacenar dentro del repositorio porque el repositorio controla su
propio contenido.

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
for dir in skills hooks rules templates scripts output-styles agent-tools; do
  rsync -a --delete \
    --exclude='__pycache__' \
    --exclude='.DS_Store' \
    --exclude='node_modules' \
    --exclude='*.test.sh' \
    --exclude='*.backup.*' \
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

> `rsync --delete` se usa sólo dentro de las carpetas gestionadas. Excluye
> `node_modules` y backups `*.backup.*`; así, si eliminás una skill del
> repositorio, desaparece del destino sin borrar dependencias locales ni la
> ruta de rollback. El `--exclude='*.test.sh'` queda como defensa en
> profundidad: todas las suites de este repo viven versionadas en
> `.github/test/` (fuera de estas carpetas gestionadas), así que hoy no hay
> ningún `*.test.sh` real que excluir.

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
- Haiku para tareas livianas y background, cuando Claude Code lo selecciona;
- autocompact en `1000000` tokens (limitado por el contexto real del modelo activo);
- permisos, hooks y MCP definidos en el archivo principal.

## Proveedores alternativos

Todos son opcionales. Cada proveedor tiene su propio settings y su propio
helper de autenticación:

| Proveedor | Overlay | Endpoint | Fable / Opus | Sonnet | Haiku / background |
| --- | --- | --- | --- | --- | --- |
| DeepSeek | `deepseek.settings.json` | `api.deepseek.com/anthropic` | `deepseek-v4-pro[1m]` | `deepseek-v4-flash[1m]` | `deepseek-v4-flash` |
| Ollama Cloud (API directa) | `ollama.settings.json` | `ollama.com` | `minimax-m3:cloud` | `gemma4:31b-cloud` | `gpt-oss:120b-cloud` |
| OpenRouter | `openrouter.settings.json` | `openrouter.ai/api` | `openai/gpt-5.6-luna-pro[1m]` (Fable) / `qwen/qwen3.8-flash[1m]` (Opus) | `z-ai/glm-5.3-flash[1m]` | `openrouter/free` |

Los modelos de la tabla son **las elecciones de esta configuración**, no
defaults universales. La disponibilidad, los precios y los límites de cada
proveedor pueden cambiar. OpenRouter además declara
`ANTHROPIC_DEFAULT_FABLE_MODEL` para la cuarta clase de modelos de Claude Code;
este overlay la ordena por calidad ascendente sobre el mismo Sonnet base
(`z-ai/glm-5.3-flash[1m]`): Opus usa `qwen/qwen3.8-flash[1m]` y Fable `openai/gpt-5.6-luna-pro[1m]`, excluyendo deliberadamente al vendor que
ya tiene overlay propio en esta tabla (DeepSeek).
No hay rotación automática de modelo por tier en Claude Code —
`ANTHROPIC_DEFAULT_OPUS_MODEL` admite un solo string en el schema oficial—,
así que para alternar puntualmente a otro modelo dentro de un tier se usa
el flag `--model` por sesión, por ejemplo `claude --openrouter --model
qwen/qwen3.8-flash` o `claude --deepseek --model deepseek-v4-pro`. Todos los modelos de este overlay con sufijo `[1m]` declaran ventana de 1M y respetan el `CLAUDE_CODE_AUTO_COMPACT_WINDOW` de
`1048576`; verificar límites reales por proveedor antes de sesiones largas con Fable, que es de uso poco frecuente en esta configuración.

Claude Code actual incorpora Fable 5 como una clase de modelo separada. Todos
los overlays declaran explícitamente `ANTHROPIC_DEFAULT_FABLE_MODEL` para que
`/model fable` no envíe por accidente un ID `claude-*` al provider alternativo.
El mapping sólo garantiza selección de un modelo fuerte del provider; no afirma
equivalencia de capacidad con Claude Fable 5.

OpenRouter documenta el endpoint Anthropic-compatible, el bearer token, el
gateway model discovery y el mapeo de roles; también advierte que Claude Code
sólo está garantizado con el provider Anthropic first-party. En este overlay,
los IDs de DeepSeek/OpenAI/free son una elección explícita de OpenRouter y
quedan en categoría **best effort**, no en garantía de paridad total con Claude.

Ollama usa el endpoint Anthropic-compatible directo de `https://ollama.com` y
un API key resuelto por `ollama-api-key.sh`; no requiere el daemon local. Los
IDs con sufijo `:cloud` se validan contra la biblioteca viva de Ollama y con
inferencia real. Si preferís el bridge local, la integración oficial usa
`http://localhost:11434`, `ANTHROPIC_AUTH_TOKEN=ollama` y un Ollama instalado,
iniciado y autenticado.

### Activación

Sin nada extra, `claude` a secas usa Anthropic y cada overlay se activa por
sesión con `--settings`:

```bash
claude --settings ~/.claude/deepseek.settings.json
claude --settings ~/.claude/openrouter.settings.json
```

El resto de los overlays se activa de la misma forma cambiando el nombre del
archivo.

### Atajos opcionales en el shell (receta)

Si preferís banderas cortas (`claude --deepseek`), pegá este bloque en tu
`.zshrc`. Es opcional y no forma parte de la instalación por defecto:
`claude` sin bandera sigue llamando al binario real con
`command claude "$@"`.

<!-- claude-wrapper:start -->
```zsh
# claude --deepseek -> settings separado con opusplan mapeado a DeepSeek.
# claude a secas queda igual que siempre (Anthropic).
# Ejecuta claude con el overlay de un provider alternativo. provider_env y
# args llegan por scoping dinamico de zsh (locals del caller claude()).
_claude_run_provider() {
  local file="$1" label="$2" settings claude_bin
  settings="$HOME/.claude/$file"
  claude_bin="${commands[claude]:-}"
  if [[ ! -r "$settings" ]]; then
    print -u2 "claude: no se encontro el settings de $label: $settings"
    return 1
  fi
  if [[ -z "$claude_bin" ]]; then
    print -u2 "claude: binario de Claude Code no encontrado"
    return 1
  fi
  # Aislar el overlay: las variables exportadas por otro provider no deben
  # ganar sobre el settings seleccionado.
  env "${provider_env[@]}" \
    "$claude_bin" \
    --settings "$settings" \
    "${args[@]}"
}

claude() {
  local -a args=()
  local -a provider_env=(
    -u ANTHROPIC_API_KEY
    -u ANTHROPIC_AUTH_TOKEN
    -u ANTHROPIC_BASE_URL
    -u ANTHROPIC_MODEL
    -u ANTHROPIC_DEFAULT_OPUS_MODEL
    -u ANTHROPIC_DEFAULT_SONNET_MODEL
    -u ANTHROPIC_DEFAULT_HAIKU_MODEL
    -u ANTHROPIC_DEFAULT_FABLE_MODEL
    -u CLAUDE_CODE_SUBAGENT_MODEL
    -u CLAUDE_CODE_AUTO_COMPACT_WINDOW
    -u CLAUDE_CODE_MAX_CONTEXT_TOKENS
    -u CLAUDE_CODE_EFFORT_LEVEL
    -u CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY
    -u CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS
    -u CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
    -u ENABLE_TOOL_SEARCH
    -u API_TIMEOUT_MS
  )
  local provider='' a
  local provider_count=0
  for a in "$@"; do
    case "$a" in
      --deepseek)   provider=deepseek;   provider_count=$((provider_count + 1)) ;;
      --openrouter) provider=openrouter; provider_count=$((provider_count + 1)) ;;
      --ollama)     provider=ollama;     provider_count=$((provider_count + 1)) ;;
      *)            args+=("$a") ;;
    esac
  done
  if (( provider_count > 1 )); then
    print -u2 'claude: selecciona un solo provider por invocacion'
    return 2
  fi
  case "$provider" in
    deepseek)   _claude_run_provider deepseek.settings.json DeepSeek ;;
    openrouter) _claude_run_provider openrouter.settings.json OpenRouter ;;
    ollama)     _claude_run_provider ollama.settings.json Ollama ;;
    *)          command claude "$@" ;;
  esac
}
```
<!-- claude-wrapper:end -->

Este bloque está cubierto por `.github/test.sh`, que lo extrae de este README
y verifica el aislamiento de variables, el ruteo de un overlay y el rechazo
de banderas ambiguas: la receta documentada es la receta probada.

Para sumar otro proveedor, alcanzan dos líneas siguiendo el mismo
patrón, porque `_claude_run_provider` ya resuelve settings, binario y
aislamiento:

```zsh
--acme) provider=acme; provider_count=$((provider_count + 1)) ;;
acme)   _claude_run_provider acme.settings.json ACME ;;
```

### Proveedores retirados (recetas)

Estos overlays existieron en este repositorio y se purgaron: kimi, minimax y
qwen en `56a0b68`, GLM después. Cada uno se reactiva igual: restaurar su
overlay y su helper desde el historial, crear su archivo de clave (`0600`) y
sumar sus dos líneas al bloque de arriba. Los modelos son los vigentes al
momento del purge; verificar antes de usar.

| Proveedor | Flag | Overlay y helper (restaurar del historial) | Clave |
| --- | --- | --- | --- |
| GLM (Z.AI) | `--glm` | `git show 93d15cf:config/claude/glm.settings.json`, `git show 93d15cf:config/claude/scripts/glm-api-key.sh` | `~/.config/claude/glm.key` |
| Kimi / Moonshot | `--kimi` | `git show b0563fa^:config/claude/kimi.settings.json`, `git show b0563fa^:config/claude/scripts/kimi-api-key.sh` | `~/.config/claude/kimi.key` (`KIMI_API_KEY_FILE`) |
| MiniMax | `--minimax` | `git show b0563fa^:config/claude/minimax.settings.json`, `git show b0563fa^:config/claude/scripts/minimax-api-key.sh` | `~/.config/claude/minimax.key` (`MINIMAX_API_KEY_FILE`) |
| QwenCloud Token Plan | `--qwen` | `git show b0563fa^:config/claude/qwen.settings.json`, `git show b0563fa^:config/claude/scripts/qwen-api-key.sh` | `~/.config/claude/qwen.key` (`QWEN_API_KEY_FILE`) |

Ejemplo con Kimi (los demás son análogos cambiando el nombre):

```bash
git show b0563fa^:config/claude/kimi.settings.json > ~/.claude/kimi.settings.json
git show b0563fa^:config/claude/scripts/kimi-api-key.sh > ~/.claude/scripts/kimi-api-key.sh
chmod +x ~/.claude/scripts/kimi-api-key.sh
```

```zsh
--kimi) provider=kimi; provider_count=$((provider_count + 1)) ;;
kimi)   _claude_run_provider kimi.settings.json Kimi ;;
```

Endpoints y modelos al momento del purge: Kimi `api.moonshot.ai/anthropic`
(`kimi-k3[1m]` / `kimi-k2.6` / `kimi-k2.5`), MiniMax `api.minimax.io/anthropic`
(`MiniMax-M3[1m]` / `MiniMax-M3`), QwenCloud
`token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic`
(`qwen3.8-max[1m]` / `qwen3.7-max[1m]` / `qwen3.6-flash`).


### API keys

Las claves nunca forman parte del repositorio. Los helpers de los proveedores
HTTP buscan estos archivos locales, todos con permisos `0600`:

| Proveedor | Archivo |
| --- | --- |
| DeepSeek | `~/.config/claude/deepseek.key` |
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

Los nombres de las variables disponibles son `DEEPSEEK_API_KEY_FILE` y
`OPENROUTER_API_KEY_FILE`.

Claude Code ejecuta cada `apiKeyHelper` sólo en la CLI de terminal y envía su
salida como `X-Api-Key` y `Authorization: Bearer`. Eso permite mantener las
claves fuera del JSON y cubrir providers que esperan uno u otro encabezado;
el wrapper opcional de la receta además limpia las variables exportadas de
otro provider antes de cargar el overlay elegido.

Si falta una clave, Claude Code normal sigue funcionando; sólo falla el
proveedor cuyo helper no puede leer su archivo.

Ollama es la excepción: el overlay fija `ANTHROPIC_AUTH_TOKEN=ollama` (valor
requerido pero ignorado por Ollama), y la autenticación de los modelos cloud la
resuelve la sesión local de Ollama.

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
bash "$CLAUDE_DIR/../../.github/validate.sh"
```

La validación comprueba la estructura de la configuración, los manifiestos y
las dependencias declaradas. No forma parte del runtime instalado, no prueba
credenciales ni garantiza que un proveedor externo responda. Para una auditoría
read-only del entorno efectivo de Claude, Herdr, Engram y MCP:

```bash
bash "$CLAUDE_DIR/../../.github/test/doctor.sh"
```

Las suites, smoke tests, paridad y el doctor viven en `.github/test/` de forma
intencional: prueban la configuración, pero Claude no los carga como runtime.

## Principios de esta configuración

- **Presupuesto, no balde.** `CLAUDE.md`, `rules/`, las descripciones de skills y
  lo que inyecten los hooks se pagan en tokens en cada turno de cada sesión. Todo
  lo que se agregue ahí compite por atención con lo que ya está. Antes de sumar
  una regla: ¿el modelo ya lo hace solo? ¿lo puede descubrir leyendo el repo? Si
  la respuesta es sí, no va.
- **Los hooks no le hablan al usuario en cada turno.** Un hook de
  `UserPromptSubmit` que inyecta contexto en cada prompt, o uno de `Stop` que
  avisa algo siempre, se vuelve invisible y de paso gasta la ventana. Los hooks
  de esta config o bloquean algo concreto (secrets, operaciones destructivas,
  gate de commit) o se callan.
- **Nada de burocracia de proceso auto-activada.** Los roadmaps, recibos y gates
  de convergencia que se encendían solos se sacaron: armaban un contrato que el
  usuario no pidió y que después había que destrabar. Lo que quede opt-in se
  enciende a mano.
- Mantener `opusplan` y el flujo nativo de Claude Code, sin commands que
  sombreen `/plan`.
- Separar los overlays de proveedores del settings principal.
- No guardar secretos en Git, `settings.json` ni `.zshrc`.
- Proteger secretos y operaciones de red: `deny` para archivos sensibles y
  `ask` para installs y push. Fallar explícitamente si falta una clave.
- Mantener la configuración portable: lo específico de macOS o del shell vive
  fuera de esta carpeta.
