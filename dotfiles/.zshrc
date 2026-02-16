export SP_DEVENV_ROOT="${HOME}/devenv"
export SP_DOTFILES_ROOT="${SP_DEVENV_ROOT}/dotfiles"

function devenv_run_git {
    git -C ${SP_DEVENV_ROOT} "$@"
}

function HaveTool {
    if (( $+commands[$1] )); then
        echo true
    else
        echo false
    fi
}

function HaveFile {
    if [[ -f $1 ]]; then
        echo true
    else
        echo false
    fi
}


IS_SP_PRIVATE_HOST=$(HaveFile ${HOME}/.sp-private-host)

TOOL_ROOTS=(
    /opt/tools
    /opt/llvm-19
    ${HOME}/.local
    /opt/valgrind
    /opt/asn1c
    /opt/tmux
    /opt/nvim
    /opt/ripgrep
    ${HOME}/go
    /opt/go
)


export PATH=$PATH:~/devenv/scripts

# Setup fzf
if [[ -f ${SP_DOTFILES_ROOT}/fzf/bin/fzf ]]; then
    SP_FZF_ROOT=${SP_DOTFILES_ROOT}/fzf
    PATH="${PATH:+${PATH}:}${SP_FZF_ROOT}/bin"
fi

ADDED_PATHS=""
ADDED_MANPATHS=""
for tool in "${TOOL_ROOTS[@]}" ; do
    if [[ -d "${tool}/bin" ]] ; then
        ADDED_PATHS="${ADDED_PATHS}:${tool}/bin"
        if [[ -d "${tool}/man" ]] ; then
            ADDED_MANPATHS="${ADDED_MANPATHS}:${tool}/man"
        elif [[ -d "${tool}/doc" ]] ; then
            ADDED_MANPATHS="${ADDED_MANPATHS}:${tool}/doc"
        elif [[ -d "${tool}/share/man" ]] ; then
            ADDED_MANPATHS="${ADDED_MANPATHS}:${tool}/share/man"
        fi
    elif [[ -d "${tool}" ]]; then
        ADDED_PATHS="${ADDED_PATHS}:${tool}"
    fi
done

if [[ ! -z "${ADDED_PATHS}" ]] ; then
    export PATH=$PATH:${ADDED_PATHS}
fi

if [[ ! -z "${ADDED_MANPATHS}" ]] ; then
    export MANPATH=${MANPATH}:${ADDED_MANPATHS}
fi

# Must be after ADDED_PATHS stuff
HAVE_GIT=$(HaveTool git)
HAVE_FZF=$(HaveTool fzf)
HAVE_RIPGREP=$(HaveTool rg)
HAVE_FD=$(HaveTool fd)
HAVE_GO=$(HaveTool go)
HAVE_DOCKER=$(HaveTool docker)
HAVE_RUST=$(HaveTool rustc)
HAVE_DELTA=$(HaveTool delta)
HAVE_NODE=$(HaveTool node)
HAVE_TMUX=$(HaveTool tmux)
HAVE_LAZYGIT=$(HaveTool lazygit)

if [[ -d "/home/spastukhov/.local/bin" ]] ; then
    export PATH="/home/spastukhov/.local/bin:$PATH"
fi

[[ -f ~/.config/.pythonrc ]] && export PYTHONSTARTUP=~/.config/.pythonrc
[[ -f  ${HOME}/.cargo/env ]] && source "${HOME}/.cargo/env"
[[ -f ~/.ripgreprc        ]] && export RIPGREP_CONFIG_PATH=~/.ripgreprc

if [[ -d "/opt/rh/gcc-toolset-14" ]] ; then
    if [[ -d "/opt/rh/gcc-toolset-14/root/usr/share/man" ]] ; then
        export MANPATH="$MANPATH:/opt/rh/gcc-toolset-14/root/usr/share/man"
    fi
    if [[ -f /opt/rh/gcc-toolset-14/root/bin/gdb ]]; then
        export SYSTEMD_DEBUGGER=/opt/rh/gcc-toolset-14/root/bin/gdb
        alias gdb='/opt/rh/gcc-toolset-14/root/usr/bin/gdb'
    fi
elif [[ -d "/opt/rh/gcc-toolset-13" ]] ; then
    if [[ -d "/opt/rh/gcc-toolset-13/root/usr/share/man" ]] ; then
        export MANPATH="$MANPATH:/opt/rh/gcc-toolset-13/root/usr/share/man"
    fi
    if [[ -f /opt/rh/gcc-toolset-13/root/bin/gdb ]]; then
        export SYSTEMD_DEBUGGER=/opt/rh/gcc-toolset-13/root/bin/gdb
        alias gdb='/opt/rh/gcc-toolset-13/root/usr/bin/gdb'
    fi
fi

if [[ -d /opt/couchbase ]]; then
    alias cbq="/opt/couchbase/bin/cbq"
fi

if $HAVE_DELTA; then
    export DELTA_FEATURES=+side-by-side
    export GIT_PAGER='delta'
else
    export GIT_PAGER='less -RS'
fi

#export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/local/python-3.11.3/lib/"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
if $IS_SP_PRIVATE_HOST; then
    ZSH_THEME="robbyrussell"
else
    ZSH_THEME="amuse"
fi

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
zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 30

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
#COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder
plugins=(cp yum dnf pip)

# $HAVE_FZF && plugins+=(fzf) # no need as we use native fzf integration
$HAVE_GIT && plugins+=(git)
$HAVE_GO && plugins+=(golang)
$HAVE_DOCKER && plugins+=(docker docker-compose)
$HAVE_RUST && plugins+=(rust)
$HAVE_NODE && plugins+=(node npm)
$HAVE_TMUX && plugins+=(tmux)

ZSH_CUSTOM=${SP_DOTFILES_ROOT}/zsh_custom

for custom_plug in $(ls ${ZSH_CUSTOM}/plugins); do
    plugins+=(${custom_plug})
done

HISTSIZE=250000
SAVEHIST=100000
ZSH_PECO_HISTORY_DEDUP=1
source $ZSH/lib/history.zsh
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
if $HAVE_FZF; then
    export FZF_DEFAULT_OPTS='--height=~90% --ansi --preview "bat --color=always --line-range :500 {}" --preview-window=right:wrap'
    #export FZF_DEFAULT_OPTS='--ansi --preview "bat --color=always --style=header,grid --line-range :500 {}" --preview-window=down:3:wrap'
    #export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --ansi --preview "bat --color=always --style=header,grid --line-range :500 {}" --preview-window=down:3:wrap'
    source <(fzf --zsh) # integrate fzf into zsh
    __fzf_git_fzf='function _fzf_git_fzf() {
        fzf --height 50% --tmux 95%,95% \
          --layout reverse --multi --min-height 20+ --border \
          --no-separator --header-border horizontal \
          --border-label-pos 2 \
          --color ''label:blue'' \
          --preview-window ''right,70%'' --preview-border line \
          --bind ''ctrl-/:change-preview-window\(down,50%\|hidden\|\)'' "$@"
        }'
   source ${SP_DOTFILES_ROOT}/fzf-git/fzf-git.sh
fi
source $ZSH/oh-my-zsh.sh

export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; theno
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
export EDITOR='nvim'
CORRECT_IGNORE_FILE='release'

alias please='sudo $(fc -ln -1)'

if $HAVE_GIT; then
    alias glg='git lg'
    alias glgm='git lg2'
    alias glga='git lga'
    alias glgam='git lga2'
    alias gbt='git bt'
    alias gdh='gd HEAD'
    alias gd~='gd HEAD~'
fi

$HAVE_LAZYGIT && alias lg='lazygit'

alias vimdiff='nvim -d'
#unset '_comps[delta]'
_comps[delta]=_delta

function sg {
    rg $* | delta
}

compdef _gnu_generic build.sh
compdef _gnu_generic asn1c

function changeTps {
    VER=$1
    for f in installed build; do
        ln -sf ~/third_party_$VER/$f ~/ggsn/third_party/
    done
    ll ~/ggsn/third_party
}

function cleanPatch
{
    sed "s/@@.*@@/@@@@/g" $1 | sed "s/index [.a-f0-9]*/index xx xx/g"
}

function mcssh
{
    mc $(pwd) sh://$1:C/$2
}

zstyle -e ':completion:*:(mcssh):hosts' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'

if [[ -d ~/vcpkg ]]; then
    export VCPKG_ROOT=~/vcpkg
    export PATH=$PATH:${VCPKG_ROOT}
    autoload bashcompinit
    bashcompinit
    source ${VCPKG_ROOT}/scripts/vcpkg_completion.zsh
fi

SP_FUNCTIONS_ROOT=${SP_DOTFILES_ROOT}/functions
for fn in $(ls ${SP_FUNCTIONS_ROOT}/*.zsh); do
    source ${fn}
done

if [[ -f /bin/zsh ]]; then
    export SHELL=/bin/zsh
fi

PENTE_EDGE_ID=$(jq -r '.edge.edgeId' /home/pente/auc/conf/config.json 2>/dev/null)
# TEMP old AUC configs
[[ -z "${PENTE_EDGE_ID}" ]] && PENTE_EDGE_ID=$(grep -i  'EdgeId' /home/pente/auc/conf/config.properties 2>/dev/null | grep -oE '[0-9]+$')
PENTE_HOST_IP=$(ip a show nic0 2>/dev/null | sed -nE "s/.*inet ([^\/]+)\/.*/\1/p")

[[ -f ~/.local-functions.zsh ]] && source ~/.local-functions.zsh
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local


if [[ -n "${PENTE_EDGE_ID}" ]]; then
    export RPS1="%{$fg_bold[red]%}$(hostname)(E:${PENTE_EDGE_ID})%{$reset_color%}"
else
    export RPS1="%{$fg_bold[red]%}$(hostname)%{$reset_color%}"
fi

[[ -n "${PENTE_HOST_IP}" ]] && RPS1="${RPS1} - ${PENTE_HOST_IP}"
[[ -n "${PENTE_HOST_TAG}" ]] && RPS1="${RPS1} - ${PENTE_HOST_TAG}"

alias vim='nvim'

