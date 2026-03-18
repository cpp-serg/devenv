#!/bin/bash

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)
function die() {
  echo "$1" 1>&2
  exit 1
}

export PATH=$PATH:/usr/local/go/bin

go install github.com/jesseduffield/lazygit@latest || die "Failed to install lazygit"
[[ ! -d /opt/tools ]] && ${SUDO} mkdir /opt/tools
[[ ! -x /opt/tools ]] && ${SUDO} chmod a+rx /opt/tools

${SUDO} cp "$HOME/go/bin/lazygit" /opt/tools/ && ${SUDO} chmod 755 /opt/tools/lazygit

echo "lazygit installed successfully"
