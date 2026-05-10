#!/usr/bin/env bash
# build.sh — Build Open5GS RPMs for Rocky Linux 8 via Docker/Podman
#
# Source code is cloned to ./open5gs-source on the host and mounted
# into the build container, along with ccache and output volumes.
#
# Usage:
#   ./build.sh              # build and extract RPMs to ./rpms/
#   ./build.sh --no-cache   # rebuild image from scratch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="open5gs-rpm-builder"
OUTPUT_DIR="${SCRIPT_DIR}/rpms"
SOURCE_DIR="${SCRIPT_DIR}/open5gs-source"
CCACHE_DIR="${SCRIPT_DIR}/cont_ccache"
OPEN5GS_VERSION="2.7.7"
OPEN5GS_REPO="https://github.com/open5gs/open5gs.git"

# Use podman if docker is not available
if command -v docker &>/dev/null; then
    CTR=docker
elif command -v podman &>/dev/null; then
    CTR=podman
else
    echo "ERROR: neither docker nor podman found" >&2
    exit 1
fi

CTR_ARGS=()
for arg in "$@"; do
    case "$arg" in
        --no-cache) CTR_ARGS+=(--no-cache) ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ---------- clone source if needed ----------
if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
    echo "==> Cloning open5gs v${OPEN5GS_VERSION} into ${SOURCE_DIR} ..."
    git clone --branch "v${OPEN5GS_VERSION}" "${OPEN5GS_REPO}" "${SOURCE_DIR}"
else
    echo "==> Source already present at ${SOURCE_DIR}"
fi

# Download meson subprojects so the container doesn't need network
echo "==> Downloading meson subprojects ..."
(cd "${SOURCE_DIR}" && meson subprojects download 2>/dev/null || true)

# ---------- prepare host directories ----------
mkdir -p "${OUTPUT_DIR}" "${CCACHE_DIR}"

# ---------- build image ----------
echo "==> Using ${CTR}"
echo "==> Building image '${IMAGE_NAME}' ..."
${CTR} build "${CTR_ARGS[@]}" -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

# ---------- run build ----------
CONTAINER_NAME="open5gs-build"
${CTR} rm -f "${CONTAINER_NAME}" 2>/dev/null || true

echo "==> Starting build container ..."
${CTR} run --name "${CONTAINER_NAME}" \
    -e "OPEN5GS_VERSION=${OPEN5GS_VERSION}" \
    -v "${SOURCE_DIR}:/src:ro,Z" \
    -v "${SCRIPT_DIR}:/spec:ro,Z" \
    -v "${OUTPUT_DIR}:/output:Z" \
    -v "${CCACHE_DIR}:/root/.ccache:Z" \
    "${IMAGE_NAME}"

echo ""
echo "==> Built RPMs:"
ls -lh "${OUTPUT_DIR}"/*.rpm 2>/dev/null || echo "(no RPMs found — check build log)"
echo ""
echo "==> Build tree at ${OUTPUT_DIR}/rpmbuild-BUILD/"
echo "==> Container '${CONTAINER_NAME}' kept for inspection:"
echo "    ${CTR} exec -it ${CONTAINER_NAME} sh"
echo "    ${CTR} rm ${CONTAINER_NAME}   # to clean up"
