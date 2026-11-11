# Sebita Dotfiles

Configuración personal para **macOS Apple Silicon**. Instala copias
independientes de shell, Git, Ghostty, Fastfetch, VS Code y Claude Code; no
crea symlinks hacia el repo.

## Instalación

```bash
git clone https://github.com/sebitabravo/dotfiles.git
cd dotfiles
./install.sh --dry-run
./install.sh
```

`./install.sh` ejecuta el bootstrap completo: Command Line Tools y Homebrew,
dependencias del `Brewfile`, herramientas de shell/agentes (Oh My Zsh,
Powerlevel10k, Herdr, CodeGraph, CLIs solicitadas) y despliegue de dotfiles.
Al final aplica `config/macos/defaults.sh --no-sudo`, que reinicia Dock y
Finder. Solo corre con el HOME real de la cuenta; `DOTFILES_SKIP_MACOS_DEFAULTS=1`
lo omite. El tier con sudo (sudoers, Touch ID, firewall) queda manual.

`--dry-run` es el único flag: imprime cada comando sin ejecutar nada. Las
descargas usan los URLs oficiales y cada payload debe coincidir con el SHA-256
aprobado en `.github/install/remote-installers.sha256`; si cambia, la
instalación aborta antes de ejecutar. Cuando un proveedor publique un payload
nuevo, el manifiesto se actualiza a mano.

Identidad Git fuera del repo:

```bash
git config --file ~/.gitconfig.local user.name "Tu Nombre"
git config --file ~/.gitconfig.local user.email "tu@email"
```

## Qué administra `install.sh`

- `.zshenv`, `.zprofile`, `.zshrc`, `.p10k.zsh`, `.gitconfig`, ignore y hooks
  globales de Git.
- Config y shaders de Ghostty; config de Herdr (conserva estado local); config
  y logo de Fastfetch; settings, keybindings y MCP de VS Code.
- Runtime de Claude Code: skills, hooks, reglas, templates, settings.
- MCP administrados en `~/.claude.json`: transaccional, conserva entradas no
  administradas, snapshot antes de la primera mutación.

Reemplazos sin backup: los archivos gestionados se sobrescriben en cada
`./install.sh`. Los `*.backup.*` que ya existan no se tocan. No modifica
`~/.gitconfig.local`, credenciales ni tokens.

## Qué queda manual

- Apps de [`docs/MANUAL_INSTALL.md`](docs/MANUAL_INSTALL.md), autenticación de
  CLIs y fuentes si las instalás aparte.
- Extensiones de VS Code: `install.sh` intenta instalarlas si encuentra la CLI
  `code`; si no, habilitala desde VS Code y volvé a ejecutar el instalador.
- `config/macos/defaults.sh`: revisalo con `--dry-run --no-sudo` y auditá con
  `.github/verify.sh`. `install.sh` aplica automáticamente el tier de usuario
  solo al HOME real; el tier con sudo queda manual.
- API keys y tokens: nunca en el repo.

Detalle de Claude en [`config/claude/README.md`](config/claude/README.md).
