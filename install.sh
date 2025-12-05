#!/bin/bash

# 🚀 Instalación Automática de Dotfiles
# Autor: sebitabravo
# Descripción: Script para configurar una nueva Mac con todos los dotfiles

set -e  # Exit on error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funciones de utilidad
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

# Banner
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════╗
║   🍎 Instalador de Dotfiles - macOS       ║
║   Configuración profesional de desarrollo  ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar que estamos en macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "Este script solo funciona en macOS"
    exit 1
fi

print_info "Iniciando instalación de dotfiles..."
echo ""

# Directorio del script
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
print_info "Dotfiles directory: $DOTFILES_DIR"
echo ""

# Paso 1: Instalar Homebrew
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 1: Homebrew${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if ! command -v brew &> /dev/null; then
    print_warning "Homebrew no encontrado. Instalando..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Configurar Homebrew en el PATH
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    print_success "Homebrew instalado correctamente"
else
    print_success "Homebrew ya está instalado"
fi
echo ""

# Paso 2: Instalar paquetes del Brewfile
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 2: Instalando paquetes de Homebrew${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "$DOTFILES_DIR/Brewfile" ]; then
    print_info "Instalando paquetes del Brewfile..."
    cd "$DOTFILES_DIR"
    brew bundle install
    print_success "Paquetes instalados"
else
    print_warning "Brewfile no encontrado, saltando..."
fi
echo ""

# Paso 3: Instalar Oh My Zsh
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 3: Oh My Zsh${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_warning "Oh My Zsh no encontrado. Instalando..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    print_success "Oh My Zsh instalado"
else
    print_success "Oh My Zsh ya está instalado"
fi
echo ""

# Paso 4: Instalar Powerlevel10k
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 4: Powerlevel10k Theme${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    print_warning "Powerlevel10k no encontrado. Instalando..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    print_success "Powerlevel10k instalado"
else
    print_success "Powerlevel10k ya está instalado"
fi
echo ""

# Paso 5: Instalar plugins de Zsh (opcionales pero recomendados)
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 5: Plugins de Zsh (Opcionales)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# zsh-autosuggestions
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
    print_info "Instalando zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    print_success "zsh-autosuggestions instalado"
else
    print_success "zsh-autosuggestions ya está instalado"
fi

# zsh-syntax-highlighting
if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
    print_info "Instalando zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    print_success "zsh-syntax-highlighting instalado"
else
    print_success "zsh-syntax-highlighting ya está instalado"
fi
echo ""

# Paso 6: Copiar archivos de configuración
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 6: Copiando archivos de configuración${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Backup de archivos existentes
backup_dir="$HOME/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

backup_and_copy() {
    local file=$1
    if [ -f "$HOME/$file" ]; then
        print_warning "Respaldando $file existente..."
        cp "$HOME/$file" "$backup_dir/$file"
    fi
    cp "$DOTFILES_DIR/$file" "$HOME/$file"
    print_success "$file copiado"
}

# Copiar archivos de configuración principales
for file in .zshrc .zprofile .gitconfig .p10k.zsh; do
    if [ -f "$DOTFILES_DIR/$file" ]; then
        backup_and_copy "$file"
    fi
done
echo ""

# Paso 7: Configurar directorios de configuración
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 7: Configuraciones adicionales${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Crear directorio .config si no existe
mkdir -p "$HOME/.config"

# Copiar configuración de fastfetch
if [ -d "$DOTFILES_DIR/config/fastfetch" ]; then
    print_info "Copiando configuración de fastfetch..."
    cp -r "$DOTFILES_DIR/config/fastfetch" "$HOME/.config/"
    print_success "Fastfetch configurado"
fi

# Copiar configuración de VS Code
if [ -d "$DOTFILES_DIR/config/vscode" ]; then
    print_info "Copiando configuración de VS Code..."
    VSCODE_DIR="$HOME/Library/Application Support/Code/User"
    mkdir -p "$VSCODE_DIR"
    
    if [ -f "$DOTFILES_DIR/config/vscode/settings.json" ]; then
        cp "$DOTFILES_DIR/config/vscode/settings.json" "$VSCODE_DIR/settings.json"
        print_success "VS Code settings.json copiado"
    fi
    
    if [ -f "$DOTFILES_DIR/config/vscode/keybindings.json" ]; then
        cp "$DOTFILES_DIR/config/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
        print_success "VS Code keybindings.json copiado"
    fi
fi

# Copiar configuración de Claude
if [ -d "$DOTFILES_DIR/config/claude" ]; then
    print_info "Copiando configuración de Claude..."
    # Claude suele usar ~/.config o ~/Library/Application Support/Claude
    # Ajustar según necesidad
    mkdir -p "$HOME/.config/claude"
    cp -r "$DOTFILES_DIR/config/claude/"* "$HOME/.config/claude/" 2>/dev/null || true
    print_success "Claude configurado"
fi
echo ""

# Paso 8: Configurar Node.js con fnm
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 8: Configurando Node.js${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if command -v fnm &> /dev/null; then
    print_info "Configurando Node.js con fnm..."
    eval "$(fnm env --use-on-cd)"
    
    # Instalar LTS
    fnm install --lts
    fnm default lts-latest
    print_success "Node.js LTS instalado y configurado como default"
    
    # También instalar versión 20
    fnm install 20
    print_success "Node.js 20 instalado"
else
    print_warning "fnm no encontrado, saltando configuración de Node.js"
fi
echo ""

# Paso 9: Configurar Python con pyenv
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 9: Configurando Python${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if command -v pyenv &> /dev/null; then
    print_info "Configurando Python con pyenv..."
    
    # Instalar Python 3.14.1
    print_info "Instalando Python 3.14.1 (esto puede tardar)..."
    pyenv install -s 3.14.1
    pyenv global 3.14.1
    print_success "Python 3.14.1 instalado y configurado como default"
else
    print_warning "pyenv no encontrado, saltando configuración de Python"
fi
echo ""

# Paso 10: Configurar Dock
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Paso 10: Configurando Dock de macOS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "$DOTFILES_DIR/docs/dock.sh" ]; then
    print_info "Aplicando configuración del Dock..."
    bash "$DOTFILES_DIR/docs/dock.sh"
    print_success "Dock configurado"
else
    print_warning "Script de Dock no encontrado"
fi
echo ""

# Resumen final
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Instalación Completada${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
print_success "Todos los dotfiles han sido instalados correctamente"
echo ""
print_info "Próximos pasos:"
echo "  1. Reinicia tu terminal: exec zsh"
echo "  2. Configura Powerlevel10k: p10k configure"
echo "  3. Revisa apps de instalación manual: docs/MANUAL_INSTALL.md"
echo "  4. Instala extensiones de VS Code según necesites"
echo ""

if [ -d "$backup_dir" ]; then
    print_info "Archivos originales respaldados en: $backup_dir"
fi

echo ""
print_success "¡Disfruta tu nuevo setup! 🚀"
echo ""
