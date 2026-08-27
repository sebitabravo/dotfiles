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
    *) SELF="$(dirname -- "$SELF")/$LINK" ;;
  esac
done
DOTFILES="$(cd -- "$(dirname -- "$SELF")" && pwd -P)"

case "$#:${1:-}" in
  0:) DRY_RUN=0 ;;
  1:--dry-run) DRY_RUN=1 ;;
  *)
    printf 'uso: %s [--dry-run]\n' "$0" >&2
    exit 2
    ;;
esac
STAMP="$(date +%Y%m%d%H%M%S)"
BACKUP_ROOT="$HOME/.dotfiles-backups/$STAMP"
REMOTE_INSTALLER_MANIFEST="$DOTFILES/config/install/remote-installers.sha256"
P10K_URL='https://github.com/romkatv/powerlevel10k.git'
P10K_COMMIT='3308262dfbd743b6e1d3956a2b5572f7a049d692'
FONT_DESTINATION="$HOME/Library/Fonts"
# Fuentes versionadas que usa la configuracion. Se mantienen aqui, en vez del
# manifiesto de instaladores remotos, porque este flujo instala archivos y no
# ejecuta codigo remoto.
FONT_LABELS=(
  'Cascadia Code PL'
  'FiraCode Nerd Font'
  'JetBrains Mono'
  'Meslo LG'
  'IosevkaTerm NF'
)
FONT_URLS=(
  'https://github.com/microsoft/cascadia-code/releases/download/v2407.24/CascadiaCode-2407.24.zip'
  'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/FiraCode.zip'
  'https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip'
  'https://codeload.github.com/andreberg/Meslo-Font/zip/09a431d546d211130352c28eb0466e5d7d5aeaf0'
  'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.2.1/IosevkaTerm.zip'
)
FONT_SHA256S=(
  'e67a68ee3386db63f48b9054bd196ea752bc6a4ebb4df35adce6733da50c8474'
  '4ee8fbafecfc90460399b9828270b8ece30ccbf60b3ab875d64ff77696c6e262'
  '6f6376c6ed2960ea8a963cd7387ec9d76e3f629125bc33d1fdcd7eb7012f7bbf'
  '930d960c30ff582c1ca27721f74cc93c0f51e74f63b88360904eaa1af65f55e4'
  '4d2c7fc44f215cd762ceab5167aa13285f179e83f36d56a1129c2871b9552080'
)
# El zip de Meslo LG no trae .ttf sueltos: distribuye cada version como un zip
# anidado (dist/<version>/Meslo LG <version>.zip). Se fija la ruta y el
# checksum del zip interno para poder verificarlo antes de extraerlo, igual
# que el zip externo.
FONT_NESTED_ZIPS=(
  ''
  ''
  ''
  'dist/v1.2.1/Meslo LG v1.2.1.zip'
  ''
)
FONT_NESTED_SHA256S=(
  ''
  ''
  ''
  'd0bcb7668dda8fa1a0f8162d626adb434c32854e243b5bd52a717cf569af08d0'
  ''
)
# These parallel lists are the bootstrap allow-list. The manifest must contain
# exactly one `label|sha256|url` record for every entry before any bootstrap
# network access or mutation is allowed.
REMOTE_INSTALLER_LABELS=(
  'Homebrew'
  'Oh My Zsh'
  'Herdr'
  'CodeGraph'
  'Gentle AI'
  'OpenCode'
  'Codex'
  'Cursor Agent'
  'Antigravity CLI'
  'Claude Code'
  'GitHub Copilot CLI'
  'Kilo Code'
)
REMOTE_INSTALLER_URLS=(
  'https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh'
  'https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh'
  'https://herdr.dev/install.sh'
  'https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh'
  'https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh'
  'https://opencode.ai/install'
  'https://chatgpt.com/codex/install.sh'
  'https://cursor.com/install'
  'https://antigravity.google/cli/install.sh'
  'https://claude.ai/install.sh'
  'https://gh.io/copilot-install'
  'https://kilo.ai/cli/install'
)
# Set only while a verified remote installer is present. The trap removes this
# exact mktemp path and never recursively removes a caller-controlled directory.
P10K_STAGE=''
REMOTE_INSTALLER_SCRIPT=''
FONT_STAGE=''
CLAUDE_JSON_SNAPSHOT=''
CLAUDE_JSON_SNAPSHOT_EXISTS=0
CLAUDE_JSON_TRANSACTION_ACTIVE=0
# This seam keeps the production defaults explicit while letting the focused
# tests emulate standard Homebrew locations without writing under /opt or
# /usr/local. It only changes which executable paths are inspected.
HOMEBREW_BREW_CANDIDATES="${DOTFILES_HOMEBREW_BREW_CANDIDATES:-/opt/homebrew/bin/brew:/usr/local/bin/brew}"

run() { if [ "$DRY_RUN" -eq 1 ]; then printf '  DRY  %s\n' "$*"; else "$@"; fi; }

restore_claude_json_snapshot() {
  local restore_stage=''

  [ "$CLAUDE_JSON_TRANSACTION_ACTIVE" -eq 1 ] || return 0
  if [ "$CLAUDE_JSON_SNAPSHOT_EXISTS" -eq 1 ]; then
    restore_stage="$(mktemp "$(dirname -- "$HOME/.claude.json")/.claude-json-restore.XXXXXX")" || {
      printf '%s\n' '  ERROR  no se pudo preparar la restauracion transaccional de ~/.claude.json' >&2
      return 1
    }
    if ! cp -p -- "$CLAUDE_JSON_SNAPSHOT" "$restore_stage" ||
      ! mv -- "$restore_stage" "$HOME/.claude.json"; then
      rm -f -- "$restore_stage"
      printf '%s\n' '  ERROR  no se pudo restaurar ~/.claude.json desde el snapshot transaccional' >&2
      return 1
    fi
  elif ! rm -f -- "$HOME/.claude.json"; then
    printf '%s\n' '  ERROR  no se pudo eliminar el nuevo ~/.claude.json tras fallar el registro MCP' >&2
    return 1
  fi

  rm -f -- "$CLAUDE_JSON_SNAPSHOT"
  CLAUDE_JSON_SNAPSHOT=''
  CLAUDE_JSON_SNAPSHOT_EXISTS=0
  CLAUDE_JSON_TRANSACTION_ACTIVE=0
}

abort_claude_mcp_transaction() {
  local message="$1"

  if ! restore_claude_json_snapshot; then
    printf '%s\n' '  ERROR  el rollback transaccional de ~/.claude.json fallo; no se exponen sus contenidos' >&2
  fi
  printf '  ERROR  %s\n' "$message" >&2
  return 1
}

cleanup_bootstrap_staging() {
  if [ "$CLAUDE_JSON_TRANSACTION_ACTIVE" -eq 1 ]; then
    restore_claude_json_snapshot || true
  fi
  [ -z "$REMOTE_INSTALLER_SCRIPT" ] || rm -f -- "$REMOTE_INSTALLER_SCRIPT"
  [ -z "$P10K_STAGE" ] || rm -rf -- "$P10K_STAGE"
  [ -z "$FONT_STAGE" ] || rm -rf -- "$FONT_STAGE"
}

trap cleanup_bootstrap_staging EXIT

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
      *)
        PATH="$brew_dir:$PATH"
        export PATH
        ;;
    esac
    return 0
  done
  return 0
}

expected_remote_installer_index() {
  local wanted_label="$1" index
  for ((index = 0; index < ${#REMOTE_INSTALLER_LABELS[@]}; index++)); do
    [ "${REMOTE_INSTALLER_LABELS[$index]}" = "$wanted_label" ] && {
      printf '%s\n' "$index"
      return 0
    }
  done
  return 1
}

validate_remote_installer_manifest() {
  local line label sha256 url delimiters index expected_url
  local -a seen

  [ -f "$REMOTE_INSTALLER_MANIFEST" ] || {
    printf '  FALTA  manifiesto de instaladores remotos: %s\n' "$REMOTE_INSTALLER_MANIFEST" >&2
    return 1
  }

  for ((index = 0; index < ${#REMOTE_INSTALLER_LABELS[@]}; index++)); do
    seen[index]=0
  done

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '' | '#'*) continue ;;
    esac

    delimiters="${line//[^|]/}"
    if [ "${#delimiters}" -ne 2 ]; then
      printf '  ERROR  manifiesto remoto invalido (se esperaba label|sha256|url): %s\n' "$line" >&2
      return 1
    fi

    IFS='|' read -r label sha256 url <<EOF
$line
EOF
    if [ -z "$label" ] || [ -z "$sha256" ] || [ -z "$url" ] ||
      ! [[ "$sha256" =~ ^[0-9a-f]{64}$ ]]; then
      printf '  ERROR  manifiesto remoto invalido (label, SHA-256 hexadecimal y URL HTTPS requeridos): %s\n' "$line" >&2
      return 1
    fi

    index="$(expected_remote_installer_index "$label")" || {
      printf '  ERROR  manifiesto remoto contiene etiqueta inesperada: %s\n' "$label" >&2
      return 1
    }
    if [ "${seen[$index]}" -eq 1 ]; then
      printf '  ERROR  manifiesto remoto contiene etiqueta duplicada: %s\n' "$label" >&2
      return 1
    fi

    expected_url="${REMOTE_INSTALLER_URLS[$index]}"
    if [ "$url" != "$expected_url" ]; then
      printf '  ERROR  URL no autorizada para %s: %s\n' "$label" "$url" >&2
      return 1
    fi
    seen[index]=1
  done <"$REMOTE_INSTALLER_MANIFEST"

  for ((index = 0; index < ${#REMOTE_INSTALLER_LABELS[@]}; index++)); do
    if [ "${seen[$index]}" -ne 1 ]; then
      printf '  ERROR  manifiesto remoto sin registro para: %s\n' "${REMOTE_INSTALLER_LABELS[$index]}" >&2
      return 1
    fi
  done
}

remote_installer_record() {
  local wanted_label="$1" line label sha256 url
  REMOTE_INSTALLER_SHA256=''
  REMOTE_INSTALLER_URL=''

  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '' | '#'*) continue ;;
    esac
    IFS='|' read -r label sha256 url <<EOF
$line
EOF
    if [ "$label" = "$wanted_label" ]; then
      REMOTE_INSTALLER_SHA256="$sha256"
      REMOTE_INSTALLER_URL="$url"
      return 0
    fi
  done <"$REMOTE_INSTALLER_MANIFEST"

  printf '  ERROR  no existe un checksum autorizado para %s\n' "$wanted_label" >&2
  return 1
}

sha256_file() {
  if command_exists shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command_exists sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  else
    printf '%s\n' '  ERROR  se requiere shasum o sha256sum para verificar instaladores remotos' >&2
    return 1
  fi
}

install_configured_fonts() {
  local index archive extract_dir actual font_file font_name destination
  local font_count nested_zip_path nested_zip_file
  local -a font_files font_copy_needed

  [ "$(uname -s)" = 'Darwin' ] || {
    printf '%s\n' '  SKIP   fuentes (solo se instalan en macOS)'
    return 0
  }

  if [ "$DRY_RUN" -eq 1 ]; then
    for ((index = 0; index < ${#FONT_LABELS[@]}; index++)); do
      printf '  DRY  descarga HTTPS verificada de %s (SHA-256 %s)\n' \
        "${FONT_URLS[$index]}" "${FONT_SHA256S[$index]}"
      printf '  DRY  unzip en staging temporal  # %s\n' "${FONT_LABELS[$index]}"
      if [ -n "${FONT_NESTED_ZIPS[$index]}" ]; then
        printf '  DRY  verificar y extraer zip anidado %s (SHA-256 %s)\n' \
          "${FONT_NESTED_ZIPS[$index]}" "${FONT_NESTED_SHA256S[$index]}"
      fi
    done
    printf '  DRY  instalar .ttf nuevos desde staging en %s\n' "$FONT_DESTINATION"
    return 0
  fi

  require_command curl 'fuentes'
  require_command unzip 'fuentes'
  require_command find 'fuentes'
  require_command cmp 'fuentes'

  FONT_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-fonts.XXXXXX")" || {
    printf '%s\n' '  ERROR  no se pudo preparar el staging temporal de fuentes' >&2
    return 1
  }

  for ((index = 0; index < ${#FONT_LABELS[@]}; index++)); do
    archive="$FONT_STAGE/$index.zip"
    extract_dir="$FONT_STAGE/$index"
    printf '  DOWNLOAD %s\n' "${FONT_LABELS[$index]}"
    if ! curl --proto '=https' --proto-redir '=https' --tlsv1.2 --fail --silent --show-error \
      --location --connect-timeout 10 --max-time 300 --output "$archive" "${FONT_URLS[$index]}"; then
      printf '  ERROR  no se pudo descargar %s desde HTTPS\n' "${FONT_LABELS[$index]}" >&2
      return 1
    fi

    actual="$(sha256_file "$archive")" || return 1
    if [ "$actual" != "${FONT_SHA256S[$index]}" ]; then
      printf '  ERROR  checksum SHA-256 no coincide para %s\n' "${FONT_LABELS[$index]}" >&2
      return 1
    fi

    mkdir -p -- "$extract_dir"
    if ! unzip -q "$archive" -d "$extract_dir"; then
      printf '  ERROR  no se pudo extraer %s\n' "${FONT_LABELS[$index]}" >&2
      return 1
    fi

    font_count=0
    while IFS= read -r -d '' font_file; do
      font_files[${#font_files[@]}]="$font_file"
      font_count=$((font_count + 1))
    done < <(find "$extract_dir" -type f -name '*.ttf' -print0)

    if [ "$font_count" -eq 0 ] && [ -n "${FONT_NESTED_ZIPS[$index]}" ]; then
      nested_zip_path="${FONT_NESTED_ZIPS[$index]}"
      nested_zip_file="$(find "$extract_dir" -type f -path "*/$nested_zip_path" -print -quit)"
      if [ -z "$nested_zip_file" ]; then
        printf '  ERROR  %s no contiene el zip anidado esperado: %s\n' \
          "${FONT_LABELS[$index]}" "$nested_zip_path" >&2
        return 1
      fi

      actual="$(sha256_file "$nested_zip_file")" || return 1
      if [ "$actual" != "${FONT_NESTED_SHA256S[$index]}" ]; then
        printf '  ERROR  checksum SHA-256 no coincide para el zip anidado de %s\n' "${FONT_LABELS[$index]}" >&2
        return 1
      fi

      if ! unzip -q "$nested_zip_file" -d "$extract_dir"; then
        printf '  ERROR  no se pudo extraer el zip anidado de %s\n' "${FONT_LABELS[$index]}" >&2
        return 1
      fi

      while IFS= read -r -d '' font_file; do
        font_files[${#font_files[@]}]="$font_file"
        font_count=$((font_count + 1))
      done < <(find "$extract_dir" -type f -name '*.ttf' -print0)
    fi

    if [ "$font_count" -eq 0 ]; then
      printf '  ERROR  %s no contiene archivos .ttf; se aborta\n' "${FONT_LABELS[$index]}" >&2
      return 1
    fi
  done

  for ((index = 0; index < ${#font_files[@]}; index++)); do
    font_name="${font_files[$index]##*/}"
    destination="$FONT_DESTINATION/$font_name"
    if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
      font_copy_needed[index]=1
    elif [ -f "$destination" ] && cmp -s -- "${font_files[$index]}" "$destination"; then
      font_copy_needed[index]=0
      printf '  SKIP   fuente existente: %s\n' "$font_name"
    else
      printf '  ERROR  existe una fuente distinta con el mismo nombre: %s\n' "$destination" >&2
      return 1
    fi
  done

  mkdir -p -- "$FONT_DESTINATION" || {
    printf '  ERROR  no se pudo crear el destino de fuentes: %s\n' "$FONT_DESTINATION" >&2
    return 1
  }
  for ((index = 0; index < ${#font_files[@]}; index++)); do
    [ "${font_copy_needed[$index]}" -eq 1 ] || continue
    font_name="${font_files[$index]##*/}"
    if ! cp -p -- "${font_files[$index]}" "$FONT_DESTINATION/$font_name"; then
      printf '  ERROR  no se pudo instalar la fuente: %s\n' "$font_name" >&2
      return 1
    fi
    printf '  FONT   %s\n' "$font_name"
  done
}

download_verified_remote_installer() {
  local label="$1" actual

  remote_installer_record "$label"
  REMOTE_INSTALLER_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/dotfiles-remote-installer.XXXXXX")" || {
    printf '  ERROR  no se pudo preparar la descarga de %s\n' "$label" >&2
    return 1
  }
  require_command curl "$label"
  if ! curl --proto '=https' --proto-redir '=https' --tlsv1.2 --fail --silent --show-error \
    --location --connect-timeout 10 --max-time 120 --output "$REMOTE_INSTALLER_SCRIPT" "$REMOTE_INSTALLER_URL"; then
    printf '  ERROR  no se pudo descargar %s desde HTTPS\n' "$label" >&2
    return 1
  fi

  actual="$(sha256_file "$REMOTE_INSTALLER_SCRIPT")" || return 1
  if [ "$actual" != "$REMOTE_INSTALLER_SHA256" ]; then
    printf '  ERROR  checksum SHA-256 no coincide para %s; se aborta antes de ejecutar el instalador\n' "$label" >&2
    return 1
  fi
}

execute_verified_remote_installer() {
  local shell="$1"
  shift

  "$shell" "$REMOTE_INSTALLER_SCRIPT" "$@"
  rm -f -- "$REMOTE_INSTALLER_SCRIPT"
  REMOTE_INSTALLER_SCRIPT=''
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
    remote_installer_record 'Homebrew'
    printf '  DRY  descarga HTTPS verificada de %s -> /bin/bash  # Homebrew\n' "$REMOTE_INSTALLER_URL"
  else
    download_verified_remote_installer 'Homebrew'
    execute_verified_remote_installer /bin/bash
    prepare_homebrew_path
  fi
}

run_remote_installer() {
  local label="$1" shell="$2"
  shift 2

  if [ "$DRY_RUN" -eq 1 ]; then
    remote_installer_record "$label"
    printf '  DRY  descarga HTTPS verificada de %s -> %s' "$REMOTE_INSTALLER_URL" "$shell"
    if [ "$#" -gt 0 ]; then
      printf ' %s' "$*"
    fi
    printf '  # %s\n' "$label"
    return 0
  fi

  download_verified_remote_installer "$label"
  execute_verified_remote_installer "$shell" "$@"
}

install_remote_tool() {
  local label="$1" command_name="$2" shell="$3"
  shift 3

  if tool_exists "$command_name"; then
    printf '  SKIP   %s (ya existe %s)\n' "$label" "$command_name"
    return 0
  fi

  run_remote_installer "$label" "$shell" "$@"
}

install_bootstrap_tools() {
  local zsh_custom p10k_dir p10k_parent p10k_actual
  zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  p10k_dir="$zsh_custom/themes/powerlevel10k"

  printf '%s\n' 'herramientas de shell y agentes'

  if [ -d "$HOME/.oh-my-zsh" ]; then
    printf '%s\n' '  SKIP   Oh My Zsh (ya existe ~/.oh-my-zsh)'
  elif [ "$DRY_RUN" -eq 1 ]; then
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes run_remote_installer 'Oh My Zsh' sh --unattended
  else
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes run_remote_installer 'Oh My Zsh' sh --unattended
  fi

  if [ -d "$p10k_dir" ]; then
    printf '  SKIP   Powerlevel10k (ya existe %s)\n' "$p10k_dir"
  elif [ "$DRY_RUN" -eq 1 ]; then
    printf '  DRY  git init + fetch HTTPS %s + verificar %s + mover atomico a %s  # Powerlevel10k\n' \
      "$P10K_URL" "$P10K_COMMIT" "$p10k_dir"
  else
    require_command git 'Powerlevel10k'
    p10k_parent="$(dirname -- "$p10k_dir")"
    mkdir -p -- "$p10k_parent"
    P10K_STAGE="$(mktemp -d "$p10k_parent/.powerlevel10k-stage.XXXXXX")" || {
      printf '%s\n' '  ERROR  no se pudo preparar el staging temporal de Powerlevel10k' >&2
      return 1
    }
    git init --quiet "$P10K_STAGE/repo"
    git -C "$P10K_STAGE/repo" remote add origin "$P10K_URL"
    git -C "$P10K_STAGE/repo" \
      -c http.sslVersion=tlsv1.2 \
      -c http.lowSpeedLimit=1 \
      -c http.lowSpeedTime=30 \
      -c http.connectTimeout=10 \
      fetch --quiet --depth=1 origin "$P10K_COMMIT"
    git -C "$P10K_STAGE/repo" cat-file -e "$P10K_COMMIT^{commit}"
    git -C "$P10K_STAGE/repo" checkout --quiet --detach "$P10K_COMMIT"
    p10k_actual="$(git -C "$P10K_STAGE/repo" rev-parse HEAD)"
    if [ "$p10k_actual" != "$P10K_COMMIT" ]; then
      printf '  ERROR  Powerlevel10k no resolvio el commit esperado (%s)\n' "$P10K_COMMIT" >&2
      return 1
    fi
    [ ! -e "$p10k_dir" ] && [ ! -L "$p10k_dir" ] || {
      printf '  ERROR  Powerlevel10k aparecio durante la instalacion: %s\n' "$p10k_dir" >&2
      return 1
    }
    mv -- "$P10K_STAGE/repo" "$p10k_dir"
    rmdir -- "$P10K_STAGE"
    P10K_STAGE=''
  fi

  install_remote_tool 'Herdr' herdr sh
  install_remote_tool 'CodeGraph' codegraph sh
  install_remote_tool 'Gentle AI' gentle-ai bash
  install_remote_tool 'OpenCode' opencode bash --no-modify-path
  install_remote_tool 'Codex' codex sh
  install_remote_tool 'Cursor Agent' agent bash
  install_remote_tool 'Antigravity CLI' agy bash
  install_remote_tool 'Claude Code' claude bash
  install_remote_tool 'GitHub Copilot CLI' copilot bash
  install_remote_tool 'Kilo Code' kilo bash --no-modify-path
}

# Claude's user-scope MCP registry is separate from the managed manifest copied
# to ~/.claude/mcp-servers.json. The versioned manifest is the source of truth;
# the CLI is the only writer so unrelated user-owned entries stay untouched.
# shellcheck disable=SC2016
register_claude_mcp_servers() {
  [ "$DRY_RUN" -eq 0 ] || return 0

  local manifest name definition old_definition had_existing claude_bin jq_bin
  manifest="$DOTFILES/config/claude/mcp-servers.json"
  jq_bin="${DOTFILES_JQ_BIN:-$(command -v jq 2>/dev/null || true)}"
  [ -x "$jq_bin" ] || {
    printf '  ERROR  jq es requerido para registrar MCP administrados\n' >&2
    return 1
  }

  claude_bin="$(command -v claude 2>/dev/null || true)"
  if [ -z "$claude_bin" ]; then
    for candidate in \
      "$HOME/.local/bin/claude" \
      "$HOME/bin/claude" \
      "$HOME/.npm-global/bin/claude"; do
      if [ -x "$candidate" ]; then
        claude_bin="$candidate"
        break
      fi
    done
  fi
  [ -n "$claude_bin" ] || {
    printf '  ERROR  no se encontro Claude Code para registrar MCP administrados; ejecuta claude mcp add-json --scope user manualmente y repite la instalacion\n' >&2
    return 1
  }

  "$jq_bin" -e '.mcpServers | type == "object" and length > 0' "$manifest" >/dev/null 2>&1 || {
    printf '  ERROR  el manifiesto MCP administrado no contiene servidores validos: %s\n' "$manifest" >&2
    return 1
  }

  if ! CLAUDE_JSON_SNAPSHOT="$(mktemp "${TMPDIR:-/tmp}/dotfiles-claude-json.XXXXXX")"; then
    printf '%s\n' '  ERROR  no se pudo preparar el snapshot transaccional de ~/.claude.json' >&2
    return 1
  fi
  if [ -f "$HOME/.claude.json" ]; then
    if ! cp -p -- "$HOME/.claude.json" "$CLAUDE_JSON_SNAPSHOT"; then
      rm -f -- "$CLAUDE_JSON_SNAPSHOT"
      CLAUDE_JSON_SNAPSHOT=''
      printf '%s\n' '  ERROR  no se pudo preservar ~/.claude.json antes de registrar MCP administrados' >&2
      return 1
    fi
    CLAUDE_JSON_SNAPSHOT_EXISTS=1
  else
    rm -f -- "$CLAUDE_JSON_SNAPSHOT"
    CLAUDE_JSON_SNAPSHOT=''
    CLAUDE_JSON_SNAPSHOT_EXISTS=0
  fi
  CLAUDE_JSON_TRANSACTION_ACTIVE=1

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    definition="$("$jq_bin" -c --arg name "$name" '.mcpServers[$name]' "$manifest")" || {
      abort_claude_mcp_transaction "no se pudo leer la definicion MCP administrada: $name"
      return 1
    }
    old_definition=''
    had_existing=0

    if [ -f "$HOME/.claude.json" ] &&
      "$jq_bin" -e --arg name "$name" --argjson definition "$definition" \
        '.mcpServers[$name] == $definition' "$HOME/.claude.json" >/dev/null 2>&1; then
      :
    else
      if [ -f "$HOME/.claude.json" ] &&
        "$jq_bin" -e --arg name "$name" '.mcpServers[$name] != null' "$HOME/.claude.json" >/dev/null 2>&1; then
        had_existing=1
        old_definition="$("$jq_bin" -c --arg name "$name" '.mcpServers[$name]' "$HOME/.claude.json")" || {
          abort_claude_mcp_transaction "no se pudo capturar la definicion MCP existente: $name"
          return 1
        }
        "$claude_bin" mcp remove --scope user "$name" >/dev/null 2>&1 || {
          abort_claude_mcp_transaction "no se pudo reemplazar el MCP administrado existente: $name"
          return 1
        }
      fi
      if ! "$claude_bin" mcp add-json --scope user "$name" "$definition" >/dev/null 2>&1; then
        if [ "$had_existing" -eq 1 ] &&
          "$claude_bin" mcp add-json --scope user "$name" "$old_definition" >/dev/null 2>&1; then
          abort_claude_mcp_transaction "no se pudo registrar el MCP administrado $name con claude mcp add-json --scope user; se restauro la definicion anterior"
        elif [ "$had_existing" -eq 1 ]; then
          abort_claude_mcp_transaction "no se pudo registrar el MCP administrado $name y tampoco se pudo restaurar la definicion anterior"
        else
          abort_claude_mcp_transaction "no se pudo registrar el MCP administrado $name con claude mcp add-json --scope user"
        fi
        return 1
      fi
    fi

    if [ ! -f "$HOME/.claude.json" ] ||
      ! "$jq_bin" -e --arg name "$name" --argjson definition "$definition" \
        '.mcpServers[$name] == $definition' "$HOME/.claude.json" >/dev/null 2>&1 ||
      ! "$claude_bin" mcp get "$name" >/dev/null 2>&1; then
      abort_claude_mcp_transaction "no se pudo verificar el registro MCP administrado: $name"
      return 1
    fi
  done < <("$jq_bin" -r '.mcpServers | keys[]' "$manifest")

  rm -f -- "$CLAUDE_JSON_SNAPSHOT"
  CLAUDE_JSON_SNAPSHOT=''
  CLAUDE_JSON_SNAPSHOT_EXISTS=0
  CLAUDE_JSON_TRANSACTION_ACTIVE=0
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
  config/claude/ollama.settings.json
  config/claude/openrouter.settings.json
  # settings.json consolidates UserPromptSubmit into this dispatcher. Keep
  # both the dispatcher and its bounded GitHub helper in the preflight so a
  # clean clone cannot deploy a settings file that references missing code.
  config/claude/hooks/user-prompt-dispatcher.sh
  config/claude/hooks/lib/github-request.sh
)

REQUIRED_FILES=(
  config/install/remote-installers.sha256
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
  [ -e "$src" ] || {
    printf '  FALTA  %s (instalacion abortada)\n' "$1" >&2
    return 1
  }
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
  [ -d "$src" ] || {
    printf '  FALTA  %s (instalacion abortada)\n' "$1" >&2
    return 1
  }
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
        *) backup_dst="$BACKUP_ROOT/absolute/${dst#/}" ;;
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
validate_remote_installer_manifest

# Las herramientas externas corren antes de copiar los archivos de shell: así
# el `.zshrc` gestionado conserva la última palabra sobre la configuración.
# validate_sources ya comprobó cada archivo y directorio que se copiará antes de
# llegar a prerrequisitos, descargas o cualquier cambio en el HOME.
install_macos_prerequisites
printf '\n'
install_bootstrap_tools
printf '\n'
echo "fonts"
install_configured_fonts
printf '\n'

echo "shell"
copy .zshrc "$HOME/.zshrc"
copy .zshenv "$HOME/.zshenv"
copy .zprofile "$HOME/.zprofile"
copy .p10k.zsh "$HOME/.p10k.zsh"

echo "git"
copy .gitconfig "$HOME/.gitconfig"
copy config/git/.gitignore_global "$HOME/.gitignore_global"
copy_dir git-hooks "$HOME/.git-hooks"

echo "terminal"
copy_dir config/ghostty "$HOME/.config/ghostty"
copy config/herdr/config.toml "$HOME/.config/herdr/config.toml"
copy config/btop/btop.conf "$HOME/.config/btop/btop.conf"

echo "fastfetch"
copy_dir config/fastfetch "$HOME/.config/fastfetch"

echo "vscode"
VSCODE="$HOME/Library/Application Support/Code/User"
copy config/vscode/settings.json "$VSCODE/settings.json"
copy config/vscode/keybindings.json "$VSCODE/keybindings.json"
copy config/vscode/mcp.json "$VSCODE/mcp.json"

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

register_claude_mcp_servers

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
