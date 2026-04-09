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

alias pgw_pools='curl -s http://127.0.0.15:39096/v1/ipman/pools\?list_allocated | jqp'
alias pgw_allocations='curl -s http://127.0.0.15:39096/v1/ipman/allocations | jqp'

pgw_imsi_lookup() { curl -s "http://127.0.0.15:39096/v1/ipman/imsi/$1" | jqp }

pgw_ip_lookup() { curl -s "http://127.0.0.15:39096/v1/ipman/ip/$1" | jqp }

if (( $+commands[npx] )); then
  jqp() { npx prettier --parser json --print-width 160 | bat -l json -p }
else
  jqp() { jq }
fi
