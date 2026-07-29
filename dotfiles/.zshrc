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

# update-alternatives puts our canonical tool names (fd, bat, delta, nvim, tmux)
# in /usr/local/bin. Some login paths leave it out entirely - `pct exec`, cron,
# minimal sshd setups - which hides those tools, so put it back, ahead of
# /usr/bin so the alternative wins over any same-named distro binary.
for _sp_local_dir in /usr/local/sbin /usr/local/bin; do
    [[ -d ${_sp_local_dir} ]] && path=(${_sp_local_dir} ${path:#${_sp_local_dir}})
done
unset _sp_local_dir
export PATH

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
    ${HOME}/.local
    /opt/valgrind
    /opt/asn1c
    /opt/tmux
    /opt/nvim
    /opt/ripgrep
    ${HOME}/go
    /opt/go
)

# latest_llvm llvm
latest_llvm=(/opt/llvm-*(NoN[-1]))
if (( $#latest_llvm )); then
    TOOL_ROOTS+=("$latest_llvm")
fi

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
HAVE_NVIM=$(HaveTool nvim)

# Distribution, used to pick the right oh-my-zsh package plugins below.
SP_OS_ID=""
[[ -r /etc/os-release ]] && SP_OS_ID=$( . /etc/os-release 2>/dev/null; echo ${ID:-} )

# ---------------------------------------------------------------------------
# Completion cache
# ---------------------------------------------------------------------------
# fzf, delta, lxc and pick-ssh all generate their zsh completions by running the
# tool itself (`source <(fzf --zsh)`), which forks a process on *every* shell
# start. Cache the generated script and re-run the generator only when the tool's
# binary changes.
#
# The cache key - the binary's resolved path, mtime and size - is stored as the
# first line of the cache file, so a cache hit costs one zstat and one `read`,
# both builtins. Upgrading a tool, or switching which binary `fd`/`bat` point at
# via update-alternatives, changes mtime/size and invalidates the entry.
SP_COMPLETION_CACHE="${XDG_CACHE_HOME:-${HOME}/.cache}/devenv/completions"

zmodload -F zsh/stat b:zstat 2>/dev/null
SP_HAVE_ZSTAT=$(( $+builtins[zstat] ))

# sp_completion_cache <cache-name> <tool> [generator args...]
# On success sets $REPLY to a sourceable file and returns 0. Sourcing is left to
# the caller so the completion script runs with the shell's own options rather
# than this function's.
function sp_completion_cache {
    emulate -L zsh

    local name=$1 tool=$2
    shift 2

    local bin=${commands[$tool]}
    [[ -n $bin ]] || return 1

    (( SP_HAVE_ZSTAT )) || { REPLY=""; return 2; }   # caller falls back

    # zstat's +element form takes exactly one element, so use the hash form and
    # read both fields from it. Symlinks are followed, which is what makes an
    # update-alternatives switch invalidate the entry.
    local -A st
    zstat -H st -- $bin 2>/dev/null || return 1
    local key="# devenv-completion-cache ${bin} ${st[mtime]} ${st[size]}"
    local file="${SP_COMPLETION_CACHE}/${name}.zsh"

    # Cache hit: first line still matches the binary we would run.
    local first=""
    [[ -s $file ]] && read -r first < $file
    if [[ $first == $key ]]; then
        REPLY=$file
        return 0
    fi

    [[ -d $SP_COMPLETION_CACHE ]] || mkdir -p -- $SP_COMPLETION_CACHE || return 1

    # Regenerate. A tool that does not understand the flag (Ubuntu 24.04 packages
    # delta 0.16, which has no --generate-completion) fails here and is simply
    # left without completions.
    local tmp="${file}.new.$$"
    if ! { print -r -- $key; $bin "$@" } >| $tmp 2>/dev/null; then
        rm -f -- $tmp
        return 1
    fi
    # Anything at or below the key line alone means the generator produced nothing.
    zstat -H st -- $tmp 2>/dev/null || { rm -f -- $tmp; return 1; }
    if (( st[size] <= ${#key} + 1 )); then
        rm -f -- $tmp
        return 1
    fi

    mv -f -- $tmp $file || { rm -f -- $tmp; return 1; }
    REPLY=$file
    return 0
}

# Drop the cache; the next shell regenerates it.
function sp_completion_cache_clear {
    rm -rf -- $SP_COMPLETION_CACHE
    print -r -- "cleared ${SP_COMPLETION_CACHE}"
}

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
plugins=(cp pip)

# Package manager plugin depends on the distribution, not on the dotfiles.
case ${SP_OS_ID} in
    ubuntu)                             plugins+=(ubuntu) ;;
    debian|raspbian)                    plugins+=(debian) ;;
    rocky|rhel|centos|almalinux|fedora) plugins+=(yum dnf) ;;
esac

$HAVE_GIT && plugins+=(git)
$HAVE_GO && plugins+=(golang)
$HAVE_DOCKER && plugins+=(docker docker-compose)
$HAVE_RUST && plugins+=(rust)
$HAVE_NODE && plugins+=(node npm)
$HAVE_TMUX && plugins+=(tmux)
# $HAVE_FZF && plugins+=(fzf) # no need as we use native fzf integration

ZSH_CUSTOM=${SP_DOTFILES_ROOT}/zsh_custom

# Submodules may not be checked out yet; (/N:t) yields nothing instead of an
# error when the directory is missing or empty.
for custom_plug in ${ZSH_CUSTOM}/plugins/*(/N:t); do
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
    # integrate fzf into zsh, from cache when the binary has not changed
    if sp_completion_cache fzf fzf --zsh; then
        source $REPLY
    else
        [[ $? -eq 2 ]] && source <(fzf --zsh)   # no zstat: generate every time
    fi
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

if $HAVE_LXD; then
    if sp_completion_cache lxc lxc completion zsh; then
        source $REPLY
    else
        [[ $? -eq 2 ]] && source <(lxc completion zsh)
    fi
fi

export ZSH_AUTOSUGGEST_STRATEGY=(history completion)

export LANG=en_US.UTF-8

# nvim is the intended editor, but a host where the build failed (or has not run
# yet) should still get a working EDITOR rather than a missing command.
if $HAVE_NVIM; then
    export EDITOR='nvim'
elif (( $+commands[vim] )); then
    export EDITOR='vim'
else
    export EDITOR='vi'
fi
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
    # --generate-completion only exists in newer deltas (Ubuntu 24.04 packages
    # 0.16, which answers with a full clap usage dump on stderr). The cache helper
    # discards a failed generator, so an old delta just gets no completions.
    if sp_completion_cache delta delta --generate-completion zsh; then
        source $REPLY
    else
        [[ $? -eq 2 ]] && source <(delta --generate-completion zsh 2>/dev/null)
    fi
else
    export GIT_PAGER='less -RS'
fi

if $HAVE_PICKSSH; then
    if sp_completion_cache pick-ssh pick-ssh --embed zsh; then
        source $REPLY
    else
        [[ $? -eq 2 ]] && source <(pick-ssh --embed zsh)
    fi
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

if $HAVE_NVIM; then
    alias vim='nvim'
    alias vimd='nvim -d'
elif (( $+commands[vim] )); then
    alias vimd='vim -d'
fi
alias tma='tmux attach'
alias ncdu="${SUDO} ncdu -x"
alias df="${SUDO} df -h"
alias du="${SUDO} du -h"
alias reboot="${SUDO} reboot"
alias cld=$'su -l - claude-runner -c "zsh -ic \'cd $(pwd) && exec claude --allow-dangerously-skip-permissions\'"'
alias cldp='su - claude-runner'

# Remove duplicates from path
typeset -U path PATH
path=(${path})
