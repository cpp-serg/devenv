#!/bin/bash
# User mode: the base profile plus an interview. Each group prints what is
# already installed on this host before asking, so the answer is informed by the
# machine rather than guessed. --yes takes every default.

# shellcheck shell=bash

profile_user() {
    header "Optional components"
    say "Answer once per group. Defaults are in capitals; --yes accepts them all."

    if ask_group n "Extra developer packages (beyond the base toolchain)" ccache gdb clang; then
        run_step "extra developer packages" step_extra_dev || true
    else
        skip_step "extra developer packages"
    fi

    if ask_group y "Terminal multiplexer" tmux; then
        run_step "tmux" step_tmux || true
    else
        skip_step "tmux"
    fi

    if ask_group y "Fuzzy finder (fzf + fzf-git key bindings)" fzf; then
        run_step "fzf" step_fzf || true
    else
        skip_step "fzf"
    fi

    if ask_group y "Pager and diff tooling (bat previews, delta as git pager)" bat delta; then
        run_step "bat + delta" step_bat_delta || true
    else
        skip_step "bat + delta"
    fi

    if ask_group y "Git browsers" lazygit tig; then
        run_step "lazygit + tig" step_git_uis || true
    else
        skip_step "lazygit + tig"
    fi

    if ask_group y "Misc command line tools" lbzip2 python3 sqlite3 jq; then
        run_step "misc CLI tools" step_misc_cli || true
    else
        skip_step "misc CLI tools"
    fi

    if ask_group n "Language toolchains (needed to build the /opt/tools binaries)" rustc go; then
        run_step "rust" step_rust || true
        run_step "go" step_go || true
    else
        skip_step "rust + go toolchains"
    fi

    if ask_group n "Claude Code CLI" claude; then
        run_step "claude" step_claude || true
    else
        skip_step "claude"
    fi

    if ask_group y "Make zsh the login shell" zsh; then
        run_step "login shell" step_chsh || true
    else
        skip_step "login shell change"
    fi
}
