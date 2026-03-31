#!/usr/bin/env bash
# build.sh — Build Open5GS RPMs for Rocky Linux 9 via Docker
#
# Usage:
#   ./build.sh              # build and extract RPMs to ./rpms/
#   ./build.sh --no-cache   # rebuild from scratch
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="open5gs-rpm-builder"
OUTPUT_DIR="${SCRIPT_DIR}/rpms"

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

echo "==> Using ${CTR}"
echo "==> Building image '${IMAGE_NAME}'..."
${CTR} build "${CTR_ARGS[@]}" -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

CONTAINER_NAME="open5gs-build"

echo "==> Extracting RPMs and build tree to ${OUTPUT_DIR}/"
mkdir -p "${OUTPUT_DIR}"
# Remove previous build container if it exists
${CTR} rm -f "${CONTAINER_NAME}" 2>/dev/null || true
${CTR} run --name "${CONTAINER_NAME}" -v "${OUTPUT_DIR}:/output:Z" "${IMAGE_NAME}"

echo ""
echo "==> Built RPMs:"
ls -lh "${OUTPUT_DIR}"/*.rpm 2>/dev/null || echo "(no RPMs found — check build log)"
echo ""
echo "==> Build tree at ${OUTPUT_DIR}/rpmbuild/"
echo "==> Container '${CONTAINER_NAME}' kept for inspection:"
echo "    ${CTR} exec -it ${CONTAINER_NAME} sh"
echo "    ${CTR} rm ${CONTAINER_NAME}   # to clean up"
