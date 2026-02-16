#!/bin/bash

MY_DIR=$(cd $(dirname $0); pwd)
INSTALL_DIR=$(cd ${MY_DIR}/../../install; pwd)
echo ${INSTALL_DIR}
# set ${SUDO} conditionally
SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

${SUDO} dnf install -y util-linux-user git git-lfs tar bzip2 unzip python3 sqlite htop ripgrep fd-find ninja-build make dos2unix lbzip2 cmake gcc-c++
# ${INSTALL_DIR}/install-git.sh
${INSTALL_DIR}/install-cmake.sh
${INSTALL_DIR}/install-tmux.sh
${INSTALL_DIR}/install-neovim.sh
${MY_DIR}/dotfiles/fzf/install --bin

