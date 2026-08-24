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

case "$#:${1:-}" in
  0:)          DRY_RUN=0 ;;
  1:--dry-run) DRY_RUN=1 ;;
  *)
    printf 'uso: %s [--dry-run]\n' "$0" >&2
    exit 2
    ;;
esac
STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_ROOT="$HOME/.dotfiles-backups/$STAMP"

run() { if [ "$DRY_RUN" -eq 1 ]; then printf '  DRY  %s\n' "$*"; else "$@"; fi; }

# Aparta lo que ya exista en el destino en vez de pisarlo.
backup() {
  [ -e "$1" ] || [ -L "$1" ] || return 0
  printf '  BACKUP %s.backup.%s\n' "$1" "$STAMP"
  run mv -- "$1" "$1.backup.$STAMP"
}

# El despliegue usa copias independientes. Así el usuario puede editar su
# configuración instalada aunque mueva o elimine este repositorio.
copy() {
  local src="$DOTFILES/$1" dst="$2"
  [ -e "$src" ] || { printf '  FALTA  %s (instalacion abortada)\n' "$1" >&2; return 1; }
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf '  REMOVE  symlink %s\n' "$dst"
    run rm -- "$dst"
  elif [ -L "$dst" ]; then
    backup "$dst"
  fi
  cmp -s -- "$src" "$dst" && return 0
  backup "$dst"
  run mkdir -p -- "$(dirname -- "$dst")"
  run cp -p -- "$src" "$dst"
  printf '  COPY   %s\n' "$dst"
}

copy_dir() {
  local src="$DOTFILES/$1" dst="$2"
  local backup_dst changes
  local -a excludes
  [ -d "$src" ] || { printf '  FALTA  %s (instalacion abortada)\n' "$1" >&2; return 1; }
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf '  REMOVE  symlink %s\n' "$dst"
    run rm -- "$dst"
  elif [ -L "$dst" ] || { [ -e "$dst" ] && [ ! -d "$dst" ]; }; then
    backup "$dst"
  fi
  excludes=(
    --exclude='__pycache__'
    --exclude='.DS_Store'
    --exclude='node_modules'
    --exclude='*.test.sh'
    --exclude='*.backup.*'
  )
  if [ -d "$dst" ]; then
    changes=$(rsync -rlptc --dry-run --itemize-changes --delete \
      "${excludes[@]}" "$src/" "$dst/")
    if [ -n "$changes" ]; then
      case "$dst" in
        "$HOME"/*) backup_dst="$BACKUP_ROOT/${dst#"$HOME"/}" ;;
        *)         backup_dst="$BACKUP_ROOT/absolute/${dst#/}" ;;
      esac
      printf '  BACKUP %s/ -> %s/\n' "$dst" "$backup_dst"
      run mkdir -p -- "$backup_dst"
      run rsync -rlpt "${excludes[@]}" "$dst/" "$backup_dst/"
    fi
  fi
  run mkdir -p -- "$dst"
  # --checksum evita falsos MATCH cuando tamaño y mtime coinciden por azar.
  run rsync -rlptc --delete "${excludes[@]}" "$src/" "$dst/"
  printf '  COPY   %s/\n' "$dst"
}

printf 'repo: %s\n\n' "$DOTFILES"

echo "shell"
copy .zshrc    "$HOME/.zshrc"
copy .zshenv   "$HOME/.zshenv"
copy .zprofile "$HOME/.zprofile"
copy .p10k.zsh "$HOME/.p10k.zsh"

echo "git"
copy .gitconfig                   "$HOME/.gitconfig"
copy config/git/.gitignore_global "$HOME/.gitignore_global"
copy_dir git-hooks                "$HOME/.git-hooks"

echo "terminal"
copy_dir config/ghostty "$HOME/.config/ghostty"

echo "fastfetch"
copy_dir config/fastfetch "$HOME/.config/fastfetch"

echo "vscode"
VSCODE="$HOME/Library/Application Support/Code/User"
copy config/vscode/settings.json    "$VSCODE/settings.json"
copy config/vscode/keybindings.json "$VSCODE/keybindings.json"
copy config/vscode/mcp.json         "$VSCODE/mcp.json"

echo "claude"
for d in agents skills hooks rules templates scripts output-styles agent-tools; do
  copy_dir "config/claude/$d" "$HOME/.claude/$d"
done
for f in CLAUDE.md statusline.sh mcp-servers.json skills-lock.json tweakcc-theme.json skill-registry.md; do
  copy "config/claude/$f" "$HOME/.claude/$f"
done
# Claude Code y los overlays de proveedores leen estos JSON desde runtime.
# Se copian (no se enlazan) porque Claude Code puede reescribir settings.json y
# las credenciales se resuelven por helper externo, nunca desde estos archivos.
for f in settings.json deepseek.settings.json glm.settings.json \
  kimi.settings.json minimax.settings.json ollama.settings.json \
  openrouter.settings.json qwen.settings.json; do
  copy "config/claude/$f" "$HOME/.claude/$f"
done

# core.hooksPath no se fija con `git config --global`: la copia instalada debe
# conservar la configuracion portable versionada sin escribir rutas locales del
# usuario dentro del archivo fuente.

if [ "$DRY_RUN" -eq 0 ] && [ ! -f "$HOME/.gitconfig.local" ]; then
  cat <<'EOF'

Falta ~/.gitconfig.local con tu identidad:

  git config --file ~/.gitconfig.local user.name  "Tu Nombre"
  git config --file ~/.gitconfig.local user.email "tu@email"
EOF
fi
