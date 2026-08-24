# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# El PATH no se toca en este archivo. Vive en .zshenv (setup_user_path) porque
# los shells no interactivos tambien lo necesitan.

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
alias ls='eza --git --group-directories-first --icons=auto'
alias l='eza --git --group-directories-first --icons=auto'
alias ll='eza --long --header --icons=auto --git --group-directories-first -al --classify=auto'
alias la='eza --git --group-directories-first --icons=auto -a'
alias lt='eza --git --level=2 --icons=auto --group-directories-first -T'
alias ltl='eza --git --group-directories-first --icons=auto -TL'
alias lsn='eza --long --header --icons=auto --git --group-directories-first --no-permissions --no-user --time-style=relative'
alias grep="rg --color=auto"
alias mkdir="mkdir -p"
alias cat='bat --paging=never'
alias less='bat'
alias sail='sh $([ -f sail ] && echo sail || echo vendor/bin/sail)'
alias rdd="$HOME/.claude/scripts/rdd.sh"
# zoxide provee 'z' (jump por frecency) y 'zi' (seleccion interactiva) via init.
# NO redefinir 'z' como alias: la expansion de alias gana sobre la funcion y rompe el jump.

# Pyenv — defer init (~300ms ahorro, elimina jitter). Los shims ya estan en el PATH.
pyenv() {
  unfunction pyenv
  eval "$(command pyenv init - zsh)"
  pyenv "$@"
}

# Zoxide
eval "$(zoxide init zsh)"

# fzf — fuzzy finder (Ctrl+T files, Alt+C dirs)
# fd as backend: faster, gitignore-aware. Ctrl-R lo toma fzf-history-widget.
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
source <(fzf --zsh) 2>/dev/null

# Alias Tunnel pinggy
tunnel() { ssh -p 443 -R0:localhost:${1:-3000} a.pinggy.io; }

# Engram Cloud (NAS via Tailscale) — set token in ~/.engram-cloud.env
[[ -f "$HOME/.engram-cloud.env" ]] && source "$HOME/.engram-cloud.env"

# Herd PHP configuration
[[ -d "$HOME/Library/Application Support/Herd/config/php/84" ]] && \
  export HERD_PHP_84_INI_SCAN_DIR="$HOME/Library/Application Support/Herd/config/php/84/"

# Herd NVM — el PATH de la version default lo resuelve .zshenv. Solo nvm en si
# necesita lazy-load; node/npm/npx vienen del PATH estatico.
# Para auto-switch segun .nvmrc corre 'nvm use' a mano, o instala fnm/vfox.
_nvm_lazy_load() {
  unfunction nvm 2>/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
}
nvm()   { _nvm_lazy_load; nvm "$@"; }

# Herd shell config — DESACTIVADO (registraba chpwd hook que cargaba nvm en cada cd)
# [[ -f "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh" ]] && \
#   builtin source "/Applications/Herd.app/Contents/Resources/config/shell/zshrc.zsh"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# p10k transient prompt
typeset -g POWERLEVEL9K_TRANSIENT_PROMPT=always

# Zsh usability plugins — optional at runtime, managed by Brewfile.
# Syntax highlighting must load after Oh My Zsh and the other widgets.
if [[ -r "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  builtin source "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi
if [[ -r "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  builtin source "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

fastfetch

# claude --deepseek -> settings separado con opusplan mapeado a DeepSeek.
# claude a secas queda igual que siempre (Anthropic).
claude() {
  local -a args=()
  local -a provider_env=(
    -u ANTHROPIC_API_KEY
    -u ANTHROPIC_AUTH_TOKEN
    -u ANTHROPIC_BASE_URL
    -u ANTHROPIC_MODEL
    -u ANTHROPIC_DEFAULT_OPUS_MODEL
    -u ANTHROPIC_DEFAULT_SONNET_MODEL
    -u ANTHROPIC_DEFAULT_HAIKU_MODEL
    -u ANTHROPIC_DEFAULT_FABLE_MODEL
    -u CLAUDE_CODE_SUBAGENT_MODEL
    -u CLAUDE_CODE_AUTO_COMPACT_WINDOW
    -u CLAUDE_CODE_MAX_CONTEXT_TOKENS
    -u CLAUDE_CODE_EFFORT_LEVEL
    -u CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY
    -u CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS
    -u CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
    -u ENABLE_TOOL_SEARCH
    -u API_TIMEOUT_MS
  )
  local use_ds=false use_glm=false use_kimi=false use_mm=false use_or=false use_ol=false use_qwen=false a deepseek_settings glm_settings kimi_settings minimax_settings openrouter_settings ollama_settings qwen_settings claude_bin
  local provider_count=0
  for a in "$@"; do
    case "$a" in
      --deepseek)   use_ds=true; provider_count=$((provider_count + 1)) ;;
      --glm)        use_glm=true; provider_count=$((provider_count + 1)) ;;
      --kimi)       use_kimi=true; provider_count=$((provider_count + 1)) ;;
      --minimax)    use_mm=true; provider_count=$((provider_count + 1)) ;;
      --openrouter) use_or=true; provider_count=$((provider_count + 1)) ;;
      --ollama)     use_ol=true; provider_count=$((provider_count + 1)) ;;
      --qwen)       use_qwen=true; provider_count=$((provider_count + 1)) ;;
      *)            args+=("$a") ;;
    esac
  done
  if (( provider_count > 1 )); then
    print -u2 'claude: selecciona un solo provider por invocacion'
    return 2
  fi
  if $use_ds; then
    deepseek_settings="$HOME/.claude/deepseek.settings.json"
    claude_bin="${commands[claude]:-}"
    if [[ ! -r "$deepseek_settings" ]]; then
      print -u2 "claude: no se encontro el settings de DeepSeek: $deepseek_settings"
      return 1
    fi
    if [[ -z "$claude_bin" ]]; then
      print -u2 "claude: binario de Claude Code no encontrado"
      return 1
    fi
    # Aislar el overlay: las variables exportadas por otro provider no deben
    # ganar sobre el settings seleccionado.
    env "${provider_env[@]}" \
      "$claude_bin" \
      --settings "$deepseek_settings" \
      "${args[@]}"
  elif $use_glm; then
    glm_settings="$HOME/.claude/glm.settings.json"
    claude_bin="${commands[claude]:-}"
    if [[ ! -r "$glm_settings" ]]; then
      print -u2 "claude: no se encontro el settings de GLM: $glm_settings"
      return 1
    fi
    if [[ -z "$claude_bin" ]]; then
      print -u2 "claude: binario de Claude Code no encontrado"
      return 1
    fi
    # Mismo patron que --deepseek: apiKeyHelper en el settings, sin tocar el
    # entorno aca. Z.AI documenta ANTHROPIC_AUTH_TOKEN, pero acepta X-Api-Key
    # igual (verificado con curl: 429 de saldo en ambos, ninguno 401 de auth).
    env "${provider_env[@]}" \
      "$claude_bin" \
      --settings "$glm_settings" \
      "${args[@]}"
  elif $use_kimi; then
    kimi_settings="$HOME/.claude/kimi.settings.json"
    claude_bin="${commands[claude]:-}"
    if [[ ! -r "$kimi_settings" ]]; then
      print -u2 "claude: no se encontro el settings de Kimi: $kimi_settings"
      return 1
    fi
    if [[ -z "$claude_bin" ]]; then
      print -u2 "claude: binario de Claude Code no encontrado"
      return 1
    fi
    env "${provider_env[@]}" \
      "$claude_bin" \
      --settings "$kimi_settings" \
      "${args[@]}"
  elif $use_mm; then
    minimax_settings="$HOME/.claude/minimax.settings.json"
    claude_bin="${commands[claude]:-}"
    if [[ ! -r "$minimax_settings" ]]; then
      print -u2 "claude: no se encontro el settings de MiniMax: $minimax_settings"
      return 1
    fi
    if [[ -z "$claude_bin" ]]; then
      print -u2 "claude: binario de Claude Code no encontrado"
      return 1
    fi
    env "${provider_env[@]}" \
      "$claude_bin" \
      --settings "$minimax_settings" \
      "${args[@]}"
  elif $use_or; then
    openrouter_settings="$HOME/.claude/openrouter.settings.json"
    claude_bin="${commands[claude]:-}"
    if [[ ! -r "$openrouter_settings" ]]; then
      print -u2 "claude: no se encontro el settings de OpenRouter: $openrouter_settings"
      return 1
    fi
    if [[ -z "$claude_bin" ]]; then
      print -u2 "claude: binario de Claude Code no encontrado"
      return 1
    fi
    env "${provider_env[@]}" \
      "$claude_bin" \
      --settings "$openrouter_settings" \
      "${args[@]}"
  elif $use_ol; then
    ollama_settings="$HOME/.claude/ollama.settings.json"
    claude_bin="${commands[claude]:-}"
    if [[ ! -r "$ollama_settings" ]]; then
      print -u2 "claude: no se encontro el settings de Ollama: $ollama_settings"
      return 1
    fi
    if [[ -z "$claude_bin" ]]; then
      print -u2 "claude: binario de Claude Code no encontrado"
      return 1
    fi
    env "${provider_env[@]}" \
      "$claude_bin" \
      --settings "$ollama_settings" \
      "${args[@]}"
  elif $use_qwen; then
    qwen_settings="$HOME/.claude/qwen.settings.json"
    claude_bin="${commands[claude]:-}"
    if [[ ! -r "$qwen_settings" ]]; then
      print -u2 "claude: no se encontro el settings de Qwen: $qwen_settings"
      return 1
    fi
    if [[ -z "$claude_bin" ]]; then
      print -u2 "claude: binario de Claude Code no encontrado"
      return 1
    fi
    env "${provider_env[@]}" \
      "$claude_bin" \
      --settings "$qwen_settings" \
      "${args[@]}"
  else
    command claude "$@"
  fi
}
