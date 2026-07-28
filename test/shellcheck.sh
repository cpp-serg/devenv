#!/bin/bash
# Lint every shell script in the repository.
#
#   test/shellcheck.sh          # report
#   test/shellcheck.sh --strict # also fail on style/info level findings
#
# bootstrap.sh is checked as POSIX sh on purpose: it is executed by /bin/sh,
# which is dash on Debian/Ubuntu/Proxmox, so a bashism there is a real bug.
# Submodules (fzf, tpm, zsh_custom plugins) are other people's code and skipped.

set -uo pipefail

MY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "${MY_DIR}/.." && pwd)
cd "$REPO_ROOT" || exit 1

SEVERITY=warning
[ "${1:-}" = --strict ] && SEVERITY=style

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck is not installed."
    echo "  Debian/Ubuntu: apt-get install -y shellcheck"
    echo "  EL:            dnf install -y ShellCheck   (needs EPEL)"
    exit 127
fi

# Submodules are other people's code (and fzf-git.sh is zsh, which shellcheck
# cannot parse). Paths are normalised to be repo-relative with no leading ./ so
# one skip list works for both the git and the find branch.
is_skipped() {
    case "$1" in
        bootstrap.sh) return 0 ;;                        # linted separately, as sh
        dotfiles/fzf/* | dotfiles/fzf-git/* | dotfiles/zsh_custom/* | \
            dotfiles/.config/tmux/plugins/*) return 0 ;;
        # Self-contained build recipes for other projects (open5gs, sigscale,
        # srsRAN, ueransim). Not on the bootstrap path; they carry their own
        # pre-existing findings and are not part of this lint's contract.
        install-suites/*) return 0 ;;
        *) return 1 ;;
    esac
}

mapfile -t files < <(
    { git ls-files '*.sh' 2>/dev/null || find . -name '*.sh' -type f; } | sed 's|^\./||' | sort -u
)

rc=0
checked=0

# POSIX shell: the one file that must not use bash features.
echo "== bootstrap.sh (as POSIX sh) =="
shellcheck --shell=sh --severity="$SEVERITY" --external-sources bootstrap.sh || rc=1
if command -v dash >/dev/null 2>&1; then
    dash -n bootstrap.sh && echo "dash -n: ok" || rc=1
fi

echo
echo "== bash scripts =="
for f in "${files[@]}"; do
    is_skipped "$f" && continue
    checked=$((checked + 1))
    shellcheck --shell=bash --severity="$SEVERITY" --external-sources "$f" || rc=1
    bash -n "$f" || rc=1
done

echo
if [ "$rc" -eq 0 ]; then
    echo "shellcheck: ${checked} script(s) clean at severity=${SEVERITY}"
else
    echo "shellcheck: findings above" >&2
fi
exit "$rc"
