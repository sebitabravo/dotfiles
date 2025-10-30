#!/bin/bash

# Configuración del Dock de macOS
# Configuración exacta usada en mi Mac

set -e

echo "⚙️  Configurando Dock de macOS..."

# Configuración de auto-hide del Dock
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -int 0
killall Dock

echo "✅ Dock configurado correctamente"
