# VS Code Config

Configuracion optimizada para desarrollo full-stack (Laravel + React + TypeScript).

## Estructura

```
config/vscode/
├── settings.json        # Preferencias del editor
├── keybindings.json     # Atajos de teclado personalizados
├── mcp.json             # MCP servers para Copilot Chat
├── extensions.json      # Extensiones recomendadas por categoria
└── README.md            # Este archivo
```

## MCP Servers

`mcp.json` configura servidores MCP para Copilot Chat:

| Server | Proposito |
|---|---|
| `context7` | Documentacion actualizada de librerias (via npx) |
| `engram` | Memoria persistente entre sesiones (requiere instalacion: `brew install engram`) |

## Keybindings

| Atajo | Accion |
|---|---|
| `shift shift` | Toggle sidebar |
| `cmd+alt+s` | Guardar sin formatear |

## Filosofia

- **Curado > masivo**. Extensiones esenciales, no coleccion de 50+.
- **Universal**. Sin paths hardcodeados a usuarios especificos.
- **Categorizado**. Core vs opcional por stack.
