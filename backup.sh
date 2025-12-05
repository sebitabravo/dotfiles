#!/bin/bash

# 💾 Script de Backup de Dotfiles
# Autor: sebitabravo
# Descripción: Sincroniza cambios de configuración al repositorio

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Directorio del script
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   💾 Backup de Dotfiles                   ║
║   Sincronizando configuraciones...        ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

cd "$DOTFILES_DIR"

# Copiar archivos principales
print_info "Copiando archivos de configuración..."

# Shell configs
cp ~/.zshrc .zshrc 2>/dev/null && print_success ".zshrc actualizado" || print_info ".zshrc no encontrado"
cp ~/.zprofile .zprofile 2>/dev/null && print_success ".zprofile actualizado" || print_info ".zprofile no encontrado"
cp ~/.p10k.zsh .p10k.zsh 2>/dev/null && print_success ".p10k.zsh actualizado" || print_info ".p10k.zsh no encontrado"

# Git config
cp ~/.gitconfig .gitconfig 2>/dev/null && print_success ".gitconfig actualizado" || print_info ".gitconfig no encontrado"

# Actualizar Brewfile
print_info "Actualizando Brewfile..."
brew bundle dump --force --file=./Brewfile
print_success "Brewfile actualizado"

# VS Code configs
print_info "Copiando configuraciones de VS Code..."
VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
mkdir -p config/vscode

if [ -f "$VSCODE_USER_DIR/settings.json" ]; then
    cp "$VSCODE_USER_DIR/settings.json" config/vscode/settings.json
    print_success "VS Code settings.json actualizado"
fi

if [ -f "$VSCODE_USER_DIR/keybindings.json" ]; then
    cp "$VSCODE_USER_DIR/keybindings.json" config/vscode/keybindings.json
    print_success "VS Code keybindings.json actualizado"
fi

# Fastfetch config
print_info "Copiando configuración de fastfetch..."
if [ -d "$HOME/.config/fastfetch" ]; then
    mkdir -p config/fastfetch
    cp -r "$HOME/.config/fastfetch/"* config/fastfetch/ 2>/dev/null || true
    print_success "Fastfetch configuración actualizada"
fi

# Claude config
print_info "Copiando configuración de Claude..."
if [ -d "$HOME/.config/claude" ]; then
    mkdir -p config/claude
    cp -r "$HOME/.config/claude/"* config/claude/ 2>/dev/null || true
    print_success "Claude configuración actualizada"
fi

# Verificar cambios
echo ""
print_info "Verificando cambios..."
if git diff --quiet; then
    print_success "No hay cambios para guardar"
else
    print_info "Cambios detectados:"
    git status --short
    echo ""
    
    # Preguntar si hacer commit
    read -p "¿Deseas hacer commit de estos cambios? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Mensaje de commit: " commit_msg
        
        git add .
        git commit -m "$commit_msg"
        print_success "Commit realizado"
        
        read -p "¿Deseas hacer push? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push
            print_success "Push realizado"
        fi
    fi
fi

echo ""
print_success "Backup completado 🎉"
