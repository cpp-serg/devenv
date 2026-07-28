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

mapfile -t files < <(
    git ls-files '*.sh' 2>/dev/null \
        || find . -name '*.sh' -not -path './dotfiles/fzf/*' -not -path './dotfiles/zsh_custom/*'
)

rc=0

# POSIX shell: the one file that must not use bash features.
echo "== bootstrap.sh (as POSIX sh) =="
shellcheck --shell=sh --severity="$SEVERITY" --external-sources bootstrap.sh || rc=1
if command -v dash >/dev/null 2>&1; then
    dash -n bootstrap.sh && echo "dash -n: ok" || rc=1
fi

echo
echo "== bash scripts =="
for f in "${files[@]}"; do
    case "$f" in
        bootstrap.sh | dotfiles/fzf/* | dotfiles/zsh_custom/* | dotfiles/fzf-git/*) continue ;;
    esac
    shellcheck --shell=bash --severity="$SEVERITY" --external-sources "$f" || rc=1
    bash -n "$f" || rc=1
done

echo
if [ "$rc" -eq 0 ]; then
    echo "shellcheck: clean at severity=${SEVERITY}"
else
    echo "shellcheck: findings above" >&2
fi
exit "$rc"
