#!/bin/bash
# The individual installation steps, each idempotent and safe to re-run.
# Profiles pick which ones to call; setup.sh wraps them in run_step so one
# failure does not abort the whole bootstrap.
# Meant to be *sourced* after lib/pkg.sh.

[ -n "${SP_STEPS_SOURCED:-}" ] && return 0
SP_STEPS_SOURCED=1

_steps_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SP_REPO_ROOT=${SP_REPO_ROOT:-$(cd "${_steps_dir}/.." && pwd)}
SP_INSTALL_DIR="${SP_REPO_ROOT}/install"
SP_DOTFILES="${SP_REPO_ROOT}/dotfiles"
SP_TUNE_DIR="${SP_REPO_ROOT}/tune/os"

# Below these versions the distro package is not worth having and we build
# instead (RL8 ships tmux 2.7, and cmake 3.11 is too old for neovim).
CMAKE_MIN=3.20
TMUX_MIN=3.2

# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

# run_script <script> [args...] : execute one of the install-*.sh helpers, or
# just report it under --dry-run. Every external invocation goes through this so
# a dry run never builds or downloads anything.
run_script() {
    if [ "$SP_DRY_RUN" = true ]; then
        step "[dry-run] $*"
        return 0
    fi
    "$@"
}

# ensure_tool <canonical> <binary> [builder-script]
# Prefer the distro package; fall back to the source/toolchain builder when the
# repos do not carry it (lazygit and delta are missing on several distros).
ensure_tool() {
    local canonical="$1" binary="$2" builder="${3:-}" native=""

    if have "$binary"; then
        step "${binary} already present ($(tool_version "$binary"))"
        return 0
    fi

    native=$(pkgmap "$canonical" 2>/dev/null | awk '{print $1}') || native=""
    if [ -n "$native" ] && pkg_available "$native"; then
        pkg_install_tool "$canonical"
        return 0
    fi

    if [ -n "$builder" ] && [ -x "$builder" ]; then
        warn "${canonical} is not in this distro's repos; building it instead"
        run_script "$builder"
        return 0
    fi

    warn "${canonical} is not available here and cannot be built; skipped"
    return 0
}

# ensure_cmake / ensure_tmux: distro package when new enough, source build when not.
ensure_cmake() {
    local installed candidate
    installed=$(cmd_version cmake)
    if version_ge "$installed" "$CMAKE_MIN"; then
        step "cmake ${installed} is >= ${CMAKE_MIN}, keeping it"
        return 0
    fi
    candidate=$(pkg_bin_version cmake)
    if version_ge "$candidate" "$CMAKE_MIN"; then
        pkg_install cmake
        return 0
    fi
    warn "distro cmake (${candidate:-none}) is older than ${CMAKE_MIN}; installing the Kitware build"
    pkg_install make
    run_script "${SP_INSTALL_DIR}/install-cmake.sh"
}

ensure_tmux() {
    local installed candidate
    installed=$(cmd_version tmux)
    if version_ge "$installed" "$TMUX_MIN"; then
        step "tmux ${installed} is >= ${TMUX_MIN}, keeping it"
        return 0
    fi
    candidate=$(pkg_bin_version tmux)
    if version_ge "$candidate" "$TMUX_MIN"; then
        pkg_install tmux
        return 0
    fi
    warn "distro tmux (${candidate:-none}) is older than ${TMUX_MIN}; building from source"
    pkg_install tmux-build-deps make
    run_script "${SP_INSTALL_DIR}/install-tmux.sh"
}

# ---------------------------------------------------------------------------
# base steps
# ---------------------------------------------------------------------------

step_repos() { pkg_enable_repos; }

step_core_pkgs() {
    pkg_install zsh git git-lfs tig htop ncdu dos2unix tar unzip bzip2 findutils curl ca-certificates less
    # ripgrep keeps its name everywhere; fd-find installs /usr/bin/fdfind on
    # Debian, so pkg_install_tool registers `fd` through update-alternatives.
    pkg_install_tool ripgrep fd
}

step_git() {
    if [ "${SP_BUILD_GIT:-false}" = true ]; then
        pkg_install git-build-deps make
        run_script "${SP_INSTALL_DIR}/install-git.sh"
    else
        pkg_install git
    fi
}

step_toolchain() {
    pkg_install toolchain gettext
    ensure_cmake
    pkg_install ninja
}

step_ohmyzsh() {
    if [ -d "${HOME}/.oh-my-zsh" ]; then
        step "oh-my-zsh already installed"
        return 0
    fi
    have zsh || pkg_install zsh
    step "installing oh-my-zsh"
    [ "$SP_DRY_RUN" = true ] && return 0
    # KEEP_ZSHRC keeps the installer from writing its own ~/.zshrc, which the
    # original script had to move out of the way afterwards.
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL --retry 3 --retry-delay 2 https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
        || die "oh-my-zsh installation failed"
}

step_submodules() {
    if [ ! -d "${SP_REPO_ROOT}/.git" ]; then
        step "not a git checkout (copied tree); skipping submodule update"
        return 0
    fi
    step "updating git submodules"
    [ "$SP_DRY_RUN" = true ] && return 0
    git -C "$SP_REPO_ROOT" submodule update --init --recursive -j10
}

step_links() {
    run_script "${SP_DOTFILES}/set-links.sh" --mode "${SP_LINK_MODE:-entries}"
}

step_gitconfig() {
    local cfg="${SP_DOTFILES}/.config/git/config"
    if [ -e "$cfg" ]; then
        step "git config already present, left untouched"
        return 0
    fi
    step "creating dotfiles/.config/git/config from the template"
    [ "$SP_DRY_RUN" = true ] && return 0
    cp "${cfg}.template" "$cfg"
}

step_neovim() {
    pkg_install nvim-build-deps
    ensure_cmake
    run_script "${SP_INSTALL_DIR}/install-neovim.sh"
}

# ---------------------------------------------------------------------------
# optional steps
# ---------------------------------------------------------------------------

step_extra_dev() {
    pkg_install ccache gdb clang dev-headers make
    [ "$OS_FAMILY" = el ] && pkg_install el-toolsets
    return 0
}

step_tmux() {
    ensure_tmux
    # tpm is a submodule; nothing to install, just report it.
    [ -e "${SP_DOTFILES}/.config/tmux/plugins/tpm/tpm" ] \
        || warn "tmux plugin manager (tpm) submodule is missing"
}

step_fzf() {
    if [ ! -x "${SP_DOTFILES}/fzf/install" ]; then
        warn "fzf submodule missing; run 'git submodule update --init --recursive'"
        return 0
    fi
    step "installing fzf binary"
    run_script "${SP_DOTFILES}/fzf/install" --bin
}

step_bat_delta() {
    ensure_tool bat bat "${SP_INSTALL_DIR}/install-bat.sh"
    ensure_tool delta delta "${SP_INSTALL_DIR}/install-delta.sh"
}

step_git_uis() {
    ensure_tool lazygit lazygit "${SP_INSTALL_DIR}/install-lazygit.sh"
    ensure_tool tig tig
}

step_misc_cli() { pkg_install lbzip2 python3 sqlite jq; }

step_rust() {
    if have rustc; then
        step "rust already installed ($(tool_version rustc))"
        return 0
    fi
    run_script "${SP_INSTALL_DIR}/install-rust.sh"
}

step_go() {
    if have go || [ -x /usr/local/go/bin/go ]; then
        step "go already installed"
        return 0
    fi
    run_script "${SP_INSTALL_DIR}/install-golang.sh"
}

step_claude() {
    if have claude; then
        step "claude already installed"
        return 0
    fi
    run_script "${SP_INSTALL_DIR}/install-claude.sh"
}

step_chsh() {
    local zsh_path
    zsh_path=$(command -v zsh) || { warn "zsh not found; cannot change the shell"; return 0; }
    if [ "${SHELL:-}" = "$zsh_path" ]; then
        step "login shell is already ${zsh_path}"
        return 0
    fi
    pkg_install chsh
    step "changing the login shell to ${zsh_path}"
    [ "$SP_DRY_RUN" = true ] && return 0
    grep -qxF "$zsh_path" /etc/shells 2>/dev/null \
        || echo "$zsh_path" | ${SUDO} tee -a /etc/shells >/dev/null
    ${SUDO} chsh -s "$zsh_path" "$(id -un)" || warn "chsh failed"
}

step_sctp() {
    if [ "$IS_CONTAINER" = true ]; then
        skip_step "SCTP setup" "containers cannot load kernel modules"
        return 0
    fi
    if [ "$IS_PVE" = true ]; then
        skip_step "SCTP setup" "not loading modules on a Proxmox host"
        return 0
    fi
    run_script "${SP_INSTALL_DIR}/install-sctp.sh"
}

step_dev_tools() { run_script "${SP_TUNE_DIR}/install-dev-tools.sh"; }

step_opt_tools() { run_script "${SP_INSTALL_DIR}/rebuild_all_tools.sh"; }

step_work_tweaks() { run_script "${SP_TUNE_DIR}/configure-services.sh"; }
