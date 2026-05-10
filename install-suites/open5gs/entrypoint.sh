#!/usr/bin/env bash
# entrypoint.sh — run rpmbuild against the bind-mounted source tree
set -euo pipefail

OPEN5GS_VERSION="${OPEN5GS_VERSION:-2.7.7}"
BUILD_DIR="/root/rpmbuild/BUILD/open5gs-${OPEN5GS_VERSION}"

echo "==> ccache stats (before):"
ccache -s 2>/dev/null || true

# Source is already bind-mounted at BUILD_DIR by docker run.
# Verify it exists.
if [[ ! -f "${BUILD_DIR}/meson.build" ]]; then
    echo "ERROR: source not found at ${BUILD_DIR}/meson.build" >&2
    echo "       Mount the source directory to ${BUILD_DIR}" >&2
    exit 1
fi

echo "==> Copying spec file ..."
cp /spec/open5gs.spec /root/rpmbuild/SPECS/open5gs.spec

echo "==> Running rpmbuild ..."
QA_RPATHS=0x0001 rpmbuild -bb --noclean \
    --undefine=_disable_source_fetch \
    /root/rpmbuild/SPECS/open5gs.spec \
    2>&1 | tee /tmp/rpmbuild.log || \
{ echo "=== RPM BUILD FAILED ===" ; tail -100 /tmp/rpmbuild.log ; exit 1 ; }

echo "==> Copying results to /output ..."
cp -rv /root/rpmbuild/RPMS/*/*.rpm /output/
cp -a /root/rpmbuild/BUILDROOT /output/rpmbuild-BUILDROOT

echo "==> ccache stats (after):"
ccache -s 2>/dev/null || true

echo "=== Done ==="
