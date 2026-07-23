#!/usr/bin/env bash
#
# build.sh — clone and build UERANSIM inside a Rocky 8 container, storing all
# files on the host.
#
# This script lives in ~/devenv/install-suites/ueransim but is callable from
# anywhere. It operates on the CURRENT directory:
#
#   <cwd>/ueransim        <- git clone of the requested tag (on the host)
#   <cwd>/ueransim/build  <- CMake/Ninja build tree (on the host)
#   <cwd>/bin             <- assembled runtime artifacts (the outcome),
#                            kept OUTSIDE the clone
#
# The source directory is bind-mounted into a Rocky 8 build container; the
# compiler runs there, but every file it writes lands on the host mount.
# Podman is used if available, otherwise Docker.
#
# Usage:
#   cd /path/to/workspace
#   ~/devenv/install-suites/ueransim/build.sh
#
#   UERANSIM_VERSION=v3.2.6 ~/devenv/install-suites/ueransim/build.sh
#
set -euo pipefail

# ---- configuration ---------------------------------------------------------
UERANSIM_VERSION="${UERANSIM_VERSION:-v3.3.0}"
UERANSIM_REPO="${UERANSIM_REPO:-https://github.com/aligungr/UERANSIM.git}"
IMAGE_TAG="${IMAGE_TAG:-ueransim-buildenv:rocky8}"

# Where the support files (this script + Containerfile) live — used only to
# locate the Containerfile, independent of the current directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINERFILE="${SCRIPT_DIR}/Containerfile"

# All work happens relative to the caller's current directory.
WORK_DIR="$(pwd)"
SRC_DIR="${WORK_DIR}/ueransim"
BIN_DIR="${WORK_DIR}/bin"

# ---- pick a container engine (podman preferred) ----------------------------
if command -v podman >/dev/null 2>&1; then
    ENGINE=podman
elif command -v docker >/dev/null 2>&1; then
    ENGINE=docker
else
    echo "error: neither podman nor docker found on PATH" >&2
    exit 1
fi
echo ">> engine: ${ENGINE}    version: ${UERANSIM_VERSION}    workdir: ${WORK_DIR}"

# ---- clone (or reuse) the source on the host -------------------------------
if [ -d "${SRC_DIR}/.git" ]; then
    echo ">> source already present at ${SRC_DIR}, checking out ${UERANSIM_VERSION}"
    git -C "${SRC_DIR}" fetch --depth 1 origin tag "${UERANSIM_VERSION}"
    git -C "${SRC_DIR}" checkout -f "${UERANSIM_VERSION}"
else
    echo ">> cloning ${UERANSIM_REPO} (${UERANSIM_VERSION}) into ${SRC_DIR}"
    git clone --depth 1 --branch "${UERANSIM_VERSION}" "${UERANSIM_REPO}" "${SRC_DIR}"
fi

# ---- build the toolchain image ---------------------------------------------
echo ">> building build-env image ${IMAGE_TAG}"
"${ENGINE}" build -t "${IMAGE_TAG}" -f "${CONTAINERFILE}" "${SCRIPT_DIR}"

# ---- compile inside the container, writing back to the host mount ----------
# The ':Z' suffix relabels the mount for SELinux (Rocky 8 default). Under
# rootless podman, files written as container-root map back to the host user.
# The container only compiles; assembly of bin/ happens on the host so the
# outcome can live OUTSIDE the clone.
echo ">> compiling in container (build tree written to host)"
"${ENGINE}" run --rm \
    -v "${SRC_DIR}:/work:Z" \
    -w /work \
    "${IMAGE_TAG}" \
    bash -euo pipefail -c '
        cmake -B build -G Ninja -S . \
            -DCMAKE_EXPORT_COMPILE_COMMANDS=YES \
            -DCMAKE_BUILD_TYPE=RelWithDebInfo
        cmake --build build
    '

# ---- assemble the outcome directory on the host, outside the clone ---------
echo ">> assembling ${BIN_DIR}"
rm -rf "${BIN_DIR}"
mkdir -p "${BIN_DIR}"
cp "${SRC_DIR}/build/nr-gnb"       "${BIN_DIR}/"
cp "${SRC_DIR}/build/nr-ue"        "${BIN_DIR}/"
cp "${SRC_DIR}/build/nr-cli"       "${BIN_DIR}/"
cp "${SRC_DIR}/build/libdevbnd.so" "${BIN_DIR}/"
cp "${SRC_DIR}/tools/nr-binder"    "${BIN_DIR}/"
cp -r "${SRC_DIR}/config"          "${BIN_DIR}/config"
printf 'UERANSIM %s\n' "${UERANSIM_VERSION}" > "${BIN_DIR}/VERSION"

echo ">> done. artifacts at ${BIN_DIR}:"
ls -la "${BIN_DIR}"
