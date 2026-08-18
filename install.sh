#!/usr/bin/env bash
# Despliega esta configuracion a su lugar en el sistema.
#
#   ./install.sh              instala
#   ./install.sh --dry-run    muestra que haria, no toca nada
#
# Funciona con el repo en cualquier carpeta -- Developer, Downloads, Descargas,
# Desktop, Escritorio, una ruta con espacios o con tildes. La raiz se deduce de
# donde vive ESTE archivo, no del directorio desde el que lo llames.
set -euo pipefail

# Si te llamaron a traves de un symlink, seguirlo hasta el archivo real: sin
# esto la raiz seria la carpeta del enlace y no la del repo.
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
  LINK="$(readlink "$SELF")"
  case "$LINK" in
    /*) SELF="$LINK" ;;
    *)  SELF="$(dirname -- "$SELF")/$LINK" ;;
  esac
done
DOTFILES="$(cd -- "$(dirname -- "$SELF")" && pwd -P)"

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
STAMP="$(date +%Y%m%d%H%M%S)"

run() { if [ "$DRY_RUN" -eq 1 ]; then printf '  DRY  %s\n' "$*"; else "$@"; fi; }

# Aparta lo que ya exista en el destino en vez de pisarlo.
backup() {
  [ -e "$1" ] || [ -L "$1" ] || return 0
  printf '  BACKUP %s.backup.%s\n' "$1" "$STAMP"
  run mv -- "$1" "$1.backup.$STAMP"
}

# Enlaza. Editas el repo y el cambio ya esta aplicado: no queda una segunda
# copia que pueda quedar vieja.
link() {
  local src="$DOTFILES/$1" dst="$2"
  [ -e "$src" ] || { printf '  FALTA  %s (se omite)\n' "$1" >&2; return 0; }
  [ "$(readlink "$dst" 2>/dev/null)" = "$src" ] && return 0
  backup "$dst"
  run mkdir -p -- "$(dirname -- "$dst")"
  run ln -sfn -- "$src" "$dst"
  printf '  LINK   %s\n' "$dst"
}

# Solo para archivos que la app duena reescribe sola.
copy() {
  local src="$DOTFILES/$1" dst="$2"
  [ -e "$src" ] || { printf '  FALTA  %s (se omite)\n' "$1" >&2; return 0; }
  cmp -s -- "$src" "$dst" && return 0
  backup "$dst"
  run mkdir -p -- "$(dirname -- "$dst")"
  run cp -p -- "$src" "$dst"
  printf '  COPY   %s\n' "$dst"
}

printf 'repo: %s\n\n' "$DOTFILES"

echo "shell"
link .zshrc    "$HOME/.zshrc"
link .zshenv   "$HOME/.zshenv"
link .zprofile "$HOME/.zprofile"
link .p10k.zsh "$HOME/.p10k.zsh"

echo "git"
link .gitconfig                   "$HOME/.gitconfig"
link config/git/.gitignore_global "$HOME/.gitignore_global"
link git-hooks                    "$HOME/.git-hooks"

echo "terminal"
link config/ghostty   "$HOME/.config/ghostty"

echo "vscode"
VSCODE="$HOME/Library/Application Support/Code/User"
link config/vscode/settings.json    "$VSCODE/settings.json"
link config/vscode/keybindings.json "$VSCODE/keybindings.json"
link config/vscode/mcp.json         "$VSCODE/mcp.json"

echo "claude"
for d in agents skills hooks rules templates scripts output-styles; do
  link "config/claude/$d" "$HOME/.claude/$d"
done
for f in CLAUDE.md statusline.sh mcp-servers.json skills-lock.json tweakcc-theme.json skill-registry.md; do
  link "config/claude/$f" "$HOME/.claude/$f"
done
# Claude Code y los overlays de proveedores leen estos JSON desde runtime.
# Se copian (no se enlazan) porque Claude Code puede reescribir settings.json y
# las credenciales se resuelven por helper externo, nunca desde estos archivos.
for f in settings.json deepseek.settings.json glm.settings.json \
  kimi.settings.json minimax.settings.json ollama.settings.json \
  openrouter.settings.json; do
  copy "config/claude/$f" "$HOME/.claude/$f"
done

# core.hooksPath NO se fija con `git config --global`: ~/.gitconfig es un
# symlink al repo, y ese comando escribiria la ruta absoluta de ESTE home
# dentro del archivo versionado. El .gitconfig ya declara hooksPath.

if [ "$DRY_RUN" -eq 0 ] && [ ! -f "$HOME/.gitconfig.local" ]; then
  cat <<'EOF'

Falta ~/.gitconfig.local con tu identidad:

  git config --file ~/.gitconfig.local user.name  "Tu Nombre"
  git config --file ~/.gitconfig.local user.email "tu@email"
EOF
fi
