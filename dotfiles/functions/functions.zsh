#!/bin/zsh
function podbld {
    [[ -d cont_deploy ]] || mkdir cont_deploy
    [[ -d cont_ccache ]] || mkdir cont_ccache
    [[ -d cont_build ]] || mkdir cont_build
    [[ -d cont_INSTALL ]] || mkdir cont_INSTALL
    [[ -d cont_third_party ]] || mkdir cont_third_party

    podman run -it --rm --name build_oxio \
        -v $(pwd):/ggsn \
        -v $(pwd)/cont_build:/ggsn/build \
        -v $(pwd)/cont_third_party:/ggsn/third_party \
        -v $(pwd)/cont_INSTALL:/ggsn/_INSTALL \
        -v $(pwd)/cont_deploy:/home/pente/ggsn \
        -v $(pwd)/cont_ccache:/root/.ccache \
        oxio:zsh $@
}

function sp-ssh-shared-push {
    # Store paths relative to ~/.ssh so extraction lands in ./shared and ./config
    rm -f ~/devenv/dotfiles/ssh_shared.zip
    ( cd ~/.ssh && zip -er ~/devenv/dotfiles/ssh_shared.zip shared config ) || return
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

function _sp_ssh_show_diff {
    # Diff two paths (files or dirs) using difft, delta, or diff (in that order)
    local a=$1 b=$2
    if (( $+commands[difft] )); then
        difft "$a" "$b"
    elif (( $+commands[delta] )); then
        diff -ru "$a" "$b" | delta
    else
        diff -ru "$a" "$b"
    fi
}

function _sp_ssh_maybe_install {
    # Install extracted $name into ~/.ssh, prompting if a local version exists
    local name=$1 newpath=$2
    local localpath=~/.ssh/$name

    if [[ ! -e $newpath ]]; then
        echo "  $name: not present in archive, skipping"
        return
    fi

    if [[ ! -e $localpath ]]; then
        cp -a "$newpath" "$localpath"
        echo "  $name: installed (no local version existed)"
        return
    fi

    while true; do
        local choice
        read "choice?  $name exists locally. Replace? [y]es / [n]o / [d]iff? "
        case $choice in
            y|Y)
                rm -rf "$localpath"
                cp -a "$newpath" "$localpath"
                echo "  $name: replaced"
                return
                ;;
            n|N)
                echo "  $name: kept local version"
                return
                ;;
            d|D)
                _sp_ssh_show_diff "$localpath" "$newpath"
                ;;
            *)
                echo "  please answer y, n, or d"
                ;;
        esac
    done
}

function sp-ssh-shared-pull {
    devenv_run_git pull --autostash || return

    local tmp
    tmp=$(mktemp -d /tmp/ssh_shared.XXXXXX) || return
    trap "rm -rf '$tmp'" EXIT INT TERM

    unzip -o ~/devenv/dotfiles/ssh_shared.zip -d "$tmp" || { rm -rf "$tmp"; trap - EXIT INT TERM; return 1; }

    _sp_ssh_maybe_install shared "$tmp/shared"
    _sp_ssh_maybe_install config "$tmp/config"

    rm -rf "$tmp"
    trap - EXIT INT TERM
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
