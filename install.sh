#!/usr/bin/env bash
# Despliega esta configuracion a su lugar en el sistema.
#
#   ./install.sh              ejecuta el bootstrap completo
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
HOMEBREW_INSTALL_URL='https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
# This seam keeps the production defaults explicit while letting the focused
# tests emulate standard Homebrew locations without writing under /opt or
# /usr/local. It only changes which executable paths are inspected.
HOMEBREW_BREW_CANDIDATES="${DOTFILES_HOMEBREW_BREW_CANDIDATES:-/opt/homebrew/bin/brew:/usr/local/bin/brew}"

run() { if [ "$DRY_RUN" -eq 1 ]; then printf '  DRY  %s\n' "$*"; else "$@"; fi; }

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

require_command() {
  command_exists "$1" && return 0
  printf '  FALTA  %s (requerido para instalar %s)\n' "$1" "$2" >&2
  return 1
}

# Algunas herramientas se instalan en rutas que no siempre están presentes en
# PATH durante la misma sesión. Detectarlas evita una reinstalación innecesaria
# sin cambiar el PATH ni tocar la configuración del usuario.
tool_exists() {
  local command_name="$1" candidate
  command_exists "$command_name" && return 0

  for candidate in \
    "$HOME/.local/bin/$command_name" \
    "$HOME/bin/$command_name" \
    "$HOME/.cargo/bin/$command_name" \
    "$HOME/.npm-global/bin/$command_name" \
    "$HOME/.local/share/pnpm/$command_name" \
    "$HOME/.opencode/bin/$command_name" \
    "$HOME/.kilo/bin/$command_name"; do
    [ -x "$candidate" ] && return 0
  done
  return 1
}

brew_exists() {
  local candidate
  local -a candidates

  command_exists brew && return 0
  IFS=: read -r -a candidates <<<"$HOMEBREW_BREW_CANDIDATES"
  for candidate in "${candidates[@]}"; do
    [ -x "$candidate" ] && return 0
  done
  return 1
}

prepare_homebrew_path() {
  local candidate brew_dir
  local -a candidates

  IFS=: read -r -a candidates <<<"$HOMEBREW_BREW_CANDIDATES"
  for candidate in "${candidates[@]}"; do
    [ -x "$candidate" ] || continue
    brew_dir="$(dirname -- "$candidate")"
    case ":$PATH:" in
      *":$brew_dir:"*) ;;
      *) PATH="$brew_dir:$PATH"; export PATH ;;
    esac
    return 0
  done
  return 0
}

install_macos_prerequisites() {
  if [ "$(uname -s)" != 'Darwin' ]; then
    printf '%s\n' '  ERROR  el bootstrap solo es compatible con macOS; no se ejecutaron instaladores, descargas ni despliegue.' >&2
    return 1
  fi

  printf '%s\n' 'prerrequisitos macOS'

  if xcode-select --print-path >/dev/null 2>&1; then
    printf '%s\n' '  SKIP   Apple Command Line Tools (ya existe)'
  elif [ "$DRY_RUN" -eq 1 ]; then
    printf '%s\n' '  DRY  xcode-select --install  # Apple Command Line Tools'
  else
    require_command xcode-select 'Apple Command Line Tools'
    xcode-select --install
    printf '%s\n' '  STOP   Apple Command Line Tools se solicito mediante el flujo de macOS. Completalo (puede requerir aprobacion GUI/admin) y volve a ejecutar ./install.sh.' >&2
    return 1
  fi

  prepare_homebrew_path
  if brew_exists; then
    printf '%s\n' '  SKIP   Homebrew (ya existe brew)'
  elif [ "$DRY_RUN" -eq 1 ]; then
    printf "  DRY  /bin/bash -c \"\$(curl -fsSL %s)\"  # Homebrew\n" "$HOMEBREW_INSTALL_URL"
  else
    require_command curl 'Homebrew'
    brew_script="$(curl -fsSL "$HOMEBREW_INSTALL_URL")"
    /bin/bash -c "$brew_script"
    prepare_homebrew_path
  fi
}

run_remote_installer() {
  local label="$1" url="$2" shell="$3"
  shift 3

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '  DRY  curl -fsSL %s | %s -s --' "$url" "$shell"
    if [ "$#" -gt 0 ]; then
      printf ' %s' "$*"
    fi
    printf '  # %s\n' "$label"
    return 0
  fi

  require_command curl "$label"
  curl -fsSL "$url" | "$shell" -s -- "$@"
}

install_remote_tool() {
  local label="$1" command_name="$2" url="$3" shell="$4"
  shift 4

  if tool_exists "$command_name"; then
    printf '  SKIP   %s (ya existe %s)\n' "$label" "$command_name"
    return 0
  fi

  run_remote_installer "$label" "$url" "$shell" "$@"
}

install_bootstrap_tools() {
  local zsh_custom p10k_dir
  zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  p10k_dir="$zsh_custom/themes/powerlevel10k"

  printf '%s\n' 'herramientas de shell y agentes'

  if [ -d "$HOME/.oh-my-zsh" ]; then
    printf '%s\n' '  SKIP   Oh My Zsh (ya existe ~/.oh-my-zsh)'
  elif [ "$DRY_RUN" -eq 1 ]; then
    printf '%s\n' '  DRY  curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -s -- --unattended  # Oh My Zsh'
  else
    require_command curl 'Oh My Zsh'
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh |
      RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -s -- --unattended
  fi

  if [ -d "$p10k_dir" ]; then
    printf '  SKIP   Powerlevel10k (ya existe %s)\n' "$p10k_dir"
  elif [ "$DRY_RUN" -eq 1 ]; then
    printf '  DRY  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git %s  # Powerlevel10k\n' "$p10k_dir"
  else
    require_command git 'Powerlevel10k'
    mkdir -p -- "$(dirname -- "$p10k_dir")"
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
  fi

  install_remote_tool 'Herdr' herdr https://herdr.dev/install.sh sh
  install_remote_tool 'CodeGraph' codegraph https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh sh
  install_remote_tool 'Gentle AI' gentle-ai https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh bash
  install_remote_tool 'OpenCode' opencode https://opencode.ai/install bash --no-modify-path
  install_remote_tool 'Codex' codex https://chatgpt.com/codex/install.sh sh
  install_remote_tool 'Cursor Agent' agent https://cursor.com/install bash
  install_remote_tool 'Antigravity CLI' agy https://antigravity.google/cli/install.sh bash
  install_remote_tool 'Claude Code' claude https://claude.ai/install.sh bash
  install_remote_tool 'GitHub Copilot CLI' copilot https://gh.io/copilot-install bash
  install_remote_tool 'Kilo Code' kilo https://kilo.ai/cli/install bash --no-modify-path
}

RSYNC_EXCLUDES=(
  --exclude='__pycache__'
  --exclude='.DS_Store'
  --exclude='node_modules'
  --exclude='*.test.sh'
  --exclude='*.backup.*'
)

# Esta lista se reutiliza durante el despliegue. Así todo archivo de Claude
# copiado queda incluido en el preflight y no puede empezar un bootstrap con un
# checkout incompleto.
CLAUDE_FILES=(
  config/claude/CLAUDE.md
  config/claude/statusline.sh
  config/claude/mcp-servers.json
  config/claude/skills-lock.json
  config/claude/tweakcc-theme.json
  config/claude/skill-registry.md
  config/claude/settings.json
  config/claude/deepseek.settings.json
  config/claude/glm.settings.json
  config/claude/kimi.settings.json
  config/claude/minimax.settings.json
  config/claude/ollama.settings.json
  config/claude/openrouter.settings.json
  config/claude/qwen.settings.json
)

REQUIRED_FILES=(
  .zshrc
  .zshenv
  .zprofile
  .p10k.zsh
  .gitconfig
  config/git/.gitignore_global
  config/herdr/config.toml
  config/btop/btop.conf
  config/vscode/settings.json
  config/vscode/keybindings.json
  config/vscode/mcp.json
  "${CLAUDE_FILES[@]}"
)
REQUIRED_DIRS=(
  git-hooks
  config/ghostty
  config/fastfetch
  config/claude/agents
  config/claude/skills
  config/claude/hooks
  config/claude/rules
  config/claude/templates
  config/claude/scripts
  config/claude/output-styles
  config/claude/agent-tools
)

validate_sources() {
  local source_path
  for source_path in "${REQUIRED_FILES[@]}"; do
    [ -f "$DOTFILES/$source_path" ] || {
      printf '  FALTA  %s (instalacion abortada)\n' "$source_path" >&2
      return 1
    }
  done
  for source_path in "${REQUIRED_DIRS[@]}"; do
    [ -d "$DOTFILES/$source_path" ] || {
      printf '  FALTA  %s (instalacion abortada)\n' "$source_path" >&2
      return 1
    }
  done
}

# Aparta lo que ya exista en el destino en vez de pisarlo.
backup() {
  [ -e "$1" ] || [ -L "$1" ] || return 0
  printf '  BACKUP %s.backup.%s\n' "$1" "$STAMP"
  run mv -- "$1" "$1.backup.$STAMP"
}

cleanup_backup_stage() {
  local stage="$1" backup_dst="$2"
  rm -rf -- "$stage"
  rmdir "$(dirname -- "$backup_dst")" 2>/dev/null || true
  rmdir "$BACKUP_ROOT" 2>/dev/null || true
  rmdir "$(dirname -- "$BACKUP_ROOT")" 2>/dev/null || true
}

backup_dir() {
  local src="$1" dst="$2" stage
  printf '  BACKUP %s/ -> %s/\n' "$src" "$dst"

  if [ "$DRY_RUN" -eq 1 ]; then
    run mkdir -p -- "$dst"
    run rsync -rlpt "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/"
    return 0
  fi

  mkdir -p -- "$BACKUP_ROOT"
  if ! stage="$(mktemp -d "$BACKUP_ROOT/.dotfiles-backup-stage.XXXXXX")"; then
    rmdir "$BACKUP_ROOT" 2>/dev/null || true
    rmdir "$(dirname -- "$BACKUP_ROOT")" 2>/dev/null || true
    return 1
  fi

  if ! rsync -rlpt "${RSYNC_EXCLUDES[@]}" "$src/" "$stage/"; then
    cleanup_backup_stage "$stage" "$dst"
    return 1
  fi

  if ! mkdir -p -- "$(dirname -- "$dst")"; then
    cleanup_backup_stage "$stage" "$dst"
    return 1
  fi

  if ! mv -- "$stage" "$dst"; then
    cleanup_backup_stage "$stage" "$dst"
    return 1
  fi
}

# El despliegue usa copias independientes. Así el usuario puede editar su
# configuración instalada aunque mueva o elimine este repositorio.
copy() {
  local src="$DOTFILES/$1" dst="$2" parent stage backup_path
  [ -e "$src" ] || { printf '  FALTA  %s (instalacion abortada)\n' "$1" >&2; return 1; }
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then
      printf '  REMOVE  symlink %s\n' "$dst"
      run rm -- "$dst"
    fi
  elif cmp -s -- "$src" "$dst"; then
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    backup "$dst"
    run mkdir -p -- "$(dirname -- "$dst")"
    run cp -p -- "$src" "$dst"
    printf '  COPY   %s\n' "$dst"
    return 0
  fi

  parent="$(dirname -- "$dst")"
  mkdir -p -- "$parent"
  if ! stage="$(mktemp "$parent/.dotfiles-file-stage.XXXXXX")"; then
    return 1
  fi

  # Copia primero a un archivo temporal del mismo directorio. Si cp falla,
  # el destino original todavía no se ha movido ni truncado.
  if ! cp -p -- "$src" "$stage"; then
    rm -f -- "$stage"
    return 1
  fi

  backup_path="$dst.backup.$STAMP"
  if ! backup "$dst"; then
    rm -f -- "$stage"
    return 1
  fi

  if ! mv -- "$stage" "$dst"; then
    rm -f -- "$stage"
    if [ -e "$backup_path" ] || [ -L "$backup_path" ]; then
      mv -- "$backup_path" "$dst" || true
    fi
    return 1
  fi

  printf '  COPY   %s\n' "$dst"
}

copy_dir() {
  local src="$DOTFILES/$1" dst="$2"
  local backup_dst changes
  [ -d "$src" ] || { printf '  FALTA  %s (instalacion abortada)\n' "$1" >&2; return 1; }
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf '  REMOVE  symlink %s\n' "$dst"
    run rm -- "$dst"
  elif [ -L "$dst" ] || { [ -e "$dst" ] && [ ! -d "$dst" ]; }; then
    backup "$dst"
  fi
  if [ -d "$dst" ]; then
    changes=$(rsync -rlptc --dry-run --itemize-changes --delete \
      "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/")
    if [ -n "$changes" ]; then
      case "$dst" in
        "$HOME"/*) backup_dst="$BACKUP_ROOT/${dst#"$HOME"/}" ;;
        *)         backup_dst="$BACKUP_ROOT/absolute/${dst#/}" ;;
      esac
      backup_dir "$dst" "$backup_dst"
    fi
  fi
  run mkdir -p -- "$dst"
  # --checksum evita falsos MATCH cuando tamaño y mtime coinciden por azar.
  run rsync -rlptc --delete "${RSYNC_EXCLUDES[@]}" "$src/" "$dst/"
  printf '  COPY   %s/\n' "$dst"
}

printf 'repo: %s\n\n' "$DOTFILES"

validate_sources

# Las herramientas externas corren antes de copiar los archivos de shell: así
# el `.zshrc` gestionado conserva la última palabra sobre la configuración.
# validate_sources ya comprobó cada archivo y directorio que se copiará antes de
# llegar a prerrequisitos, descargas o cualquier cambio en el HOME.
install_macos_prerequisites
printf '\n'
install_bootstrap_tools
printf '\n'

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
copy config/herdr/config.toml "$HOME/.config/herdr/config.toml"
copy config/btop/btop.conf "$HOME/.config/btop/btop.conf"

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
# Claude Code y los overlays de proveedores leen estos archivos desde runtime.
# Se copian (no se enlazan) porque Claude Code puede reescribir settings.json y
# las credenciales se resuelven por helper externo, nunca desde estos archivos.
for source_path in "${CLAUDE_FILES[@]}"; do
  copy "$source_path" "$HOME/.claude/${source_path##*/}"
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
