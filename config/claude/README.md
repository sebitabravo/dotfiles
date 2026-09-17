# Claude Code

Configuración personal de Claude Code: `opusplan`, skills, reglas, hooks y MCP.
`claude` a secas usa siempre Anthropic; ningún proveedor alternativo está activo.

## Qué contiene

| Ruta | Propósito |
| --- | --- |
| `settings.json` | Config principal: env, permisos, hooks, statusline. |
| `CLAUDE.md` | Instrucciones globales. |
| `skills/` + `skills-lock.json` + `skill-registry.md` | Skills bajo demanda; índice humano no cargado en sesión. |
| `rules/`, `hooks/`, `templates/`, `agent-tools/` | Reglas, validaciones, plantilla de proyecto, manifest de toolchains. |
| `statusline.sh`, `mcp-servers.json`, `tweakcc-theme.json` | Statusline, MCP, tema. |

Las suites y auditorías viven en `.github/test/`, fuera de esta carpeta.

## Convivencia con gentle-ai

- **gentle-ai fusiona:** bloques `<!-- gentle-ai:... -->` en `CLAUDE.md` y deep
  merge sobre `settings.json` (no afloja un `deny`).
- **Este repo reemplaza:** `CLAUDE.md` y `settings.json` enteros. `install.sh`
  corre primero y llama `gentle-ai sync --agent claude-code` al final. Invertir
  el orden borra la capa de gentle-ai.
- gentle-ai ganó donde duplicaba: RDD (`gentle-ai review`), conducta del agente
  (persona/output style), `skill-creator`, `agents/` y `commands/`.
- Este repo conserva: hooks de seguridad, gate de commit, `rules/`, permisos,
  skills de dominio, statusline, manifest MCP.

| Ruta | Dueño | `install.sh` |
| --- | --- | --- |
| `hooks/`, `rules/`, `templates/`, `scripts/`, `agent-tools/` | este repo | `rsync --delete` |
| `skills/` | compartido | aditivo, `--delete` por entrada |
| `agents/`, `commands/`, `mcp/`, `output-styles/` | gentle-ai | no se tocan |
| `CLAUDE.md`, `settings.json` | repo + capa gentle-ai | copia + `gentle-ai sync` |

Gate de commit: runners del repo solo con el root Git listado en `~/.claude/trusted-repositories`.

## Instalación

Desde la raíz del repo, `./install.sh` hace todo. Para copiar solo esta
carpeta (`CLAUDE_DIR="$PWD/config/claude"`):

```bash
mkdir -p "$HOME/.claude"
for dir in hooks rules templates agent-tools; do
  rsync -a --delete --exclude='__pycache__' --exclude='.DS_Store' \
    --exclude='node_modules' --exclude='*.test.sh' --exclude='*.backup.*' \
    "$CLAUDE_DIR/$dir/" "$HOME/.claude/$dir/"
done
for skill in "$CLAUDE_DIR"/skills/*/; do
  rsync -a --delete --exclude='__pycache__' --exclude='.DS_Store' \
    --exclude='node_modules' "$skill" "$HOME/.claude/skills/$(basename "$skill")/"
done
for file in CLAUDE.md statusline.sh mcp-servers.json skills-lock.json \
  tweakcc-theme.json skill-registry.md settings.json; do
  cp -p "$CLAUDE_DIR/$file" "$HOME/.claude/$file"
done
```

No borra `settings.local.json` ni autenticación; sí reemplaza `settings.json` completo.

## Configuración actual

- `model: "opusplan"`: Opus planifica, Sonnet ejecuta, Haiku para background.
- Límites deliberados: salida `64000`, autocompact `1024000`, esfuerzo `high`,
  `MAX_THINKING_TOKENS` `10000`. Rangos en la [doc oficial de env
  vars](https://code.claude.com/docs/en/env-vars.md).
- Permisos: Auto Mode sin `allow`/`ask`; `deny` mínimo para secretos y
  `npm install -g`.

## Proveedores retirados (recetas)

Purgados: kimi/minimax/qwen en `56a0b68`; DeepSeek/Ollama Cloud/OpenRouter en
`f3b6bcb`. Restaurar: `git show <ref>:config/claude/<prov>.settings.json >
~/.claude/<prov>.settings.json` (y el helper de `scripts/` con `chmod +x`),
crear la clave `0600` en `~/.config/claude/`, activar con `--settings`.

| Proveedor | Ref | Clave |
| --- | --- | --- |
| Kimi / MiniMax / QwenCloud | `b0563fa^` | `~/.config/claude/<prov>.key` (`<PROV>_API_KEY_FILE`) |
| DeepSeek / OpenRouter | `f3b6bcb` | ídem |
| Ollama Cloud | `f3b6bcb` | ninguna (auth vía sesión local) |

El instalador no retira overlays ya desplegados:

```bash
rm -f ~/.claude/{deepseek,ollama,openrouter}.settings.json
```

## Principios

- **Presupuesto, no balde:** todo lo que carga en cada turno compite por
  atención. Si el modelo ya lo hace solo o lo puede leer del repo, no va.
- **Los hooks o bloquean algo concreto o se callan.**
- **Nada de burocracia auto-activada;** lo opt-in se enciende a mano.
- `opusplan` y flujo nativo de Claude Code, sin commands que sombreen `/plan`.
- Sin secretos en Git ni `settings.json`; fallo explícito si falta una clave.
- Portable: lo de macOS o del shell vive fuera de esta carpeta.
