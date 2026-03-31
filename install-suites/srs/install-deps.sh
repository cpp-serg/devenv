#!/bin/bash
# Install runtime dependencies for srsRAN 4G on Rocky Linux 8 / RHEL 8 / CentOS 8
set -euo pipefail

SUDO=$([ "$(id -u)" -ne 0 ] && echo "sudo" || echo "")

echo "=== Installing srsRAN 4G runtime dependencies ==="

# EPEL is required for mbedtls, zeromq, libsodium, openpgm
$SUDO dnf install -y epel-release
$SUDO dnf config-manager --set-enabled powertools

$SUDO dnf install -y \
    fftw-libs-single \
    mbedtls \
    lksctp-tools \
    libconfig \
    zeromq \
    boost-program-options \
    libsodium \
    openpgm \
    libunwind

echo ""
echo "=== All dependencies installed ==="
echo ""
echo "To run srsRAN binaries from this folder:"
echo "  export LD_LIBRARY_PATH=$(cd "$(dirname "$0")" && pwd)/lib"
echo "  ./srsenb config/enb.conf"
echo "  ./srsue  config/ue.conf"
echo "  ./srsepc config/epc.conf"
