GIT_JPU_GGSN_PATH=git@bitbucket.org:jpugit/ggsn.git
GIT_JPU_AMF_PATH=git@bitbucket.org:jpugit/pente-amfd.git
GIT_JPU_CFG_MANAGER_PATH=git@bitbucket.org:jpugit/cfg-manager.git
GIT_JPU_CICD_PATH=git@bitbucket.org:jpugit/cicd.git
GIT_JPU_HSS_PATH=git@bitbucket.org:jpugit/hss.git
GIT_JPU_MME_PATH=git@bitbucket.org:jpugit/open5gs.git
GIT_JPU_TESTS_PATH=git@bitbucket.org:jpugit/jpu-tests.git

function _doClone
{
    url=$1
    if [[ -z $2 ]]; then
        dir=$(basename $url)
        dir=${dir%.git}
    else
        dir=$2
    fi

    echo "Cloning $1 to $dir"
    git clone --recursive -j 10 $url $dir
}

function clone-ggsn
{
    _doClone $GIT_JPU_GGSN_PATH
}

function clone-amf
{
    _doClone $GIT_JPU_AMF_PATH amf
}

function clone-cfg-manager
{
    _doClone $GIT_JPU_CFG_MANAGER_PATH cfgManager
}

function clone-cicd
{
    _doClone $GIT_JPU_CICD_PATH cicd
}

function clone-hss
{
    _doClone $GIT_JPU_HSS_PATH hss
}

function clone-mme
{
    _doClone $GIT_JPU_MME_PATH mme
}

function clone-tests
{
    _doClone $GIT_JPU_TESTS_PATH automation
}

function clone-all
{
    clone-ggsn
    clone-amf
    clone-cfg-manager
    clone-cicd
    clone-hss
    clone-mme
    clone-tests
}

function git-here
{
    git init
    git config --global --add safe.directory $(pwd)
    git config user.email "sergiy@pentenetworks.com"
    git config user.name "Sergiy"
    git add .
    git commit -m "initial commit"
}

# Forward to `git <cmd>` with a shorthand for recent commits: a "-N" in any of
# the first <narg> positional args is rewritten to HEAD~N. This lets e.g.
#   sp-git-show  -2      -> git show  HEAD~2
#   sp-git-diff  -1 -3   -> git diff  HEAD~1 HEAD~3
# Usage: _sp-git-fwd <narg> <cmd> [args...]
function _sp-git-fwd
{
    local narg=$1
    local cmd=$2
    shift 2

    # rewrite the first <narg> "-N" args -> HEAD~N, pass the rest through
    local -a fwd
    local i a
    for ((i = 1; i <= $#; i++)); do
        a=${@[i]}
        if [[ $i -le $narg && $a =~ '^-[0-9]+$' ]]; then
            fwd+=("HEAD~${a#-}")
        else
            fwd+=("$a")
        fi
    done
    git $cmd "${fwd[@]}"
}

function sp-git-show  { _sp-git-fwd 1 show  "$@" }
function sp-git-showt { _sp-git-fwd 1 showt "$@" }
function sp-git-diff  { _sp-git-fwd 2 diff  "$@" }
function sp-git-difft { _sp-git-fwd 2 difft "$@" }

alias gd='sp-git-diff'
alias gdt='sp-git-difft'
alias gsh='sp-git-show'
alias gsht='sp-git-showt'

alias gdth='git difft HEAD'
