#!/bin/bash
# Link this repository's dotfiles into $HOME.
#
#   set-links.sh [--mode entries|dir] [--home DIR] [--dry-run]
#
# --mode entries (default)
#     Link every entry *inside* dotfiles/.config separately, leaving anything
#     else in ~/.config alone. Debian, Ubuntu and Proxmox hosts usually already
#     have a populated ~/.config, and replacing it wholesale loses that state.
#
# --mode dir
#     Replace ~/.config with one symlink to dotfiles/.config (what this script
#     used to do unconditionally).
#
# Re-running is safe: a link that already points at the right place is left
# alone, and anything else in the way is moved to <name>.bak.<timestamp>
# instead of overwriting the previous backup.

set -euo pipefail

MY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
MODE=entries
HOME_DIR=${HOME}
DRY_RUN=${SP_DRY_RUN:-false}
TS=$(date +%Y%m%d-%H%M%S)

while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE=${2:?--mode needs entries|dir}; shift ;;
        --home) HOME_DIR=${2:?--home needs a directory}; shift ;;
        --dry-run) DRY_RUN=true ;;
        -h | --help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "set-links.sh: unknown option $1" >&2; exit 1 ;;
    esac
    shift
done

case "$MODE" in
    entries | dir) ;;
    *) echo "set-links.sh: --mode must be 'entries' or 'dir'" >&2; exit 1 ;;
esac

# link_one <src> <dst>
link_one() {
    local src="$1" dst="$2"

    if [ -L "$dst" ]; then
        if [ "$(readlink -f "$dst" 2>/dev/null || true)" = "$(readlink -f "$src")" ]; then
            printf '  ok       %s\n' "$dst"
            return 0
        fi
        printf '  relink   %s (was -> %s)\n' "$dst" "$(readlink "$dst")"
        [ "$DRY_RUN" = true ] || rm -f "$dst"
    elif [ -e "$dst" ]; then
        printf '  backup   %s -> %s.bak.%s\n' "$dst" "$dst" "$TS"
        [ "$DRY_RUN" = true ] || mv "$dst" "${dst}.bak.${TS}"
    else
        printf '  link     %s -> %s\n' "$dst" "$src"
    fi

    [ "$DRY_RUN" = true ] || ln -sfn "$src" "$dst"
}

printf 'linking dotfiles from %s into %s (mode: %s)\n' "$MY_DIR" "$HOME_DIR" "$MODE"

[ "$DRY_RUN" = true ] || mkdir -p "$HOME_DIR"

link_one "${MY_DIR}/.zshrc" "${HOME_DIR}/.zshrc"

if [ "$MODE" = dir ]; then
    link_one "${MY_DIR}/.config" "${HOME_DIR}/.config"
else
    [ "$DRY_RUN" = true ] || mkdir -p "${HOME_DIR}/.config"
    # dotglob so .pythonrc and friends are linked too; nullglob so an empty
    # directory is not an error.
    shopt -s dotglob nullglob
    for src in "${MY_DIR}"/.config/*; do
        link_one "$src" "${HOME_DIR}/.config/$(basename "$src")"
    done
    shopt -u dotglob nullglob
fi
