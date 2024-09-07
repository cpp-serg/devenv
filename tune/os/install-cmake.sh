#!/bin/bash

CMAKE_VER=3.30.3

curl -fsSL https://github.com/Kitware/CMake/releases/download/v$CMAKE_VER/cmake-$CMAKE_VER-linux-x86_64.sh -o install_cmake.sh
sudo mkdir /opt/cmake && sudo sh install_cmake.sh --skip-license --exclude-subdir --prefix=/opt/cmake
rm install_cmake.sh
sudo update-alternatives --install /usr/local/bin/cmake cmake /opt/cmake/bin/cmake 100
sudo update-alternatives --install /usr/local/bin/ccmake ccmake /opt/cmake/bin/ccmake 100
sudo update-alternatives --install /usr/local/bin/ctest ctest /opt/cmake/bin/ctest 100

