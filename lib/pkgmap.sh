#!/bin/bash
# Canonical tool name -> native package name(s) for the detected OS family.
# Meant to be *sourced*; requires lib/distro.sh to have been sourced first.
#
#   pkgmap zsh          -> zsh
#   pkgmap sqlite       -> sqlite   (el)   / sqlite3        (debian)
#   pkgmap toolchain    -> gcc gcc-c++ make (el) / build-essential (debian)
#
# Names that are identical on both families fall through to the default branch,
# so only the divergent ones need an entry.

[ -n "${SP_PKGMAP_SOURCED:-}" ] && return 0
SP_PKGMAP_SOURCED=1

# _pkgmap_pick <candidate>... : the first candidate the enabled repos actually
# carry, falling back to the first one so the caller still names something.
# For the handful of tools whose package name moves between releases and there
# is no version to key off reliably. Each probe costs a repo lookup, so the
# answer is cached for the rest of the run.
declare -A _PKGMAP_PICKED=()
_pkgmap_pick() {
    local key="$*" c
    if [ -n "${_PKGMAP_PICKED[$key]:-}" ]; then
        echo "${_PKGMAP_PICKED[$key]}"
        return 0
    fi
    # pkg_available lives in lib/pkg.sh, which sources this file; it exists by
    # the time pkgmap is actually called, but not while this file is read.
    if declare -F pkg_available >/dev/null 2>&1; then
        for c in "$@"; do
            if pkg_available "$c"; then
                _PKGMAP_PICKED[$key]=$c
                echo "$c"
                return 0
            fi
        done
    fi
    _PKGMAP_PICKED[$key]=$1
    echo "$1"
}

# pkgmap <canonical> : print the native package list, or nothing when the
# canonical name has no meaning on this family (e.g. el-toolsets on Debian).
pkgmap() {
    local name="$1"

    if [ "$OS_FAMILY" = el ]; then
        case "$name" in
            toolchain)       echo "gcc gcc-c++ make" ;;
            gxx)             echo "gcc-c++" ;;
            sqlite)          echo "sqlite" ;;
            chsh)            echo "util-linux-user" ;;
            xmllint)         echo "libxml2" ;;
            ninja)           echo "ninja-build" ;;
            dev-headers)     echo "libxml2-devel openssl-devel expat-devel libcurl-devel" ;;
            git-build-deps)  echo "autoconf gettext-devel libcurl-devel openssl-devel expat-devel" ;;
            tmux-build-deps) echo "automake libevent-devel byacc ncurses-devel" ;;
            nvim-build-deps) echo "gcc gcc-c++ make gettext ninja-build curl unzip git patch" ;;
            sctp)            echo "lksctp-tools lksctp-tools-devel" ;;
            # EL8 has no bare `python3` package - the platform interpreter is
            # python36 and the newer streams are python3.11/python3.12. EL9+
            # does ship `python3`, so ask the repos rather than hardcoding.
            python3)         _pkgmap_pick python3 python3.12 python3.11 python36 ;;
            el-toolsets)     echo "gcc-toolset-13-gcc-c++ gcc-toolset-14-gdb gcc-toolset-13-libasan-devel" ;;
            *)               _pkgmap_common "$name" ;;
        esac
        return
    fi

    if [ "$OS_FAMILY" = debian ]; then
        case "$name" in
            toolchain)       echo "build-essential" ;;
            gxx)             echo "g++" ;;
            sqlite)          echo "sqlite3" ;;
            chsh)            echo "passwd" ;;
            xmllint)         echo "libxml2-utils" ;;
            ninja)           echo "ninja-build" ;;
            dev-headers)     echo "libxml2-dev libssl-dev libexpat1-dev libcurl4-openssl-dev" ;;
            git-build-deps)  echo "autoconf gettext libcurl4-openssl-dev libssl-dev libexpat1-dev" ;;
            tmux-build-deps) echo "automake libevent-dev bison libncurses-dev pkg-config" ;;
            nvim-build-deps) echo "build-essential gettext ninja-build curl unzip git patch" ;;
            sctp)            echo "libsctp-dev lksctp-tools" ;;
            # No gcc-toolset concept; gcc already ships its matching libasan.
            el-toolsets)     echo "gdb" ;;
            *)               _pkgmap_common "$name" ;;
        esac
        return
    fi

    echo "pkgmap: unsupported OS family '${OS_FAMILY}'" >&2
    return 1
}

# Canonical names whose package name is the same on both families.
_pkgmap_common() {
    case "$1" in
        zsh | git | git-lfs | tig | htop | ncdu | dos2unix | lbzip2 | unzip | bzip2 | tar | \
            findutils | python3 | jq | make | ccache | gdb | clang | ripgrep | cmake | gcc | \
            gettext | curl | ca-certificates | dialog | ncurses-term | tmux | wget | rsync | \
            less | file | patch | autoconf | automake | libtool | sudo | flex | bison)
            echo "$1"
            ;;
        # fd-find on both, but the binary it installs differs (see alt_register).
        fd) echo "fd-find" ;;
        bat) echo "bat" ;;
        # Packaged as git-delta; the binary is `delta`.
        delta) echo "git-delta" ;;
        lazygit) echo "lazygit" ;;
        *)
            echo "pkgmap: unknown canonical package '$1'" >&2
            return 1
            ;;
    esac
}

# Binaries whose distro package installs them under a different name.
# Prints the real binary name for the current family, or the canonical name.
pkgmap_binary() {
    if [ "$OS_FAMILY" = debian ]; then
        case "$1" in
            fd)  echo fdfind ;;
            bat) echo batcat ;;
            *)   echo "$1" ;;
        esac
    else
        echo "$1"
    fi
}
