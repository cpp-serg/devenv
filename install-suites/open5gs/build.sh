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

# Build artifacts go in the directory you run this from, not next to the
# scripts, so the suite checkout stays clean and separate working directories
# can hold independent builds. Set WORK_DIR to override.
: "${WORK_DIR:=$(pwd)}"

IMAGE_NAME="open5gs-rpm-builder"
OUTPUT_DIR="${WORK_DIR}/rpms"
SOURCE_DIR="${WORK_DIR}/open5gs-source"
CCACHE_DIR="${WORK_DIR}/cont_ccache"
OPEN5GS_REPO="https://github.com/open5gs/open5gs.git"
VERSION_ENV="${SCRIPT_DIR}/version.env"

# Version comes from version.env only — never hardcode it here. It drives the
# upstream tag, the rpmbuild BUILD path and the RPM version, which must agree.
if [[ ! -f "${VERSION_ENV}" ]]; then
    echo "ERROR: ${VERSION_ENV} not found" >&2
    exit 1
fi
# shellcheck source=version.env
source "${VERSION_ENV}"
echo "==> Building open5gs ${OPEN5GS_VERSION}-${OPEN5GS_RELEASE} (from version.env)"
echo "==> Work dir: ${WORK_DIR}"

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
TAG="v${OPEN5GS_VERSION}"
if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
    echo "==> Cloning open5gs ${TAG} into ${SOURCE_DIR} ..."
    git clone --branch "${TAG}" "${OPEN5GS_REPO}" "${SOURCE_DIR}"
else
    # An existing clone may sit on a different tag, and will still carry the
    # previous run's applied patches. Reset it to a pristine tag so the patches
    # below apply exactly once. Untracked files (the subprojects cache) are kept.
    if ! git -C "${SOURCE_DIR}" rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
        echo "==> Fetching tags to find ${TAG} ..."
        git -C "${SOURCE_DIR}" fetch --tags origin
    fi
    echo "==> Resetting ${SOURCE_DIR} to pristine ${TAG}"
    echo "    (discards local modifications to tracked files; patches re-applied below)"
    git -C "${SOURCE_DIR}" checkout --force --detach "refs/tags/${TAG}"
fi

# Download meson subprojects so the container doesn't need network
echo "==> Downloading meson subprojects ..."
(cd "${SOURCE_DIR}" && meson subprojects download 2>/dev/null || true)

# ---------- apply patches ----------
PATCHES_DIR="${SCRIPT_DIR}/patches"
if [[ -d "${PATCHES_DIR}" ]]; then
    shopt -s nullglob
    patches=("${PATCHES_DIR}"/*.patch)
    shopt -u nullglob
    if [[ ${#patches[@]} -gt 0 ]]; then
        echo "==> Applying patches from ${PATCHES_DIR} ..."
        for p in "${patches[@]}"; do
            if (cd "${SOURCE_DIR}" && git apply --check "$p" 2>/dev/null); then
                echo "  Applying: $(basename "$p")"
                (cd "${SOURCE_DIR}" && git apply "$p")
            elif (cd "${SOURCE_DIR}" && git apply --reverse --check "$p" 2>/dev/null); then
                # Reverse-applies cleanly, so it is already in the tree.
                echo "  Already applied, skipping: $(basename "$p")"
            else
                # Neither forward nor reverse: the patch does not fit this
                # version. Silently skipping would ship an RPM missing it.
                echo "ERROR: patch does not apply to ${TAG}: $(basename "$p")" >&2
                exit 1
            fi
        done
    fi
fi

# ---------- prepare host directories ----------
mkdir -p "${OUTPUT_DIR}" "${CCACHE_DIR}"

# ---------- build image ----------
echo "==> Using ${CTR}"
echo "==> Building image '${IMAGE_NAME}' ..."
${CTR} build "${CTR_ARGS[@]}" -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

# ---------- run build ----------
CONTAINER_NAME="open5gs-build"
${CTR} rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Mount source directly into rpmbuild's BUILD directory so meson
# reuses its build tree across runs (true incremental builds).
BUILD_MOUNT="/root/rpmbuild/BUILD/open5gs-${OPEN5GS_VERSION}"

# The meson build directory lives inside the mounted source tree so builds are
# incremental across runs. It caches absolute paths, including the versioned
# BUILD directory above, and is untracked so the git reset does not clear it.
# After a version bump it would still point at the old path and meson would
# fail with "Neither source directory ... contain a build file meson.build".
# Drop only a build dir configured for a different path; an unchanged version
# keeps its cache and stays incremental.
shopt -s nullglob
for info in "${SOURCE_DIR}"/*/meson-info/meson-info.json; do
    builddir="$(dirname "$(dirname "${info}")")"
    if ! grep -q "\"${BUILD_MOUNT}\"" "${info}"; then
        echo "==> Removing stale meson build dir $(basename "${builddir}") (configured for another version)"
        rm -rf "${builddir}"
    fi
done
shopt -u nullglob

echo "==> Starting build container ..."
${CTR} run --name "${CONTAINER_NAME}" \
    -e "OPEN5GS_VERSION=${OPEN5GS_VERSION}" \
    -e "OPEN5GS_RELEASE=${OPEN5GS_RELEASE}" \
    -v "${SOURCE_DIR}:${BUILD_MOUNT}:Z" \
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
