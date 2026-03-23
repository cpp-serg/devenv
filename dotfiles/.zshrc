export SP_MASTER_USER="spastukhov"

export SP_DEVENV_ROOT="${HOME}/devenv"
export SP_DOTFILES_ROOT="${SP_DEVENV_ROOT}/dotfiles"
export KEYTIMEOUT=100

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

function devenv_run_git {
    git -C ${SP_DEVENV_ROOT} "$@"
}

function HaveFile {
    [[ -f $1 ]] && echo true || echo false
}

IS_SP_PRIVATE_HOST=$(HaveFile ${HOME}/.sp-private-host)

export PATH="$PATH:$HOME/devenv/scripts"
[[ -d "${HOME}/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# If I'm running as a different user, still bring tools from master user (if accessible)
if [[ ("${USER}" != "${SP_MASTER_USER}") && (-x "/home/${SP_MASTER_USER}") ]]; then
    for p in .local/bin .local/devenv/scripts; do
        [[ -x "/home/${SP_MASTER_USER}/${p}" ]] && export PATH="/home/${SP_MASTER_USER}/${p}:$PATH"
    done
fi

# Setup fzf
if [[ -f ${SP_DOTFILES_ROOT}/fzf/bin/fzf ]]; then
    SP_FZF_ROOT=${SP_DOTFILES_ROOT}/fzf
    PATH="${PATH:+${PATH}:}${SP_FZF_ROOT}/bin"
fi

ADDED_PATHS=""
ADDED_MANPATHS=""
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

for tool in "${TOOL_ROOTS[@]}" ; do
    [[ -d "${tool}" && -x "${tool}" ]] || continue

    if [[ ! -d "${tool}/bin" ]] ; then
        # simple tool dir, no docs, man etc.
        ADDED_PATHS="${ADDED_PATHS}:${tool}"
        continue
    fi

    ADDED_PATHS="${ADDED_PATHS}:${tool}/bin"
    if [[ -d "${tool}/man" ]] ; then
        ADDED_MANPATHS="${ADDED_MANPATHS}:${tool}/man"
    elif [[ -d "${tool}/doc" ]] ; then
        ADDED_MANPATHS="${ADDED_MANPATHS}:${tool}/doc"
    elif [[ -d "${tool}/share/man" ]] ; then
        ADDED_MANPATHS="${ADDED_MANPATHS}:${tool}/share/man"
    fi
done

[[ ! -z "${ADDED_PATHS}" ]] && export PATH=$PATH:${ADDED_PATHS}
[[ ! -z "${ADDED_MANPATHS}" ]] && export MANPATH=${MANPATH}:${ADDED_MANPATHS}

# Must be after ADDED_PATHS stuff
function HaveTool {
    (( $+commands[$1] )) && echo true || echo false
}

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
HAVE_PICKSSH=$(HaveTool pick-ssh)
HAVE_LXD=$(HaveTool lxc)
HAVE_CLAUDE=$(HaveTool claude)

[[ -f ~/.config/.pythonrc ]] && export PYTHONSTARTUP=~/.config/.pythonrc
[[ -f ${HOME}/.cargo/env  ]] && source "${HOME}/.cargo/env"
[[ -f ~/.ripgreprc        ]] && export RIPGREP_CONFIG_PATH=~/.ripgreprc


for gcc_toolset_ver in 15 14 13; do
    toolset_root="/opt/rh/gcc-toolset-${gcc_toolset_ver}/root"
    [[ ! -d "${toolset_root}" ]] && continue

    [[ -d "${toolset_root}/usr/share/man" ]] && export MANPATH="$MANPATH:${toolset_root}/usr/share/man"
    if [[ -f "${toolset_root}/bin/gdb" ]]; then
        export SYSTEMD_DEBUGGER="${toolset_root}/bin/gdb"
        alias gdb="${toolset_root}/usr/bin/gdb"
    fi
done

[[ -d /opt/couchbase ]] && alias cbq="/opt/couchbase/bin/cbq"

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=$(${IS_SP_PRIVATE_HOST} && echo "robbyrussell" || echo "amuse")

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

$HAVE_GIT && plugins+=(git)
$HAVE_GO && plugins+=(golang)
$HAVE_DOCKER && plugins+=(docker docker-compose)
$HAVE_RUST && plugins+=(rust)
$HAVE_NODE && plugins+=(node npm)
$HAVE_TMUX && plugins+=(tmux)
# $HAVE_FZF && plugins+=(fzf) # no need as we use native fzf integration

ZSH_CUSTOM=${SP_DOTFILES_ROOT}/zsh_custom

for custom_plug in $(ls ${ZSH_CUSTOM}/plugins); do
    plugins+=(${custom_plug})
done

HISTSIZE=250000
SAVEHIST=100000
source $ZSH/lib/history.zsh
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_FIND_NO_DUPS
fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
source $ZSH/oh-my-zsh.sh

if $HAVE_FZF; then
    export FZF_DEFAULT_OPTS='--height=~90% --ansi --preview "bat --color=always --line-range :500 {}" --preview-window=right:wrap'
    #export FZF_DEFAULT_OPTS='--ansi --preview "bat --color=always --style=header,grid --line-range :500 {}" --preview-window=down:3:wrap'
    #export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border --ansi --preview "bat --color=always --style=header,grid --line-range :500 {}" --preview-window=down:3:wrap'
    source <(fzf --zsh) # integrate fzf into zsh
    __fzf_git_fzf='function _fzf_git_fzf() {
        fzf --height 70% --tmux 95%,95% \
          --layout reverse --multi --min-height 20+ --border \
          --no-separator --header-border horizontal \
          --border-label-pos 2 \
          --color ''label:blue'' \
          --preview-window ''right,70%'' --preview-border line \
          --bind ''ctrl-/:change-preview-window\(down,50%\|hidden\|\)'' "$@"
        }'
   source ${SP_DOTFILES_ROOT}/fzf-git/fzf-git.sh
fi

$HAVE_LXD && source <(lxc completion zsh)

export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

export LANG=en_US.UTF-8

export EDITOR='nvim'
CORRECT_IGNORE_FILE='release'

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

compdef _gnu_generic build.sh
compdef _gnu_generic asn1c
$HAVE_CLAUDE && compdef _gnu_generic claude

if $HAVE_DELTA; then
    export DELTA_FEATURES=+side-by-side
    export GIT_PAGER='delta'
    source <(delta --generate-completion zsh)
else
    export GIT_PAGER='less -RS'
fi

if $HAVE_PICKSSH; then
    source <(pick-ssh --embed zsh)
    export PICK_SSH_CONFIG="theme=catppuccin-mocha"
fi

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


# TEMP old AUC configs
[[ -z "${PENTE_EDGE_ID}" ]] && PENTE_EDGE_ID=$(grep -i  'EdgeId' /home/pente/auc/conf/config.properties 2>/dev/null | grep -oE '[0-9]+$')

# find first interface from given list with an IP
for nic in nic0 br0 eth0; do
    PENTE_HOST_IP=$(ip a show ${nic} 2>/dev/null | sed -nE "s/.*inet ([^\/]+)\/.*/\1/p" | head -n1)
    [[ -n "${PENTE_HOST_IP}" ]] && break
done

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
alias tma='tmux attach'
alias vimd='nvim -d'
alias ncdu="${SUDO} ncdu -x"
alias df="${SUDO} df -h"
alias du="${SUDO} du -h"
alias reboot="${SUDO} reboot"
alias cld=$'su -l - claude-runner -c "zsh -ic \'cd $(pwd) && exec claude --allow-dangerously-skip-permissions\'"'
alias cldp='su - claude-runner'

