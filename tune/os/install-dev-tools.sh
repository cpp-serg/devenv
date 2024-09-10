#!/bin/bash

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

${SUDO} dnf install -y \
    gcc-toolset-13-gcc-c++ \
    gcc-toolset-13-gdb \
    gcc-toolset-13-libasan-devel \
    libxml2-devel \
    openssl-devel \
    ninja-build \
    cmake \
    ccache
