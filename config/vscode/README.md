# VS Code Config

Configuracion optimizada para desarrollo full-stack (Laravel + React + TypeScript).

## Estructura

```
config/vscode/
├── settings.json        # Preferencias del editor
├── keybindings.json     # Atajos de teclado personalizados
├── mcp.json             # MCP servers para VS Code
├── extensions.json      # Extensiones recomendadas por categoria
└── README.md            # Este archivo
```

## MCP Servers

`mcp.json` configura servidores MCP para VS Code:

| Server | Proposito |
|---|---|
| `context7` | Documentacion actualizada de librerias (MCP HTTP hospedado) |
| `engram` | Memoria persistente entre sesiones (requiere instalacion: `brew install engram`) |
| `codegraph` | Exploracion del codigo local mediante el servidor MCP de CodeGraph |
| `playwright` | Automatizacion y pruebas de navegador mediante Playwright MCP |

## Keybindings

| Atajo | Accion |
|---|---|
| `shift shift` | Toggle sidebar |
| `cmd+alt+s` | Guardar sin formatear |

## Filosofia

- **Curado > masivo**. Extensiones esenciales, no coleccion de 50+.
- **Universal**. Sin paths hardcodeados a usuarios especificos.
- **Categorizado**. Core vs opcional por stack.
