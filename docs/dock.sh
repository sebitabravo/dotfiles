#!/bin/bash

# Configuración del Dock de macOS
# Configuración exacta usada en mi Mac

set -e

echo "⚙️  Configurando Dock de macOS..."
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -int 0
killall Dock
echo "✅ Dock configurado correctamente"

echo "⚙️  Habilitando HUD de Metal para desarrollo..."
/bin/launchctl setenv MTL_HUD_ENABLED 1
echo "✅ HUD de Metal habilitado"
