GGSN_PATH=git@bitbucket.org:jpugit/ggsn.git

function clone-ggsn
{
    git clone --recursive -j 10 $GGSN_PATH
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

