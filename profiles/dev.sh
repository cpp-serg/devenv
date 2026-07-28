#!/bin/bash
# Developer mode: everything, without asking. This is the original bootstrap
# behaviour, plus the version floors and the distro abstraction.

# shellcheck shell=bash

profile_dev() {
    header "Developer components"

    run_step "extra developer packages" step_extra_dev || true
    run_step "EL toolsets / dev headers" step_dev_tools || true
    run_step "tmux" step_tmux || true
    run_step "fzf" step_fzf || true
    run_step "bat + delta" step_bat_delta || true
    run_step "lazygit + tig" step_git_uis || true
    run_step "misc CLI tools" step_misc_cli || true
    run_step "rust" step_rust || true
    run_step "go" step_go || true
    run_step "claude" step_claude || true
    run_step "SCTP" step_sctp || true
    run_step "login shell" step_chsh || true

    # Rust/Go built tools that land in /opt/tools (fd, rg, bat, delta, difft,
    # fzf, lazygit, peco, tree-sitter). They take priority 100 in
    # update-alternatives, above the distro packages installed above.
    run_step "/opt/tools rebuild" step_opt_tools || true

    # Site-specific: the CIFS build share, sshd banner/forwarding, tmux lock.
    # Dev mode only, and skippable with --no-work-tweaks.
    if [ "${SP_WORK_TWEAKS:-true}" = true ]; then
        run_step "work host tweaks" step_work_tweaks || true
    else
        skip_step "work host tweaks" "--no-work-tweaks"
    fi
}
