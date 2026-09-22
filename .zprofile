# Corre en shells de login, despues de /etc/zprofile (path_helper).

eval "$(/opt/homebrew/bin/brew shellenv zsh)"
export HOMEBREW_NO_ANALYTICS=1

# path/fpath are unique arrays (declared in .zshenv), so OrbStack's append-only
# init remains idempotent even in nested login shells.
if [[ -f "$HOME/.orbstack/shell/init.zsh" ]]; then
  source "$HOME/.orbstack/shell/init.zsh" 2>/dev/null
fi

# path_helper y brew shellenv ya reordenaron el PATH; reafirmamos la prioridad
# definida en .zshenv. Es idempotente, no duplica entradas.
setup_user_path
