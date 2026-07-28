#!/bin/bash
# Everyday software for a devenv machine, in distro-neutral terms.
#
# Kept as a standalone entry point (it predates setup.sh), but it now shares the
# same step functions, so "setup.sh --dev" and running this by hand install the
# same things. Prefer setup.sh; this is for topping up an existing machine.

set -euo pipefail

MY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SP_REPO_ROOT=$(cd "${MY_DIR}/../.." && pwd)
export SP_REPO_ROOT

# shellcheck source=lib/pkg.sh
. "${SP_REPO_ROOT}/lib/pkg.sh"
# shellcheck source=lib/steps.sh
. "${SP_REPO_ROOT}/lib/steps.sh"

pkg_enable_repos

step_core_pkgs
step_misc_cli
pkg_install dialog make

step_toolchain      # gcc/g++/make + cmake (>= 3.20) + ninja + gettext
step_tmux           # distro package when new enough, source build otherwise
step_neovim         # always built from source
step_fzf
step_sctp || warn "SCTP setup failed; continuing"
