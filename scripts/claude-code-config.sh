#!/bin/bash

# Configuración de Claude Code instalado via Homebrew
# Basado en: https://formulae.brew.sh/cask/claude-code

set -e

echo "⚙️  Configurando Claude Code..."

# Agregar ~/.local/bin al PATH para evitar warnings
# Claude Code busca el binario en ~/.local/bin por defecto
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' ~/.zshrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
    echo "✅ Agregado ~/.local/bin al PATH en .zshrc"
else
    echo "✓ ~/.local/bin ya está en el PATH"
fi

# Aplicar cambios en la sesión actual
export PATH="$HOME/.local/bin:$PATH"

# Verificar instalación
if command -v claude &> /dev/null; then
    echo "✅ Claude Code instalado correctamente"
    echo "   Versión: $(claude --version 2>/dev/null || echo 'desconocida')"
    echo "   Ubicación: $(which claude)"

    # IMPORTANTE: Deshabilitar auto-updater de Claude Code
    # El auto-updater instala updates en ~/.local/bin/claude y causa conflictos con Homebrew
    echo ""
    echo "🔧 Deshabilitando auto-updater de Claude Code..."
    claude config set autoUpdates false 2>/dev/null || echo "⚠️  No se pudo deshabilitar auto-updater (puede que ya esté deshabilitado)"

    echo ""
    echo "✅ Auto-updater deshabilitado. Usa 'brew upgrade --cask claude-code' para actualizar"
else
    echo "⚠️  Claude Code no encontrado. Asegúrate de instalarlo con:"
    echo "   brew install --cask claude-code"
fi

echo ""
echo "💡 Tip: Reinicia tu terminal o ejecuta 'source ~/.zshrc' para aplicar los cambios"
echo "💡 Para verificar la instalación ejecuta: claude doctor"

echo "✅ Configuración completada"
