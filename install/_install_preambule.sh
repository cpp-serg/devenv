#!/bin/bash
# Common preamble for the install scripts. Meant to be *sourced*, not executed:
#   source "$(dirname "${BASH_SOURCE[0]}")/_install_preambule.sh"
# Provides: strict mode, ${SUDO}, ${SYSTEM_ARCH}, die(), _workdir(),
# _deploy_to_opt().

set -euo pipefail

# sudo prefix when not already running as root, empty otherwise
SUDO=$([ "$(id -u)" -ne 0 ] && echo sudo || true)

# Architecture of the machine this script runs on (uname -m form: x86_64,
# aarch64, ...), detected once at source time so callers can reference it
# directly as ${SYSTEM_ARCH}.
SYSTEM_ARCH=$(uname -m)

function die() {
  echo "$1" 1>&2
  exit 1
}

# cd into a fresh temporary directory that is removed automatically when the
# script exits (on success or failure). Use this before cloning/building so
# re-runs stay clean and a failed build leaves nothing behind.
function _workdir() {
  local d
  d=$(mktemp -d)
  trap "rm -rf '$d'" EXIT
  cd "$d" || die "Failed to enter work directory $d"
}

# Deploy a built binary into /opt/tools (creating the directory if needed) and
# make it executable, then print a success line.
#   _deploy_to_opt <source-binary-path> [target-name]
# target-name defaults to the basename of the source path.
function _deploy_to_opt() {
  local src="$1"
  local target="${2:-$(basename "$src")}"

  ${SUDO} install -d -m 755 /opt/tools
  ${SUDO} install -m 755 "$src" "/opt/tools/$target"

  local version
  version=$("/opt/tools/$target" --version 2>/dev/null | head -n1 || true)
  echo "$target $version installed successfully"
}
