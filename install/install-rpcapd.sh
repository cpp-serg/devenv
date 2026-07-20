#!/bin/bash

source "$(dirname "$0")/_install_preambule.sh"

${SUDO} dnf install -y ninja-build cmake flex
_workdir
git clone https://github.com/the-tcpdump-group/libpcap.git && cd libpcap
mkdir release && cd release
cmake -G Ninja -DBUILD_SHARED_LIBS=0 -DENABLE_REMOTE=1 -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/opt/libpcap ..
ninja && ${SUDO} ninja install

${SUDO} tee /etc/systemd/system/rpcapd.service > /dev/null <<EOF
[Unit]
Description=Rpcap Per-Connection Server
After=network.target

[Service]
ExecStart=/opt/libpcap/sbin/rpcapd -n

[Install]
WantedBy=multi-user.target
EOF

${SUDO} systemctl daemon-reload
${SUDO} systemctl enable --now rpcapd

