## ---------------------------------------------------------------------------
## Dockerfile — Open5GS RPM build environment for Rocky Linux 8.10
##
## This image contains only the build toolchain and dependencies.
## Source code, ccache, and output directory are mounted at runtime.
##
## Usage:
##   See build.sh
## ---------------------------------------------------------------------------

FROM rockylinux:8.10

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
        pkgconfig python3 python3-pip \
        ccache

# Rocky 8: python3.6 is too old for modern meson. Use python3.9.
# Install meson to system site-packages (rpmbuild strips /usr/local/).
RUN dnf -y module enable python39 && \
    dnf -y install python39 python39-pip && \
    alternatives --set python3 /usr/bin/python3.9 && \
    python3.9 -m pip install --prefix=/usr meson && \
    ln -sf /usr/bin/meson /usr/local/bin/meson

# Rocky 8.10 repo skew: powertools carries a libnghttp2-devel release
# (1.33.0-6.el8_10.3) newer than any libnghttp2 in baseos (-6.el8_10.2), and the
# devel subpackage requires an exact version match, so the newest devel is
# uninstallable. Pin devel to the base library version actually present.
RUN dnf -y install libnghttp2 && \
    dnf -y install "libnghttp2-devel-$(rpm -q --queryformat '%{VERSION}-%{RELEASE}' libnghttp2)"

# ---------- open5gs build dependencies ----------
RUN dnf -y install \
        lksctp-tools-devel \
        gnutls-devel \
        libgcrypt-devel \
        openssl-devel \
        libidn-devel \
        mongo-c-driver-devel \
        libyaml-devel \
        libmicrohttpd-devel \
        libcurl-devel \
        libtalloc-devel \
        systemd-rpm-macros \
    && dnf clean all

# ---------- configure ccache ----------
# Put ccache wrappers first in PATH so gcc/g++ calls go through ccache
RUN ln -s /usr/bin/ccache /usr/local/bin/gcc && \
    ln -s /usr/bin/ccache /usr/local/bin/g++ && \
    ln -s /usr/bin/ccache /usr/local/bin/cc && \
    ln -s /usr/bin/ccache /usr/local/bin/c++

ENV CCACHE_DIR=/root/.ccache
ENV PATH="/usr/local/bin:${PATH}"

# ---------- set up rpmbuild tree ----------
RUN rpmdev-setuptree

# ---------- entrypoint ----------
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
