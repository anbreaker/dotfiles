# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Homebrew (portable: Apple Silicon uses /opt/homebrew, Intel uses /usr/local)
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

# ~/.local/bin needs to be on PATH early: on Linux, install.sh's Herdr installer puts the
# binary there, and the Herdr auto-attach check further down in this file needs to find it.
export PATH="$HOME/.local/bin:$PATH"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="agnoster"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

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

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

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
plugins=(zsh-autocomplete git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# zsh-autocomplete: forzar que Tab/Shift-Tab naveguen el menú de completado
# (por defecto ya lo hacen, pero lo dejamos explícito por si otro plugin lo pisa)
bindkey -M menuselect '^I' menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete

# zsh-autocomplete pisa las flechas arriba/abajo con su propio widget de menú de
# historial, perdiendo el up-line-or-search de Oh My Zsh (buscar en el historial
# respetando el prefijo ya escrito). Lo restauramos.
bindkey '^[[A' up-line-or-search
bindkey '^[[B' down-line-or-search

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

# Maven configuration (manual download fallback; brew-installed mvn is already on PATH)
if [ -d /usr/local/apache-maven ]; then
    export M2_HOME=/usr/local/apache-maven
    export PATH=$M2_HOME/bin:$PATH
fi

# MySQL client (derived from the active Homebrew prefix)
if [ -n "$HOMEBREW_PREFIX" ] && [ -d "$HOMEBREW_PREFIX/opt/mysql-client/bin" ]; then
    export PATH="$HOMEBREW_PREFIX/opt/mysql-client/bin:$PATH"
fi

# Powerlevel10k configuration (disabled - using agnoster theme)
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Hide username in prompt (agnoster theme)
DEFAULT_USER=$USER

# Google Cloud SDK (from previous config)
# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/dev/COMMON/TOOLS/GCP/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/dev/COMMON/TOOLS/GCP/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/dev/COMMON/TOOLS/GCP/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/dev/COMMON/TOOLS/GCP/google-cloud-sdk/completion.zsh.inc"; fi

# ~/.local/bin on PATH (from previous config)
if [ -f "$HOME/.local/bin/env" ]; then . "$HOME/.local/bin/env"; fi

# Testcontainers (WLS-29): point at whichever Docker socket is actually in use.
# Mac uses Colima. Linux may use Docker Desktop (~/.docker/desktop/docker.sock) or the
# native Docker Engine, which already listens on the default /var/run/docker.sock (no
# override needed there).
if [ "$(uname -s)" = "Darwin" ] && command -v colima >/dev/null 2>&1; then
    export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
    export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE="/var/run/docker.sock"
elif [ "$(uname -s)" = "Linux" ] && [ -S "$HOME/.docker/desktop/docker.sock" ]; then
    export TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE="unix://$HOME/.docker/desktop/docker.sock"
fi

# Personal / machine-local config (e.g. export HERDR_SESSION_PER_PATH=1). Deliberately kept OUTSIDE
# this repo so a secret can never end up in a commit. Sourced here, before the Herdr auto-attach
# below, because that block may exec and the variables it reads must already be set.
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Auto-attach to Herdr in every new terminal (Ghostty, Terminal.app, etc.).
# Default: one shared Herdr session. With HERDR_SESSION_PER_PATH=1, each distinct cwd opens or
# reattaches to its own session (see the opt-in branch below).
# Rollback: comment out or delete this block and open a new tab.
WM_VAR="$HERDR_ENV"
WM_CMD="herdr"
if [[ $- == *i* ]] && command -v "$WM_CMD" >/dev/null 2>&1 && [[ -z "${WM_VAR#/}" ]] && [[ -z "$TMUX" ]] && [[ -z "$ZELLIJ" ]] && [[ -z "$HERDR_ENV" ]] && [[ -t 1 ]]; then
    if [[ "$HERDR_SESSION_PER_PATH" == "1" ]]; then
        # Opt-in: one Herdr session per directory. The name is the slugified basename plus a short
        # hash of the full path (avoids collisions between same-named folders) and is stable per
        # path, so reopening a terminal in the same directory reattaches to the same session.
        __herdr_slug="$(basename "$PWD" | tr -c 'a-zA-Z0-9' '-' | tr -s '-' | sed 's/^-//;s/-$//')"
        __herdr_hash="$(printf '%s' "$PWD" | cksum | cut -d' ' -f1 | cut -c1-6)"
        exec $WM_CMD --session "${__herdr_slug:-root}-${__herdr_hash}"
    fi
    exec $WM_CMD
fi

# Opt-in Herdr spaces (HERDR_AUTO_WORKSPACES=1): chpwd hook + agent wrapper. ~/.zshrc is a symlink
# into the repo, so resolve the real directory of this file to find herdr/workspaces.zsh.
__herdr_ws_file="${${(%):-%x}:A:h}/herdr/workspaces.zsh"
[[ -r "$__herdr_ws_file" ]] && source "$__herdr_ws_file"
unset __herdr_ws_file

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
