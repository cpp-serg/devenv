#!/bin/bash
# Install runtime dependencies for srsRAN 4G on Rocky Linux 8/9, RHEL 8/9, CentOS 8
set -euo pipefail

SUDO=$([ "$(id -u)" -ne 0 ] && echo "sudo" || echo "")

# Detect OS major version
OS_VER=$(rpm -E %{rhel})
echo "=== Installing srsRAN 4G runtime dependencies (EL${OS_VER}) ==="

# EPEL is required for mbedtls, zeromq, libsodium, openpgm
$SUDO dnf install -y epel-release

# powertools (EL8) was renamed to crb (EL9)
if [ "$OS_VER" -ge 9 ]; then
    $SUDO dnf config-manager --set-enabled crb
else
    $SUDO dnf config-manager --set-enabled powertools
fi

PACKAGES=(
    fftw-libs-single
    mbedtls
    lksctp-tools
    libconfig
    libunwind
)

$SUDO dnf install -y "${PACKAGES[@]}"

echo ""
echo "=== All dependencies installed ==="
echo ""
echo "To run srsRAN binaries from this folder:"
echo "  export LD_LIBRARY_PATH=$(cd "$(dirname "$0")" && pwd)/lib"
echo "  ./srsenb config/enb.conf"
echo "  ./srsue  config/ue.conf"
echo "  ./srsepc config/epc.conf"
