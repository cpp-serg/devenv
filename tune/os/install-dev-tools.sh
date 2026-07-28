#!/bin/bash
# Compiler-adjacent extras: caches, debuggers, sanitizer runtimes and the
# -devel/-dev headers that building things tends to need.
#
# On EL this includes the gcc-toolset collections, which is how a Rocky 8 box
# gets a modern g++ and gdb. Debian/Ubuntu have no equivalent - their gcc is
# already current and ships its own libasan - so those entries map to plain gdb
# (see lib/pkgmap.sh).

set -euo pipefail

MY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/pkg.sh
. "${MY_DIR}/../../lib/pkg.sh"

pkg_install toolchain make cmake ninja ccache gdb dev-headers \
    tar bzip2 unzip python3 sqlite dos2unix lbzip2 git git-lfs

if [ "$OS_FAMILY" = el ]; then
    pkg_install el-toolsets
fi
