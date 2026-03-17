#!/bin/bash

SUDO=$([ $(id -u) -ne 0 ] && echo sudo)

function die() {
  echo "$1" 1>&2
  exit 1
}

. "$HOME/.cargo/env"

cargo install git-delta || die "Failed to install delta"

[[ ! -d /opt/tools ]] && ${SUDO} mkdir /opt/tools
[[ ! -x /opt/tools ]] && ${SUDO} chmod a+rx /opt/tools

${SUDO} cp "$HOME/.cargo/bin/delta" /opt/tools/ && ${SUDO} chmod 755 /opt/tools/delta

echo "delta $(delta --version) installed successfully"
