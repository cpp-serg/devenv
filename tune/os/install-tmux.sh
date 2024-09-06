#!/bin/bash
TMUX_VER=3.4

dnf install -y automake libevent-devel byacc ncurses-devel
git clone https://github.com/tmux/tmux.git --branch ${TMUX_VER} --single-branch && cd tmux
sh autogen.sh && ./configure --prefix=/opt/tmux && make -j
sudo make install
cd .. && rm -rf tmux
sudo update-alternatives --install /usr/local/bin/tmux tmux /opt/tmux/bin/tmux 100
