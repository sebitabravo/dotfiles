#!/bin/bash

# 🚀 Setup completo para Mac
# Uso:
#   ./setup.sh         (interactivo - te pregunta qué instalar)
#   ./setup.sh --auto  (automático - instala todo sin preguntar)

set -e

DOTFILES_DIR="$HOME/Developer/dotfiles"
AUTO_MODE=false

# Detectar modo automático
if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
fi

# Función para preguntar en modo interactivo
ask() {
    if $AUTO_MODE; then
        return 0  # Siempre sí en modo auto
    fi

    echo -n "$1 (y/n) "
    read -r response
    [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
}

echo "╔════════════════════════════════════════════════════════════╗"
if $AUTO_MODE; then
    echo "║  🚀 INSTALACIÓN AUTOMÁTICA - Sin preguntas                ║"
else
    echo "║  🚀 INSTALACIÓN INTERACTIVA                               ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# 1. HOMEBREW
# ============================================================================
echo "📦 [1/7] Homebrew..."
if ! command -v brew &> /dev/null; then
    if ask "   ¿Instalar Homebrew?"; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Configurar PATH (Apple Silicon)
        if [[ $(uname -m) == 'arm64' ]]; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        echo "   ✓ Homebrew instalado"
    fi
else
    echo "   ✓ Ya instalado"
fi
echo ""

# ============================================================================
# 2. BREWFILE
# ============================================================================
echo "📦 [2/7] Paquetes y apps (Brewfile)..."
if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    if ask "   ¿Instalar paquetes desde Brewfile?"; then
        cd "$DOTFILES_DIR"
        brew bundle install
        echo "   ✓ Paquetes instalados"
    fi
else
    echo "   ⚠️  Brewfile no encontrado"
fi
echo ""

# ============================================================================
# 3. OH MY ZSH
# ============================================================================
echo "📦 [3/7] Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    if ask "   ¿Instalar Oh My Zsh?"; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        echo "   ✓ Oh My Zsh instalado"
    fi
else
    echo "   ✓ Ya instalado"
fi
echo ""

# ============================================================================
# 4. DOTFILES (Symlinks)
# ============================================================================
echo "📦 [4/7] Dotfiles (symlinks)..."
if [ -f "$DOTFILES_DIR/install.sh" ]; then
    if ask "   ¿Crear symlinks de configuraciones?"; then
        bash "$DOTFILES_DIR/install.sh"
        echo "   ✓ Symlinks creados"
    fi
fi
echo ""

# ============================================================================
# 5. NODE.JS y PYTHON
# ============================================================================
echo "🔧 [5/7] Node.js v20 y Python 3.11.1..."
if [ -f "$DOTFILES_DIR/scripts/languages.sh" ]; then
    if ask "   ¿Instalar Node.js y Python?"; then
        bash "$DOTFILES_DIR/scripts/languages.sh"
        echo "   ✓ Lenguajes instalados"
    fi
fi
echo ""

# ============================================================================
# 6. CLAUDE CODE
# ============================================================================
echo "⚙️  [6/7] Claude Code..."
if [ -f "$DOTFILES_DIR/scripts/claude-code-config.sh" ]; then
    if command -v claude &> /dev/null; then
        if ask "   ¿Configurar Claude Code?"; then
            bash "$DOTFILES_DIR/scripts/claude-code-config.sh"
            echo "   ✓ Claude Code configurado"
        fi
    else
        echo "   ⚠️  Claude Code no instalado"
    fi
fi
echo ""

# ============================================================================
# 7. DOCK
# ============================================================================
echo "⚙️  [7/7] Dock de macOS..."
if [ -f "$DOTFILES_DIR/scripts/dock.sh" ]; then
    if ask "   ¿Configurar Dock?"; then
        bash "$DOTFILES_DIR/scripts/dock.sh"
        echo "   ✓ Dock configurado"
    fi
fi
echo ""

# ============================================================================
# RESUMEN
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                ✅ INSTALACIÓN COMPLETADA                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Próximos pasos:"
echo ""
echo "   1. Reiniciar terminal o ejecutar: source ~/.zshrc"
echo "   2. Apps de App Store: ver MANUAL_INSTALL.md"
echo "   3. Extensiones de Raycast: ver scripts/raycast-extensions.md"
echo "   4. Configurar Powerlevel10k: p10k configure"
echo ""
