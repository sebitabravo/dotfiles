# 🔧 Dotfiles - sebitabravo

Configuración completa para macOS. Nunca más pierdas tu configuración al formatear.

## 🚀 Instalación

```bash
# 1. Clonar
git clone <tu-repo-url> ~/Developer/dotfiles
cd ~/Developer/dotfiles

# 2. Ejecutar setup
./setup.sh --auto    # Instalación automática (recomendado)
./setup.sh           # Instalación interactiva (te pregunta)

# Solo actualizar symlinks
./install.sh
```

## 📁 Estructura

```
dotfiles/
├── setup.sh              # Script de instalación (--auto para automático)
├── install.sh            # Crear symlinks únicamente
├── Brewfile              # Apps y herramientas de Homebrew
├── .zshrc                # Zsh + Oh My Zsh + Powerlevel10k
├── .zprofile             # Shell profile
├── .gitconfig            # Git config
├── config/
│   ├── vscode/           # VS Code settings y keybindings
│   ├── claude/           # Claude Code (100+ agents y commands)
│   └── fastfetch/        # Fastfetch con tema personalizado
└── scripts/
    ├── claude-code-config.sh  # Config de Claude Code (PATH)
    ├── dock.sh                # Config del Dock de macOS
    └── languages.sh           # Instalar Node.js v20 y Python 3.11.1
```

## 📦 ¿Qué incluye?

### Herramientas CLI
- **fnm** - Node.js manager
- **pyenv** - Python version manager
- **gh** - GitHub CLI
- **bun** - JavaScript runtime
- **fastfetch** - System info
- **powerlevel10k** - Zsh theme
- **ffmpeg**, **imagemagick**, **vercel-cli**, **gemini-cli**

### Configuraciones (via symlinks)
- **Zsh** con Oh My Zsh + Powerlevel10k
- **VS Code** settings y keybindings
- **Claude Code** con 100+ agents y commands personalizados
- **Fastfetch** con tema personalizado
- **Git** con aliases útiles
- **Dock** optimizado (auto-hide instantáneo)

## 🔧 Scripts individuales

```bash
# Configurar Claude Code (PATH y auto-updates)
./scripts/claude-code-config.sh

# Configurar Dock
./scripts/dock.sh

# Instalar Node.js y Python
./scripts/languages.sh
```

## 📌 Actualizar configuraciones

**Los symlinks hacen que tus cambios se reflejen automáticamente.** Solo haz commit:

```bash
git status
git add .
git commit -m "Update configs"
git push
```

**Actualizar Brewfile** (después de instalar apps):
```bash
brew bundle dump --force
git add Brewfile
git commit -m "Update Brewfile"
git push
```

## 📝 Apps de instalación manual

Ver [MANUAL_INSTALL.md](MANUAL_INSTALL.md) para apps de App Store y otros.

Ver [scripts/raycast-extensions.md](scripts/raycast-extensions.md) para extensiones de Raycast.

## 💡 Comandos útiles

```bash
fastfetch           # Ver info del sistema
p10k configure      # Configurar Powerlevel10k
brew bundle dump    # Actualizar Brewfile
```

## ⚠️ Notas

- NO versionar claves SSH (`.ssh/id_*`)
- NO versionar archivos `.env` o secrets
- Los symlinks apuntan a archivos en este repo
- Reinicia terminal después de instalar: `source ~/.zshrc`

---

Hecho con ❤️ por sebitabravo
