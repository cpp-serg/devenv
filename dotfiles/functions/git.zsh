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

