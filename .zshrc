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
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

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

export BROWSER=google-chrome-stable
export EDITOR=nvim
export TERMINAL=kitty

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

alias ls='ls --color=auto'
alias ll='ls -lah'
alias vim='nvim'

autoload -Uz compinit
compinit

unsetopt LIST_AMBIGUOUS

zstyle ':completion:*' auto-list false

# --- pywal integration: load and auto-reload color variables ---
# Enable variable expansion in prompts (harmless even with p10k).
setopt prompt_subst

# Path to pywal colors
_wal_colors_file="${HOME}/.cache/wal/colors.sh"

# Load once now (if present)
if [[ -f $_wal_colors_file ]]; then
  source "$_wal_colors_file"
fi

# Auto-reload pywal colors whenever the file changes (e.g., after wallswitch)
typeset -g _wal_colors_mtime=0
_reload_wal_colors_if_needed() {
  # GNU/BSD stat compatibility
  local mtime
  mtime=$(stat -c %Y "$_wal_colors_file" 2>/dev/null || stat -f %m "$_wal_colors_file" 2>/dev/null || echo 0)
  if [[ $mtime -gt $_wal_colors_mtime ]]; then
    [[ -f "$_wal_colors_file" ]] && source "$_wal_colors_file"
    _wal_colors_mtime=$mtime
  fi
}
precmd_functions+=(_reload_wal_colors_if_needed)
# --- end pywal integration ---

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# p10k color overrides (use pywal)

# readable dir block
typeset -g POWERLEVEL9K_DIR_BACKGROUND="${color1}"     # softer violet (e.g. #906FB0)
typeset -g POWERLEVEL9K_DIR_FOREGROUND="#ffffff"       # pure white for max contrast
typeset -g POWERLEVEL9K_DIR_PATH_FOREGROUND="#ffffff"
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND="#ffffff"

# anchors (~, /) slightly dimmer (but still readable)
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND="${color7}"  # your light text
typeset -g POWERLEVEL9K_DIR_ANCHOR_BOLD=false

# drop status from right prompt
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

# --- zsh-syntax-highlighting tuned for your wal palette ---

# Valid commands/keywords/functions: use color3 + bold
ZSH_HIGHLIGHT_STYLES[command]="fg=${color3},bold"
ZSH_HIGHLIGHT_STYLES[builtin]="fg=${color3},bold"
ZSH_HIGHLIGHT_STYLES[alias]="fg=${color3},bold"
ZSH_HIGHLIGHT_STYLES[reserved-word]="fg=${color3},bold"   # if, for, while
ZSH_HIGHLIGHT_STYLES[function]="fg=${color3},bold"        # user-defined functions

# Options / separators: readable neutral
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]="fg=${color7}"     # #d5c9e0
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]="fg=${color7}"
ZSH_HIGHLIGHT_STYLES[commandseparator]="fg=${color6}"         # #B195CA

# Paths
ZSH_HIGHLIGHT_STYLES[path]="fg=${color7}"                     # existing path = readable
ZSH_HIGHLIGHT_STYLES[path_prefix]="fg=${color7}"
ZSH_HIGHLIGHT_STYLES[path_approx]="fg=${color3},bold"         # approx/glob = violet
ZSH_HIGHLIGHT_STYLES[globbing]="fg=${color5}"

# Strings & assignments
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]="fg=${color4}"   # #9E7AC3
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]="fg=${color4}"
ZSH_HIGHLIGHT_STYLES[assign]="fg=${color7}"

# Errors / unknown: keep clearly red regardless of wal palette
ZSH_HIGHLIGHT_STYLES[unknown-token]="fg=#ff5f5f,bold"
ZSH_HIGHLIGHT_STYLES[unknown-option]="fg=#ff5f5f,bold"
ZSH_HIGHLIGHT_STYLES[redirection]="fg=#ff5f5f,bold"
ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]="fg=#ff5f5f,bold"
ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]="fg=#ff5f5f,bold"

# Comments faint
ZSH_HIGHLIGHT_STYLES[comment]="fg=${color8}"                  # #958c9c

# --- end styles ---

