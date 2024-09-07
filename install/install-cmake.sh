#!/bin/bash

DST_DIR=/opt/cmake

function die() {
  echo "$1"
  exit 1
}

# set ${SUDO} conditionally
SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

# if first argument is not empty, use it as the version
# otherwise figure out latest version
if [ -n "$1" ]; then
  CMAKE_VER=$1
else
  CMAKE_VER=$(curl -Ls https://cmake.org/download | xmllint  --html --nowarning --xpath '//*[@id="latest"]/text()' - 2>/dev/null | sed -rn "s/.*\((.+)\)/\1/p")
fi

echo "Installing CMake version $CMAKE_VER"
if [[ -d $DST_DIR ]]; then
  echo "CMake is already installed in $DST_DIR. Remove it first."
  exit 0
fi

curl -fsSL https://github.com/Kitware/CMake/releases/download/v$CMAKE_VER/cmake-$CMAKE_VER-linux-x86_64.sh -o install_cmake.sh || die "Failed to download CMake installer"
$SUDO mkdir /opt/cmake && $SUDO sh install_cmake.sh --skip-license --exclude-subdir --prefix=$DST_DIR

$SUDO alternatives --install /usr/local/bin/cmake cmake /opt/cmake/bin/cmake 100
$SUDO alternatives --install /usr/local/bin/ccmake ccmake /opt/cmake/bin/ccmake 100
$SUDO alternatives --install /usr/local/bin/ctest ctest /opt/cmake/bin/ctest 100
hash -r # reload hash table so that the new cmake is found
