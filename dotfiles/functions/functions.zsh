#!/bin/zsh

function sp-ssh-shared-push {
    zip -er ~/devenv/dotfiles/ssh_shared.zip ~/.ssh/shared || return
    if ! devenv_run_git diff --cached --quiet; then
        echo "~/devenv is not clean"
        return
    fi

    if ! read -q "?Commit ssh_shared.zip? [y/N]"; then
        return
    fi
    devenv_run_git add ~/devenv/dotfiles/ssh_shared.zip
    devenv_run_git commit -m "Update ssh_shared.zip"
    devenv_run_git push
}
