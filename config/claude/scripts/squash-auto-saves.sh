#!/bin/bash
# Squash todos los commits "auto-save:" en el rango no pusheado
# Uso: ~/.claude/scripts/squash-auto-saves.sh

set -euo pipefail

REMOTE=${1:-origin}
BRANCH=${2:-$(git branch --show-current)}

# Encontrar cuántos commits locales hay vs remote
REMOTE_HEAD=$(git rev-parse "$REMOTE/$BRANCH" 2>/dev/null) || {
    echo "No remote branch $REMOTE/$BRANCH encontrada" >&2
    exit 1
}

LOCAL_HEAD=$(git rev-parse HEAD)

if [ "$REMOTE_HEAD" = "$LOCAL_HEAD" ]; then
    echo "Nada para pushear."
    exit 0
fi

# Contar auto-save commits
AUTO_SAVES=$(git log "$REMOTE_HEAD..$LOCAL_HEAD" --oneline --grep="auto-save:" 2>/dev/null | wc -l | tr -d ' ')

if [ "$AUTO_SAVES" -eq 0 ]; then
    echo "No hay auto-save commits para squashear."
    exit 0
fi

echo "Encontrados $AUTO_SAVES auto-save commits entre $REMOTE_HEAD y $LOCAL_HEAD"
echo "Ejecutando rebase interactivo..."

# Usar GIT_SEQUENCE_EDITOR para hacer squash automático
# Marcamos todos los commits "auto-save:" como fixup
GIT_SEQUENCE_EDITOR="sed -i '' '/auto-save:/s/^pick/fixup/'" git rebase -i "$REMOTE_HEAD"

echo "Auto-save commits squasheados. Listo para push."
