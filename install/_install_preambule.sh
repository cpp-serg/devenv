#!/bin/bash
# Common preamble for the install scripts. Meant to be *sourced*, not executed:
#   source "$(dirname "${BASH_SOURCE[0]}")/_install_preambule.sh"
#
# Provides strict mode plus everything from lib/: ${SUDO}, ${SYSTEM_ARCH},
# ${OS_FAMILY}, die(), warn(), step(), pkg_install(), alt_register(), and the
# local helpers _workdir() and _deploy_to_opt().
#
# Build dependencies are declared with canonical names and resolved per distro
# by lib/pkgmap.sh, so no install script mentions dnf or apt directly.

set -euo pipefail

_preambule_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/pkg.sh
. "${_preambule_dir}/../lib/pkg.sh"

# cd into a fresh temporary directory that is removed automatically when the
# script exits (on success or failure). Use this before cloning/building so
# re-runs stay clean and a failed build leaves nothing behind.
function _workdir() {
  local d
  d=$(mktemp -d)
  # shellcheck disable=SC2064  # expand $d now: the trap must know this dir
  trap "rm -rf '$d'" EXIT
  cd "$d" || die "Failed to enter work directory $d"
}

# Deploy a built binary into /opt/tools (creating the directory if needed) and
# make it executable, then print a success line.
#   _deploy_to_opt <source-binary-path> [target-name]
# target-name defaults to the basename of the source path.
#
# The binary is also registered with update-alternatives at priority 100, above
# the 50 the distro packages get, so a freshly built tool takes over the plain
# name (fd, bat, ...) even where the distro ships a differently named one.
function _deploy_to_opt() {
  local src="$1"
  local target="${2:-$(basename "$src")}"

  ${SUDO} install -d -m 755 /opt/tools
  ${SUDO} install -m 755 "$src" "/opt/tools/$target"

  alt_register "$target" "/opt/tools/$target" 100

  local version
  version=$("/opt/tools/$target" --version 2>/dev/null | head -n1 || true)
  echo "$target $version installed successfully"
}
