#!/bin/sh
# Entry point for a fresh machine:
#
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/cpp-serg/devenv/main/bootstrap.sh)"
#   sh -c "$(curl -fsSL https://raw.githubusercontent.com/cpp-serg/devenv/main/bootstrap.sh)" -- --user
#
# IMPORTANT: this file must stay POSIX sh. It is executed by whatever /bin/sh
# is, which is bash on Rocky but dash on Debian/Ubuntu/Proxmox - dash has no
# [[ ]], no arrays and no `local`. Everything that wants bash lives in
# setup.sh, which this script execs once the repository is on disk.
#
# Responsibilities, in order:
#   1. parse arguments
#   2. make sure git (and curl/ca-certificates) are installed, asking first
#   3. clone or update the repository
#   4. hand over to bash setup.sh with the same arguments

set -eu

REPO_URL=https://github.com/cpp-serg/devenv.git
TARGET_ROOT=${SP_DEVENV_ROOT:-${HOME}/devenv}
BRANCH=""
ASSUME_YES=false
DRY_RUN=false
SRC=""

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [options]

Mode:
  --dev                 developer machine: install everything, no questions (default)
  --user                lean machine: base tools only, then ask about optional groups

Options:
  --yes                 never ask anything; accept every default
  --dry-run             show what would be installed/changed, change nothing
  --target DIR          where to clone the repo (default ~/devenv)
  --branch REF          branch or tag to check out
  --repo URL|PATH       clone from somewhere else; a local directory is copied
                        as-is (used by the LXC test harness)
  --link-mode entries   symlink each entry inside .config (default, safer)
  --link-mode dir       symlink ~/.config as a whole (legacy behaviour)
  --build-git           build git from source instead of using the distro package
  --no-work-tweaks      skip the site-specific tweaks in dev mode
  -h, --help            this text

Examples:
  sh -c "$(curl -fsSL .../bootstrap.sh)" -- --user
  sh -c "$(curl -fsSL .../bootstrap.sh)" -- --dev --yes
EOF
}

# ---------------------------------------------------------------------------
# 1. arguments (kept in FORWARD for setup.sh)
# ---------------------------------------------------------------------------
FORWARD=""
add_forward() { FORWARD="${FORWARD} $1"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --dev | --user)
            add_forward "$1" ;;
        --yes | -y)
            ASSUME_YES=true; add_forward "--yes" ;;
        --dry-run)
            DRY_RUN=true; add_forward "--dry-run" ;;
        --target)
            [ $# -ge 2 ] || { echo "--target needs a directory" >&2; exit 1; }
            TARGET_ROOT=$2; shift ;;
        --branch)
            [ $# -ge 2 ] || { echo "--branch needs a ref" >&2; exit 1; }
            BRANCH=$2; shift ;;
        --repo)
            [ $# -ge 2 ] || { echo "--repo needs a URL or path" >&2; exit 1; }
            SRC=$2; shift ;;
        --link-mode)
            [ $# -ge 2 ] || { echo "--link-mode needs entries|dir" >&2; exit 1; }
            add_forward "--link-mode"; add_forward "$2"; shift ;;
        --build-git | --no-work-tweaks)
            add_forward "$1" ;;
        -h | --help)
            usage; exit 0 ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# minimal helpers (the rich versions live in lib/ui.sh, not available yet)
# ---------------------------------------------------------------------------
say() { printf '==> %s\n' "$*"; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# A terminal we can ask questions on? Piping the script into sh (rather than the
# documented sh -c form) leaves no tty, in which case every question takes its
# default instead of hanging.
INTERACTIVE=false
if [ -t 1 ]; then
    if [ -t 0 ]; then
        INTERACTIVE=true
    elif (exec 3</dev/tty) 2>/dev/null; then
        INTERACTIVE=true
    fi
fi

# ask <prompt> <default y|n>
ask() {
    _def=$2
    if [ "$ASSUME_YES" = true ] || [ "$INTERACTIVE" != true ]; then
        [ "$_def" = y ] && return 0 || return 1
    fi
    if [ "$_def" = y ]; then _hint="[Y/n]"; else _hint="[y/N]"; fi
    while :; do
        printf '%s %s ' "$1" "$_hint" >/dev/tty
        IFS= read -r _ans </dev/tty || _ans=""
        case "$_ans" in
            "") [ "$_def" = y ] && return 0 || return 1 ;;
            y | Y | yes | YES) return 0 ;;
            n | N | no | NO) return 1 ;;
            *) printf 'Please answer y or n.\n' >/dev/tty ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# 2. package manager + prerequisites
# ---------------------------------------------------------------------------
OS_ID=unknown
OS_LIKE=""
if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID=${ID:-unknown}
    OS_LIKE=${ID_LIKE:-}
fi

PKG=""
case " ${OS_ID} ${OS_LIKE} " in
    *" rhel "* | *" centos "* | *" fedora "*)
        if command -v dnf >/dev/null 2>&1; then PKG=dnf
        elif command -v yum >/dev/null 2>&1; then PKG=yum
        fi ;;
    *" debian "* | *" ubuntu "*)
        command -v apt-get >/dev/null 2>&1 && PKG=apt-get ;;
esac
[ -n "$PKG" ] || die "unsupported distribution '${OS_ID}': need dnf/yum or apt-get"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null 2>&1 \
        || die "not running as root and sudo is not installed - re-run as root"
    SUDO=sudo
fi

pkg_install() {
    say "installing: $*"
    [ "$DRY_RUN" = true ] && return 0
    if [ "$PKG" = apt-get ]; then
        DEBIAN_FRONTEND=noninteractive ${SUDO} apt-get update -qq || true
        # shellcheck disable=SC2086  # deliberate: $* is a package list
        DEBIAN_FRONTEND=noninteractive ${SUDO} apt-get install -y --no-install-recommends $*
    else
        # shellcheck disable=SC2086
        ${SUDO} ${PKG} install -y $*
    fi
}

# git is what makes everything else possible, so it gets its own question.
if command -v git >/dev/null 2>&1; then
    say "git found: $(git --version)"
else
    say "git is not installed; it is required to fetch the devenv repository."
    ask "Install git now?" y || die "git is required - aborting"
    pkg_install git || die "failed to install git"
fi

# curl and CA certificates: needed by oh-my-zsh, the Claude installer and every
# release download later on. Quietly added, no question - they are plumbing.
MISSING=""
command -v curl >/dev/null 2>&1 || MISSING="${MISSING} curl"
if [ "$PKG" = apt-get ] && [ ! -e /etc/ssl/certs/ca-certificates.crt ]; then
    MISSING="${MISSING} ca-certificates"
fi
# shellcheck disable=SC2086
[ -n "$MISSING" ] && pkg_install $MISSING

# ---------------------------------------------------------------------------
# 3. fetch or update the repository
# ---------------------------------------------------------------------------
if [ -n "$SRC" ] && [ -d "$SRC" ]; then
    # Local directory: copy it verbatim, submodule checkouts included, so a work
    # tree can be tested without pushing it anywhere.
    say "copying local source ${SRC} -> ${TARGET_ROOT}"
    if [ "$DRY_RUN" != true ]; then
        mkdir -p "$TARGET_ROOT"
        (cd "$SRC" && tar cf - .) | (cd "$TARGET_ROOT" && tar xf -)
    fi
else
    [ -n "$SRC" ] && REPO_URL=$SRC
    if [ -d "${TARGET_ROOT}/.git" ]; then
        say "updating existing checkout in ${TARGET_ROOT}"
        if [ "$DRY_RUN" != true ]; then
            git -C "$TARGET_ROOT" fetch --tags origin || warn "fetch failed; using the checkout as-is"
            [ -n "$BRANCH" ] && git -C "$TARGET_ROOT" checkout "$BRANCH"
            git -C "$TARGET_ROOT" pull --ff-only || warn "pull failed; using the checkout as-is"
            git -C "$TARGET_ROOT" submodule update --init --recursive -j10 || warn "submodule update failed"
        fi
    else
        say "cloning ${REPO_URL} -> ${TARGET_ROOT}"
        if [ "$DRY_RUN" != true ]; then
            if [ -n "$BRANCH" ]; then
                git clone --recursive -j10 --branch "$BRANCH" "$REPO_URL" "$TARGET_ROOT"
            else
                git clone --recursive -j10 "$REPO_URL" "$TARGET_ROOT"
            fi
        fi
    fi
fi

if [ "$DRY_RUN" = true ] && [ ! -f "${TARGET_ROOT}/setup.sh" ]; then
    say "dry-run: repository not present, stopping before setup.sh"
    exit 0
fi

[ -f "${TARGET_ROOT}/setup.sh" ] || die "${TARGET_ROOT}/setup.sh missing - incomplete checkout?"

# ---------------------------------------------------------------------------
# 4. hand over to bash
# ---------------------------------------------------------------------------
command -v bash >/dev/null 2>&1 || pkg_install bash
chmod +x "${TARGET_ROOT}/setup.sh" 2>/dev/null || true

SP_INTERACTIVE=$INTERACTIVE
export SP_INTERACTIVE
SP_DEVENV_ROOT=$TARGET_ROOT
export SP_DEVENV_ROOT

# shellcheck disable=SC2086  # FORWARD is a deliberately unquoted argument list
exec bash "${TARGET_ROOT}/setup.sh" $FORWARD
