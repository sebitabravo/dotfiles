# Corre en shells de login, despues de /etc/zprofile (path_helper).

eval "$(/opt/homebrew/bin/brew shellenv zsh)"
export HOMEBREW_NO_ANALYTICS=1

# init.zsh de OrbStack no es idempotente: prepend-ea su bin cada vez que se
# sourcea. Si ya esta en el PATH, el script completo ya corrio antes.
if [[ -f "$HOME/.orbstack/shell/init.zsh" ]] && [[ ":$PATH:" != *":$HOME/.orbstack/bin:"* ]]; then
  source "$HOME/.orbstack/shell/init.zsh" 2>/dev/null
fi

# path_helper y brew shellenv ya reordenaron el PATH; reafirmamos la prioridad
# definida en .zshenv. Es idempotente, no duplica entradas.
setup_user_path
