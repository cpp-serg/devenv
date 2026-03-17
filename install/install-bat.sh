#!/bin/bash

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

die() {
  echo "$1" 1>&2
  exit 1
}

. "$HOME/.cargo/env"

cargo install bat || die "Failed to install bat"

[[ ! -d /opt/tools ]] && ${SUDO} mkdir /opt/tools
[[ ! -x /opt/tools ]] && ${SUDO} chmod a+rx /opt/tools

${SUDO} cp "$HOME/.cargo/bin/bat" /opt/tools/ && ${SUDO} chmod 755 /opt/tools/bat

echo "bat $(bat --version) installed successfully"
