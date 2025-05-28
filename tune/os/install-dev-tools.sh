#!/bin/bash

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

${SUDO} dnf install -y \
    tar \
    make \
    bzip2 \
    unzip \
    python3 \
    sqlite \
    dos2unix \
    lbzip2 \
    git \
    git-lfs \
    cmake \
    gcc-c++ \
    ninja-build \
    ccache\
    gcc-toolset-13-gcc-c++ \
    gcc-toolset-14-gdb \
    gcc-toolset-13-libasan-devel \
    libxml2-devel \
    openssl-devel
