## ---------------------------------------------------------------------------
## Dockerfile — build Open5GS RPMs on Rocky Linux 8.10
##
## Usage:
##   podman build -t open5gs-rpm-builder .
##   podman run --name open5gs-build -v "$PWD/rpms:/output:Z" open5gs-rpm-builder
##
## The resulting RPMs will appear in ./rpms/ on the host.
## The full rpmbuild tree (BUILD, BUILDROOT, RPMS) is at ./rpms/rpmbuild/.
## ---------------------------------------------------------------------------

FROM rockylinux:8.10 AS builder

ARG OPEN5GS_VERSION=2.7.7
ARG OPEN5GS_REPO=https://github.com/open5gs/open5gs.git

# ---------- enable repos & install base tools ----------
RUN dnf -y install epel-release dnf-plugins-core && \
    dnf config-manager --set-enabled powertools && \
    dnf -y update

# ---------- build tools ----------
RUN dnf -y install \
        rpm-build rpmdevtools \
        git-core \
        gcc gcc-c++ \
        ninja-build cmake \
        bison flex \
        pkgconfig python3 python3-pip

# Rocky 8: python3.6 is too old for modern meson. Use python3.9.
# Install meson to system site-packages (rpmbuild strips /usr/local/).
RUN dnf -y module enable python39 && \
    dnf -y install python39 python39-pip && \
    alternatives --set python3 /usr/bin/python3.9 && \
    python3.9 -m pip install --prefix=/usr meson && \
    ln -sf /usr/bin/meson /usr/local/bin/meson

# ---------- open5gs build dependencies ----------
RUN dnf -y install \
        lksctp-tools-devel \
        gnutls-devel \
        libgcrypt-devel \
        openssl-devel \
        libidn-devel \
        mongo-c-driver-devel \
        libyaml-devel \
        libnghttp2-devel \
        libmicrohttpd-devel \
        libcurl-devel \
        libtalloc-devel \
        systemd-rpm-macros \
    && dnf clean all

# ---------- set up rpmbuild tree ----------
RUN rpmdev-setuptree

# ---------- clone source & create tarball ----------
RUN git clone --depth 1 --branch v${OPEN5GS_VERSION} ${OPEN5GS_REPO} \
        /tmp/open5gs-${OPEN5GS_VERSION}

# Meson subprojects: download wraps upfront so rpmbuild doesn't need network
RUN cd /tmp/open5gs-${OPEN5GS_VERSION} && \
    meson subprojects download || true

# Create the source tarball expected by the spec's %setup -q
RUN tar czf /root/rpmbuild/SOURCES/open5gs-${OPEN5GS_VERSION}.tar.gz \
        -C /tmp open5gs-${OPEN5GS_VERSION} && \
    rm -rf /tmp/open5gs-${OPEN5GS_VERSION}

# ---------- copy spec ----------
COPY open5gs.spec /root/rpmbuild/SPECS/open5gs.spec

# ---------- build RPMs (--noclean keeps BUILDROOT) ----------
# QA_RPATHS=0x0001: allow standard RPATHs (/usr/lib64) that meson embeds
RUN QA_RPATHS=0x0001 rpmbuild -bb --noclean \
        --undefine=_disable_source_fetch \
        /root/rpmbuild/SPECS/open5gs.spec \
        2>&1 | tee /tmp/rpmbuild.log || \
    { echo "=== RPM BUILD FAILED ===" ; tail -100 /tmp/rpmbuild.log ; exit 1 ; }

# Drop the source tarball to save space in the output layer
RUN rm -f /root/rpmbuild/SOURCES/*.tar.gz

# ---------- lightweight output stage ----------
FROM rockylinux:8.10-minimal

COPY --from=builder /root/rpmbuild/BUILD/ /rpmbuild/BUILD/
COPY --from=builder /root/rpmbuild/BUILDROOT/ /rpmbuild/BUILDROOT/
COPY --from=builder /root/rpmbuild/RPMS/ /rpmbuild/RPMS/
COPY --from=builder /root/rpmbuild/SPECS/ /rpmbuild/SPECS/

# Default: copy RPMs and rpmbuild tree to /output
CMD ["sh", "-c", "cp -rv /rpmbuild/RPMS/*/*.rpm /output/ && cp -a /rpmbuild /output/rpmbuild && echo '=== Done ==='"]
