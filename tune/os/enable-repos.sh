#!/bin/bash
# Enable the repositories the rest of the setup needs:
#   EL      EPEL plus CodeReady Builder (called powertools on EL8)
#   Ubuntu  the universe component, if ripgrep/fd-find are not reachable
#   Debian  nothing beyond an index refresh
#   Proxmox nothing at all - a PVE host's apt sources are left alone
#
# The logic itself lives in pkg_enable_repos (lib/pkg.sh) so setup.sh and this
# standalone entry point cannot drift apart.

set -euo pipefail

MY_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/pkg.sh
. "${MY_DIR}/../../lib/pkg.sh"

pkg_enable_repos
