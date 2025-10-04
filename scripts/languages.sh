#!/bin/bash

# Instalación de versiones específicas de Node.js y Python

set -e

echo "🔧 Instalando Node.js y Python..."

# ============================================================================
# Node.js con fnm
# ============================================================================

if command -v fnm &> /dev/null; then
    echo "📦 Instalando Node.js v20 LTS con fnm..."

    # Instalar Node.js 20 LTS
    fnm install 20
    fnm use 20
    fnm default 20

    echo "✅ Node.js $(node --version) instalado"
    echo "✅ npm $(npm --version) instalado"
else
    echo "⚠️  fnm no está instalado. Ejecuta 'brew install fnm' primero."
fi

# ============================================================================
# Python con pyenv
# ============================================================================

if command -v pyenv &> /dev/null; then
    echo "📦 Instalando Python 3.11.1 con pyenv..."

    # Instalar Python 3.11.1
    pyenv install 3.11.1 --skip-existing
    pyenv global 3.11.1

    echo "✅ Python $(python --version) instalado"
    echo "✅ pip $(pip --version) instalado"

    # Actualizar pip
    pip install --upgrade pip
else
    echo "⚠️  pyenv no está instalado. Ejecuta 'brew install pyenv' primero."
fi

echo "✅ Instalación completada"
