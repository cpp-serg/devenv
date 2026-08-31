#!/usr/bin/env bash
# entrypoint.sh — run rpmbuild against the bind-mounted source tree
set -euo pipefail

# Same version.env build.sh read, via the /spec mount. build.sh also exports
# these, and version.env assigns with := so the exported values win — either way
# the spec's Version: and the mounted BUILD path cannot disagree.
# shellcheck source=version.env
source /spec/version.env

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
    --define "open5gs_version ${OPEN5GS_VERSION}" \
    --define "open5gs_release ${OPEN5GS_RELEASE}" \
    /root/rpmbuild/SPECS/open5gs.spec \
    2>&1 | tee /tmp/rpmbuild.log || \
{ echo "=== RPM BUILD FAILED ===" ; tail -100 /tmp/rpmbuild.log ; exit 1 ; }

echo "==> Copying results to /output ..."
# Clear previously built RPMs first. The install scripts locate packages with
# "ls open5gs-<comp>-*.rpm | head -1", which sorts alphabetically — leaving an
# older build in place would silently install it (2.7.7 sorts before 2.8.0).
rm -f /output/*.rpm
cp -rv /root/rpmbuild/RPMS/*/*.rpm /output/

# Replace the BUILDROOT copy rather than copying into it: "cp -a src dst" with
# an existing dst nests as dst/BUILDROOT/, and install.sh expects the
# open5gs-<version>-<release>.<dist>.<arch> directory at the top level.
rm -rf /output/rpmbuild-BUILDROOT
mkdir -p /output/rpmbuild-BUILDROOT
cp -a /root/rpmbuild/BUILDROOT/. /output/rpmbuild-BUILDROOT/

echo "==> ccache stats (after):"
ccache -s 2>/dev/null || true

echo "=== Done ==="
