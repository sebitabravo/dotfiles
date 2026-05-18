# Gemini CLI Config

Configuracion optimizada de Gemini CLI con MCP servers, hooks, sandbox policies, y sistema de memoria persistente. Diseñada para maxima productividad con minima context window bloat.

## Estructura

```
config/gemini/
├── GEMINI.md                    # Instrucciones globales (senior architect mode)
├── settings.json                # Hooks, MCPs, modelo, tools, UI
├── system.md                    # Protocolo de memoria Engram (system prompt)
├── .env                         # Variables de entorno (ENGRAM_DATA_DIR)
├── README.md                    # Este archivo
└── policies/
    ├── auto-saved.toml          # Reglas auto-guardadas (pytest en yolo)
    └── sandbox.toml             # Modos sandbox + comandos permitidos
```

## Instalacion rapida

```bash
# 1. Archivos core
ln -sf ~/Developer/dotfiles/config/gemini/settings.json ~/.gemini/settings.json
ln -sf ~/Developer/dotfiles/config/gemini/GEMINI.md ~/.gemini/GEMINI.md
ln -sf ~/Developer/dotfiles/config/gemini/system.md ~/.gemini/system.md
cp -n ~/Developer/dotfiles/config/gemini/.env ~/.gemini/.env

# 2. Policies
mkdir -p ~/.gemini/policies
ln -sf ~/Developer/dotfiles/config/gemini/policies/auto-saved.toml ~/.gemini/policies/auto-saved.toml
ln -sf ~/Developer/dotfiles/config/gemini/policies/sandbox.toml ~/.gemini/policies/sandbox.toml
```

O en una linea:

```bash
ln -sf ~/Developer/dotfiles/config/gemini/settings.json ~/.gemini/ && ln -sf ~/Developer/dotfiles/config/gemini/GEMINI.md ~/.gemini/ && ln -sf ~/Developer/dotfiles/config/gemini/system.md ~/.gemini/ && cp -n ~/Developer/dotfiles/config/gemini/.env ~/.gemini/ && mkdir -p ~/.gemini/policies && ln -sf ~/Developer/dotfiles/config/gemini/policies/auto-saved.toml ~/.gemini/policies/ && ln -sf ~/Developer/dotfiles/config/gemini/policies/sandbox.toml ~/.gemini/policies/ && echo 'OK - Gemini CLI config instalada'
```

> [!IMPORTANT]
> Revisa los paths en `settings.json` y `.env`. Usan `$HOME` como placeholder. Si tu estructura de directorios difiere (ej. `~/Projects` en vez de `~/projects`), ajusta `sandboxAllowedPaths` y `allowed_paths` en `policies/sandbox.toml`.

## Extensiones recomendadas

```bash
# Caveman — compresion de comunicacion ~75%
gemini extensions install caveman

# Engram — memoria persistente entre sesiones (ya configurado en settings.json)
```

## MCP Servers

Configurados en `settings.json`:

| Server | Utilidad |
|---|---|
| `context7` | Documentacion actualizada de librerias |
| `engram` | Memoria persistente entre sesiones (requiere `brew install engram`) |

**Regla**: maximo 5-6 MCPs activos. Cada MCP tool description consume tokens de la context window. Mas MCPs = menos espacio para tu codigo.

## Hooks

Hooks desactivados por defecto (`hooksConfig.enabled: false`). Sin dependencia de superset ni herramientas externas.

Para agregar hooks personalizados, edita la seccion `hooks` en `settings.json`. Gemini CLI soporta: `BeforeAgent`, `AfterAgent`, `AfterTool`, `Notification`, `SessionStart`, `SessionEnd`, `PreCompact`, `PostCompact`.

## Sandbox Policies

`policies/sandbox.toml` define tres modos:

| Modo | Network | Readonly | Comandos |
|---|---|---|---|
| `plan` | off | si | ninguno |
| `default` | off | no | cat, ls, grep, head, tail, less |
| `accepting_edits` | off | no | sed, grep, awk, perl, cat, echo |

`policies/auto-saved.toml` permite pytest en modo yolo (sin confirmacion).

## Modelo

Default: `gemini-2.5-flash`.

Cambiar en `settings.json` → `model.name`. Opciones: `gemini-2.5-pro`, `gemini-2.5-flash`, `gemma`.

Settings clave del modelo:
- `maxSessionTurns: 100` — limite de turnos por sesion
- `compressionThreshold: 0.3` — comprime contexto al 30% de uso
- `skipNextSpeakerCheck: true` — evita esperas innecesarias entre turnos
- `summarizeToolOutput` — trunca output de shell a 2000 tokens

## UI

Configuracion de interfaz minimalista:

- `hideTips: true` — sin tips distractivos
- `compactToolOutput: true` — output de tools compacto
- `inlineThinkingMode: "off"` — sin thinking inline
- `showLineNumbers: true` — numeros de linea en codigo
- `errorVerbosity: "full"` — errores completos
- `showCitations: false` — sin citas en respuestas
- `showModelInfoInChat: false` — sin info de modelo en chat
- `loadingPhrases: "off"` — sin frases de carga

## Seguridad

- `toolSandboxing: true` — sandbox activo por defecto
- `environmentVariableRedaction: true` — redacta variables de entorno en output
- `folderTrust: true` — confirmacion de carpetas nuevas
- `enablePermanentToolApproval: true` — recordar decisiones de tool approval
- `usageStatisticsEnabled: false` — telemetria desactivada

## Filosofia

- **Curado > masivo**. 2 MCPs y 2 policies, no 18 MCPs y 47 reglas.
- **Context window first**. Cada feature compite por tokens con tu codigo.
- **Convenciones sobre configuracion**. Reglas claras en `GEMINI.md`.
- **Hooks con proposito**. Cada hook tiene una funcion concreta, no es ruido.
- **Sandbox minimalista**. Solo los comandos necesarios en cada modo.
