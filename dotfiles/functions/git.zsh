
function git-here
{
    git init 
    git config --global --add safe.directory $(pwd)
    git config user.email "sergiy@pentenetworks.com"
    git config "Sergiy"
    git add .
    git commit -m "initial commit"
}

