#!/bin/bash
# Build SigScale OCS in a Podman container and extract artifacts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CLEAN=0
while getopts "c" opt; do
    case ${opt} in
        c) CLEAN=1 ;;
        *) echo "Usage: $0 [-c]  (-c for clean/no-cache build)"; exit 1 ;;
    esac
done

# Clone OCS source if it doesn't exist
if [ ! -d ocs ]; then
    echo "Cloning OCS source..."
    git clone https://github.com/sigscale/ocs.git ocs
elif [ ! -f ocs/configure.ac ]; then
    echo "ERROR: ocs/ exists but configure.ac not found."
    exit 1
fi

OCS_VSN=$(sed -n 's/^AC_INIT(\[ocs\], \[\(.*\)\],.*/\1/p' ocs/configure.ac)
echo "Building OCS v${OCS_VSN}..."

# Build container image
BUILD_ARGS=""
if [ "$CLEAN" -eq 1 ]; then
    BUILD_ARGS="--no-cache"
fi
podman build ${BUILD_ARGS} -t ocs-builder -f Containerfile .

# Extract artifacts
echo "Extracting artifacts..."
rm -rf output/
mkdir -p output/
CONTAINER=$(podman create ocs-builder)
podman cp "${CONTAINER}:/artifacts/." output/
podman rm "${CONTAINER}" > /dev/null

echo ""
echo "Build complete. Artifacts in output/:"
find output/ -type f | sort
echo ""
echo "Release tarball: output/ocs-${OCS_VSN}.tar.gz"
