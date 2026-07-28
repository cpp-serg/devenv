#!/bin/bash
# Host OS detection. Meant to be *sourced*, not executed:
#   source "${SP_REPO_ROOT}/lib/distro.sh"
#
# Exposes:
#   OS_ID        rocky | debian | ubuntu | ...      (/etc/os-release ID)
#   OS_VER       8.10 | 13.6 | 24.04 | ...          (VERSION_ID)
#   OS_MAJOR     8 | 13 | 24
#   OS_FAMILY    el | debian                        (which package manager dialect)
#   OS_PRETTY    human readable name
#   PKG_MGR      dnf | yum | apt-get
#   IS_PVE       true when running on a Proxmox VE host
#   IS_CONTAINER true inside a container (LXC, docker, ...)
#   SUDO         "sudo" when not root, empty when root
#   SYSTEM_ARCH  uname -m

[ -n "${SP_DISTRO_SOURCED:-}" ] && return 0
SP_DISTRO_SOURCED=1

OS_ID=unknown
OS_VER=""
OS_PRETTY=""
_os_like=""

if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID=${ID:-unknown}
    OS_VER=${VERSION_ID:-}
    OS_PRETTY=${PRETTY_NAME:-$OS_ID}
    _os_like=${ID_LIKE:-}
fi

# shellcheck disable=SC2034  # consumed by lib/pkg.sh and the profiles
OS_MAJOR=${OS_VER%%.*}

OS_FAMILY=unknown
case " ${OS_ID} ${_os_like} " in
    *" rhel "* | *" centos "* | *" fedora "*) OS_FAMILY=el ;;
    *" debian "* | *" ubuntu "*) OS_FAMILY=debian ;;
esac

PKG_MGR=""
case ${OS_FAMILY} in
    el)
        if command -v dnf >/dev/null 2>&1; then
            PKG_MGR=dnf
        elif command -v yum >/dev/null 2>&1; then
            PKG_MGR=yum
        fi
        ;;
    debian) command -v apt-get >/dev/null 2>&1 && PKG_MGR=apt-get ;;
esac

# Proxmox VE host: Debian underneath, but its apt sources and sshd config must
# not be touched, and installing a build toolchain on a hypervisor is a choice
# the user should make deliberately.
IS_PVE=false
if [ -d /etc/pve ] && command -v pveversion >/dev/null 2>&1; then
    IS_PVE=true
fi

# Containers cannot load kernel modules, so SCTP setup and similar steps have
# to degrade to a warning instead of failing the run.
IS_CONTAINER=false
if [ -f /.dockerenv ] || [ -f /run/systemd/container ] || [ -n "${container:-}" ]; then
    IS_CONTAINER=true
elif command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt -cq 2>/dev/null; then
    IS_CONTAINER=true
fi

SYSTEM_ARCH=$(uname -m)

# sudo prefix when not already running as root, empty otherwise. Unlike the
# original one-liner this refuses to hand back "sudo" when sudo is not actually
# installed, so the failure is a clear message instead of "sudo: not found"
# repeated for every package.
# shellcheck disable=SC2034  # used by every sourcing script
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        # shellcheck disable=SC2034  # used by every sourcing script
        SUDO=sudo
    else
        echo "ERROR: not running as root and sudo is not installed." >&2
        echo "       Re-run as root, or install sudo first." >&2
        return 1 2>/dev/null || exit 1
    fi
fi

distro_summary() {
    printf '%s (id=%s ver=%s family=%s pkg=%s arch=%s)' \
        "${OS_PRETTY:-unknown}" "$OS_ID" "${OS_VER:-?}" "$OS_FAMILY" "${PKG_MGR:-none}" "$SYSTEM_ARCH"
    [ "$IS_PVE" = true ] && printf ' [Proxmox VE host]'
    [ "$IS_CONTAINER" = true ] && printf ' [container]'
    printf '\n'
}
