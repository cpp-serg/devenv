DEVENV_ROOT="${HOME}/devenv"
DOTFILES_ROOT="${DEVENV_ROOT}/dotfiles"

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
    /opt/llvm-18
    /opt/ccache
    ${HOME}/.local
    /opt/valgrind
    /opt/asn1c
    /opt/tmux
    /opt/nvim
    /opt/ripgrep
    ${HOME}/go
    /opt/go
)


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

if [[ -d "/opt/rh/gcc-toolset-13/root/usr/share/man" ]] ; then
    export MANPATH="$MANPATH:/opt/rh/gcc-toolset-13/root/usr/share/man"
fi

[[ -f ~/.config/.pythonrc ]] && export PYTHONSTARTUP=~/.config/.pythonrc
[[ -f  ${HOME}/.cargo/env ]] && source "${HOME}/.cargo/env"
[[ -f ~/.ripgreprc        ]] && export RIPGREP_CONFIG_PATH=~/.ripgreprc

$HAVE_DELTA && export DELTA_FEATURES=+side-by-side

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
plugins=(cp yum dnf sudo pip)

$HAVE_FZF && plugins+=(fzf)
$HAVE_GIT && plugins+=(git)
$HAVE_GO && plugins+=(golang)
$HAVE_DOCKER && plugins+=(docker docker-compose)
$HAVE_RUST && plugins+=(rust)
$HAVE_NODE && plugins+=(node npm)
$HAVE_TMUX && plugins+=(tmux)

ZSH_CUSTOM=${DOTFILES_ROOT}/zsh_custom

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
    FZF_BASE=/home/spastukhov/install_soft/fzf/
    export FZF_DEFAULT_OPTS='--height=~90% --ansi --preview "bat --color=always --line-range :500 {}" --preview-window=right:wrap'
    #export FZF_DEFAULT_OPTS='--ansi --preview "bat --color=always --style=header,grid --line-range :500 {}" --preview-window=down:3:wrap'
    #export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --ansi --preview "bat --color=always --style=header,grid --line-range :500 {}" --preview-window=down:3:wrap'
    alias vimf='vim $(fzf)'
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
alias gdb='/opt/rh/gcc-toolset-13/root/usr/bin/gdb'

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
function ddf {
    delta $1 ~/jpu-tests-sp/helpers/core/testPython/$1
}

function cleanPatch
{
    sed "s/@@.*@@/@@@@/g" $1 | sed "s/index [.a-f0-9]*/index xx xx/g"
}

function mcssh
{
    mc $(pwd) sh://$1:C/$2
}

function jenk
{
    user='sergiy@pentenetworks.com'
    token='11555f916ea5a61c13f876455ea547f351'
    wget --auth-no-challenge  --user $user --password $token $*
}

function jenkapi
{
    jenk_serv=http://jenkinsil.jpu.io
    jenk -q -O - ${jenk_serv}/${1}/api/json | jq
}

function git-here
{
    git init 
    git config --global --add safe.directory $(pwd)
    git config user.email "sergiy@pentenetworks.com"
    git config "Sergiy"
    git add .
    git commit -m "initial commit"
}

MASTER_ROOT=job/pente-ggsn
MVNO_ROOT=view/%20%20%20%20%20MVNO%20Official%20Builds/job/pente-ggsn-MVNO
PATCHES_ROOT=view/%20%20%20%20%20Patch%20builds/job/pente-ggsn_patch
TAGS_ROOT=view/%20%20%20%20Dev%20Builds/job/pente-ggsn_tag

function jtags
{
    jenkapi view/%20%20%20%20Dev%20Builds/job/pente-ggsn_tag | jq '.jobs[].url' | sed -nE 's/.*job\/([0-9][^/]+)\/"/\1/p' | tac
}

function jpatches
{
    #jenkapi $MASTER_ROOT 
    #'.builds[].url'
    #| sed -nE 's/.*job\/[^/]+\/([0-9]+)\/"/\1/p'
    #
}

function ccc
{
    delta $1 ~/ggsn/$1
}

zstyle -e ':completion:*:(mcssh):hosts' hosts 'reply=(${=${${(f)"$(cat {/etc/ssh_,~/.ssh/known_}hosts(|2)(N) /dev/null)"}%%[# ]*}//,/ })'

[[ -f ~/resilienceFns.sh ]] && source ~/resilienceFns.sh

if [[ -d /home/spastukhov/build-tools/vcpkg ]]; then
    export VCPKG_ROOT=/home/spastukhov/build-tools/vcpkg
    export PATH=$PATH:${VCPKG_ROOT}
    autoload bashcompinit
    bashcompinit
    source ${VCPKG_ROOT}/scripts/vcpkg_completion.zsh
fi
# temp
export ASAN_OPTIONS=detect_leaks=0

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

