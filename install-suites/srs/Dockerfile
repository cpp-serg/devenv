FROM rockylinux:8.10

# Enable repos and install build deps
RUN dnf install -y epel-release dnf-plugins-core && \
    dnf config-manager --set-enabled powertools && \
    dnf groupinstall -y "Development Tools" && \
    dnf install -y \
        cmake3 \
        gcc \
        gcc-c++ \
        fftw-devel \
        mbedtls-devel \
        boost-devel \
        boost-static \
        lksctp-tools-devel \
        libconfig-devel \
        zeromq-devel \
        czmq-devel \
        git \
        rpm-build \
        patchelf \
        && \
    dnf clean all

WORKDIR /build/srsran
