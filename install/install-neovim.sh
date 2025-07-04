#!/bin/bash
# This script is used to build and install neovim from source

branch=${1:-stable}
dstDir=${2:-/opt/nvim}

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

function die() {
    echo "$1" 1>&2
    exit 1
}

currDir=$(basename $(pwd))
if [ "$currDir" != "neovim" ]; then
    git clone --depth 1 --branch ${branch}  https://github.com/neovim/neovim || die "Failed to clone neovim"
    pushd neovim
    delete=1
else
    echo "Already in neovim directory"
fi

[ -e .deps ] && rm -rf .deps
[ -e build ] && rm -rf build

cmake -S cmake.deps -B .deps -G Ninja -D CMAKE_BUILD_TYPE=Release -DUSE_BUNDLED=ON || die "Failed to configure neovim dependencies"
cmake --build .deps

cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=YES -DCMAKE_INSTALL_PREFIX=${dstDir} -DDEPS_PREFIX=$(pwd)/.deps/usr/ || die "Failed to configure neovim"
cmake --build build || die "Failed to build neovim"

${SUDO} rm -rf /opt/nvim || die "Failed to remove old neovim"
${SUDO} cmake --install build || die "Failed to install neovim"

${SUDO} update-alternatives --install /usr/local/bin/nvim nvim /opt/nvim/bin/nvim 100
# ${SUDO} update-alternatives --install /usr/local/bin/vim vim /usr/local/bin/nvim 100
# ${SUDO} update-alternatives --install /usr/local/bin/vi vi /usr/local/bin/nvim 100
hash -r  # reload hash table so that new version of nvim is found

if [[ $delete -eq 1 ]]; then
    popd
    rm -rf neovim
fi

