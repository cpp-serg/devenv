#!/bin/bash

DST_DIR=/opt/cmake

source "$(dirname "$0")/_install_preambule.sh"

# if first argument is not empty, use it as the version
# otherwise figure out latest version
if [ -n "${1:-}" ]; then
  CMAKE_VER=$1
else
  CMAKE_VER=$(curl -Ls --retry 3 --retry-delay 2 https://cmake.org/download | xmllint  --html --nowarning --xpath '//*[@id="latest"]/text()' - 2>/dev/null | sed -rn "s/.*\((.+)\)/\1/p")
fi

echo "Installing CMake version $CMAKE_VER"
if [[ -d $DST_DIR ]]; then
  echo "CMake is already installed in $DST_DIR. Remove it first."
  exit 0
fi

curl -fsSL --retry 3 --retry-delay 2 "https://github.com/Kitware/CMake/releases/download/v$CMAKE_VER/cmake-$CMAKE_VER-linux-$SYSTEM_ARCH.sh" -o install_cmake.sh || die "Failed to download CMake installer"
$SUDO mkdir /opt/cmake && $SUDO sh install_cmake.sh --skip-license --exclude-subdir --prefix="$DST_DIR"
rm install_cmake.sh

$SUDO update-alternatives --install /usr/local/bin/cmake cmake /opt/cmake/bin/cmake 100
$SUDO update-alternatives --install /usr/local/bin/ccmake ccmake /opt/cmake/bin/ccmake 100
$SUDO update-alternatives --install /usr/local/bin/ctest ctest /opt/cmake/bin/ctest 100
hash -r # reload hash table so that the new cmake is found
