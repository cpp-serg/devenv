#!/bin/bash
TMUX_VER=3.6a
source "$(dirname "$0")/_install_preambule.sh"

${SUDO} dnf install -y automake libevent-devel byacc ncurses-devel

_workdir
git clone https://github.com/tmux/tmux.git --branch "${TMUX_VER}" --single-branch && cd tmux
sh autogen.sh && ./configure --prefix=/opt/tmux && make -j
${SUDO} make install

${SUDO} update-alternatives --install /usr/local/bin/tmux tmux /opt/tmux/bin/tmux 100
hash -r  # reload hash table so that tmux is found
