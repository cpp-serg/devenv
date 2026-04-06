#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="srsran4g-builder"
OUTPUT_DIR="${SCRIPT_DIR}/output"
SRSRAN_SRC="${SCRIPT_DIR}/srsran_src"

echo "=== Building srsRAN 4G RPMs for Rocky Linux 8.10 ==="

# Clone sources locally if not already present
if [ -d "${SRSRAN_SRC}/.git" ]; then
    echo "--- Source directory already exists, skipping clone ---"
else
    echo "--- Cloning srsRAN 4G sources ---"
    git clone --depth 1 --branch release_23_11 https://github.com/srsran/srsRAN_4G.git "${SRSRAN_SRC}"
fi

# Build the builder image (deps only)
echo "--- Building container image ---"
podman build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

# Build inside container with mounted source
echo "--- Building srsRAN inside container ---"
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

podman run --rm \
    -v "${SRSRAN_SRC}:/build/srsran:Z" \
    -v "${SCRIPT_DIR}/srsran4g.spec:/staging/srsran4g.spec:ro,Z" \
    -v "${SCRIPT_DIR}/install-deps.sh:/staging/install-deps.sh:ro,Z" \
    -v "${OUTPUT_DIR}:/output:Z" \
    "${IMAGE_NAME}" \
    bash -c '
set -euo pipefail

# Clean and create build directory
rm -rf /build/srsran/build
mkdir -p /build/srsran/build
cd /build/srsran/build
cmake3 .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_ZEROMQ=ON \
    -DBoost_USE_STATIC_LIBS=ON \
    -DENABLE_RF_PLUGINS=OFF
make -j$(nproc)

# Stage artifacts
mkdir -p /staging/configs
cp /build/srsran/build/srsenb/src/srsenb /staging/
cp /build/srsran/build/srsue/src/srsue /staging/
cp /build/srsran/build/srsepc/src/srsepc /staging/
cp /build/srsran/build/srsepc/src/srsmbms /staging/
# Configs
cp /build/srsran/srsenb/enb.conf.example /staging/configs/
cp /build/srsran/srsenb/rr.conf.example /staging/configs/
cp /build/srsran/srsenb/sib.conf.example /staging/configs/
cp /build/srsran/srsenb/rb.conf.example /staging/configs/
cp /build/srsran/srsue/ue.conf.example /staging/configs/
cp /build/srsran/srsepc/epc.conf.example /staging/configs/
cp /build/srsran/srsepc/mbms.conf.example /staging/configs/

# Build RPMs
mkdir -p /root/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
cp /staging/srsran4g.spec /root/rpmbuild/SPECS/
cp /staging/srsenb /root/rpmbuild/BUILD/
cp /staging/srsue /root/rpmbuild/BUILD/
cp -r /staging/configs /root/rpmbuild/BUILD/
rpmbuild -bb /root/rpmbuild/SPECS/srsran4g.spec \
    --define "_topdir /root/rpmbuild"

# Collect all artifacts into /output
mkdir -p /output/bin/config
cp /root/rpmbuild/RPMS/*/*.rpm /output/
# Binaries
cp /staging/srsenb /output/bin/
cp /staging/srsue /output/bin/
cp /staging/srsepc /output/bin/
cp /staging/srsmbms /output/bin/
# Config files
for f in /staging/configs/*.conf.example; do
    base=$(basename "$f" .example)
    cp "$f" "/output/bin/config/${base}"
done
cp /staging/configs/*.conf.example /output/bin/config/
# Install-deps script
cp /staging/install-deps.sh /output/bin/install-deps.sh
chmod +x /output/bin/install-deps.sh
echo "=== Build artifacts ==="
ls -laR /output/
'

echo ""
echo "=== Build complete ==="
echo "Artifacts in ${OUTPUT_DIR}:"
ls -la "${OUTPUT_DIR}/"
