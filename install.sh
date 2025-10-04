#!/bin/bash

# Script para crear symlinks de dotfiles
# Uso: ./install.sh

set -e

DOTFILES_DIR="$HOME/Developer/dotfiles"

echo "📦 Instalando dotfiles..."

# Backup de archivos/directorios existentes
backup_if_exists() {
    if [ -f "$1" ] || [ -L "$1" ] || [ -d "$1" ]; then
        echo "⚠️  Haciendo backup de $1"
        mv "$1" "$1.backup.$(date +%Y%m%d_%H%M%S)"
    fi
}

# Crear symlink (archivos o directorios)
create_symlink() {
    local source="$1"
    local target="$2"

    backup_if_exists "$target"
    ln -sf "$source" "$target"
    echo "✓ Creado symlink: $target -> $source"
}

# ============================================================================
# DOTFILES DEL HOME
# ============================================================================
create_symlink "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"
create_symlink "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

# ============================================================================
# VS CODE
# ============================================================================
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
if [ -d "$VSCODE_USER_DIR" ]; then
    create_symlink "$DOTFILES_DIR/config/vscode/settings.json" "$VSCODE_USER_DIR/settings.json"
    create_symlink "$DOTFILES_DIR/config/vscode/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
    echo "✓ VS Code configurado"
else
    echo "⚠️  VS Code no instalado, saltando configuración"
fi

# ============================================================================
# CLAUDE CODE
# ============================================================================
CLAUDE_CONFIG_DIR="$HOME/.config/claude-code"
if [ -d "$DOTFILES_DIR/config/claude" ]; then
    # Crear directorio base si no existe
    mkdir -p "$CLAUDE_CONFIG_DIR"

    # Symlink de settings.json
    if [ -f "$DOTFILES_DIR/config/claude/settings.json" ]; then
        create_symlink "$DOTFILES_DIR/config/claude/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
    fi

    # Symlink de carpetas completas (agents y commands)
    if [ -d "$DOTFILES_DIR/config/claude/agents" ]; then
        create_symlink "$DOTFILES_DIR/config/claude/agents" "$CLAUDE_CONFIG_DIR/agents"
    fi

    if [ -d "$DOTFILES_DIR/config/claude/commands" ]; then
        create_symlink "$DOTFILES_DIR/config/claude/commands" "$CLAUDE_CONFIG_DIR/commands"
    fi

    echo "✓ Claude Code configurado"
else
    echo "⚠️  Configuraciones de Claude Code no encontradas"
fi

# ============================================================================
# FASTFETCH
# ============================================================================
if [ -d "$DOTFILES_DIR/config/fastfetch" ]; then
    # Crear directorio .config si no existe
    mkdir -p "$HOME/.config"

    # Symlink de toda la carpeta fastfetch
    create_symlink "$DOTFILES_DIR/config/fastfetch" "$HOME/.config/fastfetch"
    echo "✓ Fastfetch configurado"
else
    echo "⚠️  Configuraciones de Fastfetch no encontradas"
fi

echo ""
echo "✅ ¡Dotfiles instalados correctamente!"
echo "⚠️  Reinicia tu terminal para aplicar los cambios"
