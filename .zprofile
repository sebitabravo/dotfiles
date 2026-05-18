# Homebrew environment setup
eval "$(/opt/homebrew/bin/brew shellenv)"

# OrbStack CLI tools (conditional — only if installed)
[[ -f "$HOME/.orbstack/shell/init.zsh" ]] && source "$HOME/.orbstack/shell/init.zsh" 2>/dev/null
