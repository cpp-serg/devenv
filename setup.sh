#!/bin/bash
# Orchestrator, run by bootstrap.sh once the repository is on disk. Unlike
# bootstrap.sh this may use every bash feature.
#
# Can also be re-run directly on an already-configured machine:
#   ~/devenv/setup.sh --user
#   ~/devenv/setup.sh --dev --dry-run

set -euo pipefail

SP_REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export SP_REPO_ROOT

MODE=""
SP_LINK_MODE=entries
SP_BUILD_GIT=false
SP_WORK_TWEAKS=true
SP_OPT_TOOLS=true
: "${SP_INTERACTIVE:=false}"
SP_ASSUME_YES=false
SP_DRY_RUN=false

while [ $# -gt 0 ]; do
    case "$1" in
        --dev) MODE=dev ;;
        --user) MODE=user ;;
        --yes | -y) SP_ASSUME_YES=true ;;
        --dry-run) SP_DRY_RUN=true ;;
        --link-mode)
            SP_LINK_MODE=${2:?--link-mode needs entries|dir}; shift ;;
        --build-git) SP_BUILD_GIT=true ;;
        --no-work-tweaks) SP_WORK_TWEAKS=false ;;
        --no-opt-tools) SP_OPT_TOOLS=false ;;
        -h | --help)
            sed -n '1,20p' "${SP_REPO_ROOT}/bootstrap.sh"; exit 0 ;;
        *) echo "setup.sh: unknown option $1" >&2; exit 1 ;;
    esac
    shift
done

case "$SP_LINK_MODE" in
    entries | dir) ;;
    *) echo "setup.sh: --link-mode must be 'entries' or 'dir'" >&2; exit 1 ;;
esac

export SP_INTERACTIVE SP_ASSUME_YES SP_DRY_RUN SP_LINK_MODE SP_BUILD_GIT SP_WORK_TWEAKS SP_OPT_TOOLS

# Everything from here on is also written to a log file, so a long run can be
# reviewed afterwards. Questions are printed on /dev/tty and stay interactive.
SP_LOG=${SP_LOG:-/tmp/devenv-bootstrap-$(date +%Y%m%d-%H%M%S).log}
if [ "$SP_DRY_RUN" != true ]; then
    exec > >(tee -a "$SP_LOG") 2>&1
fi

# shellcheck source=lib/pkg.sh
. "${SP_REPO_ROOT}/lib/pkg.sh"
# shellcheck source=lib/steps.sh
. "${SP_REPO_ROOT}/lib/steps.sh"

header "devenv setup"
say "$(distro_summary)"
say "repository: ${SP_REPO_ROOT}"
[ "$SP_DRY_RUN" = true ] || say "log: ${SP_LOG}"

[ "$OS_FAMILY" = unknown ] && die "unsupported distribution: $(distro_summary)"

# ---------------------------------------------------------------------------
# Mode
# ---------------------------------------------------------------------------
ask_mode() {
    local ans
    cat >/dev/tty <<'EOF'

Which kind of machine is this?

  [D]eveloper  everything: compilers, toolchains, debug tooling, /opt builds
  [U]ser       lean: shell, dotfiles, editor and search tools, then a few questions

EOF
    while :; do
        printf 'Mode [D/u]: ' >/dev/tty
        IFS= read -r ans </dev/tty || ans=""
        case "$ans" in
            "" | d | D | dev) echo dev; return ;;
            u | U | user) echo user; return ;;
            *) printf "Please answer 'd' or 'u'.\n" >/dev/tty ;;
        esac
    done
}

if [ -z "$MODE" ]; then
    if [ "$SP_INTERACTIVE" = true ] && [ "$SP_ASSUME_YES" != true ]; then
        MODE=$(ask_mode)
    else
        MODE=dev
    fi
fi
say "mode: ${MODE}"

# A hypervisor is a poor place for a build toolchain, but neovim is built from
# source, so the toolchain arrives either way - just make the choice visible.
if [ "$IS_PVE" = true ]; then
    warn "this is a Proxmox VE host: repo changes, sshd edits and CIFS mounts are skipped"
    if [ "$MODE" = dev ]; then
        warn "dev mode installs a full toolchain on a hypervisor; --user is usually what you want"
    fi
fi

# ---------------------------------------------------------------------------
# Profiles
# ---------------------------------------------------------------------------
# shellcheck source=profiles/base.sh
. "${SP_REPO_ROOT}/profiles/base.sh"
# shellcheck source=profiles/user.sh
. "${SP_REPO_ROOT}/profiles/user.sh"
# shellcheck source=profiles/dev.sh
. "${SP_REPO_ROOT}/profiles/dev.sh"

profile_base

case "$MODE" in
    user) profile_user ;;
    dev) profile_dev ;;
esac

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
rc=0
print_summary || rc=1
[ "$SP_DRY_RUN" = true ] || say "full log: ${SP_LOG}"

if [ "$rc" -eq 0 ] && [ "$SP_DRY_RUN" != true ]; then
    header "Next"
    say "  start a new shell:  exec zsh"
    say "  re-run any time:    ${SP_REPO_ROOT}/setup.sh --${MODE}"
fi

exit "$rc"
