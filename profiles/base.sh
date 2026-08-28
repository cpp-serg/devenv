#!/bin/bash
# The unconditional part of a devenv machine: shell, dotfiles, search tools and
# the editor. Runs in both user and dev mode and is never asked about.
#
# The toolchain (gcc/g++/make/cmake/ninja/gettext) is part of the base because
# neovim is always built from source - it is a prerequisite, not an option.

# shellcheck shell=bash

profile_base() {
    header "Base configuration (installed in every mode)"

    # EPEL/CRB on EL, universe on Ubuntu: ripgrep and fd-find are not in the
    # RL8 core repos, so this has to happen before any package install.
    run_step "repositories" step_repos || true

    run_step "core packages" step_core_pkgs || true
    run_step "git" step_git || true
    # As everywhere else here: record the failure in the summary and keep going.
    # setup.sh still exits non-zero at the end if anything failed.
    run_step "oh-my-zsh" step_ohmyzsh || true
    run_step "git submodules" step_submodules || true
    run_step "dotfile symlinks" step_links || true
    run_step "git config" step_gitconfig || true

    # Neovim is always built from source, on every distro, which is what makes
    # the toolchain mandatory.
    run_step "build toolchain" step_toolchain || true
    run_step "neovim (source build)" step_neovim || true
}
