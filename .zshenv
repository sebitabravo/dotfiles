# Corre en TODA invocacion de zsh, incluidos scripts no interactivos.
#
# En shells de login /etc/zprofile ejecuta path_helper DESPUES de este archivo y
# reconstruye el PATH completo, mandando al final todo lo que agreguemos aca. Por
# eso setup_user_path() se define aca (para que los scripts tengan las herramientas)
# pero se vuelve a invocar desde .zprofile, que es donde el orden queda firme.

export HOMEBREW_PREFIX=/opt/homebrew

export GOPATH="$HOME/go"
export PNPM_HOME="$HOME/Library/pnpm"
export ANDROID_HOME="$HOME/Library/Android/sdk"

# Mueve el directorio al frente del PATH aunque ya este presente. Un prepend que
# solo agrega si falta no serviria: path_helper deja las entradas presentes pero
# en el orden equivocado, y hay que poder reordenarlas.
path_promote() {
  [[ -d "$1" ]] || return 0
  PATH="${PATH//":$1:"/:}"
  PATH="${PATH#"$1:"}"
  PATH="${PATH%":$1"}"
  export PATH="$1:$PATH"
}

path_append() {
  [[ -d "$1" ]] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$PATH:$1" ;;
  esac
}

# Herd NVM — resuelve el bin de la version 'default' leyendo los alias, sin cargar
# nvm.sh. Deja node disponible incluso en shells no interactivos.
export NVM_DIR="$HOME/Library/Application Support/Herd/config/nvm"
_nvm_default=$(cat "$NVM_DIR/alias/default" 2>/dev/null)
if [[ -f "$NVM_DIR/alias/$_nvm_default" ]]; then
  _nvm_default=$(cat "$NVM_DIR/alias/$_nvm_default")
elif [[ ! -d "$NVM_DIR/versions/node/$_nvm_default" ]]; then
  # El alias es un patron de version (ej: "24") — resolver a la mas alta instalada.
  _nvm_default=$(ls "$NVM_DIR/versions/node/" 2>/dev/null | grep "^v${_nvm_default}\." | sort -V | tail -1)
fi
export NVM_DEFAULT_BIN="$NVM_DIR/versions/node/$_nvm_default/bin"
unset _nvm_default

# Unica definicion del orden de prioridad del PATH. El ultimo path_promote gana,
# asi que el node de Herd queda por delante del symlink que Hermes deja en
# ~/.local/bin.
setup_user_path() {
  # Red de seguridad: en shells de login esto ya lo pone brew shellenv desde
  # .zprofile, pero un shell interactivo no-login nunca lo ejecuta y se quedaria
  # sin fzf, zoxide ni el resto de Homebrew.
  path_append "$HOMEBREW_PREFIX/bin"
  path_append "$HOMEBREW_PREFIX/sbin"

  path_promote "$HOME/.pyenv/shims"
  path_promote "$HOME/.console-ninja/.bin"
  path_promote "$HOME/.opencode/bin"
  path_promote "$PNPM_HOME/bin"
  path_promote "$HOME/Library/Application Support/Herd/bin"
  path_promote "$HOME/.local/bin"
  path_promote "$NVM_DEFAULT_BIN"

  path_append "$GOPATH/bin"
  path_append "$HOME/.spicetify"
  path_append "$ANDROID_HOME/tools"
  path_append "$ANDROID_HOME/platform-tools"
  path_append "$ANDROID_HOME/emulator"
}

setup_user_path
