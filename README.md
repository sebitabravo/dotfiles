# 🔧 Dotfiles - sebitabravo

Configuración completa para macOS. Nunca más pierdas tu configuración al formatear.

## 📋 Prerequisitos

- macOS (Sonoma o superior recomendado)
- Terminal (Terminal.app o Warp)
- Conexión a internet

## 🚀 Instalación Completa

### Paso 1: Clonar el repositorio

```bash
# Crear carpeta Developer si no existe
mkdir -p ~/Developer

# Clonar dotfiles
git clone <tu-repo-url> ~/Developer/dotfiles
cd ~/Developer/dotfiles
```

### Paso 2: Instalar Homebrew

```bash
# Instalar Homebrew (si no lo tienes)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Añadir Homebrew al PATH (sigue las instrucciones que aparecen después de instalar)
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

### Paso 3: Instalar herramientas con Homebrew

```bash
# Instalar todas las herramientas y apps del Brewfile
brew bundle install
```

### Paso 4: Instalar Oh My Zsh

```bash
# Instalar Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# IMPORTANTE: Cuando pregunte si quieres cambiar el shell a zsh, di "Y" (yes)
# Si pregunta si quieres sobrescribir .zshrc, di "N" (no)
```

### Paso 5: Crear symlinks

```bash
# Backup de configuraciones actuales (opcional pero recomendado)
mv ~/.zshrc ~/.zshrc.backup 2>/dev/null
mv ~/.p10k.zsh ~/.p10k.zsh.backup 2>/dev/null
mv ~/.gitconfig ~/.gitconfig.backup 2>/dev/null

# Crear symlinks
ln -sf ~/Developer/dotfiles/.zshrc ~/.zshrc
ln -sf ~/Developer/dotfiles/.p10k.zsh ~/.p10k.zsh
ln -sf ~/Developer/dotfiles/.gitconfig ~/.gitconfig

# Si tienes .zprofile personalizado, también créalo
ln -sf ~/Developer/dotfiles/.zprofile ~/.zprofile
```

### Paso 6: Configurar terminal

```bash
# Recargar configuración de zsh
source ~/.zshrc

# Configurar Powerlevel10k (opcional, solo si quieres cambiar el estilo)
p10k configure
```

### Paso 7: Instalar versiones de Node.js y Python

```bash
# Instalar Node.js con fnm
fnm install 20
fnm use 20
fnm default 20

# Verificar Node.js
node -v
npm -v

# Instalar Python con pyenv
pyenv install 3.13.7
pyenv global 3.13.7

# Verificar Python
python --version
```

### Paso 8: Configuraciones adicionales (Opcional)

```bash
# Configurar Claude Code PATH
./scripts/claude-code-config.sh

# Optimizar Dock de macOS (auto-hide instantáneo)
./scripts/dock.sh
```

## 📁 Estructura

```bash
dotfiles/
├── Brewfile              # Apps y herramientas de Homebrew
├── .zshrc                # Zsh + Oh My Zsh + Powerlevel10k
├── .p10k.zsh             # Configuración de Powerlevel10k
├── .zprofile             # Shell profile
├── .gitconfig            # Git config
├── config/
│   ├── vscode/           # VS Code settings y keybindings
│   ├── claude/           # Claude Code (100+ agents y commands)
│   └── fastfetch/        # Fastfetch con tema personalizado
├── scripts/
│   ├── claude-code-config.sh  # Config de Claude Code (PATH)
│   └── dock.sh                # Config del Dock de macOS
└── MANUAL_INSTALL.md     # Apps de instalación manual
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

## ✅ Verificar instalación

```bash
# Verificar que todo esté instalado correctamente
brew --version          # Debe mostrar versión de Homebrew
zsh --version          # Debe mostrar versión de Zsh
fnm --version          # Debe mostrar versión de fnm
pyenv --version        # Debe mostrar versión de pyenv
node -v                # Debe mostrar v20.x.x
python --version       # Debe mostrar 3.13.7
gh --version           # Debe mostrar versión de GitHub CLI
fastfetch              # Debe mostrar info del sistema con tema personalizado
```

## 🔄 Reinstalar en otra Mac

```bash
# 1. Clonar repo
git clone <tu-repo-url> ~/Developer/dotfiles
cd ~/Developer/dotfiles

# 2. Ejecutar pasos 2-8 de la instalación completa
# Todo está automatizado, solo sigue los pasos en orden
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
# Sistema
fastfetch                    # Ver info del sistema con estilo
myip                         # Ver tu IP pública

# Powerlevel10k
p10k configure              # Reconfigurar tema del prompt

# Homebrew
brew bundle dump --force    # Actualizar Brewfile con apps instaladas
brew bundle cleanup         # Eliminar apps no listadas en Brewfile
brew update && brew upgrade # Actualizar todas las apps

# Git (desde ~/.gitconfig)
git status                  # Ver estado del repo
git log --oneline --graph  # Ver historial visual

# Python & Node
fnm list                    # Ver versiones de Node instaladas
pyenv versions             # Ver versiones de Python instaladas
```

## 🐛 Troubleshooting

### Powerlevel10k no se ve bien

```bash
# Instalar fuente Nerd Font recomendada
brew install --cask font-meslo-lg-nerd-font

# En tu terminal:
# 1. Preferences > Profiles > Text
# 2. Font > MesloLGS NF Regular
# 3. Reiniciar terminal
```

### fnm o pyenv no funcionan

```bash
# Recargar zsh
source ~/.zshrc

# Verificar que los paths estén bien
echo $PATH | tr ':' '\n' | grep -E 'fnm|pyenv'
```

### Los alias de Claude Code no funcionan

```bash
# Ejecutar script de configuración
./scripts/claude-code-config.sh

# Recargar terminal
source ~/.zshrc
```

## ⚠️ Notas importantes

- ✅ Los symlinks apuntan a archivos en este repo
- ✅ Cambios en dotfiles se reflejan automáticamente (no necesitas copiar)
- ❌ NO versionar claves SSH (`.ssh/id_*`)
- ❌ NO versionar archivos `.env` o secrets
- 🔄 Reinicia terminal después de cambios: `source ~/.zshrc`

---

Hecho con ❤️ por sebitabravo
