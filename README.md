# Sebita Dotfiles

Configuración personal para **macOS Apple Silicon**. Instala copias independientes
de shell, Git, Ghostty, Fastfetch, VS Code y Claude Code; no crea symlinks hacia el repo.

## Antes de instalar

1. `./install.sh` ejecuta el bootstrap completo: instala o verifica Apple
   Command Line Tools y [Homebrew](https://brew.sh/) en `/opt/homebrew`, luego
   instala las herramientas de shell/agentes y despliega los dotfiles. Revisalo
   primero sin cambios:

   ```bash
   ./install.sh --dry-run
   ./install.sh
   ```

   Si macOS abre el instalador de Command Line Tools, completá la aprobación
   gráfica y volvé a ejecutar `./install.sh`.
2. Instalá las dependencias del `Brewfile`:

   ```bash
   brew bundle --file=Brewfile
   ```

3. Completá las aplicaciones y herramientas manuales de
   [`docs/MANUAL_INSTALL.md`](docs/MANUAL_INSTALL.md). El prompt de shell usa
   Oh My Zsh + Powerlevel10k y el Node por defecto administrado por Laravel Herd.

## Instalación

```bash
git clone https://github.com/sebitabravo/dotfiles.git
cd dotfiles
./install.sh --dry-run
./install.sh
```

`./install.sh` ejecuta siempre el bootstrap completo: primero verifica o instala
los prerrequisitos de macOS (Command Line Tools y Homebrew), después ejecuta
Oh My Zsh, Powerlevel10k, Herdr, CodeGraph y las CLIs de agentes solicitadas, y
por último despliega los dotfiles. `--dry-run` es el único flag: no descarga ni
ejecuta instaladores externos: imprime cada comando planificado. Las descargas
se hacen desde los URLs oficiales indicados por sus proveedores y apuntan a la
versión mutable más reciente; son convenientes para bootstrap personal, pero no
ofrecen una garantía de checksum ni reproducibilidad de una versión fijada.

El instalador respalda archivos raíz reemplazados como
`<archivo>.backup.<timestamp>` y toma snapshots de los directorios que cambiarán
en `~/.dotfiles-backups/<timestamp>/`. No modifica `~/.gitconfig.local`,
credenciales, tokens ni estado local fuera de los directorios administrados.

Después configurá tu identidad Git fuera del repo:

```bash
git config --file ~/.gitconfig.local user.name "Tu Nombre"
git config --file ~/.gitconfig.local user.email "tu@email"
```

## Qué administra `install.sh`

- `.zshenv`, `.zprofile`, `.zshrc` y `.p10k.zsh`.
- `.gitconfig`, ignore global y hooks globales.
- configuración y shaders de Ghostty.
- configuración de Herdr en `~/.config/herdr/config.toml`; conserva su estado
  local y no instala integraciones de agentes.
- configuración y logo de Fastfetch.
- settings, keybindings y MCP de VS Code.
- runtime administrado de Claude Code: agentes, skills, hooks, reglas, scripts de
  runtime,
  templates, settings y overlays de providers.

## Qué queda manual

- Paquetes y aplicaciones del `Brewfile`, apps, fuentes, extensiones de VS Code y
  autenticación de CLIs. El bootstrap no autentica ninguna CLI ni configura
  integraciones de Herdr; sólo instala/verifica prerrequisitos y ejecuta los
  instaladores de shell/agentes.
- `config/macos/defaults.sh`: cambia preferencias reales y reinicia servicios;
  revisalo primero con `./defaults.sh --dry-run --no-sudo` (desde `config/macos/`)
  y auditá el resultado con `.github/verify.sh` (desde la raíz del repo). No lo
  aplica el instalador.
- `config/openlogi/config.toml`: es una plantilla con el identificador del mouse
  redactado. OpenLogi genera el identificador real al parear el dispositivo; el
  instalador no debe copiar el placeholder.
- API keys y tokens. Los overlays de Claude usan helpers externos y no incluyen
  secretos en el repo.

La documentación específica de Claude está en
[`config/claude/README.md`](config/claude/README.md).
