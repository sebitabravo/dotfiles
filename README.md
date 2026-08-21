# Sebita Dotfiles

Configuración personal para **macOS Apple Silicon**. Instala copias independientes
de shell, Git, Ghostty, VS Code y Claude Code; no crea symlinks hacia el repo.

## Antes de instalar

1. Instalá [Homebrew](https://brew.sh/) en `/opt/homebrew`.
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

El instalador respalda archivos raíz reemplazados como
`<archivo>.backup.<timestamp>` y toma snapshots de los directorios que cambiarán
en `~/.dotfiles-backups/<timestamp>/`. No modifica `~/.gitconfig.local`,
credenciales, tokens ni estado local fuera de los directorios administrados.

Después configurá tu identidad Git fuera del repo:

```bash
git config --file ~/.gitconfig.local user.name "Tu Nombre"
git config --file ~/.gitconfig.local user.email "tu@email"
```

## Verificación

```bash
bash config/claude/scripts/validate.sh
bash config/claude/scripts/check-runtime-parity.sh --strict
bash config/claude/scripts/check-provider-runtime-parity.sh --strict
ghostty +validate-config --config-file="$HOME/.config/ghostty/config.ghostty"
brew bundle check --no-upgrade --file=Brewfile
```

`validate.sh` informa las suites locales ausentes como `skipped`; no las convierte
en PASS. La validez de los JSON y hooks tampoco prueba credenciales, cuota ni
inferencia de un provider externo.

## Qué administra `install.sh`

- `.zshenv`, `.zprofile`, `.zshrc` y `.p10k.zsh`.
- `.gitconfig`, ignore global y hooks globales.
- configuración y shaders de Ghostty.
- settings, keybindings y MCP de VS Code.
- runtime administrado de Claude Code: agentes, skills, hooks, reglas, scripts,
  templates, settings y overlays de providers.

## Qué queda manual

- Apps, fuentes, extensiones de VS Code y autenticación de CLIs.
- `config/macos/defaults.sh`: cambia preferencias reales y reinicia servicios;
  revisalo primero con `./defaults.sh --dry-run --no-sudo` y auditá el resultado
  con `./verify.sh`. No lo aplica el instalador.
- `config/openlogi/config.toml`: es una plantilla con el identificador del mouse
  redactado. OpenLogi genera el identificador real al parear el dispositivo; el
  instalador no debe copiar el placeholder.
- API keys y tokens. Los overlays de Claude usan helpers externos y no incluyen
  secretos en el repo.

La documentación específica de Claude está en
[`config/claude/README.md`](config/claude/README.md).
