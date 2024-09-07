#!/bin/bash
TMUX_VER=3.4

# set ${SUDO} conditionally
SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

${SUDO} dnf install -y automake libevent-devel byacc ncurses-devel

git clone https://github.com/tmux/tmux.git --branch ${TMUX_VER} --single-branch && cd tmux
sh autogen.sh && ./configure --prefix=/opt/tmux && make -j
${SUDO} make install
cd .. && rm -rf tmux

${SUDO} update-alternatives --install /usr/local/bin/tmux tmux /opt/tmux/bin/tmux 100
hash -r  # reload hash table so that tmux is found
