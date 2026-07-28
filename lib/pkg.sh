#!/bin/bash
# The only place in the repo that knows dnf from apt-get. Everything else calls
# pkg_install with canonical names from lib/pkgmap.sh.
# Meant to be *sourced*; sources distro/pkgmap/ui/version itself.

[ -n "${SP_PKG_SOURCED:-}" ] && return 0
SP_PKG_SOURCED=1

_pkg_lib_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/distro.sh
. "${_pkg_lib_dir}/distro.sh"
# shellcheck source=lib/ui.sh
. "${_pkg_lib_dir}/ui.sh"
# shellcheck source=lib/pkgmap.sh
. "${_pkg_lib_dir}/pkgmap.sh"
# shellcheck source=lib/version.sh
. "${_pkg_lib_dir}/version.sh"

export DEBIAN_FRONTEND=noninteractive

_PKG_REFRESHED=false

# pkg_refresh : update the package index, at most once per run.
pkg_refresh() {
    [ "$_PKG_REFRESHED" = true ] && return 0
    _PKG_REFRESHED=true
    [ "$SP_DRY_RUN" = true ] && { step "[dry-run] refresh package index"; return 0; }

    case "$PKG_MGR" in
        apt-get) ${SUDO} apt-get update -qq || warn "apt-get update reported errors; continuing" ;;
        dnf | yum) ${SUDO} "$PKG_MGR" -q makecache || warn "${PKG_MGR} makecache reported errors; continuing" ;;
        *) die "no supported package manager found (family=${OS_FAMILY})" ;;
    esac
}

# pkg_installed <native-package> : already installed?
pkg_installed() {
    case "$OS_FAMILY" in
        el) rpm -q --quiet "$1" ;;
        debian)
            [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" = installed ] ;;
        *) return 1 ;;
    esac
}

# pkg_available <native-package> : known to the enabled repos?
pkg_available() {
    case "$OS_FAMILY" in
        el) ${PKG_MGR} -q info "$1" >/dev/null 2>&1 ;;
        debian) [ -n "$(apt-cache policy "$1" 2>/dev/null | sed -nE 's/^ *Candidate: (.+)/\1/p' | grep -v '^(none)$')" ] ;;
        *) return 1 ;;
    esac
}

# pkg_install_native <native-package>... : install the ones that are missing.
# Packages the repos do not carry are reported and skipped rather than aborting
# the run (e.g. lbzip2 is absent from Debian 13).
pkg_install_native() {
    local want=() missing=() unavailable=() p
    for p in "$@"; do
        pkg_installed "$p" && continue
        want+=("$p")
    done
    [ "${#want[@]}" -eq 0 ] && return 0

    pkg_refresh
    for p in "${want[@]}"; do
        if pkg_available "$p"; then
            missing+=("$p")
        else
            unavailable+=("$p")
        fi
    done

    [ "${#unavailable[@]}" -ne 0 ] && warn "not available in this distro's repos, skipped: ${unavailable[*]}"
    [ "${#missing[@]}" -eq 0 ] && return 0

    step "installing: ${missing[*]}"
    [ "$SP_DRY_RUN" = true ] && return 0

    case "$PKG_MGR" in
        apt-get) ${SUDO} apt-get install -y --no-install-recommends "${missing[@]}" ;;
        dnf | yum) ${SUDO} "$PKG_MGR" install -y "${missing[@]}" ;;
        *) die "no supported package manager found" ;;
    esac
}

# pkg_install <canonical>... : map to native names, then install.
pkg_install() {
    local native=() c mapped parts
    for c in "$@"; do
        mapped=$(pkgmap "$c") || return 1
        [ -z "$mapped" ] && continue
        parts=()
        read -ra parts <<<"$mapped"
        native+=("${parts[@]}")
    done
    [ "${#native[@]}" -eq 0 ] && return 0
    pkg_install_native "${native[@]}"
}

# pkg_bin_version <canonical> : version of the *candidate* distro package, so a
# caller can decide package-vs-source before installing anything.
pkg_bin_version() {
    local native
    native=$(pkgmap "$1" | awk '{print $1}') || return 0
    case "$OS_FAMILY" in
        el) version_normalize "$(${PKG_MGR} -q info "$native" 2>/dev/null | sed -nE 's/^Version *: *(.+)/\1/p' | head -n1)" ;;
        debian) version_normalize "$(apt-cache policy "$native" 2>/dev/null | sed -nE 's/^ *Candidate: (.+)/\1/p' | head -n1)" ;;
    esac
}

# ---------------------------------------------------------------------------
# update-alternatives wrapper
# ---------------------------------------------------------------------------
# alt_register <name> <target-binary> [priority]
#
# Registers <target-binary> as /usr/local/bin/<name>. Used for the Debian
# packages whose binary is named differently (fd-find -> fdfind, bat ->
# batcat), and by the /opt installers via install/_install_preambule.sh.
#
# Priority 50 for distro packages, leaving the 100 the /opt builds use to win,
# so a later `cargo install fd-find` automatically takes over and
# `update-alternatives --config fd` can switch back.
alt_register() {
    local name="$1" target="$2" prio="${3:-50}" resolved

    resolved=$(command -v "$target" 2>/dev/null) || resolved=""
    [ -z "$resolved" ] && [ -x "$target" ] && resolved="$target"
    if [ -z "$resolved" ]; then
        # Under --dry-run the package was never installed, so its binary is
        # legitimately absent - report the intent instead of a warning.
        if [ "$SP_DRY_RUN" = true ]; then
            step "[dry-run] alternatives: ${name} -> ${target} (priority ${prio})"
        else
            warn "alt_register: ${target} not found, skipping ${name}"
        fi
        return 0
    fi

    # Nothing to do when the name already resolves to this exact binary and it
    # is not the alternatives link itself.
    if [ "$resolved" = "/usr/local/bin/${name}" ]; then
        return 0
    fi

    step "alternatives: ${name} -> ${resolved} (priority ${prio})"
    [ "$SP_DRY_RUN" = true ] && return 0

    if have update-alternatives; then
        ${SUDO} update-alternatives --install "/usr/local/bin/${name}" "$name" "$resolved" "$prio" \
            || warn "update-alternatives failed for ${name}"
    else
        # Rare, but keep working: ~/.local/bin is already first on PATH in .zshrc.
        warn "update-alternatives missing; linking ~/.local/bin/${name} instead"
        mkdir -p "${HOME}/.local/bin"
        ln -sfn "$resolved" "${HOME}/.local/bin/${name}"
    fi
}

# pkg_install_tool <canonical> : install the package and, when the distro names
# the binary differently, register the canonical name via alternatives.
pkg_install_tool() {
    local c real
    for c in "$@"; do
        pkg_install "$c" || return 1
        real=$(pkgmap_binary "$c")
        [ "$real" = "$c" ] && continue
        [ "$SP_DRY_RUN" = true ] || have "$real" || continue
        alt_register "$c" "$real" 50
    done
}

# ---------------------------------------------------------------------------
# Repository enablement (EPEL/CRB on EL, universe on Ubuntu). Needed by the
# base profile, not just dev mode: ripgrep and fd-find live in EPEL on EL8.
# ---------------------------------------------------------------------------
pkg_enable_repos() {
    if [ "$IS_PVE" = true ]; then
        skip_step "repo setup" "Proxmox VE host - leaving apt sources alone"
        return 0
    fi

    case "$OS_FAMILY" in
        el) _pkg_enable_repos_el ;;
        debian) _pkg_enable_repos_debian ;;
    esac
}

_pkg_enable_repos_el() {
    [ "$SP_DRY_RUN" = true ] && { step "[dry-run] enable EPEL + CRB/PowerTools"; return 0; }

    pkg_install_native dnf-plugins-core || warn "failed to install dnf-plugins-core"

    if ! rpm -q --quiet epel-release; then
        step "installing epel-release"
        ${SUDO} "$PKG_MGR" install -y epel-release || warn "failed to install epel-release"
    fi

    # The CodeReady Builder repo carries the -devel packages EPEL builds against.
    # EL9+ ships the `crb` helper; on EL8 the repo is called powertools.
    if have crb; then
        ${SUDO} crb enable || warn "crb enable failed"
    elif [ "${OS_MAJOR:-0}" -le 8 ]; then
        ${SUDO} "$PKG_MGR" config-manager --set-enabled powertools \
            || ${SUDO} "$PKG_MGR" config-manager --set-enabled PowerTools \
            || warn "could not enable powertools"
    fi

    _PKG_REFRESHED=false   # new repos, index must be rebuilt
    pkg_refresh
}

_pkg_enable_repos_debian() {
    pkg_refresh
    # Ubuntu keeps ripgrep/fd-find/bat in universe; only touch sources if they
    # are genuinely unreachable.
    if [ "$OS_ID" = ubuntu ] && ! pkg_available ripgrep; then
        step "enabling the universe component"
        [ "$SP_DRY_RUN" = true ] && return 0
        if have add-apt-repository; then
            ${SUDO} add-apt-repository -y universe || warn "add-apt-repository universe failed"
        else
            pkg_install_native software-properties-common \
                && ${SUDO} add-apt-repository -y universe \
                || warn "could not enable universe"
        fi
        _PKG_REFRESHED=false
        pkg_refresh
    fi
}
