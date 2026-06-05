# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Disable network check on every shell start
zstyle ':omz:update' mode disabled

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Mark untracked files as dirty only when needed. Speeds up large repos.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(gitfast)

# Compinit caching — evita doble inicializacion (oh-my-zsh skip global)
skip_global_compinit=1
ZSH_COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump-${ZSH_VERSION}"
autoload -Uz compinit
if [[ -f "$ZSH_COMPDUMP" ]] && [[ $(find "$ZSH_COMPDUMP" -mtime -1 2>/dev/null) ]]; then
  compinit -C -d "$ZSH_COMPDUMP"
else
  compinit -d "$ZSH_COMPDUMP"
fi

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'

myip() {
    echo "Internal IP:"
    ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print "  " $2}'
    echo "External IP:"
    curl -s ifconfig.me && echo
}
alias tailscale="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
alias ports="lsof -iTCP -sTCP:LISTEN -n -P"
alias ls='eza --git --group-directories-first --icons'
alias l='eza --git --group-directories-first --icons'
alias ll='eza --long --header --icons --git --group-directories-first -alF'
alias la='eza --git --group-directories-first --icons -a'
alias lt='eza --git --level=2 --icons --group-directories-first -T'
alias ltl='eza --git --group-directories-first --icons -TL'
alias lsn='eza --long --header --icons --git --group-directories-first --no-permissions --no-user --time-style=relative'
alias grep="rg --color=auto"
alias mkdir="mkdir -p"
alias cat='bat --paging=never'
alias less='bat'
alias z='zoxide query -i'
alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'

# Pyenv — lazy-load shims PATH + defer init (~300ms ahorro, elimina jitter)
export PATH="$HOME/.pyenv/shims:$PATH"
pyenv() {
  unfunction pyenv
  eval "$(command pyenv init - zsh)"
  pyenv "$@"
}

# Zoxide
eval "$(zoxide init zsh)"

# fzf — fuzzy finder (Ctrl+T files, Alt+C dirs)
# fd as backend: faster, gitignore-aware. Ctrl-R history via atuin.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
source <(fzf --zsh) 2>/dev/null

# atuin — shell history SQLite + fuzzy search (replaces Ctrl-R)
eval "$(atuin init zsh)" 2>/dev/null

# Console Ninja
PATH=~/.console-ninja/.bin:$PATH

# Claude Code and VS Code paths
export PATH="$HOME/.local/bin:$PATH"
export PATH="/usr/local/bin:$PATH"

# Android SDK
export ANDROID_HOME=$HOME/Library/Android/sdk
[[ -d "$ANDROID_HOME" ]] && {
  export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator"
}

# Go Lang
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Alias Tunnel pinggy
tunnel() { ssh -p 443 -R0:localhost:${1:-3000} a.pinggy.io; }

# opencode
export PATH="$HOME/.opencode/bin:$PATH"

# Engram Cloud (NAS via Tailscale) — set token in ~/.engram-cloud.env
[[ -f "$HOME/.engram-cloud.env" ]] && source "$HOME/.engram-cloud.env"

# Herd PHP configuration
[[ -d "$HOME/Library/Application Support/Herd/config/php/84" ]] && \
  export HERD_PHP_84_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/84/"

# Herd NVM — PATH estático (0ms) + lazy-load nvm.sh solo cuando se necesita
# Para auto-switch de version segun .nvmrc usa 'nvm use' manualmente, o
# instala 'fnm'/'vfox' (Rust nativos, lazy-friendly).
export NVM_DIR="$HOME/Library/Application Support/Herd/config/nvm"
# Agrega bin del default al PATH inmediatamente — node disponible para scripts de pnpm global
_nvm_default=$(cat "$NVM_DIR/alias/default" 2>/dev/null)
if [[ -f "$NVM_DIR/alias/$_nvm_default" ]]; then
  _nvm_default=$(cat "$NVM_DIR/alias/$_nvm_default")
else
  # Alias es un patron de version (ej: "24") — resolver contra versiones instaladas
  _nvm_default=$(ls "$NVM_DIR/versions/node/" 2>/dev/null | grep "^v${_nvm_default}\." | sort -V | tail -1)
fi
[[ -d "$NVM_DIR/versions/node/$_nvm_default/bin" ]] && \
  export PATH="$NVM_DIR/versions/node/$_nvm_default/bin:$PATH"
unset _nvm_default
# Solo nvm necesita lazy-load. node/npm/npx/pnpm/pnpx vienen del PATH estático (línea 206).
# Wrappers eliminados: causaban recursión infinita si _nvm_lazy_load no se cargaba en entornos no interactivos.
_nvm_lazy_load() {
  unfunction nvm 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}
nvm()   { _nvm_lazy_load; nvm "$@"; }

# Herd shell config — DESACTIVADO (registraba chpwd hook que cargaba nvm en cada cd)
# [[ -f "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh" ]] && \
#   builtin source "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh"

# Herd PHP binary
[[ -d "$HOME/Library/Application Support/Herd/bin" ]] && \
  export PATH="$HOME/Library/Application Support/Herd/bin":$PATH

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# p10k transient prompt
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always

# zsh-syntax-highlighting — colorea comandos mientras escribis (debe ir al final)
source "${HOMEBREW_PREFIX:-$(brew --prefix)}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" 2>/dev/null

# zsh-autosuggestions — sugerencias grises basadas en historial
source "${HOMEBREW_PREFIX:-$(brew --prefix)}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" 2>/dev/null

# Show system info on interactive terminal only (skip IDE terminals, pipes, tmux internals)
if [[ -o interactive ]] && [[ -t 0 ]] && [[ -z "$VSCODE_INJECTION" ]] && [[ -z "$JETBRAINS_IDE" ]]; then
command -v fastfetch &>/dev/null && fastfetch
fi


# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
