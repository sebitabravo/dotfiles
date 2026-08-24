# Claude Code

Configuración personal de Claude Code con `opusplan`, agentes, skills, reglas,
hooks, MCP y overlays opcionales para proveedores compatibles con la API de
Anthropic.

Esta carpeta se puede copiar de forma independiente. Los proveedores y las
claves son opcionales: Claude Code normal funciona sin ellos.

## Qué contiene

| Ruta | Propósito |
| --- | --- |
| `settings.json` | Configuración principal, permisos, hooks, MCP y `opusplan`. |
| `CLAUDE.md` | Instrucciones globales para Claude Code. |
| `agents/` | Agentes especializados. |
| `skills/` | Skills reutilizables y workflows. |
| `rules/` | Reglas de estilo, seguridad, testing y operaciones. |
| `hooks/` | Validaciones y automatizaciones de ciclo de vida. |
| `templates/` | Plantillas para SDD y documentación. |
| `output-styles/` | Estilos de respuesta. |
| `scripts/` | Helpers de runtime: convergencia, RDD, autenticación y roadmap. |
| `agent-tools/` | Manifest de herramientas Python/Node/Rust sin runtimes duplicados. |
| `statusline.sh` | Statusline personalizada. |
| `mcp-servers.json` | Servidores MCP declarados por esta configuración. |
| `*.settings.json` | Overlays independientes para proveedores alternativos. |

Los overlays no se inyectan dentro de `settings.json`. Cada uno es un archivo
separado que se activa con `--settings`.

La carpeta contiene sólo fuentes que el runtime puede usar. Que un archivo
contenga la palabra `test` o `validate` no lo vuelve automáticamente una suite:
`hooks/lib/test-runner.sh` es una librería runtime consumida por varios Stop
hooks, `scripts/validate-task-roadmap.py` valida roadmaps durante el flujo
automático y los validadores dentro de una skill implementan capacidades de esa
skill. Las auditorías del repositorio, smoke tests, paridad, comparación de
roadmaps, dependencias y el doctor viven fuera de esta carpeta, en
`.github/test/`, y no se instalan en `~/.claude`.

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
for dir in agents skills hooks rules templates scripts output-styles agent-tools; do
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
  glm.settings.json \
  kimi.settings.json \
  minimax.settings.json \
  ollama.settings.json \
  openrouter.settings.json \
  qwen.settings.json; do
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
| GLM / Z.AI | `glm.settings.json` | `api.z.ai/api/anthropic` | `glm-5.3[1m]` | `glm-5.2[1m]` | `glm-4.7` |
| Kimi / Moonshot | `kimi.settings.json` | `api.moonshot.ai/anthropic` | `kimi-k3[1m]` | `kimi-k2.6` | `kimi-k2.5` |
| MiniMax | `minimax.settings.json` | `api.minimax.io/anthropic` | `MiniMax-M3[1m]` | `MiniMax-M3[1m]` | `MiniMax-M3` |
| Ollama Cloud (API directa) | `ollama.settings.json` | `ollama.com` | `minimax-m3:cloud` | `gemma4:31b-cloud` | `gpt-oss:120b-cloud` |
| OpenRouter | `openrouter.settings.json` | `openrouter.ai/api` | `deepseek/deepseek-v4-pro` | `openai/gpt-5.6-luna` | `openrouter/free` |
| QwenCloud Token Plan | `qwen.settings.json` | `token-plan.ap-southeast-1.maas.aliyuncs.com/apps/anthropic` | `qwen3.8-max[1m]` | `qwen3.7-max[1m]` | `qwen3.6-flash` |

Los modelos de la tabla son **las elecciones de esta configuración**, no
defaults universales. La disponibilidad, los precios y los límites de cada
proveedor pueden cambiar. En particular, la guía vigente de Coding Plan de
Z.AI recomienda `glm-5.3[1m]` para el endpoint directo; un ID de GLM
disponible en OpenRouter no se puede trasladar automáticamente al endpoint
directo de Z.AI. OpenRouter además declara
`ANTHROPIC_DEFAULT_FABLE_MODEL` para la cuarta clase de modelos de Claude Code;
este overlay la mapea al mismo DeepSeek Pro que usa para Opus.

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

La guía dedicada de Claude Code de MiniMax para su endpoint internacional
actual recomienda `MiniMax-M3[1m]` y autocompact en `1000000`. La documentación
genérica de la API Anthropic todavía muestra M2.7/204800, por lo que no se deben
mezclar ambas variantes: este overlay sigue la guía dedicada de Claude Code.

### Activación

Si también copiaste el wrapper de `.zshrc`, podés usar los comandos cortos:

```bash
claude --deepseek
claude --glm
claude --kimi
claude --minimax
claude --ollama
claude --openrouter
claude --qwen
```

El wrapper de `.zshrc` **no está dentro de `config/claude/`**. Si copiás sólo
esta carpeta, usá directamente el overlay que necesités:

```bash
claude --settings ~/.claude/deepseek.settings.json
claude --settings ~/.claude/openrouter.settings.json
claude --settings ~/.claude/qwen.settings.json
```

El resto de los overlays se activa de la misma forma cambiando el nombre del
archivo.

### Preflight de integraciones del proyecto

`hooks/project-integrations-check.sh` corre en `SessionStart` y
`UserPromptSubmit`, es de solo lectura, y reporta (nunca aplica) el estado de
CodeGraph, OpenSpec, el puente AGENTS.md/CLAUDE.md y, desde esta versión,
la higiene del repo en GitHub: la rama por defecto protegida contra
force-push y borrado, al menos un status check obligatorio antes de mergear,
y `delete_branch_on_merge` activado.

Solo la higiene de GitHub es owner-only: en `SessionStart`, primero confirma
que `gh api repos/<owner>/<repo>` devuelve `permissions.admin == true` para la
sesión autenticada en esta máquina. Si no hay remoto válido de GitHub, `gh`,
autenticación o permisos admin, la protección de ramas queda en
`NOT_APPLICABLE` y nunca se consulta. CodeGraph, OpenSpec, el puente
AGENTS.md/CLAUDE.md y el scan de scopes son chequeos locales de solo lectura
sin relación con quién es dueño del repo en GitHub, y corren siempre, sin
gating: condicionarlos a ser admin los desactivaría en cualquier remoto que no
sea GitHub (GitLab, un repo sin remoto) y en cualquier repo de GitHub sin
sesión de `gh`, que sería una regresión.

`UserPromptSubmit` no hace llamadas de red: solo reutiliza un snapshot temporal
atado al root Git, al remoto/repositorio y al `session_id` actual después de un
`SessionStart` que confirmó ownership. Si falta ese snapshot o cambió el
remoto, sale silenciosamente. La protección de GitHub se consulta únicamente
en `SessionStart`; como todo lo demás en este hook, no corrige nada por sí
sola: reporta el gap exacto y el comando `gh api` para corregirlo, y aplicar
eso sigue siendo una acción explícita y autorizada aparte.

### One-shot automático y convergencia

Para una tarea accionable no necesitás invocar `/plan`, OpenSpec ni los gates a
mano. El hook `UserPromptSubmit` clasifica el prompt, crea estado temporal por
sesión e inyecta el flujo: preflight, roadmap, descomposición con dependencias,
implementación, tests, aceptación y ciclo `verify -> diagnose -> apply`. Las
preguntas conversacionales no activan ese estado.

Los cambios pequeños usan un roadmap local `TASK-ROADMAP.md` en la raíz; los
complejos, multiarchivo o arquitectónicos usan OpenSpec como fuente de verdad.
No se usa `.claude/task-roadmap.md` por defecto porque Claude Code puede tratar
`.claude/` como configuración sensible y bloquear su escritura no interactiva;
los proyectos existentes que ya tienen ese archivo siguen siendo compatibles.
Antes de crear uno, el agente debe buscar `TASK-ROADMAP.md`, `task-roadmap.md` y
`.claude/task-roadmap.md`: si existe uno, lo reutiliza; si existen varios, debe
consolidarlos y el Stop hook bloquea hasta que quede una sola fuente.
En roadmaps directos, las tareas que comparten una frontera paralela deben
declarar `[paths: ...]` con rutas relativas concretas; `paths: none`, globs y
traversal (`.`/`..`) no prueban ownership. El validador bloquea ownership
ausente, ambiguo o solapado.
El hook no ejecuta texto del prompt, tasks ni receipts. El Stop hook exige
roadmap completo, receipt `STATUS: PASS`, `ACCEPTANCE: PASS`, `VERIFY_EXIT: 0`,
`git diff --check` y un runner nativo fresco para declarar convergencia. Si algo
falla, la sesión sigue en iteración; si falta una decisión, permiso o
integración externa, se reporta `STATUS: BLOCKED`, `ACCEPTANCE: PENDING`, un
`VERIFY_EXIT` numérico y evidencia. Ese estado conserva la sesión activa sin
simular PASS; no se debe usar para trabajo simplemente incompleto o subagentes
que todavía no entregan sus reportes.

El overlay de Qwen usa el endpoint Anthropic-compatible de **QwenCloud Token
Plan Personal/Team**. Declara `qwen3.8-max[1m]` para Fable/Opus,
`qwen3.7-max[1m]` para Sonnet, `qwen3.6-flash` para Haiku/background y un
autocompact de `983616` tokens. El sufijo `[1m]` es metadata de Claude Code y se
elimina antes de enviar el ID de producción al provider; no es parte del ID de
Qwen. Para seleccionar explícitamente el modelo principal:

```bash
claude --qwen --model qwen3.8-max
```

La clave de `~/.config/claude/qwen.key` debe ser la clave dedicada del Token
Plan (`sk-sp-...`). No la mezcles con una clave general de Pay-as-you-go ni
con el endpoint de Coding Plan. Coding Plan usa por separado
`https://coding-intl.dashscope.aliyuncs.com/apps/anthropic`; Pay-as-you-go usa
`https://dashscope-intl.aliyuncs.com/apps/anthropic`.

### Gate de convergencia real

La política escrita no basta para obligar al agente a continuar. Para una
implementación OpenSpec, después de aprobar la propuesta y antes de aplicar:

```bash
~/.claude/scripts/convergence-start.sh <change-name>
```

El hook `UserPromptSubmit` de OpenSpec lo activa automáticamente cuando el
prompt es `/opsx:apply <change-name>` (o hay un único change activo); el script
es la forma explícita y reproducible de hacerlo. Crea el marcador local
`.claude/convergence.active` y un receipt final pendiente. Mientras el marcador exista, el Stop hook bloquea con exit 2
si quedan tasks/artifacts, falla `openspec validate`, falta el receipt PASS,
falla `git diff --check` o la suite nativa del proyecto. El hook no ejecuta
texto arbitrario de `VERIFY`; detecta el runner versionado del proyecto y lo
corre fresco. Para objetivos fuera de OpenSpec, el flujo automático usa un
roadmap local y la misma condición de aceptación observable.

La fuente y el runtime se auditan por separado. Antes de afirmar que el gate
está activo en Claude Code, ejecutá desde este repositorio:

```bash
.github/test/check-runtime-parity.sh --json
.github/test/check-runtime-parity.sh --strict
.github/test/check-provider-runtime-parity.sh --json
.github/test/check-provider-runtime-parity.sh --strict
```

El auditor es de solo lectura y compara los archivos/hooks de convergencia,
one-shot y el skill orquestador; no borra ni sincroniza `~/.claude`. Un `MISSING` o `DRIFT` en
`--strict` significa que la fuente está preparada pero la sesión efectiva aún
no está protegida.

La auditoría de providers es independiente: compara semánticamente los siete
overlays JSON. Ignora formato/orden de claves y considera equivalentes el alias
`opus` y el `ANTHROPIC_DEFAULT_OPUS_MODEL` declarado en ese mismo overlay; no
ignora otros overrides. Tampoco prueba autenticación, endpoint vivo ni
inferencia con tools.

Si se autoriza activar únicamente este gate, sin desplegar el resto de los
dotfiles, el instalador acotado es:

```bash
config/claude/scripts/sync-convergence-runtime.sh --dry-run
config/claude/scripts/sync-convergence-runtime.sh --apply
```

`--apply` crea backups, instala los archivos críticos del harness y el skill
orquestador, fusiona los cuatro hooks en el `settings.json` existente y
preserva archivos/hooks runtime-only; no hace `rsync --delete` ni modifica
OpenSpec, providers o `.gitignore`.

Después de modificar la fuente o antes de una sesión autenticada, podés
verificar el motor real de hooks sin tocar tu runtime ni consumir inferencia:

```bash
bash .github/test/smoke-claude-hook-engine.sh
```

El smoke usa un `HOME` temporal, sincroniza allí el harness, ejecuta
`claude --init-only` y comprueba `SessionStart`/`compact-resume`. No sustituye
el smoke conversacional de `UserPromptSubmit`, Task tools y `Stop`.

Para verificar el contrato completo sin consumir inferencia, ejecutá además:

```bash
bash .github/test/smoke-automatic-workflow.sh
```

Ese smoke simula `UserPromptSubmit`, una sesión incompleta que Stop debe
bloquear, `TaskCreated`/`TaskCompleted` con receipts y el `Stop` final. Usa un
repo y estado temporales; no toca `~/.claude`.

Referencias: [Installation](https://openspec.dev/docs/installation),
[How Commands Work](https://openspec.dev/docs/how-commands-work) y
[CLI Reference](https://openspec.dev/docs/reference/cli).

### API keys

Las claves nunca forman parte del repositorio. Los helpers de los proveedores
HTTP buscan estos archivos locales, todos con permisos `0600`:

| Proveedor | Archivo |
| --- | --- |
| DeepSeek | `~/.config/claude/deepseek.key` |
| GLM / Z.AI | `~/.config/claude/glm.key` |
| Kimi / Moonshot | `~/.config/claude/kimi.key` |
| MiniMax | `~/.config/claude/minimax.key` |
| OpenRouter | `~/.config/claude/openrouter.key` |
| QwenCloud Token Plan | `~/.config/claude/qwen.key` (`sk-sp-...`) |

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
`OPENROUTER_API_KEY_FILE` y `QWEN_API_KEY_FILE`.

Claude Code ejecuta cada `apiKeyHelper` sólo en la CLI de terminal y envía su
salida como `X-Api-Key` y `Authorization: Bearer`. Eso permite mantener las
claves fuera del JSON y cubrir providers que esperan uno u otro encabezado;
el wrapper además limpia las variables exportadas de otro provider antes de
cargar el overlay elegido.

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

- Mantener `opusplan` y el flujo nativo de Claude Code, sin commands que
  sombreen `/plan`.
- Separar los overlays de proveedores del settings principal.
- No guardar secretos en Git, `settings.json` ni `.zshrc`.
- Proteger secretos y operaciones de red: `deny` para archivos sensibles y
  `ask` para installs y push. Fallar explícitamente si falta una clave.
- Mantener la configuración portable: lo específico de macOS o del shell vive
  fuera de esta carpeta.
